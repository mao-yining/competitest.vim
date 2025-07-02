vim9script

import autoload './config.vim' as config
import autoload './utils.vim' as utils

#-----------------------------------------------------------------------#
# Normal methods: I/O files
#-----------------------------------------------------------------------#

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
    var value = list[1]  # Vim9 列表索引从 0 开始
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
      tctbl[tcnum].input = utils.LoadFileAsString(fpath)
    else
      # check if the given file is part of a testcase and is an output file
      tcnum = MatchNumber(fname, output_file_match)
      if tcnum > -1
        if !has_key(tctbl, tcnum)
          tctbl[tcnum] = {}
        endif
        tctbl[tcnum].output = utils.LoadFileAsString(fpath)
      endif
    endif
  endfor
  return tctbl
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

# Load using format strings with modifiers
def IOFilesLoadEvalFormatString(directory: string, filepath: string, input_file_format: string, output_file_format: string): dict<any>
  # Helper: Convert format string to match pattern
  def ComputeMatch(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for idx in range(len(parts))
      var evaluated = utils.FormatStringModifiers(parts[idx])
      if evaluated == null_string
        return ''
      endif
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

# Write using format strings with modifiers
def IOFilesWriteEvalFormatString(directory: string, tctbl: dict<any>, filepath: string, input_file_format: string, output_file_format: string)
  # Helper: Convert format string with modifiers
  def ComputeFormat(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for idx in range(len(parts))
      var evaluated = utils.FormatStringModifiers(parts[idx])
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

#-----------------------------------------------------------------------#
# Buffer methods
#-----------------------------------------------------------------------#

# Get testcases path for buffer
export def BufGetTestcasesPath(bufnr: number): string
  return fnamemodify(bufname(bufnr), ':h') .. '/' .. config.GetBufferConfig(bufnr).testcases_directory .. '/'
enddef

# I/O files: Write for buffer
export def IOFilesBufWrite(bufnr: number, tctbl: dict<any>)
  var dir = BufGetTestcasesPath(bufnr)
  var fpath = bufname(bufnr)
  var conf = config.GetBufferConfig(bufnr)
  IOFilesWriteEvalFormatString(
    dir, tctbl, fpath,
    conf.testcases_input_file_format,
    conf.testcases_output_file_format)
enddef

# I/O files:
export def IOFileLocate(bufnr: number, tcnum: number): list<string>
  var dir = BufGetTestcasesPath(bufnr)
  var filepath = bufname(bufnr)
  var conf = config.GetBufferConfig(bufnr)

  def ComputeFormat(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for idx in range(len(parts))
      var evaluated = utils.FormatStringModifiers(parts[idx])
      if evaluated == null_string
        return ''
      endif
      parts[idx] = escape(evaluated, '%')
    endfor
    return join(parts, '%d')
  enddef
  # 计算输入文件格式
  var input_format = ComputeFormat(conf.testcases_input_file_format)
  # 计算输出文件格式
  var output_format = ComputeFormat(conf.testcases_output_file_format)

  # 生成文件路径
  var input_file = printf(input_format, tcnum)
  var output_file = printf(output_format, tcnum)

  return [dir .. input_file, dir .. output_file]
enddef

def IOFileEvalFormatString(directory: string, tctbl: dict<any>, filepath: string, input_file_format: string, output_file_format: string)
  # Helper: Convert format string with modifiers
  def ComputeFormat(format: string): string
    var parts = split(format, '$(TCNUM)', 1)
    for idx in range(len(parts))
      var evaluated = utils.FormatStringModifiers(parts[idx])
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

  return ( input_format, output_format )
enddef

# I/O files: Write single testcase pair
export def IOFilesBufWritePair(bufnr: number, tcnum: number, input = "", output = "")
  var tctbl = {[tcnum]: {input: input, output: output}}
  IOFilesBufWrite(bufnr, tctbl)
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

# Write testcases for buffer
def BufWriteTestcases(bufnr: number, tctbl: dict<any>)
  IOFilesBufWrite(bufnr, tctbl)
enddef

