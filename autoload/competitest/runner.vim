vim9script
# File: autoload\competitest\runner.vim
# Author: mao-yining <mao.yining@outlook.com>
# Description: A class that manage all testcases' process.
# Last Modified: 2025-08-30

import autoload './utils.vim'
import autoload './config.vim' as cfg
import autoload './runner_ui.vim'

# System command with arguments
class SystemCommand # {{{
  var exec: string
  var args: list<string>
endclass # }}}

export class TestcaseData # {{{
  var ans_bufnr: number
  var stdin_bufnr: number
  var stdout_bufnr: number
  var stderr_bufnr: number
  var ans_bufname: string
  var stdin_bufname: string
  var stdout_bufname: string
  var stderr_bufname: string
  var tcnum: string
  public var job: job
  public var status: string
  public var killed: bool
  public var running: bool
  public var hlgroup: string
  public var timelimit: number
  public var timer: number
  public var time: float
  public var starting_time: list<number>
  public var exit_code: number
  def new(
      this.ans_bufnr,
      this.stdin_bufnr,
      this.stdout_bufnr,
      this.stderr_bufnr,
      this.ans_bufname,
      this.stdin_bufname,
      this.stdout_bufname,
      this.stderr_bufname,
      this.tcnum,
      this.timelimit)
  enddef
endclass # }}}

# Testcase Runner class
export class TCRunner
  # var {{{
  var config: dict<any>
  var bufnr: number
  var cc: SystemCommand
  var rc: SystemCommand
  var compile_directory: string
  var running_directory: string
  var tcdata: list<TestcaseData>
  var compile: bool
  var next_tc: number
  var ui: runner_ui.RunnerUI
  # }}}

  def new(bufnr: number) # {{{
    var filetype = getbufvar(bufnr, '&filetype')
    var bufname = bufname(bufnr)
    var filedir = bufname != '' ? fnamemodify(bufname, ':p:h') : getcwd()
    if filedir[-1] != '/'
      filedir ..= '/'
    endif

    # Evaluate CompetiTest file-format modifiers
    def EvalCommand(cmd: dict<any>): SystemCommand
      var exec = utils.BufEvalString(bufnr, cmd.exec, null_string)
      if exec == null_string
        return null_object
      endif
      if exec[0] == '.'
        exec = filedir .. exec
      endif
      var args = [] # null_list can't be added
      if !has_key(cmd, 'args')
        return SystemCommand.new(exec, args)
      endif
      for arg in cmd.args
        var eval_arg = utils.BufEvalString(bufnr, arg, null_string)
        if eval_arg == null_string
          break
        endif
        args->add(eval_arg)
      endfor
      return SystemCommand.new(exec, args)
    enddef

    var buf_cfg = cfg.GetBufferConfig(bufnr)
    var compile_command = null_object
    if has_key(buf_cfg.compile_command, filetype) && buf_cfg.compile_command[filetype] != null_object
      compile_command = EvalCommand(buf_cfg.compile_command[filetype])
      if compile_command == null_object
        throw $"TCRunner.new: compile command for filetype '{filetype}' isn't formatted properly"
      endif
    endif

    if !has_key(buf_cfg.run_command, filetype) || buf_cfg.run_command[filetype] == null_object
      throw $"TCRunner.new: run command for filetype '{filetype}' isn't configured"
    endif
    var run_command = EvalCommand(buf_cfg.run_command[filetype])
    if run_command == null_object
      throw $"TCRunner.new: run command for filetype '{filetype}' isn't formatted properly"
    endif

    this.config = buf_cfg
    this.bufnr = bufnr
    this.cc = compile_command
    this.rc = run_command
    this.compile_directory = (filedir .. buf_cfg.compile_directory .. '/')
    this.running_directory = (filedir .. buf_cfg.running_directory .. '/')
    this.tcdata = []
    this.compile = (compile_command != null_object)
    this.next_tc = 0
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
        write
      endif

      def InitBuf(bufname: string, mode: string): number # {{{
        var bufnr = bufadd(bufname)
        setbufvar(bufnr, '&buftype', 'nofile')
        setbufvar(bufnr, '&bufhidden', 'hide')
        setbufvar(bufnr, '&filetype', "competitest_" .. mode)

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
          '',                                               # ans_bufname
          '',                                               # stdin_bufname
          this.bufnr .. "_stdout_compile",                  # stdout_bufname
          this.bufnr .. "_stderr_compile",                  # stderr_bufname
          "Compile",                                        # tcnum
          0))                                               # timelimit
      endif

      var keys = keys(tctbl)
      keys -> sort((u, v) => {
        return str2nr(u) < str2nr(v) ? -1 : 1
      })
      for tcnum in keys
        var tc = tctbl[tcnum]
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
    var tc_size = len(this.tcdata)
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
      var start = this.next_tc
      this.next_tc = start + mut
      for idx in range(start, min([start + mut - 1, tc_size - 1]))
        this.ExecuteTestcase(idx, this.rc, this.running_directory, function('RunNextCallback', [this]))
      endfor
    enddef

    if !this.compile
      RunFirstTestcases()
    else
      this.next_tc = 1
      def CompileCallback()
        if this.tcdata[0].exit_code == 0
          RunFirstTestcases()
        endif
      enddef
      this.ExecuteTestcase(0, this.cc, this.compile_directory, CompileCallback)
    endif
  enddef # }}}

  def RunNextTestcase() # {{{
    if this.next_tc > len(this.tcdata) - 1
      return
    endif
    var current_tc = this.next_tc
    this.next_tc += 1
    this.ExecuteTestcase(current_tc, this.rc, this.running_directory, function('RunNextCallback', [this]))
  enddef # }}}

  def ExecuteTestcase(tcindex: number, cmd: SystemCommand, dir: string, Callback: func = null_function) # {{{
    var tc = this.tcdata[tcindex]

    if tc.running
      return
    endif

    deletebufline(tc.stdout_bufnr,  1, '$')
    deletebufline(tc.stderr_bufnr,  1, '$')

    var job_opts = {
      cwd: dir,
      out_io: 'buffer',
      out_buf: tc.stdout_bufnr,
      err_io: 'buffer',
      err_buf: tc.stderr_bufnr,
      exit_cb: function('JobExit', [this, tcindex, Callback]),
    }
    if tc.stdin_bufnr == 0
      job_opts.in_io = "null"
    else
      # It is faster than "buffer"
      job_opts.in_io = "file"
      job_opts.in_name = tc.stdin_bufname
    endif

    utils.CreateDirectory(dir)
    var command = [cmd.exec]
    if cmd.args != null_list
      command->extend(cmd.args)
    endif

    var job = job_start(command, job_opts)

    if job_status(job) != 'run'
      echoerr "TCRunner.ExecuteTestcase: failed to start: " .. string(command)
      tc.status = "FAILED"
      tc.hlgroup = "CompetiTestWarning"
      this.UpdateUI()
      return
    endif

    # Set timeout timer
    if tc.timelimit != 0
      tc.timer = timer_start(tc.timelimit, function('JobTimeout', [this, tcindex]))
    endif

    # Update state
    tc.starting_time = reltime()
    tc.job = job
    tc.status = "RUNNING"
    tc.hlgroup = "CompetiTestRunning"
    tc.running = true
    tc.killed = false

    this.UpdateUI()
  enddef # }}}

  def KillProcess(tcindex: number) # {{{
    var tc = this.tcdata[tcindex]
    if !tc.running || tc.job == null_job
      return
    endif
    job_stop(tc.job, 'kill')
    tc.killed = true
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
export var methods = { # {{{
  exact: (output: string, expout: string) => output == expout,
  squish: (output: string, expout: string) => {
    def SquishString(str: string): string
      var res = str
      res = substitute(res, '\n', ' ', 'g')   # 将所有换行符 \n 替换为空格
      res = substitute(res, '\s\+', ' ', 'g') # 将连续空白字符替换为单个空格
      res = substitute(res, '^\s*', '', '')   # 删除开头的所有空白字符
      res = substitute(res, '\s*$', '', '')   # 删除结尾的所有空白字符
      return res
    enddef
    var _output = SquishString(output)
    var _expout = SquishString(expout)
    return _output == _expout
  },
} # }}}

export def CompareOutput(out_bufnr: number, ans_bufnr: number, method: any): bool # {{{
  sleep 1m # should wait, because datas aren't fully loaded
  silent bufload(ans_bufnr)
  var outputs: list<string> = getbufline(out_bufnr, 1, '$')
  var answers: list<string> = getbufline(ans_bufnr, 1, '$')

  # handle CRLF
  var output: string = join(outputs, "\n") -> substitute('\r\n\', '\n', 'g')
  var answer: string = join(answers, "\n") -> substitute('\r\n\', '\n', 'g')

  if type(method) == v:t_string && has_key(methods, method)
    return methods[method](output, answer)
  elseif type(method) == v:t_func
    var Method = method
    return Method(output, answer)
  else
    echoerr "compare_output: unrecognized method " .. string(method)
    return false
  endif

enddef # }}}
# }}}

def RunNextCallback(runner: TCRunner) # {{{
  runner.RunNextTestcase()
enddef # }}}

def JobExit(runner: TCRunner, tcindex: number, Callback: func, job: job, status: number) # {{{
  var tc = runner.tcdata[tcindex]
  tc.running = false
  tc.time = reltime(tc.starting_time)->reltimefloat() * 1000
  tc.exit_code = status

  timer_stop(tc.timer)
  tc.timer = 0


  # Determine status
  if tc.killed
    if tc.timelimit != 0 && tc.time >= tc.timelimit
      tc.status = "TIMEOUT"
      tc.hlgroup = "CompetiTestWrong"
    else
      tc.status = "KILLED"
      tc.hlgroup = "CompetiTestWarning"
    endif
  else
    if status != 0
      tc.status = "RET " .. status
      tc.hlgroup = "CompetiTestWarning"
    else
      if tc.ans_bufnr == 0
        tc.status = "DONE"
        tc.hlgroup = "CompetiTestDone"
      else
        var correct = CompareOutput(tc.stdout_bufnr, tc.ans_bufnr, runner.config.output_compare_method)
        if correct == true
          tc.status = "CORRECT"
          tc.hlgroup = "CompetiTestCorrect"
        elseif correct == false
          tc.status = "WRONG"
          tc.hlgroup = "CompetiTestWrong"
        endif
      endif
    endif
  endif

  runner.UpdateUI()

  if Callback != null_function
    Callback()
  endif
enddef # }}}

def JobTimeout(runner: TCRunner, tcindex: number, timer: any) # {{{
  runner.KillProcess(tcindex)
enddef # }}}

var parallelism_ability: number = 1
# SetParallelism {{{
if executable('nproc') # On Unix-like OS
  var result = systemlist('nproc --all')
  if !empty(result) && result[0] =~ '^\d\+$'
    parallelism_ability = str2nr(result[0])
  endif
elseif executable('wmic') # On Windows OS
  var result = systemlist('wmic cpu get NumberOfCores')
  if len(result) > 1 && result[1]->substitute('[^0-9]', '', 'g') =~ '^\d\+$'
    parallelism_ability = str2nr(result[1]->substitute('[^0-9]', '', 'g'))
  endif
endif
# }}}
