vim9script
# File: autoload/competitest/utils.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: utility functions
# Last Modified: 2026-01-02

# Formats string by replacing $(modifier) tokens with corresponding values
# from the provided dictionary, supporting both static string values and
# callback functions for dynamic replacement.
export def FormatStringModifiers(str: string, modifiers: dict<any>, argument = null_string): string # {{{
  var evaluated_str: list<string>
  var mod_start = 0  # 0: idle, -1: saw '$', >0: position of '('

  for i in range(len(str))
    const c = str[i]
    if mod_start == -1  # expect '('
      if c == '('
        mod_start = i  # position of '('
      else
        throw "FormatStringModifiers: '$' isn't followed by '(' in:\n" .. str
      endif
    elseif mod_start == 0  # empty
      if c == '$'
        mod_start = -1
      else
        add(evaluated_str, c)
      endif
    elseif mod_start != 0 && c == ')'
      const mod = str[mod_start + 1 : i - 1]
      const replacement = modifiers->get(mod) # return number 0 in default
      if type(replacement) == v:t_number
        throw $"FormatStringModifiers: unrecognized modifier $({mod})"
      elseif type(replacement) == v:t_string
        evaluated_str->add(replacement)
      elseif type(replacement) == v:t_func
        const Replacement = replacement
        evaluated_str->add(Replacement(argument))
      else
        throw $"FormatStringModifiers: invalid modifier type for $({mod})"
      endif
      mod_start = 0
    endif
  endfor

  if mod_start == -1
    throw "FormatStringModifiers: '$' at end without '(' in:\n" .. str
  elseif mod_start > 0
    throw "FormatStringModifiers: unclosed modifier starting at position " .. mod_start
  endif

  return evaluated_str->join(null_string)
enddef # }}}

const file_format_modifiers = { # {{{
  "": "$",
  "ABSDIR": (filepath: string) => fnamemodify(filepath, ":p:h"),
  "FABSPATH": (filepath: string) => filepath,
  "FEXT": (filepath: string) => fnamemodify(filepath, ":e"),
  "FNAME": (filepath: string) => fnamemodify(filepath, ":t"),
  "FNOEXT": (filepath: string) => fnamemodify(filepath, ":t:r"),
  "HOME": (_) => expand("~"),
} # }}}

export def EvalString(filepath: string, str: string): string # {{{
  try
    return FormatStringModifiers(str, file_format_modifiers, filepath)
  catch /^FormatStringModifiers:/
    EchoErr(string(v:exception))
  endtry
  return null_string
enddef # }}}

export def LoadFileAsString(filepath: string): string # {{{
  if filereadable(filepath)
    return readfile(filepath)->join("\n")->substitute("\r\n", "\n", "g")
  else
    return null_string
  endif
enddef # }}}

export def CreateDirectory(dirpath: string) # {{{
  if !isdirectory(dirpath)
    const safedirpath = substitute(dirpath, '[/\\]\+$', "", "")
    const upper_dir = fnamemodify(safedirpath, ":h")
    if upper_dir != safedirpath
      CreateDirectory(upper_dir)
    endif
    mkdir(safedirpath, "p")
  endif
enddef # }}}

export def WriteStringOnFile(filepath: string, content: string) # {{{
  CreateDirectory(fnamemodify(filepath, ":h"))
  writefile(content->split("\n"), filepath)
enddef # }}}

export def EchoErr(msg: string) # {{{
  echohl ErrorMsg | echom $"[competitest] {msg}" | echohl None
enddef # }}}

export def EchoWarn(msg: string) # {{{
  echohl WarningMsg | echom $"[competitest] {msg}" | echohl None
enddef # }}}
