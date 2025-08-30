vim9script noclear
# Vim global plugin for competitive programing
# Last Modified:  2025-08-30
# Maintainer:   mao-yining <mao.yining@outlook.com>

if exists("g:loaded_competitest")
  finish
endif
g:loaded_competitest = 1

# Complete function for Commands
def Complete(_: string, CmdLine: string, CursorPos: number): string # {{{
  var ending_space = CmdLine[CursorPos - 1] == " "
  var words = split(CmdLine)
  var wlen = len(words)

  if wlen == 1 || wlen == 2 && !ending_space
    return "add_testcase\nedit_testcase\ndelete_testcase\nrun\nrun_no_compile\nshow_ui\nreceive"
  elseif wlen == 2 && words[-1] == "receive" || wlen == 3 && words[-2] == "receive" && !ending_space
    return "testcases\nproblem\ncontest\npersistently\nstatus\nstop"
  else
    return null_string
  endif
enddef # }}}

command -bar -nargs=* -complete=custom,Complete CompetiTest competitest#HandleCommand(<q-args>)
