vim9script
import autoload "../autoload/competitest/commands.vim"
# commands {{{
def g:Test_Commands_Complete()
  const Complete: func(string, string, number): string = commands.Complete
  var result: string
  writefile([""], "XCommands_Complete.c", "D")
  const tcnum = 3
  for i in range(tcnum)
    writefile([""], $"XCommands_Complete{i}.in", "D")
    writefile([""], $"XCommands_Complete{i}.ans", "D")
  endfor
  silent! edit XCommands_Complete.c
  result = Complete(null_string, 'CompetiTest', 11)
  result->assert_equal("add_testcase\nedit_testcase\ndelete_testcase\nrun\nrun_no_compile\nshow_ui\nreceive")

  result = Complete(null_string, 'CompetiTest receive ', 20)
  result->assert_equal("testcases\nproblem\ncontest\npersistently\nstatus\nstop")

  result = Complete('t', 'CompetiTest receive t', 21)
  result->assert_equal("testcases\nproblem\ncontest\npersistently\nstatus\nstop")

  result = Complete('edit_testcase', 'CompetiTest edit_testcase', 25)
  result->assert_equal("add_testcase\nedit_testcase\ndelete_testcase\nrun\nrun_no_compile\nshow_ui\nreceive")

  result = Complete(null_string, 'CompetiTest edit_testcase ', 26)
  result->assert_equal("0\n1\n2")

  result = Complete(null_string, 'CompetiTest EDIT_TESTCASE ', 26)
  result->assert_equal(null_string)

  result = Complete(null_string, 'CompetiTest show_ui ', 18)
  result->assert_equal(null_string)

  result = Complete(null_string, 'CompetiTest run ', 16)
  result->assert_equal("0\n1\n2")

  result = Complete(null_string, 'CompetiTest run_no_compile ', 27)
  result->assert_equal("0\n1\n2")

  result = Complete(null_string, 'CompetiTest edit_testcase ', 26)
  result->assert_equal("0\n1\n2")

  result = Complete(null_string, 'CompetiTest unknown_command', 28)
  result->assert_equal(null_string)

  result = Complete('ru', 'CompetiTest ru', 13)
  result->assert_equal("add_testcase\nedit_testcase\ndelete_testcase\nrun\nrun_no_compile\nshow_ui\nreceive")
enddef

def g:Test_Command_error()
  execute("CompetiTest r")->assert_equal("\n[competitest] commands: subcommand r doesn't exist!")
  execute("CompetiTest run")->assert_equal("\n[competitest] run_testcases: need a valid testcase!")
enddef
# }}}
# runner {{{
# Test :CompetiTest run command functionality with C files
def g:Test_Runner_c()
  if !executable("gcc") | return | endif
  var lines: list<string> =<< trim END
    #include "stdio.h"

    int main() {
        int a, b;
        scanf("%d%d", &a, &b);
        printf("%d", a + b);

        return 0;
    }
  END
  writefile(lines, "Xrun.c", "D")
  const tcnum = 9
  for i in range(tcnum)
    writefile(["1 2"], $"Xrun{i}.in", "D")
    writefile(["3"], $"Xrun{i}.ans", "D")
  endfor
  silent! edit Xrun.c
  const bufnr = bufnr()
  execute("CompetiTest run")->assert_equal("")
  defer delete(has("win32") ? "Xrun.exe" : "Xrun")
  while getbufvar(bufnr, "competitest_runner").tcdata[0].status ==# "RUNNING"
    sleep 1m
  endwhile
  getline(1)->assert_match('Compile   DONE      \d.\d\d\d seconds')
  for i in range(tcnum)
    while getbufvar(bufnr, "competitest_runner").tcdata[i + 1].status ==# "RUNNING"
      sleep 1m
    endwhile
    getline(i + 2)->assert_match($'TC {i}      CORRECT   \d.\d\d\d seconds')
  endfor
enddef

def g:Test_Runner_python()
  if !executable("python")
    return
  endif
  writefile(["print(sum(map(int, input().split())))"], "Xrun.py", "D")
  writefile(["1 2"], "Xrun0.in", "D")
  writefile(["3"], "Xrun0.ans", "D")
  silent! edit Xrun.py
  const bufnr = bufnr()
  execute("CompetiTest run")->assert_equal("")
  sleep 10m
  while getbufvar(bufnr, "competitest_runner").tcdata[0].status ==# "RUNNING"
    sleep 1m
  endwhile
  getbufvar(bufnr, "competitest_runner").tcdata[0].status->assert_equal("CORRECT")
  getline(1)->assert_match('TC 0      CORRECT   \d.\d\d\d seconds')
enddef

def g:Test_Runner_Python_Error()
  if !executable("python")
    return
  endif
  writefile(["print(um(map(int, input().split())))"], "test_runner_py_fail.py", "D")
  writefile(["1 2"], "test_runner_py_fail0.in", "D")
  writefile(["3"], "test_runner_py_fail0.ans", "D")
  silent! edit test_runner_py_fail.py
  const bufnr = bufnr()
  execute("CompetiTest run")
  while getbufvar(bufnr, "competitest_runner").tcdata[0].status ==# "RUNNING"
    sleep 1m
  endwhile
  getbufvar(bufnr, "competitest_runner").tcdata[0].status->assert_equal("RET 1")
  getline(1)->assert_match('TC 0      RET 1     \d.\d\d\d seconds')
enddef
# }}}
# testcases {{{
def g:Test_Testcase_Actions()
  silent! edit Xtestcase_actions.c
  execute("CompetiTest add_testcase 0")->assert_equal("\n[competitest] commands: add_testcase: exactly 0 sub-arguments required.")
  execute("CompetiTest edit_testcase")->assert_equal("\n[competitest] picker: there's no testcase to pick from.")
  execute("CompetiTest edit_testcase 0")->assert_equal("\n[competitest] edit_testcase: testcase 0 doesn't exist!")
  :CompetiTest add_testcase
  "1 2"->setline(1)
  "\<Tab>"->feedkeys("tx")
  "3"->setline(1)
  execute("normal s")
  try
    execute("CompetiTest edit_testcase")->assert_equal("")
    assert_false(popup_list()->empty())
    popup_getoptions(popup_list()[0]).title->assert_equal(" Edit a Testcase ")
    "x"->feedkeys("tx")
    execute("CompetiTest edit_testcase 0")->assert_equal("")
    getline(1)->assert_equal("1 2")
    "\<Tab>"->feedkeys("tx")
    getline(1)->assert_equal("3")
    "q"->feedkeys("tx")
    execute("CompetiTest edit_testcase 1")->assert_equal("\n[competitest] edit_testcase: testcase 1 doesn't exist!")
    :CompetiTest add_testcase
    "4 5"->setline(1)
    "\<Tab>"->feedkeys("tx")
    "8"->setline(1)
    execute("normal s")

    CompetiTest delete_testcase 0

    # Delete Testcase 1 with popup_select
    execute("CompetiTest delete_testcase")->assert_equal("")
    popup_list()->empty()->assert_false()
    popup_getoptions(popup_list()[0]).title->assert_equal(" Delete a Testcase ")
    "j\<CR>"->feedkeys("tx")
    execute("CompetiTest delete_testcase 1")->assert_equal("\n[competitest] delete_testcase: testcase 1 doesn't exist!")

  finally
    var failed = false # delete_testcase failed
    failed = delete("Xtestcase_actions0.in")  == 0 || failed
    failed = delete("Xtestcase_actions0.ans") == 0 || failed
    failed = delete("Xtestcase_actions1.in")  == 0 || failed
    failed = delete("Xtestcase_actions1.ans") == 0 || failed
    failed->assert_false("Command \"delete_testcase\" Failed")
  endtry
enddef
# }}}
# receive {{{
def g:Test_Receive_status()
  execute("CompetiTest receive status")->assert_equal("\n[competitest] receive: receiving not enabled.")
enddef

def g:Test_Receive_SubCommand()
  execute("CompetiTest receive start")->assert_equal("\n[competitest] receive: unrecognized mode 'start'")
enddef
# }}}
# vim:fdm=marker
