vim9script

import autoload "./config.vim"
import autoload "./runner.vim"
import autoload "./testcases.vim"
import autoload "./widgets.vim"
import autoload "./receive.vim"

export def Command(arguments: string): void # {{{
  var args = split(arguments, ' ')
  if empty(args)
    echoerr "command: at least one argument required."
    return
  endif

  # Check if current subcommand has the correct number of arguments
  def CheckSubargs(min_args: number, max_args: number): bool
    var count = len(args) - 1
    if min_args <= count && count <= max_args
      return true
    endif
    if min_args == max_args
      echoerr $"command: {args[0]}: exactly {min_args} sub-arguments required."
    else
      echoerr $"command: {args[0]}: from {min_args} to {max_args} sub-arguments required."
    endif
    return false
  enddef

  var subcommands: dict<func()> = {
    add_testcase: () => {
      if CheckSubargs(0, 0)
        EditTestcase(true)
      endif
    },
    edit_testcase: () => {
      if CheckSubargs(0, 1)
        if len(args) == 2
          EditTestcase(false, str2nr(args[1]))
        else
          EditTestcase(false)
        endif
      endif
    },
    delete_testcase: () => {
      if CheckSubargs(0, 1)
        if len(args) == 2
          DeleteTestcase(str2nr(args[1]))
        else
          DeleteTestcase()
        endif
      endif
    },
    run: () => {
      var testcases_list: list<string> = []
      if len(args) >= 2
        testcases_list = args[1 : ]
      endif
      RunTestcases(testcases_list, true)
    },
    run_no_compile: () => {
      var testcases_list: list<string> = []
      if len(args) >= 2
        testcases_list = args[1 : ]
      endif
      RunTestcases(testcases_list, false)
    },
    show_ui: () => {
      if CheckSubargs(0, 0)
        RunTestcases(null_list, false, true)
      endif
    },
    receive: () => {
      if CheckSubargs(1, 1)
        Receive(args[1])
      endif
    },
  }

  if has_key(subcommands, args[0])
    subcommands[args[0]]()
  else
    echoerr $"command: subcommand {args[0]} doesn't exist!"
  endif
enddef # }}}

def EditTestcase(add_testcase: bool, tcnum = -1): void # {{{
  var bufnr = bufnr()
  config.LoadBufferConfig(bufnr) # reload buffer configuration since it may have been updated in the meantime
  var tctbl = testcases.BufGetTestcases(bufnr)
  def StartEditor(n: number)
    if !has_key(tctbl, n)
      echoerr $"edit_testcase: testcase {n} doesn't exist!"
      return
    endif
    widgets.Editor(bufnr, n)
  enddef

  if add_testcase
    var num = 0
    while has_key(tctbl, num)
      num = num + 1
    endwhile
    tctbl[num] = { input: "", output: "" }
    StartEditor(num)
  elseif tcnum == -1
    widgets.Picker(bufnr, tctbl, "Edit a Testcase", StartEditor)
  else
    StartEditor(tcnum)
  endif
enddef # }}}

def DeleteTestcase(tcnum = -1): void # {{{
  var bufnr = bufnr()
  var tctbl = testcases.BufGetTestcases(bufnr)
  def Delete(num: number)
    if !has_key(tctbl, num)
      echoerr $"delete_testcase: testcase {num} doesn't exist!"
      return
    endif
    var choice = confirm($"Are you sure you want to delete Testcase {num} ?", "Yes\nNo")
    if choice == 0 || choice == 2 # user pressed <Esc> or chose "No"
      return
    endif
    testcases.IOFIlesDelete(bufnr, num)
  enddef
  if tcnum == -1
    widgets.Picker(bufnr, tctbl, "Delete a Testcase", Delete)
  else
    Delete(tcnum)
  endif
enddef # }}}

def Receive(mode: string) # {{{
  var error = null_string

  if mode == "stop"
    receive.StopReceiving()
  elseif mode == "status"
    receive.ShowStatus()
  elseif mode == "testcases"
    var bufnr = bufnr()
    config.LoadBufferConfig(bufnr)
    var bufcfg = config.GetBufferConfig(bufnr)
    var notify = bufcfg.receive_print_message
    error = receive.StartReceiving("testcases", bufcfg.companion_port, notify, notify, bufcfg, bufnr)
  elseif mode == "problem" || mode == "contest" || mode == "persistently"
    var cfg = config.LoadLocalConfigAndExtend(getcwd())
    var notify = cfg.receive_print_message
    error = receive.StartReceiving(mode, cfg.companion_port, notify, notify, cfg)
  else
    error = "unrecognized mode '" .. string(mode) .. "'"
  endif

  if error != null_string
    echoerr "receive: " .. error .. "."
  endif
enddef # }}}

def RunTestcases(testcases_list: list<string>, compile: bool, only_show = false) # {{{
  var bufnr = bufnr()
  config.LoadBufferConfig(bufnr())
  var tctbl = testcases.BufGetTestcases(bufnr)

  if testcases_list != null_list
    var new_tctbl = {}
    for i in testcases_list
      var tcnum = str2nr(i) # if i is empty or error, return 0。
      if !has_key(tctbl, tcnum) # invalid testcase
        echoerr $"run_testcases: testcase {tcnum} doesn't exist!"
      else
        new_tctbl[tcnum] = tctbl[tcnum]
      endif
    endfor
    tctbl = new_tctbl
  endif

  if tctbl == null_dict
    echoerr "run_testcases: need a valid testcase!"
    return
  endif

  if !exists("b:competitest_runner")
    b:competitest_runner = runner.New(bufnr)
    if b:competitest_runner == null_object
      return
    endif
  endif

  var r = b:competitest_runner
  if !only_show
    r.KillAllProcesses()
    r.RunTestcases(tctbl, compile)
  endif
  r.SetRestoreWinID(win_getid())
  r.ShowUI()
enddef # }}}
