vim9script

import autoload './utils.vim'
import autoload './config.vim' as cfg
import autoload './compare.vim'
import autoload './runner_ui.vim'
import autoload './testcases.vim'

# System command with arguments
class SystemCommand # {{{
  var exec: string
  var args: list<string>
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
  var tcdata: list<testcases.Data>
  var compile: bool
  var next_tc: number
  var ui_restore_winid: number
  var ui: runner_ui.RunnerUI
  # }}}

  static def New(bufnr: number): TCRunner # {{{
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
        echo "TCRunner.New: compile command for filetype '" .. filetype .. "' isn't formatted properly"
        return null_object
      endif
    endif

    if !has_key(buf_cfg.run_command, filetype) || buf_cfg.run_command[filetype] == null_object
      echo "TCRunner.New: run command for filetype '" .. filetype .. "' isn't configured"
      return null_object
    endif
    var run_command = EvalCommand(buf_cfg.run_command[filetype])
    if run_command == null_object
      echo "TCRunner.New: run command for filetype '" .. filetype .. "' isn't formatted properly"
      return null_object
    endif

    var res = TCRunner.new()
    res.config = buf_cfg
    res.bufnr = bufnr
    res.cc = compile_command
    res.rc = run_command
    res.compile_directory = (filedir .. buf_cfg.compile_directory .. '/')
    res.running_directory = (filedir .. buf_cfg.running_directory .. '/')
    res.tcdata = []
    res.compile = (compile_command != null_object)
    res.next_tc = 0
    return res
  enddef # }}}

  def ReRunTestcase(tcindex: number) # {{{
    this.KillProcess(tcindex)
    this.RunTestcase(tcindex)
  enddef # }}}

  def ReRunTestcases() # {{{
    this.KillAllProcesses()
    var tc_size = len(this.tcdata)
    var mut = this.config.multiple_testing
    if mut == -1
      mut = GetAvailableParallelism()
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

  def RunTestcase(tcindex: number) # {{{
    if tcindex == 0 && this.compile
      this.ExecuteTestcase(tcindex, this.cc, this.compile_directory)
    else
      this.ExecuteTestcase(tcindex, this.rc, this.running_directory)
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

  def RunTestcases(tctbl: dict<any>, compile: bool = true) #{{{
    if tctbl != null_dict
      if this.config.save_all_files
        wall
      elseif this.config.save_current_file
        write
      endif

      this.tcdata = []
      this.compile = compile && (this.cc != null_object)
      if this.compile
        add(this.tcdata, testcases.Data.new(0, 0, '', '', this.bufnr .. "_stdout_compile", this.bufnr .. "_stderr_compile", "Compile", 0))
      endif

      var keys = keys(tctbl)
      keys -> sort((u, v) => {
        return str2nr(u) < str2nr(v) ? -1 : 1
      })
      for tcnum in keys
        var tc = tctbl[tcnum]
        add(this.tcdata, testcases.Data.new(tc.ans_bufnr, tc.input_bufnr, tc.ans_bufname, tc.input_bufname, this.bufnr .. "_stdout_" .. tcnum, this.bufnr .. "_stderr_" .. tcnum, tcnum, this.config.maximum_time))
      endfor
    endif

    def InitBuf(bufname: string, mode: string): number # {{{
      var bufnr = bufnr(bufname)
      if !bufexists(bufnr) # 清空现有缓冲区
        bufnr = bufadd(bufname)
        setbufvar(bufnr, '&buftype', 'nofile')
        setbufvar(bufnr, '&bufhidden', 'hide')
        setbufvar(bufnr, '&filetype', "competitest_" .. mode)
      endif

      return bufnr
    enddef # }}}

    # Reset state
    for tc in this.tcdata
      tc.status = ""
      tc.hlgroup = "CompetiTestRunning"
      tc.stdout_bufnr = InitBuf(tc.stdout_bufname, "out")
      tc.stderr_bufnr = InitBuf(tc.stderr_bufname, "err")
      tc.running = false
      tc.killed = false
      tc.time = 0.0
    endfor

    var tc_size = len(this.tcdata)
    var mut = this.config.multiple_testing
    if mut == -1
      mut = GetAvailableParallelism()
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

  def ExecuteTestcase(tcindex: number, cmd: SystemCommand, dir: string, Callback: func = null_function) # {{{
    var tc = this.tcdata[tcindex]
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
      # TODO: when use buffer, if a testcase is large, it will has E631, maybe
      # it's a vim's bug
      # E631: write_buf_line(): 写入失败
      job_opts.in_io = "file"
      job_opts.in_name = tc.stdin_bufname
      # job_opts.in_io = "buffer"
      # job_opts.in_buf = tc.stdin_bufnr
      # tc.stdin_bufnr->bufload()
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
      this.UpdateUI(true)
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

    this.UpdateUI(true)
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
      this.ui = runner_ui.New(this)
    endif
    this.ui.ShowUI()
    this.ui.UpdateUI()
  enddef # }}}

  def SetRestoreWinID(restore_winid: number) # {{{
    this.ui_restore_winid = restore_winid
    if this.ui != null_object
      this.ui.restore_winid = restore_winid
    endif
  enddef # }}}

  def UpdateUI(update_windows: bool = false) # {{{
    if this.ui != null_object
      if update_windows
        this.ui.update_windows = true
      endif
      this.ui.UpdateUI()
    endif
  enddef # }}}
endclass

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
        var correct = compare.CompareOutput(tc.stdout_bufnr, tc.ans_bufnr, runner.config.output_compare_method)
        if correct == true
          tc.status = "CORRECT"
          tc.hlgroup = "CompetiTestCorrect"
        elseif correct == false
          tc.status = "WRONG"
          tc.hlgroup = "CompetiTestWrong"
        else
        endif
      endif
    endif
  endif

  runner.UpdateUI(true)
  if Callback != null_function
    Callback()
  endif
enddef # }}}

def JobTimeout(runner: TCRunner, tcindex: number, timer: any) # {{{
  runner.KillProcess(tcindex)
enddef # }}}

export def New(bufnr: number): TCRunner # {{{
  return TCRunner.New(bufnr)
enddef # }}}

var parallelism_cache: number = 0

def GetAvailableParallelism(): number # {{{
  if parallelism_cache > 0
    return parallelism_cache
  endif

  var cores = 1
  if executable('nproc')
    var result = systemlist('nproc --all')
    if !empty(result) && result[0] =~ '^\d\+$'
      cores = str2nr(result[0])
    endif
  elseif executable('wmic')
    var result = systemlist('wmic cpu get NumberOfCores')
    if len(result) > 1 && result[1]->substitute('[^0-9]', '', 'g') =~ '^\d\+$'
      cores = str2nr(result[1]->substitute('[^0-9]', '', 'g'))
    endif
  endif

  parallelism_cache = cores
  return cores
enddef # }}}
