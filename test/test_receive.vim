vim9script
import autoload "../autoload/competitest/receive.vim"
import autoload "../autoload/competitest/config.vim"

# Helper function to send test data to receiver using curl with list arguments
def SendTestData(port: number, data: dict<any>): string
  const json_str = json_encode(data)
  const tmpfile = "XSendData"
  writefile([json_str], tmpfile, 'D')

  # curl arguments as list for easy modification
  const cmd = [
    'curl',
    '-s',
    '-X', 'POST',
    '-H', 'Content-Type: application/json',
    '--data', '@' .. tmpfile,
    'http://localhost:' .. port
  ]

  return system(cmd->join(' '))
enddef

# Helper to check if receiver is running
def IsReceiverRunning(): bool
  return execute("CompetiTest receive status") !~ 'not enabled'
enddef

# Helper to confirm dialog choices in persistent mode
def ConfirmDialog(choice: string)
  feedkeys(choice .. "\<CR>", 't')
enddef

# Test receiver startup and shutdown
def g:Test_Receive_StartStop()
  try
    receive.StartReceiving("testcases", 27122, false, {}, bufnr())
    execute("CompetiTest receive status")
      ->assert_equal("\n[competitest] receive: receiving testcases, listening on port 27122.")
    receive.StopReceiving()
    execute("CompetiTest receive status")
      ->assert_equal("\n[competitest] receive: receiving not enabled.")
  finally
    receive.StopReceiving()
  endtry
enddef
