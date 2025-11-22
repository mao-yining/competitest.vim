vim9script

def g:Test_Receive_status()
  execute("CompetiTest receive status")->assert_equal("\n[competitest] receive: receiving not enabled.")
enddef

def g:Test_Receive_SubCommand()
  execute("CompetiTest receive start")->assert_equal("\n[competitest] receive: unrecognized mode 'start'")
enddef
