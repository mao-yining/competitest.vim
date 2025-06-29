vim9script

import autoload './competitest/config.vim'

# Setup CompetiTest
export def Setup(opts: dict<any> = {})
  config.current_setup = config.UpdateConfigTable(config.current_setup, opts)

  SetupHighlight()
  autocmd ColorScheme * competitest#SetupHighlight()

  # Set q as exit for competitest_filetype
  autocmd Filetype competitest_in,competitest_out,competitest_ans,competitest_err,competitest_testcases nnoremap <buffer> q <Cmd>q<CR>
enddef

# Create CompetiTest highlight groups
export def SetupHighlight()
  hi CompetiTestRunning cterm=bold     gui=bold
  hi CompetiTestDone    cterm=none     gui=none
  hi CompetiTestCorrect ctermfg=green  guifg=#00ff00
  hi CompetiTestWarning ctermfg=yellow guifg=orange
  hi CompetiTestWrong   ctermfg=red    guifg=#ff0000
enddef
