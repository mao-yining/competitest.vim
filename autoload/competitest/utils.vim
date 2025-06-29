vim9script
# File: utils.vim
# Author: mao-yining
# Description: utility functions
# Last Modified: 七月 02, 2025

# 格式化字符串修饰符
export def FormatStringModifiers(str: string, modifiers: dict<any>, argument = null_string): string
  var evaluated_str: list<string>
  var mod_start = 0  # 0: idle, -1: saw '$', >0: position of '('
  var n = len(str)

  for i in range(0, n - 1)
    var c = str[i]
    if mod_start == -1  # 期望 '('
      if c == '('
        mod_start = i  # 记录 '(' 的位置
      else
        echoerr "FormatStringModifiers: '$' isn't followed by '(' in:\n" .. str
        return null_string
      endif
    elseif mod_start == 0  # 空闲状态
      if c == '$'
        mod_start = -1  # 标记遇到 '$'
      else
        add(evaluated_str, c)
      endif
    elseif mod_start != 0 && c == ')'
      var mod = str[mod_start + 1 : i - 1]  # 提取修饰符名称
      var replacement = modifiers->get(mod, null_string)
      if replacement == null_string
        echoerr 'FormatStringModifiers: unrecognized modifier $(' .. mod .. ')'
        return null_string
      endif

      if type(replacement) == v:t_string
        add(evaluated_str, replacement)
      elseif type(replacement) == v:t_func
        var Replacement = replacement
        add(evaluated_str, Replacement(argument))
      else
        echoerr 'FormatStringModifiers: invalid modifier type for $(' .. mod .. ')'
        return null_string
      endif
      mod_start = 0
    endif
  endfor

  # 错误处理：未完成的修饰符
  if mod_start == -1
    echo "format_string_modifiers: '$' at end without '(' in:\n" .. str
    return null_string
  elseif mod_start > 0
    echo "format_string_modifiers: unclosed modifier starting at position " .. mod_start
    return null_string
  endif

  return evaluated_str->join('')
enddef

# 文件格式修饰符定义
var file_format_modifiers = {
  '': '$',
  'HOME': (filepath: string): string => expand('~'),
  'FNAME': (filepath: string): string => fnamemodify(filepath, ':t'),
  'FNOEXT': (filepath: string): string => fnamemodify(filepath, ':t:r'),
  'FEXT': (filepath: string): string => fnamemodify(filepath, ':e'),
  'FABSPATH': (filepath: string): string => filepath,
  'ABSDIR': (filepath: string): string => fnamemodify(filepath, ':p:h'),
  'TCNUM': ''
}

export def EvalString(filepath: string, str: string): string
  return FormatStringModifiers(str, file_format_modifiers, filepath)
enddef

# 缓冲区上下文评估文件格式字符串
export def BufEvalString(bufnr: number, str: string, tcnum: any = null): string
  file_format_modifiers['TCNUM'] = string(tcnum ?? '')
  return EvalString(bufname(bufnr), str)
enddef

# 检查文件是否存在
export def DoesFileExist(filepath: string): bool
  return getftype(filepath) != ''
enddef

# 读取文件内容为字符串
export def LoadFileAsString(filepath: string): string
  if !filereadable(filepath)
    return null_string
  endif
  try
    var content = join(readfile(filepath), "\n")
    return substitute(content, "\r\n", "\n", 'g')
  catch
    return null_string
  endtry
enddef

# 创建目录（递归）
export def CreateDirectory(dirpath: string)
  if !isdirectory(dirpath)
    var safedirpath = substitute(dirpath, '[/\\]\+$', '', '')
    var upper_dir = fnamemodify(safedirpath, ':h')
    if upper_dir != safedirpath
      CreateDirectory(upper_dir)
    endif
    mkdir(safedirpath, 'p')
  endif
enddef

# 将字符串写入文件
export def WriteStringOnFile(filepath: string, content: string)
  CreateDirectory(fnamemodify(filepath, ':h'))
  writefile(content->split("\n"), filepath)
enddef

# 删除文件
export def DeleteFile(filepath: string)
  delete(filepath)
enddef

# 获取 UI 尺寸
export def GetUISize(): list<number>
  var height = &lines - &cmdheight
  if &laststatus != 0
    height -= 1
  endif
  return [&columns, height]
enddef

export def GetBorderChars(style: string): list<string>
  if style == 'double'
    return ['═', '║', '═', '║', '╔', '╗', '╝', '╚']
  elseif style == 'rounded'
    return ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
  else # 'single' or default
    return ['─', '│', '─', '│', '┌', '┐', '┘', '└']
  endif
enddef

