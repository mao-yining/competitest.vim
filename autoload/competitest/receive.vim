vim9script

import autoload "./config.vim"
import autoload "./testcases.vim"
import autoload "./utils.vim"

# competitive-companion task format (https://github.com/jmerle/competitive-companion/#the-format)
class CCTask
  var name: string
  var group: string
  var url: string
  var interactive: bool
  var memoryLimit: number
  var timeLimit: number
  var tests: list<dict<string>>
  var testType: string
  var input: dict<any>
  var output: dict<any>
  var languages: dict<any>
  var batch: dict<any>
  def new(data: dict<any>)
    this.name = data.name
    this.group = data.group
    this.url = data.url
    this.interactive = data.interactive
    this.memoryLimit = data.memoryLimit
    this.timeLimit = data.timeLimit
    this.tests = data.tests
    this.testType = data.testType
    this.input = data.input
    this.output = data.output
    this.languages = data.languages
    this.batch = data.batch
  enddef
endclass

# RECEIVE UTILITIES

const SCRIPT_DIR = expand('<sfile>:p:h')
class Receiver
  var server: job
  var port: number
  var CallBack: func(CCTask)
  def new(port: number, CallBack: func(CCTask))
    def OnReceive(message: string)
      var data = json_decode(message)
      if data.type == 'status'
        echom data.message
      elseif data.type == 'problem'
        this.CallBack(CCTask.new(data.data))
      elseif data.type == 'error'
        echohl ErrorMsg
        echom data.message
        echohl None
      endif
    enddef

    this.server = job_start(["python", SCRIPT_DIR .. '/receiver.py', string(port)], {
      out_cb: (_, message: string) => OnReceive(message),
    })
    this.CallBack = CallBack
  enddef

  def Close(): void
    if ch_status(this.server) == 'open'
      ch_close(this.server)
    endif
  enddef
endclass


# Create a new `TasksCollector`
class TasksCollector
  var batches: dict<any> # TODO: test whether list<any> <24-07-25> #
  var CallBack: func(list<CCTask>)
  def new(CallBack: func(list<CCTask>))
    this.batches = {}
    this.CallBack = CallBack
  enddef

  def Insert(task: CCTask): void
    if !has_key(this.batches, task.batch.id)
      this.batches[task.batch.id] = { size: task.batch.size, tasks: [] }
    endif
    var b = this.batches[task.batch.id]
    add(b.tasks, task)
    if b.size == len(b.tasks) # batch fully received
      var tasks = b.tasks
      this.batches = remove(this.batches, task.batch.id)
      this.CallBack(tasks)
    endif
  enddef
endclass

class BatchesSerialProcessor
  var batches: list<list<CCTask>> = []
  var CallBack: func(list<CCTask>, func())
  var callback_busy: bool = false
  var stopped: bool = false
  def new(CallBack: func(list<CCTask>, func()))
    this.CallBack = CallBack
  enddef

  def EnQueue(batch: list<CCTask>)
    add(this.batches, batch)
    this.Process()
  enddef

  def Process(): void
    if empty(this.batches) || this.callback_busy || this.stopped
      return
    endif
    this.callback_busy = true
    var batch = this.batches[0]
    remove(this.batches, 0)
    this.CallBack(
      batch,
      () => {
        this.callback_busy = false
        this.Process()
      })
  enddef

  def Stop()
    this.stopped = true
  enddef
endclass

# RECEIVE METHODS

# ReceiveMode = "testcases" | "problem" | "contest" | "persistently"
type ReceiveMode = string

class ReceiveStatus
  var mode: ReceiveMode
  var companion_port: number
  var receiver: Receiver
  var tasks_collector: TasksCollector
  var batches_serial_processor: BatchesSerialProcessor
  def new(this.mode, this.companion_port, this.receiver, this.tasks_collector, this.batches_serial_processor)
  enddef
endclass


var rs: ReceiveStatus = null_object

export def StopReceiving(): void
  if rs != null_object
    rs.receiver.Close()
    rs.batches_serial_processor.Stop()
    rs = null_object
  endif
enddef

export def ShowStatus(): void
  var msg: string
  if rs == null_object
    msg = "receiving not enabled."
  else
    msg = "receiving " .. rs.mode .. ", listening on port " .. rs.companion_port .. "."
  endif
  echo msg
enddef

export def StartReceiving(mode: ReceiveMode, companion_port: number, notify_on_start: bool, notify_on_receive: bool, cfg: dict<any>, bufnr = 0): string
  if rs != null_object
    return "receiving already enabled, stop it if you want to change receive mode"
  endif

  # BatchesSerialProcessor callback
  var BSP_CallBack: func(list<CCTask>, any)
  if mode == "testcases" # {{{
    if bufnr == 0
      return "bufnr required when receiving testcases"
    endif
    BSP_CallBack = (tasks: list<CCTask>, _) => {
      StopReceiving()
      if notify_on_receive
        echo "testcases received successfully!"
      endif
      StoreTestcases(bufnr, tasks[0].tests, cfg.testcases_use_single_file, cfg.replace_received_testcases, null_function)
    } # }}}
  elseif mode == "problem" # {{{
    BSP_CallBack = (tasks: list<CCTask>, _) => {
      StopReceiving()
      if notify_on_receive
        echo "problem received successfully!"
      endif
      StoreSingleProblem(tasks[0], cfg, null_function)
    } # }}}
  elseif mode == "contest" # {{{
    BSP_CallBack = (tasks: list<CCTask>, _) => {
      StopReceiving()
      if notify_on_receive
        echo "contest (" .. len(tasks) .. " tasks) received successfully!"
      endif
      StoreContest(tasks, cfg, null_function)
    } # }}}
  elseif mode == "persistently" # {{{
    BSP_CallBack = (tasks: list<CCTask>, Finished: func()) => {
      if notify_on_receive
        if len(tasks) > 1
          echo "contest (" .. len(tasks) .. " tasks) received successfully!"
        else
          echo "one task received successfully!"
        endif
      endif

      if len(tasks) > 1
        StoreContest(tasks, cfg, Finished)
      else
        var choice = confirm(
          "One task received (" .. tasks[0].name .. ").\nDo you want to store its testcases only or the full problem?",
          "Testcases\nProblem\nCancel"
        )
        if choice == 1 # user chose "Testcases"
          StoreTestcases(
            bufnr(),
            tasks[0].tests,
            cfg.testcases_use_single_file,
            cfg.replace_received_testcases,
            Finished
          )
        elseif choice == 2 # user chose "Problem"
          StoreSingleProblem(tasks[0], cfg, Finished)
        else # user pressed <esc> or chose "Cancel"
          Finished()
        endif
      endif
    }
  endif # }}}
  var batches_serial_processor = BatchesSerialProcessor.new(BSP_CallBack)
  var tasks_collector = TasksCollector.new((tasks: list<CCTask>) => {
    batches_serial_processor.EnQueue(tasks)
  })

  var receiver_or_error = Receiver.new(companion_port, (task: CCTask) => {
    tasks_collector.Insert(task)
  })

  rs = ReceiveStatus.new(
    mode,
    companion_port,
    receiver_or_error,
    tasks_collector,
    batches_serial_processor
  )

  if notify_on_start
    echo "ready to receive " .. mode .. ". Press the green plus button in your browser."
  endif
  return null_string
enddef

# STORAGE UTILITIES

def EvalReceiveModifiers(str: string, task: CCTask, file_extension: string, remove_illegal_characters: bool, date_format: string = null_string): string
  var judge: string
  var contest: string
  var hyphen = stridx(task.group, " - ")
  if hyphen == -1
    judge = task.group
    contest = "unknown_contest"
  else
    judge = strpart(task.group, 0, hyphen)
    contest = strpart(task.group, hyphen + 3)
  endif

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

  return utils.FormatStringModifiers(str, receive_modifiers)
enddef

def EvalPath(path: any, task: CCTask, file_extension: string): string
  if type(path) == v:t_string
    return EvalReceiveModifiers(path, task, file_extension, true)
  elseif type(path) == v:t_func
    var Path = path
    return Path(task, file_extension)
  endif
  return null_string
enddef

def StoreTestcases(bufnr: number, tclist: list<dict<string>>, use_single_file: bool, replace: bool, Finished: func() = null_function): void
  var tctbl = testcases.BufGetTestcases(bufnr)
  if !empty(tctbl)
    var choice = 2
    if !replace
      choice = confirm("Some testcases already exist. Do you want to keep them along the new ones?", "Keep\nReplace\nCancel")
    endif
    if choice == 2 # user chose "Replace"
      if !use_single_file
        for tcnum in keys(tctbl) # delete existing files
          testcases.io_files.buf_write_pair(bufnr, tcnum, null_string, null_string)
        endfor
      endif
      tctbl = {}
    elseif choice == 0 || choice == 3 # user pressed <esc> or chose "Cancel"
      return
    endif
  endif

  var tcindex = 0
  for tc in tclist
    while has_key(tctbl, tcindex)
      tcindex += 1
    endwhile
    tctbl[tcindex] = tc
    tcindex += 1
  endfor

  testcases.buf_write_testcases(bufnr, tctbl, use_single_file)
  if Finished != null_function
    Finished()
  endif
enddef

def StoreReceivedTaskConfig(filepath: string, confirm_overwriting: bool, task: CCTask, cfg: dict<any>): void
  if confirm_overwriting && filereadable(filepath)
    var choice = confirm('Do you want to overwrite "' .. filepath .. '"?', "Yes\nNo")
    if choice == 0 || choice == 2 # user pressed <esc> or chose "No"
      return
    endif
  endif

  var file_extension = fnamemodify(filepath, ":e")
  # Template file absolute path
  var template_file: string = null_string
  if type(cfg.template_file) == v:t_string # string with CompetiTest file-format modifiers
    template_file = utils.EvalString(filepath, cfg.template_file)
    echom template_file
  elseif type(cfg.template_file) == v:t_dict # dict with paths to template files
    template_file = get(cfg.template_file, file_extension, null_string)
  endif

  if template_file != null_string
    template_file = substitute(template_file, "^\\~", expand("~"), "") # expand tilde into home directory
    if !filereadable(template_file)
      if type(cfg.template_file) == v:t_dict # notify file absence when path is explicitly set
        echohl WarningMsg
        echo 'template file "' .. template_file .. "\" doesn't exist."
        echohl None
      endif
      template_file = null_string
    endif
  endif

  var file_directory = fnamemodify(filepath, ":h")
  # if template file exists then template_file is a string
  if template_file != null_string
    if cfg.evaluate_template_modifiers
      var str = utils.LoadFileAsString(template_file)
      assert_true(str != null_string, "CompetiTest.vim: StoreReceivedTaskConfig: cannot load '" .. template_file .. "'")
      var evaluated_str = EvalReceiveModifiers(str, task, file_extension, false, cfg.date_format)
      utils.WriteStringOnFile(filepath, evaluated_str != null_string ? evaluated_str : "")
    else
      mkdir(file_directory, "p")
      writefile(readfile(template_file), filepath)
    endif
  else
    utils.WriteStringOnFile(filepath, "")
  endif

  var tctbl: dict<dict<string>> = {}
  var tcindex = 0
  # convert testcases list into a 0-indexed testcases dict
  for tc in task.tests
    tctbl[tcindex] = tc
    tcindex += 1
  endfor

  var tcdir = file_directory .. "/" .. cfg.testcases_directory .. "/"
  testcases.IOFilesWriteEvalFormatString(tcdir, tctbl, filepath, cfg.testcases_input_file_format, cfg.testcases_output_file_format)
enddef

def StoreSingleProblem(task: CCTask, cfg: dict<any>, Finished: func() = null_function): void
  var evaluated_problem_path = EvalPath(cfg.received_problems_path, task, cfg.received_files_extension)
  if evaluated_problem_path == null_string
    echo "'received_problems_path' evaluation failed for task '" .. task.name .. "'"
    if Finished != null_function
      Finished()
    endif
    return
  endif

  if cfg.received_problems_prompt_path
    var filepath = input("Choose problem path: ", evaluated_problem_path, "file")
    if filepath == null_string
      echom "operation interrupted"
      return
    endif
    var local_cfg = config.LoadLocalConfigAndExtend(fnamemodify(filepath, ":h"))
    StoreReceivedTaskConfig(filepath, true, task, local_cfg)
    if local_cfg.open_received_problems
      execute "edit " .. fnameescape(filepath)
    endif
    if Finished != null_function
      Finished()
    endif
  else
    Finished()
  endif
enddef

def StoreContest(tasks: list<CCTask>, cfg: dict<any>, Finished: func() = null_function): void
  var contest_directory = EvalPath(cfg.received_contests_directory, tasks[0], cfg.received_files_extension)
  if contest_directory == null_string
    echo "'received_contests_directory' evaluation failed"
    if Finished != null_function
      Finished()
    endif
    return
  endif

  if cfg.received_contests_prompt_directory
    var directory = input("Choose contest directory: ", contest_directory, "file")
    if directory == null_string
      echom "operation interrupted"
      return
    endif
    var local_cfg = config.LoadLocalConfigAndExtend(directory)
    if local_cfg.received_contests_prompt_extension
      var file_extension = input( "Choose files extension: ", local_cfg.received_files_extension)
      if file_extension == null_string
        echom "operation interrupted"
        return
      endif
      for task in tasks
        var problem_path = EvalPath(local_cfg.received_contests_problems_path, task, file_extension)
        if problem_path != null_string
          var filepath = directory .. "/" .. problem_path
          StoreReceivedTaskConfig(filepath, true, task, local_cfg)
          if local_cfg.open_received_contests
            execute "edit " .. fnameescape(filepath)
          endif
        else
          echo "'received_contests_problems_path' evaluation failed for task '" .. task.name .. "'"
        endif
      endfor
      if Finished != null_function
        Finished()
      endif
    else
      Finished()
    endif
  else
    Finished()
  endif
enddef

