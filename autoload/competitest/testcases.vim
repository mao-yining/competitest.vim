vim9script
# File: autoload/competitest/testcases.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Handle testcases tasks.
# Last Modified: 2026-01-16

import autoload "./config.vim"
import autoload "./utils.vim"

# Get testcases path for buffer
export def BufGetTestcasesPath(bufnr: number): string
  return bufname(bufnr)->fnamemodify(":h") .. "/" .. config.GetBufferConfig(bufnr).testcases_directory .. "/"
enddef

# Load testcases from directory with input/output files
def IOFilesLoad(directory: string, input_file_match: string, output_file_match: string): dict<any>
  if !isdirectory(directory)
    return null_dict
  endif

  var tctbl = {}

  # Helper: Extract consistent number from filename
  def MatchNumber(filename: string, match: string): number
    const list = matchlist(filename, match)
    if empty(list)
      return -1
    endif
    return str2nr(list[1])
  enddef

  # Process directory files
  for fname in readdir(directory)
    const fpath = directory .. fname
    if getftype(fpath) != "file"
      continue
    endif

    # Check input file
    var tcnum = MatchNumber(fname, input_file_match)
    if tcnum > -1
      if !tctbl->has_key(tcnum)
        tctbl[tcnum] = {}
      endif
      const bufnr = bufadd(fpath)
      setbufvar(bufnr, "&filetype", "competitest_in")
      setbufvar(bufnr, "&bufhidden", "hide")
      tctbl[tcnum].input_bufnr = bufnr
      tctbl[tcnum].input_bufname = fpath
    else
      # check if the given file is part of a testcase and is an output file
      tcnum = MatchNumber(fname, output_file_match)
      if tcnum > -1
        if !tctbl->has_key(tcnum)
          tctbl[tcnum] = {}
        endif
        const bufnr = bufadd(fpath)
        setbufvar(bufnr, "&filetype", "competitest_ans")
        setbufvar(bufnr, "&bufhidden", "hide")
        tctbl[tcnum].ans_bufnr = bufnr
        tctbl[tcnum].ans_bufname = fpath
      endif
    endif
  endfor
  return tctbl
enddef

# I/O files:
export def IOFileLocate(bufnr: number, tcnum: number): tuple<string, string>
  const dir = BufGetTestcasesPath(bufnr)
  const filepath = bufname(bufnr)
  const cfg = config.GetBufferConfig(bufnr)

  def ComputeFormat(format: string): string
    return utils.EvalString(filepath, format,
      utils.file_format_modifiers->copy()->extend({"TCNUM": tcnum}))
  enddef

  const input_file = ComputeFormat(cfg.testcases_input_file_format)
  const output_file = ComputeFormat(cfg.testcases_output_file_format)

  return (dir .. input_file, dir .. output_file)
enddef

export def IOSingleFileWrite(bufnr: number, tctbl: dict<any>)
  const cfg = config.GetBufferConfig(bufnr)
  IOFilesWriteEvalFormatString(
    BufGetTestcasesPath(bufnr),
    tctbl,
    bufname(bufnr),
    cfg.testcases_input_file_format,
    cfg.testcases_output_file_format
  )
enddef

export def IOFilesDelete(bufnr: number, tcnum: number)
  const [input_path, output_path] = IOFileLocate(bufnr, tcnum)
  if input_path->filereadable()
    delete(input_path)
  endif
  if output_path->filereadable()
    delete(output_path)
  endif
enddef

# Load using format strings with modifiers
def IOFilesLoadEvalFormatString(directory: string, filepath: string, input_file_format: string, output_file_format: string): dict<any>
  # Helper: Convert format string to match pattern
  def ComputeMatch(format: string): string
    final parts = format->split("$(TCNUM)", 1)
    for [idx, str] in items(parts)
      const evaluated = utils.EvalString(filepath, str)
      if evaluated == null_string
        return null_string
      endif
      parts[idx] = evaluated->substitute('(\W)', '%%%1', "g")->escape('^$~.*[]\\')
    endfor
    return "^" .. parts->join('\(\d\+\)') .. "$"
  enddef

  const input_match = ComputeMatch(input_file_format)
  const output_match = ComputeMatch(output_file_format)
  if input_match == null_string || output_match == null_string
    return null_dict
  endif

  return IOFilesLoad(directory, input_match, output_match)
enddef

# Get testcases for buffer
export def BufGetTestcases(bufnr: number): dict<any>
  const cfg = config.GetBufferConfig(bufnr)
  return IOFilesLoadEvalFormatString(
    BufGetTestcasesPath(bufnr),
    bufname(bufnr),
    cfg.testcases_input_file_format,
    cfg.testcases_output_file_format)
enddef

# Write testcases to directory as input/output files
def IOFilesWrite(directory: string, tctbl: dict<any>, input_file_format: string, output_file_format: string)
  # Helper: Write or delete file based on content
  def WriteFile(fpath: string, content: any)
    if type(content) != v:t_string || content == null_string
      if fpath->filereadable()
        delete(fpath)
      endif
    else
      utils.WriteStringOnFile(fpath, content)
    endif
  enddef

  for [tcnum, tc] in items(tctbl)
    const input_file = printf(input_file_format, str2nr(tcnum))
    const output_file = printf(output_file_format, str2nr(tcnum))
    const input_content = tc->get("input", v:none)
    const output_content = tc->get("output", v:none)

    WriteFile(directory .. input_file, input_content)
    WriteFile(directory .. output_file, output_content)
  endfor
enddef

# Write using format strings with modifiers
export def IOFilesWriteEvalFormatString(directory: string, tctbl: dict<any>, filepath: string, input_file_format: string, output_file_format: string)
  def ComputeFormat(format: string): string
    return utils.EvalString(filepath, format,
      utils.file_format_modifiers->copy()->extend({"TCNUM": "%d"}))
  enddef

  const input_format = ComputeFormat(input_file_format)
  const output_format = ComputeFormat(output_file_format)
  if input_format == null_string || output_format == null_string
    return
  endif

  IOFilesWrite(directory, tctbl, input_format, output_format)
enddef
