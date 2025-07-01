vim9script

export def Complete(_: string, CmdLine: string, CursorPos: number): list<string>
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
enddef

export def Command(arguments: string): void
  var args = split(arguments, ' ')
  if !args[0]
    echo "command: at least one argument required."
    return
  endif

  # Check if current subcommand has the correct number of arguments
  def CheckSubargs(min_args: number, max_args: number): bool
    var count = len(args) - 1
    if min_args <= count && count <= max_args
      return true
    endif
    if min_args == max_args
      echo $"command: {args[0]}: exactly {min_args} sub-arguments required."
    else
      echo $"command: {args[0]}: from {min_args} to {max_args} sub-arguments required."
    endif
    return false
  enddef

  var subcommands: dict<func()> = {
    add_testcase: () => {
      if CheckSubargs(0, 0)
        AddTestcase()
      endif
    },
    edit_testcase: () => {
      if CheckSubargs(0, 1)
        EditTestcase(str2nr(args[1]))
      endif
    },
    delete_testcase: () => {
      if CheckSubargs(0, 1)
        DeleteTestcase(str2nr(args[1]))
      endif
    },
    convert: () => {
      if CheckSubargs(1, 1)
        ConvertTestcases(args[1])
      endif
    },
    run: () => {
      var testcases_list: list<string> = []
      if args[1] != null_string
        testcases_list = args[1 : ]
      endif
      RunTestcases(testcases_list, true)
    },
    run_no_compile: () => {
      var testcases_list: list<string> = []
      if args[1] != null_string
        testcases_list = args[1 : ]
      endif
      RunTestcases(testcases_list, false)
    },
    show_ui: () => {
      if CheckSubargs(0, 0)
        ShowUI()
      endif
    },
    receive: () => {
      if CheckSubargs(1, 1)
        Receive(args[1])
      endif
    },
  }

  var Sub: func = subcommands[args[0]]
  if Sub == null_function
    echo $"command: subcommand '{args[0]}' doesn't exist!"
  else
    Sub()
  endif
enddef

def AddTestcase()
  echo "TODO: AddTestcase"
enddef

def EditTestcase(tcnum: number = -1): void
  echo "TODO: EditTestcase"
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

def ShowUI()
enddef

def RunTestcases(testcases_list: list<string>, conpile: bool)
enddef

def RunTestcase(tcnum: number)
enddef
