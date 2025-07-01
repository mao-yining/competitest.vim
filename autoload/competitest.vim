vim9script

import autoload './competitest/config.vim' as config
export def Setup(opts: dict<any> = {})
  config.current_setup = config.UpdateConfigTable(config.current_setup, opts)
  SetupHighlight()
  autocmd ColorScheme * competitest#SetupHighlight()
  autocmd VimResized * competitest#ResizeUI()
enddef

export def SetupHighlight()
  hi CompetiTestRunning cterm=bold     gui=bold
  hi CompetiTestDone    cterm=none     gui=none
  hi CompetiTestCorrect ctermfg=green  guifg=#00ff00
  hi CompetiTestWarning ctermfg=yellow guifg=orange
  hi CompetiTestWrong   ctermfg=red    guifg=#ff0000
enddef

export def ResizeUI()
  # TODO: ResizeUI
enddef
