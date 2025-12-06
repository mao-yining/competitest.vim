vim9script

# Test :CompetiTest run command functionality with C files
def g:Test_Runner_c()
  execute("CompetiTest r")->assert_equal("\n[competitest] commands: subcommand r doesn't exist!")
  execute("CompetiTest run")->assert_equal("\n[competitest] run_testcases: need a valid testcase!")
  if !executable("gcc")
    return
  endif

  silent! edit test_runner.c
  var lines: list<string> =<< trim END
    #include "stdio.h"

    int main() {
        int a, b;
        scanf("%d%d", &a, &b);
        printf("%d", a + b);

        return 0;
    }
  END
  lines->setline(1)
  silent! write
  try
    :CompetiTest add_testcase
    "1 2"->setline(1)
    "\<Tab>"->feedkeys("tx")
    "3"->setline(1)
    "s"->feedkeys("tx")
    execute("CompetiTest run 0 1")->assert_equal("\n[competitest] run_testcases: testcase 1 doesn't exist!")
    tabclose
    execute("CompetiTest run")->assert_equal("")
  finally
    tabclose
    CompetiTest delete_testcase 0
    delete("test_runner.c")
    delete(has("win32") ? "test_runner.exe" : "test_runner")
    var failed = false
    failed = delete("test_runner0.in")  == 0 || failed
    failed = delete("test_runner0.ans") == 0 || failed
    failed->assert_false("Command \"delete_testcase\" Failed")
  endtry
enddef

def g:Test_Testcase_Actions()
  silent! edit test_testcase_actions.c
  execute("CompetiTest add_testcase 0")->assert_equal("\n[competitest] commands: add_testcase: exactly 0 sub-arguments required.")
  execute("CompetiTest edit_testcase")->assert_equal("\n[competitest] picker: there's no testcase to pick from.")
  execute("CompetiTest edit_testcase 0")->assert_equal("\n[competitest] edit_testcase: testcase 0 doesn't exist!")
  :CompetiTest add_testcase
  "1 2"->setline(1)
  "\<Tab>"->feedkeys("tx")
  "3"->setline(1)
  "s"->feedkeys("tx")
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
    "s"->feedkeys("tx")

    CompetiTest delete_testcase 0

    # Delete Testcase 1 with popup_select
    execute("CompetiTest delete_testcase")->assert_equal("")
    popup_list()->empty()->assert_false()
    popup_getoptions(popup_list()[0]).title->assert_equal(" Delete a Testcase ")
    "j\<CR>"->feedkeys("tx")
    execute("CompetiTest delete_testcase 1")->assert_equal("\n[competitest] delete_testcase: testcase 1 doesn't exist!")

  finally
    var failed = false # delete_testcase failed
    failed = delete("test_testcase_actions0.in")  == 0 || failed
    failed = delete("test_testcase_actions0.ans") == 0 || failed
    failed = delete("test_testcase_actions1.in")  == 0 || failed
    failed = delete("test_testcase_actions1.ans") == 0 || failed
    failed->assert_false("Command \"delete_testcase\" Failed")
  endtry
enddef

def g:Test_Runner_python()
  if !executable("python")
    return
  endif
  writefile(["print(sum(map(int, input().split())))"], "test_py.py", "D")
  writefile(["1 2"], "test_py0.in", "D")
  writefile(["3"], "test_py0.ans", "D")
  silent! edit test_py.py
  const bufnr = bufnr()
  execute("CompetiTest run")
  sleep 100m
  getbufvar(bufnr, "competitest_runner").tcdata[0].status->assert_equal("CORRECT")
  getline(1)->assert_match('TC 0      CORRECT   \d.\d\d\d seconds')
  # execute("ls!")->assert_equal("execute('ls')")
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
