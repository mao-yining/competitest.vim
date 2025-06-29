vim9script noclear
# Vim global plugin for competitive programing
# Last Change:  2025-06-29
# Maintainer:   mao-yining <mao.yining@outlook.com>

if exists("g:loaded_competitest")
  finish
endif
g:loaded_competitest = 1

if exists('g:competitest_configs')
  competitest#Setup(g:competitest_configs)
else
  competitest#Setup()
endif

# Complete function for Commands
def Complete(_: string, CmdLine: string, CursorPos: number): list<string> # {{{
  var prefix = CmdLine[ : CursorPos]
  var ending_space = prefix[-1 : -1] == " "
  var words = split(prefix)
  var wlen = len(words)

  # 获取当前正在输入的词
  var current_word = ""
  if !ending_space && wlen > 0
    current_word = words[-1]
  endif

  if wlen == 1 || wlen == 2 && !ending_space
    var candidates = ["add_testcase", "edit_testcase", "delete_testcase", "run", "run_no_compile", "show_ui", "receive"]
    # 过滤出以当前输入开头的候选词
    if !empty(current_word)
      candidates = filter(candidates, (_, val) => val =~ '^' .. current_word)
    endif
    return candidates
  elseif wlen == 2 || wlen == 3 && !ending_space
    var lastword: string
    if wlen == 2
      lastword = words[-1]
    else
      lastword = words[-2]
    endif

    if lastword == "receive"
      var candidates = ["testcases", "problem", "contest", "persistently", "status", "stop"]
      # 过滤出以当前输入开头的候选词
      if !empty(current_word)
        if wlen == 2
          candidates = filter(candidates, (_, val) => val =~ '^' .. current_word)
        else
          candidates = filter(candidates, (_, val) => val =~ '^' .. words[-1])
        endif
      endif
      return candidates
    endif
  endif
  return []
enddef # }}}

command -bar -nargs=* -complete=customlist,Complete CompetiTest competitest#commands#Command(<q-args>)
