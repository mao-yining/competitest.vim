vim9script

export def Complete(_: string, CmdLine: string, CursorPos: number): list<string> # {{{
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

import autoload "./config.vim"
import autoload "./runner.vim"
import autoload "./testcases.vim"
import autoload "./widgets.vim"

export def Command(arguments: string): void # {{{
  var args = split(arguments, ' ')
  if empty(args)
    echoerr "command: at least one argument required."
    return
  endif

  # Check if current subcommand has the correct number of arguments
  def CheckSubargs(min_args: number, max_args: number): bool
    var count = len(args) - 1
    if min_args <= count && count <= max_args
      return true
    endif
    if min_args == max_args
      echoerr $"command: {args[0]}: exactly {min_args} sub-arguments required."
    else
      echoerr $"command: {args[0]}: from {min_args} to {max_args} sub-arguments required."
    endif
    return false
  enddef

  var subcommands: dict<func()> = {
    add_testcase: () => {
      if CheckSubargs(0, 0)
        EditTestcase(true, -1)
      endif
    },
    edit_testcase: () => {
      if CheckSubargs(0, 1)
        if exists("args[1]")
          EditTestcase(false, str2nr(args[1]))
        else
          EditTestcase(false, -1)
        endif
      endif
    },
    delete_testcase: () => {
      if CheckSubargs(0, 1)
        if exists("args[1]")
          DeleteTestcase(str2nr(args[1]))
        else
          DeleteTestcase(-1)
        endif
      endif
    },
    convert: () => {
      if CheckSubargs(1, 1)
        ConvertTestcases(args[1])
      endif
    },
    run: () => {
      var testcases_list: list<string> = []
      if exists("args[1]")
        testcases_list = args[1 : ]
      endif
      RunTestcases(testcases_list, true, false)
    },
    run_no_compile: () => {
      var testcases_list: list<string> = []
      if exists("args[1]")
        testcases_list = args[1 : ]
      endif
      RunTestcases(testcases_list, false, false)
    },
    show_ui: () => {
      if CheckSubargs(0, 0)
        RunTestcases(null_list, false, true)
      endif
    },
    receive: () => {
      if CheckSubargs(1, 1)
        Receive(args[1])
      endif
    },
  }

  if has_key(subcommands, args[0])
    subcommands[args[0]]()
  else
    echoerr $"command: subcommand {args[0]} doesn't exist!"
  endif
enddef # }}}

def EditTestcase(add_testcase: bool, tcnum: number): void
  var bufnr = bufnr()
  var num = tcnum
  config.LoadBufferConfig(bufnr) # reload buffer configuration since it may have been updated in the meantime
  var tctbl = testcases.BufGetTestcases(bufnr)
  if add_testcase
      num = 0
      while has_key(tctbl, num)
          num = num + 1
      endwhile
      tctbl[num] = { input: "", output: "" }
  endif

  # Start testcase editor to edit a testcase
  def StartEditor(n: number)
    if !has_key(tctbl, n)
      echoerr $"edit_testcase: testcase {n} doesn't exist!"
      return
    endif

    # Save edited testcase
    def SaveData(tc: dict<any>)
      if config.GetBufferConfig(bufnr).testcases_use_single_file
          tctbl[n] = tc
          testcases.SingleFileBufWrite(bufnr, tctbl)
      else
            testcases.IOFilesBufWritePair(bufnr, n, tc.input, tc.output)
      endif
    enddef

      widgets.Editor(bufnr, n, tctbl[n].input, tctbl[n].output, SaveData, win_getid())
  enddef
  if num == -1
      widgets.Picker(bufnr, tctbl, "Edit a Testcase", StartEditor, win_getid())
  else
      StartEditor(num)
  endif
enddef

def DeleteTestcase(tcnum: number = -1): void
  echo "TODO: DeleteTestcase"
enddef

def ConvertTestcases(mode: string): void
  echo "TODO: DeleteTestcase"
enddef

def Receive(mode: string)
  echo "TODO: Receive"
enddef

var runners: dict<any>

def RunTestcases(testcases_list: list<string>, compile: bool, only_show: bool) # {{{
    var bufnr = bufnr()
    config.LoadBufferConfig(bufnr)
    var tctbl = testcases.BufGetTestcases(bufnr)

    if testcases_list != null_list
        var new_tctbl = {}
        for [key, tcnum] in items(testcases_list)
          echom $"key: {key}, tcnum: {tcnum}"
            var num = str2nr(tcnum)
            if num == 0 || !has_key(tctbl, num) # invalid testcase
              echoerr $"run_testcases: testcase {tcnum} doesn't exist!"
            else
                new_tctbl[num] = tctbl[num]
            endif
        endfor
        tctbl = new_tctbl
    endif

    if !has_key(runners, bufnr) # no runner is associated to buffer
        runners[bufnr] = runner.New(bufnr)
        if !has_key(runners, bufnr) # an error occurred
            return
        endif
        # remove runner data when buffer is unloaded
        execute $"autocmd BufUnload <buffer= {bufnr}> competitest#commands#RemoveRunner({expand('<abuf>')})"
    endif

    var r = runners[bufnr] # current runner
    if !only_show
        r.kill_all_processes()
        r.run_testcases(tctbl, compile)
    endif
    r.SetRestoreWinID(win_getid())
    r.ShowUI()
enddef # }}}

def RunTestcase(tcnum: number)
enddef
