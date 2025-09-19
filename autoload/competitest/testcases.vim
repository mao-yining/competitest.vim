vim9script
# File: autoload\competitest\testcases.vim
# Author: mao-yining <mao.yining@outlook.com>
# Description: Handle testcases tasks.
# Last Modified: 2025-08-30

import autoload './config.vim'
import autoload './utils.vim'

# Get testcases path for buffer
export def BufGetTestcasesPath(bufnr: number): string
  return fnamemodify(bufname(bufnr), ':h') .. '/' .. config.GetBufferConfig(bufnr).testcases_directory .. '/'
enddef

# Load testcases from directory with input/output files
def IOFilesLoad(directory: string, input_file_match: string, output_file_match: string): dict<any>
  if !isdirectory(directory)
    return {}
  endif

  var tctbl: dict<any> = {}

  # Helper: Extract consistent number from filename
  def MatchNumber(filename: string, match: string): number
    var list = matchlist(filename, match)
    if empty(list)
      return -1
    endif
    var value = list[1]
    return str2nr(value)
  enddef

  # Process directory files
  for fname in readdir(directory)
    var fpath = directory .. fname
    if getftype(fpath) != 'file'
      continue
    endif

    # Check input file
    var tcnum = MatchNumber(fname, input_file_match)
    if tcnum > -1
      if !has_key(tctbl, tcnum)
        tctbl[tcnum] = {}
      endif
      var bufnr = bufadd(fpath)
      setbufvar(bufnr, '&filetype', "competitest_in")
      setbufvar(bufnr, '&bufhidden', 'hide')
      tctbl[tcnum].input_bufnr = bufnr
      tctbl[tcnum].input_bufname = fpath
    else
      # check if the given file is part of a testcase and is an output file
      tcnum = MatchNumber(fname, output_file_match)
      if tcnum > -1
        if !has_key(tctbl, tcnum)
          tctbl[tcnum] = {}
        endif
        var bufnr = bufadd(fpath)
        setbufvar(bufnr, '&filetype', "competitest_ans")
        setbufvar(bufnr, '&bufhidden', 'hide')
        tctbl[tcnum].ans_bufnr = bufnr
        tctbl[tcnum].ans_bufname = fpath
      endif
    endif
  endfor
  return tctbl
enddef

# I/O files:
export def IOFileLocate(bufnr: number, tcnum: number): list<string>
  var dir = BufGetTestcasesPath(bufnr)
  var filepath = bufname(bufnr)
  var conf = config.GetBufferConfig(bufnr)

  def ComputeFormat(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for idx in range(len(parts))
      var evaluated = utils.EvalString(filepath, parts[idx])
      if evaluated == null_string
        return ''
      endif
      parts[idx] = escape(evaluated, '%')
    endfor
    return join(parts, '%d')
  enddef

  var input_format = ComputeFormat(conf.testcases_input_file_format)
  var output_format = ComputeFormat(conf.testcases_output_file_format)

  var input_file = printf(input_format, tcnum)
  var output_file = printf(output_format, tcnum)

  return [dir .. input_file, dir .. output_file]
enddef

export def IOFIlesDelete(bufnr: number, tcnum: number)
  var [input_path, output_path] = IOFileLocate(bufnr, tcnum)
  if utils.DoesFileExist(input_path)
    utils.DeleteFile(input_path)
  endif
  if utils.DoesFileExist(output_path)
    utils.DeleteFile(output_path)
  endif
enddef

# Load using format strings with modifiers
def IOFilesLoadEvalFormatString(directory: string, filepath: string, input_file_format: string, output_file_format: string): dict<any>
  # Helper: Convert format string to match pattern
  def ComputeMatch(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for [idx, str] in items(parts)
      var evaluated = utils.EvalString(filepath, str)
      if evaluated == null_string
        return ''
      endif
      evaluated = substitute(evaluated, "([^%w])", "%%%1", 'g')
      parts[idx] = escape(evaluated, '^$~.*[]\\')
    endfor
    return '^' .. join(parts, '\([0-9]\+\)') .. '$'
  enddef

  var input_match = ComputeMatch(input_file_format)
  var output_match = ComputeMatch(output_file_format)
  if input_match == '' || output_match == ''
    return {}
  endif

  return IOFilesLoad(directory, input_match, output_match)
enddef

# Get testcases for buffer
export def BufGetTestcases(bufnr: number): dict<any>
  var conf = config.GetBufferConfig(bufnr)
  return IOFilesLoadEvalFormatString(
    BufGetTestcasesPath(bufnr),
    bufname(bufnr),
    conf.testcases_input_file_format,
    conf.testcases_output_file_format)
enddef

# Write testcases to directory as input/output files
def IOFilesWrite(directory: string, tctbl: dict<any>, input_file_format: string, output_file_format: string)
  # Helper: Write or delete file based on content
  def WriteFile(fpath: string, content: any)
    if type(content) != v:t_string || content == ''
      if utils.DoesFileExist(fpath)
        utils.DeleteFile(fpath)
      endif
    else
      utils.WriteStringOnFile(fpath, content)
    endif
  enddef

  for [tcnum, tc] in items(tctbl)
    var input_file = printf(input_file_format, str2nr(tcnum))
    var output_file = printf(output_file_format, str2nr(tcnum))
    var input_content = tc->get('input', v:null)
    var output_content = tc->get('output', v:null)

    WriteFile(directory .. input_file, input_content)
    WriteFile(directory .. output_file, output_content)
  endfor
enddef

# Write using format strings with modifiers
export def IOFilesWriteEvalFormatString(directory: string, tctbl: dict<any>, filepath: string, input_file_format: string, output_file_format: string)
  # Helper: Convert format string with modifiers
  def ComputeFormat(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for idx in range(len(parts))
      var evaluated = utils.EvalString(filepath, parts[idx])
      if evaluated == null_string
        return ''
      endif
      parts[idx] = escape(evaluated, '%')
    endfor
    return join(parts, '%d')
  enddef

  var input_format = ComputeFormat(input_file_format)
  var output_format = ComputeFormat(output_file_format)
  if input_format == '' || output_format == ''
    return
  endif

  IOFilesWrite(directory, tctbl, input_format, output_format)
enddef
