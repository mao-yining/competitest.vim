vim9script
# File: autoload\competitest.vim
# Author: mao-yining <mao.yining@outlook.com>
# Last Modified:  2025-08-30

import autoload './competitest/config.vim'
import autoload './competitest/commands.vim'

# Setup CompetiTest
def Setup(opts: dict<any> = {})
  config.current_setup = config.UpdateConfigTable(config.current_setup, opts)

  SetupHighlight()
  autocmd ColorScheme * SetupHighlight()

  # Set q as exit for competitest_filetype
  autocmd Filetype competitest_in,competitest_out,competitest_ans,competitest_err nnoremap <buffer> q <Cmd>q<CR>
enddef

# Create CompetiTest highlight groups
def SetupHighlight()
  hi CompetiTestRunning cterm=bold     gui=bold
  hi CompetiTestDone    cterm=none     gui=none
  hi CompetiTestCorrect ctermfg=green  guifg=#00ff00
  hi CompetiTestWarning ctermfg=yellow guifg=orange
  hi CompetiTestWrong   ctermfg=red    guifg=#ff0000
enddef

export def HandleCommand(arguments: string)
  commands.Handle(arguments)
enddef

if exists('g:competitest_configs')
  Setup(g:competitest_configs)
else
  Setup()
endif
