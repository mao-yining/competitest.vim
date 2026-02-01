if !has("patch-9.1.2054")
  echoerr "Needs Vim version 9.1.2054 and above"
  finish
endif

vim9script
# Vim global plugin for competitive programing
# Maintainer:     Mao-Yining <mao.yining@outlook.com>
# Last Modified:  2026-02-01

import autoload "../autoload/competitest/commands.vim"

command -bar -nargs=+ -complete=custom,commands.Complete CompetiTest commands.Handle(<q-args>)
