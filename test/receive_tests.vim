vim9script

def g:Test_Receive_status()
  assert_equal(execute("CompetiTest receive status"), "\n[competitest] receive: receiving not enabled.")
enddef

def g:Test_Receive_SubCommand()
  assert_equal(execute("CompetiTest receive start"), "\n[competitest] receive: unrecognized mode 'start'")
enddef

# vim: shiftwidth=2 softtabstop=2 noexpandtab
