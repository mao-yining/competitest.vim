vim9script noclear
# Vim global plugin for competitive programing
# Last Change:  2025-06-29
# Maintainer:   毛同学 <stu_mao@outlook.com>

if exists("g:loaded_competitest")
  finish
endif
g:loaded_competitest = 1

if exists('g:competitest_config')
  competitest#Setup(g:competitest_config)
else
  competitest#Setup()
endif

def Complete(_: string, CmdLine: string, CursorPos: number): list<string> # {{{
    var prefix = CmdLine[ : CursorPos]
    var ending_space = prefix[-1 : -1] == " "
    var words = split(prefix)
    var wlen = len(words)

    if wlen == 1 || wlen == 2 && !ending_space
        return ["add_testcase", "edit_testcase", "delete_testcase", "convert", "run", "run_no_compile", "show_ui", "receive"]
    elseif wlen == 2 || wlen == 3 && !ending_space
        var lastword: string
        if wlen == 2
            lastword = words[-1]
        else
            lastword = words[-2]
        endif

        if lastword == "convert"
            return ["auto", "files_to_singlefile", "singlefile_to_files"]
        elseif lastword == "receive"
            return ["testcases", "problem", "contest", "persistently", "status", "stop"]
        endif
    endif
    return []
enddef # }}}

command -bar -nargs=* -complete=customlist,Complete CompetiTest competitest#commands#Command(<q-args>)
