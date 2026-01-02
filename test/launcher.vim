if !has("patch-9.1.1000")
  call writefile(["Warning: Needs Vim version 9.1.1000 and above"], "results.txt", "a")
  quit
endif

vim9script
# Script to run a unit tests
# The global variable TestName should be set to the name of the file
# containing the tests.
def LoadPlugin()
  $LANG = "en"
  filetype on
  set wildmenu
  set nomore
  set noswapfile

  # Set the $DO_PROFILE environment variable to profile the plugin
  if exists("$DO_PROFILE")
    # profile the LSP plugin
    profile start profile.txt
    profile! file */competitest/*
  endif

  source ../plugin/competitest.vim
enddef

def RunTests()
  delete("results.txt")

  # Get the list of test functions in this file and call them
  const fns: list<string> = execute("function /^Test_")
    ->split("\n")
    ->map((_, v: string) => v->substitute("^def ", "", ""))
    ->sort()
  if fns->empty()
    ["No tests are found"]->writefile("results.txt")
    return
  endif
  for f in fns
    v:errors = []
    v:errmsg = ""
    try
      silent tabnew
      silent tabonly
      :%bwipeout!
      execute $"g:{f}"
    catch
      v:errors->add($"Error: Test {f} failed with exception {v:exception} at {v:throwpoint}")
    endtry
    if v:errmsg != ""
      v:errors->add($"Error: Test {f} generated error {v:errmsg}")
    endif
    if !v:errors->empty()
      v:errors->writefile("results.txt", "a")
      [$"{f}: FAIL"]->writefile("results.txt", "a")
    else
      [$"{f}: pass"]->writefile("results.txt", "a")
    endif
  endfor
enddef

try
  LoadPlugin()
  execute($"source {g:TestName}")
  RunTests()
catch
  [$"FAIL: Tests in {g:TestName} failed with exception {v:exception} at {v:throwpoint}"]->writefile("results.txt", "a")
endtry

qall!
