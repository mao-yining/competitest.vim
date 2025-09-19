vim9script
# Vim global plugin for competitive programing
# Last Modified:  2025-09-19
# Maintainer:   Mao-Yining <mao.yining@outlook.com>

g:loaded_competitest = 1

import autoload "../autoload/competitest/commands.vim"

command -bar -nargs=+ -complete=custom,commands.Complete CompetiTest commands.Handle(<q-args>)
