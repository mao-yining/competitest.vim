vim9script
# File: autoload/competitest/commands.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Handle Commands
# Last Modified: 2026-01-02

import autoload "./config.vim"
import autoload "./runner.vim"
import autoload "./testcases.vim"
import autoload "./widgets.vim"
import autoload "./receive.vim"
import autoload "./utils.vim"

var complete_cache: string
export def Complete(arglead: string, cmdline: string, cursorpos: number): string # {{{
  const parts = cmdline->strpart(0, cursorpos)->split()
    ->extend(arglead == null_string ? [' '] : [])
  if parts->len() == 2
    return "add_testcase\nedit_testcase\ndelete_testcase\nrun\nrun_no_compile\nshow_ui\nreceive"
  elseif parts->len() == 3
    if parts[1] == 'receive'
      return "testcases\nproblem\ncontest\npersistently\nstatus\nstop"
    elseif parts[1] =~? 'edit_testcase\|delete_testcase'
      return testcases.BufGetTestcases(bufnr())->keys()->join("\n")
    elseif parts[1] =~? 'run\|run_no_compile'
      complete_cache = testcases.BufGetTestcases(bufnr())->keys()->join("\n")
      return complete_cache
    endif
  elseif parts->len() > 3 && parts[1] =~? 'run\|run_no_compile'
    return complete_cache
  endif
  return null_string
enddef # }}}

export def Handle(arguments: string): void # {{{
  const args = arguments->split(' ')

  # Check if current subcommand has the correct number of arguments
  def CheckSubargs(min_args: number, max_args: number): bool
    const count = len(args) - 1
    if min_args <= count && count <= max_args
      return true
    endif
    if min_args == max_args
      utils.EchoErr($"commands: {args[0]}: exactly {min_args} sub-arguments required.")
    else
      utils.EchoErr($"commands: {args[0]}: from {min_args} to {max_args} sub-arguments required.")
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

  if subcommands->has_key(args[0])
    subcommands[args[0]]()
  else
    utils.EchoErr($"commands: subcommand {args[0]} doesn't exist!")
  endif
enddef # }}}

def EditTestcase(add_testcase: bool, tcnum = -1): void # {{{
  const bufnr = bufnr()
  config.LoadBufferConfig(bufnr) # reload buffer configuration since it may have been updated in the meantime
  final tctbl = testcases.BufGetTestcases(bufnr)
  def StartEditor(n: number)
    if !tctbl->has_key(n)
      utils.EchoErr($"edit_testcase: testcase {n} doesn't exist!")
      return
    endif
    widgets.Editor(bufnr, n)
  enddef

  if add_testcase
    var num = 0
    while tctbl->has_key(num)
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
  def Delete(num: number): void
    if !tctbl->has_key(num)
      utils.EchoErr($"delete_testcase: testcase {num} doesn't exist!")
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

def Receive(mode: string): void # {{{
  try
    if mode == "stop"
      receive.StopReceiving()
    elseif mode == "status"
      receive.ShowStatus()
    elseif mode == "testcases"
      const bufnr = bufnr()
      config.LoadBufferConfig(bufnr)
      const bufcfg = config.GetBufferConfig(bufnr)
      receive.StartReceiving(
        "testcases",
        bufcfg.companion_port,
        bufcfg.receive_print_message,
        bufcfg,
        bufnr)
    elseif mode == "problem" || mode == "contest" || mode == "persistently"
      const cfg = config.LoadLocalConfigAndExtend(getcwd())
      receive.StartReceiving(
        mode,
        cfg.companion_port,
        cfg.receive_print_message,
        cfg)
    else
      throw $"receive: unrecognized mode {string(mode)}"
    endif
  catch /^receive:/
    utils.EchoErr(v:exception)
  endtry
enddef # }}}

def RunTestcases(testcases_list: list<string>, compile: bool, only_show = false) # {{{
  const bufnr = bufnr()
  config.LoadBufferConfig(bufnr)
  var tctbl = testcases.BufGetTestcases(bufnr)

  if testcases_list != null_list
    final new_tctbl = {}
    for i in testcases_list
      const tcnum = i # if i is empty or error, return 0。
      if !tctbl->has_key(tcnum) # invalid testcase
        utils.EchoWarn($"run_testcases: testcase {tcnum} doesn't exist!")
      else
        new_tctbl[tcnum] = tctbl[tcnum]
      endif
    endfor
    tctbl = new_tctbl
  endif

  if tctbl == null_dict
    utils.EchoErr("run_testcases: need a valid testcase!")
    return
  endif

  if !exists("b:competitest_runner")
    try
      b:competitest_runner = runner.TCRunner.new(bufnr)
    catch /^TCRunner.new:/
      utils.EchoErr(string(v:exception))
      return
    endtry
  endif

  if !only_show
    b:competitest_runner.KillAllProcesses()
    b:competitest_runner.RunAndInitTestcases(tctbl, compile)
  endif
  b:competitest_runner.ShowUI()
enddef # }}}
