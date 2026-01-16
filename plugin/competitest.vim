if !has("patch-9.1.2054")
  echoerr "Needs Vim version 9.1.2054 and above"
  finish
endif

vim9script noclear
# Vim global plugin for competitive programing
# Maintainer:     Mao-Yining <mao.yining@outlook.com>
# Last Modified:  2026-01-16

if get(g:, 'loaded_competitest', false)
  finish
endif
g:loaded_competitest = true

import autoload "../autoload/competitest/commands.vim"

command -bar -nargs=+ -complete=custom,commands.Complete CompetiTest commands.Handle(<q-args>)

def SetHighlight()
  hi CompetiTestRunning cterm=bold     gui=bold
  hi CompetiTestDone    cterm=none     gui=none
  hi CompetiTestCorrect ctermfg=green  guifg=Green
  hi CompetiTestWarning ctermfg=yellow guifg=Yellow
  hi CompetiTestWrong   ctermfg=red    guifg=Red
enddef

SetHighlight()

autocmd ColorScheme * SetHighlight()
