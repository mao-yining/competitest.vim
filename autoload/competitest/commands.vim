vim9script
# File: autoload\competitest\commands.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Handle Commands
# Last Modified: 2025-09-20

import autoload "./config.vim"
import autoload "./runner.vim"
import autoload "./testcases.vim"
import autoload "./widgets.vim"
import autoload "./receive.vim"

export def Complete(_: string, cmdline: string, cursorpos: number): string # {{{
  const ending_space = cmdline[cursorpos - 1] == " "
  const words = split(cmdline)
  const wlen = len(words)

  if wlen == 1 || wlen == 2 && !ending_space
    return "add_testcase\nedit_testcase\ndelete_testcase\nrun\nrun_no_compile\nshow_ui\nreceive"
  elseif wlen == 2 && words[-1] == "receive" || wlen == 3 && words[-2] == "receive" && !ending_space
    return "testcases\nproblem\ncontest\npersistently\nstatus\nstop"
  else
    return null_string
  endif
enddef # }}}

export def Handle(arguments: string): void # {{{
  const args = split(arguments, ' ')

  # Check if current subcommand has the correct number of arguments
  def CheckSubargs(min_args: number, max_args: number): bool
    const count = len(args) - 1
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

  const subcommands = {
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
      const testcases_list = len(args) >= 2 ? args[1 : ] : null_list
      RunTestcases(testcases_list, true)
    },
    run_no_compile: () => {
      const testcases_list = len(args) >= 2 ? args[1 : ] : null_list
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
  const bufnr = bufnr()
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
  const bufnr = bufnr()
  const tctbl = testcases.BufGetTestcases(bufnr)
  def Delete(num: number)
    if !has_key(tctbl, num)
      echoerr $"delete_testcase: testcase {num} doesn't exist!"
      return
    endif
    const choice = confirm($"Are you sure you want to delete Testcase {num} ?", "Yes\nNo")
    if choice == 0 || choice == 2 # user pressed <Esc> or chose "No"
      return
    endif
    testcases.IOFilesDelete(bufnr, num)
  enddef
  if tcnum == -1
    widgets.Picker(bufnr, tctbl, "Delete a Testcase", Delete)
  else
    Delete(tcnum)
  endif
enddef # }}}

def Receive(mode: string) # {{{
  try
    if mode == "stop"
      receive.StopReceiving()
    elseif mode == "status"
      receive.ShowStatus()
    elseif mode == "testcases"
      const bufnr = bufnr()
      config.LoadBufferConfig(bufnr)
      const bufcfg = config.GetBufferConfig(bufnr)
      const notify = bufcfg.receive_print_message
      receive.StartReceiving("testcases", bufcfg.companion_port, notify, bufcfg, bufnr)
    elseif mode == "problem" || mode == "contest" || mode == "persistently"
      const cfg = config.LoadLocalConfigAndExtend(getcwd())
      const notify = cfg.receive_print_message
      receive.StartReceiving(mode, cfg.companion_port, notify, cfg)
    else
      throw $"receive: unrecognized mode {string(mode)}"
    endif
  catch /^receive:/
    echoerr v:exception
  endtry
enddef # }}}

def RunTestcases(testcases_list: list<string>, compile: bool, only_show = false) # {{{
  const bufnr = bufnr()
  config.LoadBufferConfig(bufnr)
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
    try
      b:competitest_runner = runner.TCRunner.new(bufnr)
    catch /^TCRunner.new:/
      echoerr string(v:exception)
      return
    endtry
  endif

  if !only_show
    b:competitest_runner.KillAllProcesses()
    b:competitest_runner.RunAndInitTestcases(tctbl, compile)
  endif
  b:competitest_runner.ShowUI()
enddef # }}}
