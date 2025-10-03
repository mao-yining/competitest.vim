vim9script
# File: autoload\competitest\receive.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Receive contest, problem and testcases from competitive-companion
# Last Modified: 2025-10-03

import autoload "./config.vim"
import autoload "./testcases.vim"
import autoload "./utils.vim"

# Task Format (https://github.com/jmerle/competitive-companion/#the-format)
type CCTask = dict<any>

# RECEIVE UTILITIES

const SCRIPT_DIR = expand('<sfile>:p:h')

class Receiver # {{{
  var port: number
  var CallBack: func(CCTask)
  var server: job
  def new(this.port, this.CallBack)
    this.server = $"python3 {SCRIPT_DIR}/receiver.py {this.port}"->job_start({
      out_cb: (_, message: string) => this.CallBack(json_decode(message)),
      err_cb: (_, message: string) => utils.EchoErr(message)
    })
    if this.server->job_status() == "fail"
      throw "Failed to start the receiver server. Please ensure python3 is installed and in your $PATH."
    endif
  enddef

  def Close(): void
    if this.server->job_status() == 'run'
      this.server->job_stop()
    endif
  enddef
endclass # }}}

class TasksCollector # {{{
  var CallBack: func(list<CCTask>)
  var batches = {}

  def Insert(task: CCTask): void
    if !has_key(this.batches, task.batch.id)
      this.batches[task.batch.id] = { size: task.batch.size, tasks: [] }
    endif
    var b = this.batches[task.batch.id]
    b.tasks->add(task)
    if b.size == len(b.tasks) # batch fully received
      const tasks = b.tasks
      this.batches = this.batches->remove(task.batch.id)
      this.CallBack(tasks)
    endif
  enddef
endclass # }}}

class BatchesSerialProcessor # {{{
  var CallBack: func(list<CCTask>, func())
  var batches: list<list<CCTask>> = []
  var callback_busy: bool = false
  var stopped: bool = false

  def EnQueue(batch: list<CCTask>)
    add(this.batches, batch)
    this.Process()
  enddef

  def Process(): void
    if empty(this.batches) || this.callback_busy || this.stopped
      return
    endif
    this.callback_busy = true
    const batch = this.batches->remove(0)
    this.CallBack(
      batch,
      () => { # Finished() is passed in here
        this.callback_busy = false
        this.Process()
      })
  enddef

  def Stop()
    this.stopped = true
  enddef

endclass # }}}

# RECEIVE METHODS

# ReceiveMode = "testcases" | "problem" | "contest" | "persistently"
type ReceiveMode = string

class ReceiveStatus # {{{
  var mode: ReceiveMode
  var companion_port: number
  var receiver: Receiver
  var tasks_collector: TasksCollector
  var batches_serial_processor: BatchesSerialProcessor
endclass # }}}

var rs: ReceiveStatus = null_object

export def StopReceiving(): void # {{{
  if rs != null_object
    rs.receiver.Close()
    rs.batches_serial_processor.Stop()
    rs = null_object
  endif
enddef # }}}

export def ShowStatus(): void # {{{
  if rs == null_object
    EchoMsg("receiving not enabled.")
  else
    EchoMsg($"receiving {rs.mode}, listening on port {rs.companion_port}.")
  endif
enddef # }}}

export def StartReceiving(mode: ReceiveMode, companion_port: number, notify: bool, cfg: dict<any>, bufnr = 0) # {{{
  if rs != null_object
    throw "receive: receiving already enabled, stop it if you want to change receive mode"
  endif

  # BatchesSerialProcessor callback
  var BSP_CallBack: func(list<CCTask>, any)
  if mode == "testcases" # {{{
    if bufnr == 0
      throw "receive: bufnr required when receiving testcases"
    endif
    BSP_CallBack = (tasks: list<CCTask>, _) => {
      StopReceiving()
      if notify
        EchoMsg("testcases received successfully!")
      endif
      StoreTestcases(bufnr, tasks[0].tests, cfg.replace_received_testcases, null_function)
    } # }}}
  elseif mode == "problem" # {{{
    BSP_CallBack = (tasks: list<CCTask>, _) => {
      StopReceiving()
      if notify
        EchoMsg("problem received successfully!")
      endif
      StoreSingleProblem(tasks[0], cfg, null_function)
    } # }}}
  elseif mode == "contest" # {{{
    BSP_CallBack = (tasks: list<CCTask>, _) => {
      StopReceiving()
      if notify
        EchoMsg("contest (" .. len(tasks) .. " tasks) received successfully!")
      endif
      StoreContest(tasks, cfg, null_function)
    } # }}}
  elseif mode == "persistently" # {{{
    BSP_CallBack = (tasks: list<CCTask>, Finished: func()) => {
      if notify
        if len(tasks) > 1
          EchoMsg($"contest ({len(tasks)} tasks) received successfully!")
        else
          EchoMsg("one task received successfully!")
        endif
      endif

      if len(tasks) > 1
        StoreContest(tasks, cfg, Finished)
      else
        var choice = confirm(
          $"One task received ({tasks[0].name}).\nDo you want to store its testcases only or the full problem?",
          "Testcases\nProblem\nCancel"
        )
        if choice == 1 # user chose "Testcases"
          StoreTestcases(
            bufnr(),
            tasks[0].tests,
            cfg.replace_received_testcases,
            Finished
          )
        elseif choice == 2 # user chose "Problem"
          StoreSingleProblem(tasks[0], cfg, Finished)
        else # user pressed <Esc> or chose "Cancel"
          Finished()
        endif
      endif
    }
  endif # }}}
  const batches_serial_processor = BatchesSerialProcessor.new(BSP_CallBack)
  const tasks_collector = TasksCollector.new((tasks: list<CCTask>) => {
    batches_serial_processor.EnQueue(tasks)
  })

  const receiver_or_error = Receiver.new(companion_port, (task: CCTask) => {
    tasks_collector.Insert(task)
  })

  rs = ReceiveStatus.new(
    mode,
    companion_port,
    receiver_or_error,
    tasks_collector,
    batches_serial_processor
  )

  if notify
    EchoMsg("ready to receive " .. mode .. ". Press the green plus button in your browser.")
  endif
enddef # }}}

# STORAGE UTILITIES

def EvalReceiveModifiers(str: string, task: CCTask, file_extension: string, remove_illegal_characters: bool, date_format = null_string): string # {{{
  const hyphen = stridx(task.group, " - ")
  const judge = hyphen == -1 ? task.group : task.group->strpart(0, hyphen)
  const contest = hyphen == -1 ? "unknown_contest" : task.group->strpart(hyphen + 3)

  # CompetiTest receive modifiers
  var receive_modifiers: dict<string> = {
    "": "$", # $(): replace it with a dollar
    "HOME": expand("~"), # home directory
    "CWD": getcwd(), # current working directory
    "FEXT": file_extension,
    "PROBLEM": task.name, # problem name, name field
    "GROUP": task.group, # judge and contest name, group field
    "JUDGE": judge, # first part of group, before hyphen
    "CONTEST": contest, # second part of group, after hyphen
    "URL": task.url, # problem url, url field
    "MEMLIM": string(task.memoryLimit), # available memory, memoryLimit field
    "TIMELIM": string(task.timeLimit), # time limit, timeLimit field
    "JAVA_MAIN_CLASS": task.languages.java.mainClass, # it's almost always 'Main'
    "JAVA_TASK_CLASS": task.languages.java.taskClass, # classname-friendly version of problem name
    "DATE": strftime(date_format != null_string ? date_format : "%Y-%m-%d"),
  }

  if remove_illegal_characters
    for [modifier, value] in items(receive_modifiers)
      if modifier != "HOME" && modifier != "CWD"
        receive_modifiers[modifier] = substitute(value, '[<>:"/\\|?*]', "_", "g")
      endif
    endfor
  endif

  try
    return utils.FormatStringModifiers(str, receive_modifiers)
  catch /^FormatStringModifiers:/
    utils.EchoErr(string(v:exception))
  endtry
  return null_string
enddef # }}}

def EvalPath(path: any, task: CCTask, file_extension: string): string # {{{
  if type(path) == v:t_string
    return EvalReceiveModifiers(path, task, file_extension, true)
  elseif type(path) == v:t_func
    const Path = path
    return Path(task, file_extension)
  endif
  return null_string
enddef # }}}

def StoreTestcases(bufnr: number, tclist: list<dict<string>>, replace: bool, Finished: func() = null_function): void # {{{
  var tctbl = testcases.BufGetTestcases(bufnr)
  if !empty(tctbl)
    if replace || "Some testcases already exist. Do you want to keep them along the new ones?"->confirm("Keep\nReplace") == 2
      for tcnum in tctbl->keys() # delete existing files
        testcases.IOFilesDelete(bufnr, str2nr(tcnum))
      endfor
      tctbl = {}
    else
      return
    endif
  endif

  var tcindex = 0
  for tc in tclist
    while tctbl->has_key(tcindex)
      tcindex += 1
    endwhile
    tctbl[tcindex] = tc
    tcindex += 1
  endfor

  testcases.IOSingleFileWrite(bufnr, tctbl)
  if Finished != null_function
    Finished()
  endif
enddef # }}}

def StoreReceivedTaskConfig(filepath: string, confirm_overwriting: bool, task: CCTask, cfg: dict<any>): void # {{{
  if confirm_overwriting && filereadable(filepath)
    if $'Do you want to overwrite "{filepath}"?'->confirm("Yes\nNo") != 1
      return
    endif
  endif

  const file_extension = fnamemodify(filepath, ":e")
  # Template file absolute path
  var template_file = null_string
  if type(cfg.template_file) == v:t_string # string with CompetiTest file-format modifiers
    template_file = utils.EvalString(filepath, cfg.template_file)
  elseif type(cfg.template_file) == v:t_dict # dict with paths to template files
    template_file = get(cfg.template_file, file_extension, null_string)
  endif

  if template_file != null_string
    template_file = substitute(template_file, "^\\~", expand("~"), "") # expand tilde into home directory
    if !filereadable(template_file)
      if type(cfg.template_file) == v:t_dict # notify file absence when path is explicitly set
        utils.EchoWarn('template file "' .. template_file .. "\" doesn't exist.")
      endif
      template_file = null_string
    endif
  endif

  const file_directory = fnamemodify(filepath, ":h")
  # if template file exists then template_file is a string
  if template_file != null_string
    if cfg.evaluate_template_modifiers
      const str = utils.LoadFileAsString(template_file)
      assert_true(str != null_string, "CompetiTest.vim: StoreReceivedTaskConfig: cannot load '" .. template_file .. "'")
      const evaluated_str = EvalReceiveModifiers(str, task, file_extension, false, cfg.date_format)
      utils.WriteStringOnFile(filepath, evaluated_str != null_string ? evaluated_str : "")
    else
      mkdir(file_directory, "p")
      writefile(readfile(template_file), filepath)
    endif
  else
    utils.WriteStringOnFile(filepath, null_string)
  endif

  var tctbl: dict<dict<string>> = {}
  var tcindex = 0
  # convert testcases list into a 0-indexed testcases dict
  for tc in task.tests
    tctbl[tcindex] = tc
    tcindex += 1
  endfor

  const tcdir = file_directory .. "/" .. cfg.testcases_directory .. "/"
  testcases.IOFilesWriteEvalFormatString(tcdir, tctbl, filepath, cfg.testcases_input_file_format, cfg.testcases_output_file_format)
enddef # }}}

def StoreSingleProblem(task: CCTask, cfg: dict<any>, Finished: func() = null_function): void # {{{
  const evaluated_problem_path = EvalPath(cfg.received_problems_path, task, cfg.received_files_extension)
  if evaluated_problem_path == null_string
    EchoMsg("'received_problems_path' evaluation failed for task '" .. task.name .. "'")
    if Finished != null_function
      Finished()
    endif
    return
  endif

  if cfg.received_problems_prompt_path
    const filepath = input("Choose problem path: ", evaluated_problem_path, "file")
    if filepath == null_string
      EchoMsg("operation interrupted")
      return
    endif
    const local_cfg = config.LoadLocalConfigAndExtend(fnamemodify(filepath, ":h"))
    StoreReceivedTaskConfig(filepath, true, task, local_cfg)
    if local_cfg.open_received_problems
      execute "edit " .. fnameescape(filepath)
    endif
    if Finished != null_function
      Finished()
    endif
  else
    if Finished != null_function
      Finished()
    endif
  endif
enddef # }}}

def StoreContest(tasks: list<CCTask>, cfg: dict<any>, Finished: func() = null_function): void # {{{
  const contest_directory = EvalPath(cfg.received_contests_directory, tasks[0], cfg.received_files_extension)
  if contest_directory == null_string
    EchoMsg("'received_contests_directory' evaluation failed")
    if Finished != null_function
      Finished()
    endif
    return
  endif

  if cfg.received_contests_prompt_directory
    const directory = input("Choose contest directory: ", contest_directory, "file")
    if directory == null_string
      EchoMsg("operation interrupted")
      return
    endif
    const local_cfg = config.LoadLocalConfigAndExtend(directory)
    if local_cfg.received_contests_prompt_extension
      const file_extension = input( "Choose files extension: ", local_cfg.received_files_extension)
      if file_extension == null_string
        EchoMsg("operation interrupted")
        return
      endif
      for task in tasks
        const problem_path = EvalPath(local_cfg.received_contests_problems_path, task, file_extension)
        if problem_path != null_string
          const filepath = directory .. "/" .. problem_path
          StoreReceivedTaskConfig(filepath, true, task, local_cfg)
          if local_cfg.open_received_contests
            execute "edit " .. fnameescape(filepath)
          endif
        else
          EchoMsg("'received_contests_problems_path' evaluation failed for task '" .. task.name .. "'")
        endif
      endfor
      if Finished != null_function
        Finished()
      endif
    else
      if Finished != null_function
        Finished()
      endif
    endif
  else
    if Finished != null_function
      Finished()
    endif
  endif
enddef # }}}

def EchoMsg(msg: string) # {{{
  echomsg $'[competitest] receive: {msg}'
enddef # }}}
