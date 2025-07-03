vim9script

# Builtin methods to compare output and expected output
export var methods = {
  exact: (output: string, expout: string) => {
    return output == expout
  },
  squish: (output: string, expout: string) => {
    def SquishString(st: string): string
      var str = st
      str = substitute(str, '\n', ' ', 'g')
      str = substitute(str, '\s\+', ' ', 'g')
      str = substitute(str, '^\s', '', '')
      str = substitute(str, '\s$', '', '')
      return str
    enddef
    var _output = SquishString(output)
    var _expout = SquishString(expout)
    return _output == _expout
  },
}

# Compare output and expected output to determine if they can match
# @param output - program output
# @param expected_output - expected result, or null_string when it isn't provided
# @param method - either a builtin method name ("exact" or "squish") or a comparison function
# @return - true if output matches expected output, false if they don't match, null_string if expected_output is null_string
export def CompareOutput(output: string, expected_output: string, method: any): any
echom "output: " .. output
echom "Answer: " .. expected_output
  if expected_output == null_string
    return null
  endif

  if type(method) == v:t_string && has_key(methods, method)
    return methods[method](output, expected_output)
  elseif type(method) == v:t_func
    var Res = function("method", [output, expected_output])
    return Res()
  else
    timer_start(0, (_) => {
      Notify("compare_output: unrecognized method " .. string(method))
    })
    return false
  endif
enddef

def Notify(msg: string)
  popup_notification(msg, { time: 2000 })
enddef
