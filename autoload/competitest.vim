vim9script

import './commands.vim' as cmd
import './testcases.vim' as tc
import './runner.vim' as run
import './utils.vim' as util
import './receive.vim' as receive


export def Setup(user_config: dict<any> = {})
  g:competitest_config = extend(deepcopy(g:competitest_default_config), user_config)
enddef

export def AddTestcase()
  tc.AddTestcase()
enddef

export def RunTestcases()
  run.RunAllTestcases()
enddef

export def StartReceiver(): void
  receive.StartServer()
enddef

export def StopReceiver(): void
  receive.StopServer()
enddef
