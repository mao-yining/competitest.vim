vim9script

def RunAllTestcases(): void
  const fname = expand('%:t')
  const test_dir = $"{g:competitest_config.testcase_dir}/{fname:r}"
  const lang = &filetype

  const test_cases = glob($"{test_dir}/input_*.txt", false, true)
      ->map((_, v) => fnamemodify(v, ':t:r')->substitute('input_', '', ''))

  for case_id in test_cases
    RunTestCase(lang, test_dir, case_id)
  endfor
enddef

def RunTestCase(lang: string, dir: string, id: string): void
  const cmd = substitute(g:competitest_config.runner_language[lang], 
        \$'\$\(in\|out\)', 
        \$'\${\0}', 'g')->substitute('$in', expand('%'), '')
        ->substitute('$out', $"{dir}/temp_output", '')
        ->substitute('$id', id, 'g')

  const input_file = $"{dir}/input_{id}.txt"
  const output_file = $"{dir}/output_{id}.txt"
  const temp_output = $"{dir}/temp_output_{id}"

  job_start(cmd, {
    in_io: 'file',
    in_name: input_file,
    out_io: 'file',
    out_name: temp_output,
    close_cb: (_, _) => HandleRunResult(temp_output, output_file, id)
  })
enddef

def HandleRunResult(temp: string, expected: string, id: string): void
  const actual = readfile(temp)
  const expect = readfile(expected)

  if actual == expect
    echo $"[✓] Test {id} passed"
  else
    echo $"[✗] Test {id} failed"
    # 显示差异
  endif
  delete(temp)
enddef
