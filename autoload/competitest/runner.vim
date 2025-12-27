vim9script
# File: autoload\competitest\runner.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: A class that manage all testcases' process.
# Last Modified: 2025-11-22

import autoload "./utils.vim"
import autoload "./config.vim" as cfg
import autoload "./runner_ui.vim"

# System command with arguments
class SystemCommand # {{{
  const exec: string
  const args: list<string>
endclass # }}}

export class TestcaseData # {{{
  const ans_bufnr: number
  const stdin_bufnr: number
  const stdout_bufnr: number
  const stderr_bufnr: number
  const ans_bufname: string
  const stdin_bufname: string
  const stdout_bufname: string
  const stderr_bufname: string
  const tcnum: string
  const timelimit: number

  var job: job = null_job
  var status: string = null_string
  var killed: bool = false
  var running: bool = false
  var hlgroup: string = null_string
  var timer: number = 0
  var time: float = 0.0
  var starting_time: list<number> = null_list
  var exit_code: number = 0

  def JobStart(command: list<string>, dir: string, CallBack: func(): void, compare_method: any): void # {{{
    final options = {
      cwd: dir,
      out_io: "buffer",
      out_buf: this.stdout_bufnr,
      err_io: "buffer",
      err_buf: this.stderr_bufnr,
      exit_cb: (job: job, status: number) => {
        this.JobExit(status, compare_method, CallBack)
      }
    }

    if this.stdin_bufnr == 0
      options.in_io = "null"
    else
      # It is faster than "buffer"
      options.in_io = "file"
      options.in_name = this.stdin_bufname
    endif

    this.job = job_start(command, options)

    if job_status(this.job) != "run"
      this.status = "FAILED"
      this.hlgroup = "CompetiTestWarning"
      throw "JobStart: failed to start: " .. string(command)
    endif

    # Set timeout timer
    if this.timelimit != 0
      this.timer = timer_start(this.timelimit, (_: number) => this.JobKill())
    endif

    # Update state
    this.starting_time = reltime()
    this.status = "RUNNING"
    this.hlgroup = "CompetiTestRunning"
    this.running = true
    this.killed = false
  enddef # }}}

  def JobKill() # {{{
    this.job->job_stop("kill")
    this.killed = true
  enddef # }}}

  def JobExit(status: number, compare_method: any, CallBack: func) # {{{
    this.running = false
    this.time = reltime(this.starting_time)->reltimefloat() * 1000
    this.exit_code = status

    timer_stop(this.timer)
    this.timer = 0

    # Determine status
    if this.killed
      if this.timelimit != 0 && this.time >= this.timelimit
        this.status = "TIMEOUT"
        this.hlgroup = "CompetiTestWrong"
      else
        this.status = "KILLED"
        this.hlgroup = "CompetiTestWarning"
      endif
    else
      if status != 0
        this.status = "RET " .. status
        this.hlgroup = "CompetiTestWarning"
      else
        if this.ans_bufnr == 0
          this.status = "DONE"
          this.hlgroup = "CompetiTestDone"
        else
          const correct = CompareOutput(this.stdout_bufnr, this.ans_bufnr, compare_method)
          if correct == true
            this.status = "CORRECT"
            this.hlgroup = "CompetiTestCorrect"
          elseif correct == false
            this.status = "WRONG"
            this.hlgroup = "CompetiTestWrong"
          endif
        endif
      endif
    endif

    CallBack()
  enddef # }}}

endclass # }}}

# Testcase Runner class
export class TCRunner
  const cc: SystemCommand
  const rc: SystemCommand
  const compile_directory: string
  const running_directory: string
  const bufnr: number
  const config: dict<any>
  var compile: bool
  var next_tc: number = 0
  var tcdata: list<TestcaseData> = []
  var ui: runner_ui.RunnerUI

  def new(bufnr: number) # {{{
    const filetype = getbufvar(bufnr, "&filetype")
    const bufname = bufname(bufnr)
    const filedir = (empty(bufname) ? getcwd() : fnamemodify(bufname, ":p:h")) .. "/"

    # Evaluate CompetiTest file-format modifiers
    def EvalCommand(cmd: dict<any>): SystemCommand
      var exec = utils.BufEvalString(bufnr, cmd.exec, null_string)
      if exec == null_string
        return null_object
      endif
      if exec[0] == "."
        exec = filedir .. exec
      endif
      final args = [] # null_list can't be added
      if !cmd->has_key("args")
        return SystemCommand.new(exec, args)
      endif
      for arg in cmd.args
        const eval_arg = utils.BufEvalString(bufnr, arg, null_string)
        if eval_arg == null_string
          break
        endif
        args->add(eval_arg)
      endfor
      return SystemCommand.new(exec, args)
    enddef

    const buf_cfg = cfg.GetBufferConfig(bufnr)

    this.cc = (): SystemCommand => {
      if buf_cfg.compile_command->has_key(filetype) && buf_cfg.compile_command[filetype] != null_object
        const cmd = EvalCommand(buf_cfg.compile_command[filetype])
        if cmd == null_object
          throw $"TCRunner.new: compile command for filetype \"{filetype}\" isn't formatted properly"
        endif
        return cmd
      endif
      return null_object
    }()

    if !buf_cfg.run_command->has_key(filetype) || buf_cfg.run_command[filetype] == null_object
      throw $"TCRunner.new: run command for filetype \"{filetype}\" isn't configured"
    endif
    this.rc = EvalCommand(buf_cfg.run_command[filetype])
    if this.rc == null_object
      throw $"TCRunner.new: run command for filetype \"{filetype}\" isn't formatted properly"
    endif

    this.config = buf_cfg
    this.bufnr = bufnr
    this.compile_directory = filedir .. buf_cfg.compile_directory .. "/"
    this.running_directory = filedir .. buf_cfg.running_directory .. "/"
    this.compile = this.cc != null_object
  enddef # }}}

  def RunTestcase(tcindex: number) # {{{
    if tcindex == 0 && this.compile
      this.ExecuteTestcase(tcindex, this.cc, this.compile_directory)
    else
      this.ExecuteTestcase(tcindex, this.rc, this.running_directory)
    endif
  enddef # }}}

  def RunAndInitTestcases(tctbl: dict<any>, compile: bool = true) #{{{
    # Init Testcases {{{
    if tctbl != null_dict
      if this.config.save_all_files
        wall
      elseif this.config.save_current_file
        update
      endif

      def InitBuf(bufname: string, mode: string): number # {{{
        const bufnr = bufadd(bufname)
        setbufvar(bufnr, "&buftype", "nofile")
        setbufvar(bufnr, "&bufhidden", "hide")
        setbufvar(bufnr, "&filetype", "competitest_" .. mode)

        return bufnr
      enddef # }}}

      this.tcdata = []
      this.compile = compile && (this.cc != null_object)
      if this.compile
        add(this.tcdata, TestcaseData.new(
          0,                                                # ans_bufnr
          0,                                                # stdin_bufnr
          InitBuf(this.bufnr .. "_stdout_compile", "out"),  # stdour_bufnr
          InitBuf(this.bufnr .. "_stderr_compile", "err"),  # stderr_bufnr
          "",                                               # ans_bufname
          "",                                               # stdin_bufname
          this.bufnr .. "_stdout_compile",                  # stdout_bufname
          this.bufnr .. "_stderr_compile",                  # stderr_bufname
          "Compile",                                        # tcnum
          0))                                               # timelimit
      endif

      const keys = keys(tctbl)->sort((u, v) => {
        return str2nr(u) < str2nr(v) ? -1 : 1
      })

      for tcnum in keys
        const tc = tctbl[tcnum]
        add(this.tcdata,
          TestcaseData.new(
            tc.ans_bufnr,                                   # ans_bufnr
            tc.input_bufnr,                                 # stdin_bufnr
            InitBuf($"{this.bufnr}_stdout_{tcnum}", "out"), # stdour_bufnr
            InitBuf($"{this.bufnr}_stderr_{tcnum}", "err"), # stderr_bufnr
            tc.ans_bufname,                                 # ans_bufname
            tc.input_bufname,                               # stdin_bufname
            $"{this.bufnr}_stdout_{tcnum}",                 # stdout_bufname
            $"{this.bufnr}_stderr_{tcnum}",                 # stderr_bufname
            tcnum,                                          # tcnum
            this.config.maximum_time))                      # timelimit
      endfor
    endif # }}}
    this.RunTestcases()
  enddef # }}}

  def RunTestcases() # {{{
    const tc_size = len(this.tcdata)
    var mut = this.config.multiple_testing
    if mut == -1
      mut = parallelism_ability
      if mut <= 0
        mut = 1
      endif
    elseif mut == 0
      mut = tc_size
    endif
    mut = min([mut, tc_size])
    this.next_tc = 0

    def RunFirstTestcases()
      const start = this.next_tc
      this.next_tc = start + mut
      for idx in range(start, min([start + mut - 1, tc_size - 1]))
        this.ExecuteTestcase(idx, this.rc, this.running_directory, this.RunNextTestcase)
      endfor
    enddef

    if !this.compile
      RunFirstTestcases()
    else
      this.next_tc = 1
      def CompileCallBack()
        if this.tcdata[0].exit_code == 0
          RunFirstTestcases()
        endif
      enddef
      this.ExecuteTestcase(0, this.cc, this.compile_directory, CompileCallBack)
    endif
  enddef # }}}

  def RunNextTestcase() # {{{
    if this.next_tc > len(this.tcdata) - 1
      return
    endif
    const current_tc = this.next_tc
    this.next_tc += 1
    this.ExecuteTestcase(current_tc, this.rc, this.running_directory, this.RunNextTestcase)
  enddef # }}}

  def ExecuteTestcase(tcindex: number, cmd: SystemCommand, dir: string, CallBack: func(): void = null_function) # {{{
    const tc = this.tcdata[tcindex]

    if tc.running
      return
    endif

    deletebufline(tc.stdout_bufnr,  1, "$")
    deletebufline(tc.stderr_bufnr,  1, "$")

    utils.CreateDirectory(dir)
    final command = [cmd.exec]
    if cmd.args != null_list
      command->extend(cmd.args)
    endif

    try
      tc.JobStart(
        command,
        dir,
        () => {
          this.UpdateUI()
          if CallBack != null_function
            CallBack() # RunNextTestcase()
          endif
        },
        this.config.output_compare_method)
    catch /^JobStart:/
      utils.EchoErr(v:exception)
      this.UpdateUI()
      return
    endtry

    this.UpdateUI()
  enddef # }}}

  def KillProcess(tcindex: number) # {{{
    const tc = this.tcdata[tcindex]
    if !tc.running || tc.job == null_job
      return
    endif
    tc.JobKill()
  enddef # }}}

  def KillAllProcesses() # {{{
    for idx in range(len(this.tcdata))
      this.KillProcess(idx)
    endfor
  enddef # }}}

  def ShowUI() # {{{
    if this.ui == null_object
      this.ui = runner_ui.RunnerUI.new(this)
    endif
    this.ui.Show()
    this.ui.Update()
  enddef # }}}

  def UpdateUI() # {{{
    if this.ui != null_object && this.ui.visible
      this.ui.Update()
    endif
  enddef # }}}
endclass

# Compare Output {{{
# Builtin methods to compare output and expected output
const methods = { # {{{
  exact: (output: string, expout: string) => output == expout,
  squish: (output: string, expout: string) => {
    def SquishString(str: string): string
      return str
        ->trim()
        ->substitute('\n', " ", "g")
        ->substitute('\s\+', " ", "g")
    enddef
    return SquishString(output) == SquishString(expout)
  },
} # }}}

def CompareOutput(out_bufnr: number, ans_bufnr: number, method: any): bool # {{{
  silent bufload(ans_bufnr)
  sleep 1m # should wait, for datas aren't fully loaded

  # For some unknown reasons, somtimes will mixed with some ^M
  const output = getbufline(out_bufnr, 1, "$")->join("\n")->substitute("\r\n", "\n", "g")
  const answer = getbufline(ans_bufnr, 1, "$")->join("\n")->substitute("\r\n", "\n", "g")

  if type(method) == v:t_string && methods->has_key(method)
    return methods[method](output, answer)
  elseif type(method) == v:t_func
    const Method = method
    return Method(output, answer)
  else
    utils.EchoErr("CompareOutput: unrecognized method " .. string(method))
    return false
  endif
enddef # }}}
# }}}

const parallelism_ability = (): number => { # {{{
  if executable("nproc") # On Unix-like OS
    const result = systemlist("nproc --all")
    if !empty(result) && result[0] =~ '^\d\+$'
      return str2nr(result[0])
    endif
  elseif executable("wmic") # On Windows OS
    const result = systemlist("wmic cpu get NumberOfCores")
    if len(result) > 1 && result[1]->substitute('[^0-9]', "", "g") =~ '^\d\+$'
      return str2nr(result[1]->substitute('[^0-9]', "", "g"))
    endif
  endif
  return 1 # default
}() # }}}
