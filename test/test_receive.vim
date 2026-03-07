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

# Test receiving problem (with template)
def g:Test_Receive_Problem()
  const Xdir = "./XReceiveProblem/"->fnamemodify(":p")
  mkdir(Xdir, "pR")

  const template_file = Xdir .. "/template.cpp"
  const template_content =<< trim END
    // Problem: $(PROBLEM)
    // Judge: $(JUDGE)
    // Contest: $(CONTEST)
    // URL: $(URL)
    // Time Limit: $(TIMELIM)ms
    // Memory Limit: $(MEMLIM)MB
  END
  writefile(template_content, template_file)

  const cfg = {
    template_file: template_file,
    evaluate_template_modifiers: true,
    received_files_extension: "cpp",
    received_problems_path: Xdir .. "/$(PROBLEM).$(FEXT)",
    received_problems_prompt_path: false,
    open_received_problems: false,
    testcases_input_file_format: "$(FNOEXT)$(TCNUM).in",
    testcases_output_file_format: "$(FNOEXT)$(TCNUM).ans",
    replace_received_testcases: true,
  }
  g:competitest_configs = get(g:, 'competitest_configs', {})->extend(cfg)

  const test_data = {
    name: "sum",
    group: "UOJ - Test Problems",
    url: "https://foo/bar/",
    memoryLimit: 256,
    timeLimit: 2000,
    tests: [ { input: "1 2\n", output: "3\n" } ],
    batch: { id: "problem-batch", size: 1 },
    languages: { java: { mainClass: "Main", taskClass: "sum" } }
  }

  try
    receive.StartReceiving("problem", 27124, false, cfg, 0)
    SendTestData(27124, test_data)->assert_equal('{"status":"ok"}')
    const problem_file = Xdir .. "/sum.cpp"
    var max_wait = 10
    while max_wait > 0 && !filereadable(problem_file)
      sleep 10m
      max_wait -= 1
    endwhile
    filereadable(problem_file)->assert_true()

    const content = readfile(problem_file)
    content[0]->assert_equal("// Problem: sum")
    content[1]->assert_equal("// Judge: UOJ")
    content[2]->assert_equal("// Contest: Test Problems")
    content[3]->assert_equal("// URL: https://foo/bar/")
    content[4]->assert_equal("// Time Limit: 2000ms")
    content[5]->assert_equal("// Memory Limit: 256MB")

    const Xfile_in = Xdir .. "/sum0.in"
    const Xfile_ans = Xdir .. "/sum0.ans"
    filereadable(Xfile_in)->assert_true()
    filereadable(Xfile_ans)->assert_true()
    readfile(Xfile_in)->join("\n")->assert_equal("1 2")
    readfile(Xfile_ans)->join("\n")->assert_equal("3")
  finally
    receive.StopReceiving()
  endtry
enddef
