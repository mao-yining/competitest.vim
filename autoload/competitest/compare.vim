vim9script

# Builtin methods to compare output and expected output
export var methods = { # {{{
  exact: (output: string, expout: string) => output == expout,
  squish: (output: string, expout: string) => {
    def SquishString(str: string): string
      var res = str
      res = substitute(res, '\n', ' ', 'g')   # 将所有换行符 \n 替换为空格
      res = substitute(res, '\s\+', ' ', 'g') # 将连续空白字符替换为单个空格
      res = substitute(res, '^\s*', '', '')   # 删除开头的所有空白字符
      res = substitute(res, '\s*$', '', '')   # 删除结尾的所有空白字符
      return res
    enddef
    var _output = SquishString(output)
    var _expout = SquishString(expout)
    return _output == _expout
  },
} # }}}

export def CompareOutput(out_bufnr: number, ans_bufnr: number, method: any): any # {{{
  sleep 1m # should wait, because datas aren't fully loaded
  bufload(ans_bufnr)
  var outputs: list<string> = getbufline(out_bufnr, 1, '$')
  var answers: list<string> = getbufline(ans_bufnr, 1, '$')

  # handle CRLF
  var output: string = join(outputs, "\n") -> substitute('\r\n\', '\n', 'g')
  var answer: string = join(answers, "\n") -> substitute('\r\n\', '\n', 'g')

  if type(method) == v:t_string && has_key(methods, method)
    return methods[method](output, answer)
  elseif type(method) == v:t_func
    var Method = method
    return Method(output, answer)
  else
    echoerr "compare_output: unrecognized method " .. string(method)
    return false
  endif

enddef # }}}
