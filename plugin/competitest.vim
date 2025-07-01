vim9script
# Vim global plugin for competitive programing
# Last Change:  2025-06-29
# Maintainer:   毛同学 <stu_mao@outlook.com>

if exists("g:loaded_competitest")
  finish
endif
g:loaded_competitest = 1

command! -bar -nargs=* -complete=customlist,competitest#commands#Complete CompetiTest competitest#commands#Command(<q-args>)

competitest#Setup()

if exists('g:competitest_config')
  competitest#Setup(g:competitest_config)
else
  competitest#Setup()
endif
