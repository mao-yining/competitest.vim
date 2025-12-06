if !has("patch-9.1.1000")
  echoerr "Needs Vim version 9.1.1000 and above"
  finish
endif

vim9script noclear
# Vim global plugin for competitive programing
# Maintainer:     Mao-Yining <mao.yining@outlook.com>
# Last Modified:  2025-12-06

if get(g:, 'loaded_competitest', false)
  finish
endif
g:loaded_competitest = true

import autoload "../autoload/competitest/commands.vim"

command -bar -nargs=+ -complete=custom,commands.Complete CompetiTest commands.Handle(<q-args>)
