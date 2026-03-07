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

# Test receiving single testcase
def g:Test_Receive_SingleTestcase()
  # Create testcases directory
  const Xdir = "./XReceiveSingleTestcase/"->fnamemodify(":p")
  mkdir(Xdir, "pR")
  const test_file = Xdir .. "/Xtest.cpp"
  writefile(["int main() { return 0; }"], test_file)
  execute("edit " .. test_file, "silent!")

  const cfg = {
    testcases_input_file_format: "$(FNOEXT)$(TCNUM).in",
    testcases_output_file_format: "$(FNOEXT)$(TCNUM).ans",
    replace_received_testcases: true,
  }

  const test_data = {
    name: "A+B Problem",
    group: "ABC - Test",
    url: "https://blablabla/problems/test",
    memoryLimit: 1024,
    timeLimit: 1000,
    tests: [
      { input: "1 2\n", output: "3\n" },
      { input: "5 7\n", output: "12\n" }
    ],
    batch: { id: "test-batch", size: 1 },
    languages: { java: { mainClass: "Main", taskClass: "test" } }
  }

  try
    receive.StartReceiving("testcases", 27123, false, cfg, bufnr())
    SendTestData(27123, test_data)->assert_equal('{"status":"ok"}')

    const Xfile0_in  = Xdir .. "Xtest0.in"
    const Xfile0_ans = Xdir .. "Xtest0.ans"
    const Xfile1_in  = Xdir .. "Xtest1.in"
    const Xfile1_ans = Xdir .. "Xtest1.ans"

    var max_wait = 10
    while max_wait > 0 && !filereadable(Xfile0_in)
      sleep 10m
      max_wait -= 1
    endwhile

    filereadable(Xfile0_in)->assert_true()
    filereadable(Xfile0_ans)->assert_true()
    filereadable(Xfile1_in)->assert_true()
    filereadable(Xfile1_ans)->assert_true()

    readfile(Xfile0_in)->join("\n")->assert_equal("1 2")
    readfile(Xfile0_ans)->join("\n")->assert_equal("3")
    readfile(Xfile1_in)->join("\n")->assert_equal("5 7")
    readfile(Xfile1_ans)->join("\n")->assert_equal("12")
  finally
    receive.StopReceiving()
  endtry
enddef
