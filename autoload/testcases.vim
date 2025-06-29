vim9script

def AddTestcase(): void
  const ft = &filetype
  const fname = expand('%:t:r')
  const test_dir = $"{g:competitest_config.testcase_dir}/{fname}"

  if !isdirectory(test_dir)
    mkdir(test_dir, 'p')
  endif

  const inputs = glob($"{test_dir}/input_*.txt", false, true)
  const next_id = inputs->len() + 1
  const input_file = $"{test_dir}/input_{next_id}.txt"
  const output_file = $"{test_dir}/output_{next_id}.txt"

  execute $'split {input_file}'
  execute $'vsplit {output_file}'
enddef
