vim9script
# File: autoload/competitest/commands.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Handle Commands
# Last Modified: 2026-01-04

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
    elseif parts[1] =~# 'edit_testcase\|delete_testcase'
      return testcases.BufGetTestcases(bufnr())->keys()->join("\n")
    elseif parts[1] =~# 'run\|run_no_compile'
      complete_cache = testcases.BufGetTestcases(bufnr())->keys()->join("\n")
      return complete_cache
    endif
  elseif parts->len() > 3 && parts[1] =~# 'run\|run_no_compile'
    return complete_cache
  endif
  return null_string
enddef # }}}

export def Handle(arguments: string): void # {{{
  const args = arguments->split(' ')

  # Check if current subcommand has the correct number of arguments
  def CheckSubargs(min_args: number, max_args: number)
    const count = len(args) - 1
    if min_args <= count && count <= max_args
      return
    endif
    if min_args == max_args
      throw $"commands: {args[0]}: exactly {min_args} sub-arguments required."
    else
      throw $"commands: {args[0]}: from {min_args} to {max_args} sub-arguments required."
    endif
  enddef

  const subcommands = {
    add_testcase: () => {
      CheckSubargs(0, 0)
      AddTestcase()
    },
    edit_testcase: () => {
      CheckSubargs(0, 1)
      EditTestcase(args->get(1, '-1')->str2nr())
    },
    delete_testcase: () => {
      CheckSubargs(0, 1)
      DeleteTestcase(args->get(1, '-1')->str2nr())
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
      CheckSubargs(0, 0)
      RunTestcases(null_list, false, true)
    },
    receive: () => {
      CheckSubargs(1, 1)
      Receive(args[1])
    },
  }

  try
    if subcommands->has_key(args[0])
      subcommands[args[0]]()
    else
      throw $"commands: subcommand {args[0]} doesn't exist!"
    endif
  catch /^commands:/
    utils.EchoErr(v:exception)
  endtry
enddef # }}}

def AddTestcase() # {{{
  const bufnr = bufnr()
  final tctbl = testcases.BufGetTestcases(bufnr)
  var tcnum = 0
  while tctbl->has_key(tcnum)
    tcnum = tcnum + 1
  endwhile
  tctbl[tcnum] = { input: null_string, output: null_string }
  widgets.Editor(bufnr, tcnum)
enddef # }}}

def EditTestcase(tcnum: number): void # {{{
  const bufnr = bufnr()
  const tctbl = testcases.BufGetTestcases(bufnr)
  if tcnum == -1
    widgets.Picker(bufnr, tctbl, "Edit a Testcase",
      (n: number) => widgets.Editor(bufnr, n))
  else
    if !tctbl->has_key(tcnum)
      utils.EchoErr($"edit_testcase: testcase {tcnum} doesn't exist!")
      return
    endif
    widgets.Editor(bufnr, tcnum)
  endif
enddef # }}}

def DeleteTestcase(tcnum: number): void # {{{
  const bufnr = bufnr()
  const tctbl = testcases.BufGetTestcases(bufnr)
  if tcnum == -1
    widgets.Picker(bufnr, tctbl, "Delete a Testcase",
      (n: number) => testcases.IOFilesDelete(bufnr, n))
  else
    if !tctbl->has_key(tcnum)
      utils.EchoErr($"delete_testcase: testcase {tcnum} doesn't exist!")
      return
    endif
    testcases.IOFilesDelete(bufnr, tcnum)
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
    for tcnum in testcases_list
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
