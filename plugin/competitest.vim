vim9script noclear
# Vim global plugin for competitive programing
# Maintainer:     Mao-Yining <mao.yining@outlook.com>
# Last Modified:  2025-10-03

if exists("g:loaded_competitest")
  finish
endif

g:loaded_competitest = true

import autoload "../autoload/competitest/commands.vim"

command -bar -nargs=+ -complete=custom,commands.Complete CompetiTest commands.Handle(<q-args>)
