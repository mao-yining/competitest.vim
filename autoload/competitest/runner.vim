vim9script

import autoload './utils.vim' as utils
import autoload './config.vim' as cfg
import autoload './compare.vim' as compare
import autoload './runner_ui.vim' as runner_ui

# System command with arguments
class SystemCommand
  var exec: string
  var args: list<string>
endclass

# Testcase Runner class
export class TCRunner
  var config: dict<any>
  var bufnr: number
  var cc: SystemCommand
  var rc: SystemCommand
  var compile_directory: string
  var running_directory: string
  var tcdata: dict<any>
  var compile: bool
  var next_tc: number
  var ui_restore_winid: number
  var ui: runner_ui.RunnerUI

  # Create a new TCRunner
  static def New(bufnr: number): TCRunner
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
      var args = []
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
    res.tcdata = {}
    res.compile = (compile_command != null_object)
    res.next_tc = 0
    return res
  enddef

  # Run a testcase
  def RunTestcase(tcindex: number)
    if tcindex == -1 && this.compile
      this.ExecuteTestcase(tcindex, this.cc, this.compile_directory)
    else
      this.ExecuteTestcase(tcindex, this.rc, this.running_directory)
    endif
  enddef

  # Run next testcase in queue
  def RunNextTestcase()
    if this.next_tc > len(this.tcdata) - 2
      return
    endif
    var current_tc = this.next_tc
    this.next_tc += 1
    this.ExecuteTestcase(current_tc, this.rc, this.running_directory, function('RunNextCallback', [this]))
  enddef

  # Run testcases
  def RunTestcases(tctbl: dict<any>, compile: bool = true)
    if tctbl != null_dict
      if this.config.save_all_files
        wall
      elseif this.config.save_current_file
        var current_buf = bufnr()
        execute 'buffer' this.bufnr
        write
        execute 'buffer' current_buf
      endif

      this.tcdata = {}
      this.compile = compile && (this.cc != null_object)
      if this.compile
        this.tcdata["-1"] = { stdin: [], expout: null_list, tcnum: "Compile", }
      endif

      for [tcnum, tc] in items(tctbl)
        this.tcdata[tcnum] = {
          stdin: split(tc.input, "\n", true),
          expout: tc.output != null ? split(tc.output, "\n", true) : null,
          tcnum: tcnum,
          timelimit: this.config.maximum_time,
        }
      endfor
    endif

    # Reset state
    for [_, tc] in items(this.tcdata)
      tc.status = ""
      tc.hlgroup = "CompetiTestRunning"
      tc.stdout = null_list
      tc.stderr = null_list
      tc.running = false
      tc.killed = false
      tc.time = 0
    endfor

    var tc_size = len(this.tcdata) - 1
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
      this.next_tc = 0
      def CompileCallback()
        if this.tcdata[-1].exit_code == 0
          RunFirstTestcases()
        endif
      enddef
      this.ExecuteTestcase(-1, this.cc, this.compile_directory, CompileCallback)
    endif
  enddef

  # Execute a testcase process
  def ExecuteTestcase(tcindex: number, cmd: SystemCommand, dir: string, Callback: func = null_function)
    var tc = this.tcdata[tcindex]
    var job_opts = {
      cwd: dir,
      in_io: 'pipe',
      out_io: 'pipe',
      err_io: 'pipe',
      in_mode: 'raw',
      out_mode: 'raw',
      err_mode: 'raw',
      exit_cb: function('JobExit', [this, tcindex, Callback]),
      out_cb: function('JobOut', [this, tcindex]),
      err_cb: function('JobErr', [this, tcindex])
    }

    var command = [cmd.exec]
    if cmd.args != null
      command->extend(cmd.args)
    endif
    var job = job_start(command, job_opts)
    if job_status(job) != 'run'
      echo "TCRunner.ExecuteTestcase: failed to start: " .. string(command)
      tc.status = "FAILED"
      tc.hlgroup = "CompetiTestWarning"
      this.UpdateUI(true)
      return
    endif

    # Send input
    var stdin_data = join(tc.stdin, "\n")
    if stdin_data != ""
      ch_sendraw(job, stdin_data)
    endif
    ch_close_in(job)

    # Set timeout timer
    if has_key(tc, "timelimit")
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
  enddef

  # Kill a process
  def KillProcess(tcindex: number)
    var tc = this.tcdata[tcindex]
    if !tc.running || tc.job == null_job
      return
    endif
    job_stop(tc.job, 'kill')
    tc.killed = true
  enddef

  # Kill all processes
  def KillAllProcesses()
    for idx in range(len(this.tcdata))
      this.KillProcess(idx)
    endfor
  enddef

  # Show runner UI
  def ShowUI()
    if this.ui == null_object
      this.ui = runner_ui.New(this)
    endif
    this.ui.ShowUI()
    this.ui.UpdateUI()
  enddef

  # Set restore window ID
  def SetRestoreWinID(restore_winid: number)
    this.ui_restore_winid = restore_winid
    if this.ui != null_object
      this.ui.restore_winid = restore_winid
    endif
  enddef

  # Update UI
  def UpdateUI(update_windows: bool = false)
    if this.ui != null_object
      if update_windows
        this.ui.update_windows = true
      endif
      this.ui.update_details = true
      this.ui.UpdateUI()
    endif
  enddef

  # Resize UI
  def ResizeUI()
    if this.ui != null_object
      this.ui.ResizeUI()
    endif
  enddef
endclass

# Callback helpers
def RunNextCallback(runner: TCRunner)
  runner.RunNextTestcase()
enddef

def JobExit(runner: TCRunner, tcindex: number, Callback: func, job: any, status: number)
  var tc = runner.tcdata[tcindex]
  tc.running = false
  tc.time = reltime(tc.starting_time)->reltimefloat() * 1000
  tc.exit_code = status

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
      # Compare output
      # echom tc.stdout
      var correct = compare.CompareOutput(join(tc.stdout, "\n")->substitute('\%x00', '', 'g')->substitute('\r', " ", 'g'),
        tc.expout != null_list ? join(tc.expout, "\n") : null_string,
        runner.config.output_compare_method)
      if correct == true
        tc.status = "CORRECT"
        tc.hlgroup = "CompetiTestCorrect"
      elseif correct == false
        tc.status = "WRONG"
        tc.hlgroup = "CompetiTestWrong"
      else
        tc.status = "DONE"
        tc.hlgroup = "CompetiTestDone"
      endif
    endif
  endif

  if has_key(tc, "timer")
    timer_stop(tc.timer)
    tc.timer = 0
  endif

  runner.UpdateUI(true)
  if Callback != null_function
    Callback()
  endif
enddef

def JobOut(runner: TCRunner, tcindex: number, job: any, data: string)
  var tc = runner.tcdata[tcindex]
  if len(tc.stdout) == 0
    tc.stdout = [data]
  else
    tc.stdout[-1] ..= data
  endif
  runner.UpdateUI()
enddef

def JobErr(runner: TCRunner, tcindex: number, job: any, data: string)
  var tc = runner.tcdata[tcindex]
  if len(tc.stderr) == 0
    tc.stderr = [data]
  else
    tc.stderr[-1] ..= data
  endif
  runner.UpdateUI()
enddef

def JobTimeout(runner: TCRunner, tcindex: number, timer: any)
  runner.KillProcess(tcindex)
enddef

# Export TCRunner class
export def New(bufnr: number): TCRunner
  return TCRunner.New(bufnr)
enddef

var parallelism_cache: number = 0

def GetAvailableParallelism(): number
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
enddef
