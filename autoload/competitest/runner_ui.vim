vim9script

import autoload './utils.vim'
import autoload './runner.vim' as tcrunner

export class RunnerUI
  # variables {{{
  var runner: any
  var ui_initialized: bool = false
  var ui_visible: bool = false
  var viewer_initialized: bool = false
  var viewer_visible: bool = false
  var viewer_content: string = null_string
  var diff_view: bool = false
  public var restore_winid: number
  var update_details: bool = false
  public var update_windows: bool = false
  var update_testcase: number = -1 # Means nil
  var windows: dict<any> = {}
  var latest_line: number
  var latest_compilation_timestamp: float = 0.0
  # }}}

  def new(runner: any) # {{{
    this.runner        = runner
    this.diff_view     = runner.config.view_output_diff
    this.restore_winid = runner.ui_restore_winid
  enddef # }}}

  def Init(tc: dict<any>): dict<any> # {{{
    var windows = {}
    var bufnr = bufnr()

    execute("silent tabnew Testcases" .. bufnr)
    var new_tab = tabpagenr()
    execute($"autocmd WinClosed <buffer> call getbufvar({bufnr}, 'competitest_runner').ui.CallBack()")
    windows.tc = { winid: win_getid(), bufnr: bufnr() }
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal nobuflisted
    setlocal diffopt+=iwhiteeol
    setlocal diffopt+=iblank
    setlocal filetype=competitest_testcases
    set winwidth=37 # Testcases windows width

    silent rightbelow vsplit Output
    windows.stdout = { winid: win_getid(), bufnr: bufnr() }
    setlocal filetype=competitest_out

    silent rightbelow split Input
    windows.stdin = { winid: win_getid(), bufnr: bufnr() }
    setlocal filetype=competitest_in

    wincmd l | silent rightbelow vsplit Errors
    windows.stderr = { winid: win_getid(), bufnr: bufnr() }
    setlocal filetype=competitest_err

    wincmd k | silent rightbelow vsplit Answer
    windows.ans = { winid: win_getid(), bufnr: bufnr() }
    setlocal filetype=competitest_ans

    return windows
  enddef # }}}

  def ShowUI() # {{{
    if !this.ui_initialized || !this.ui_visible
      this.windows =  this.Init(this.runner.tcdata[0])

      for [name, win] in items(this.windows)
        var bufnr = winbufnr(win.winid)
        setbufvar(bufnr, "&buftype", "nofile")
        setbufvar(bufnr, "&bufhidden", "hide")
      endfor

      var runner_ui_mappings = {}
      for [action, maps] in items(this.runner.config.runner_ui.mappings)
        if type(maps) == v:t_string
          runner_ui_mappings[action] = [maps]
        else
          runner_ui_mappings[action] = maps
        endif
      endfor

      win_gotoid(this.windows.tc.winid)
      var bufnr = this.runner.bufnr

      for map in get(runner_ui_mappings, 'close', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>tabclose<CR>"
      endfor

      for map in get(runner_ui_mappings, 'kill', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').KillProcess(line('.') - 1)<CR>"
      endfor

      for map in get(runner_ui_mappings, 'kill_all', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').KillAllProcesses()<CR>"
      endfor

      for map in get(runner_ui_mappings, 'run_again', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ReRunTestcase(line('.') - 1)<CR>"
      endfor

      for map in get(runner_ui_mappings, 'run_all_again', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ReRunTestcases()<CR>"
      endfor

      for map in get(runner_ui_mappings, 'toggle_diff', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ui.ToggleDiffView()<CR>"
      endfor

      setbufvar(bufnr(), "showing_data", this.runner.tcdata[0])
      for map in get(runner_ui_mappings, 'view_stdout', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>execute $'tabnew +buffer{{getbufvar({bufnr()}, 'showing_data').stdout_bufnr}}'<CR>"
      endfor
      for map in get(runner_ui_mappings, 'view_answer', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>execute $'tabnew +buffer{{getbufvar({bufnr()}, 'showing_data').ans_bufnr}}'<CR>"
      endfor
      for map in get(runner_ui_mappings, 'view_input', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>execute $'tabnew +buffer{{getbufvar({bufnr()}, 'showing_data').stdin_bufnr}}'<CR>"
      endfor
      for map in get(runner_ui_mappings, 'view_stderr', [])
        execute $"nnoremap <buffer><nowait> {map} <Cmd>execute $'tabnew +buffer{{getbufvar({bufnr()}, 'showing_data').stderr_bufnr}}'<CR>"
      endfor

      execute($"autocmd CursorMoved <buffer> call getbufvar({bufnr}, 'competitest_runner').ui.UpdateUI(line('.'))", "silent")

      this.ui_initialized = true
      this.ui_visible = true
      this.update_windows = true
      this.UpdateUI()
    endif

    if this.diff_view
      this.diff_view = false
      this.ToggleDiffView()
    endif
  enddef # }}}

  def WinSetDiff(winid: number, enable_diff: bool) # {{{
    if winid > 0 && win_id2win(winid) > 0
      win_execute(winid, enable_diff ? "diffthis" : "diffoff")
      win_execute(winid, "set foldlevel=1")
    endif
  enddef # }}}

  def ToggleDiffView() # {{{
    this.diff_view = !this.diff_view
    this.WinSetDiff(this.windows.ans.winid, this.diff_view)
    this.WinSetDiff(this.windows.stdout.winid, this.diff_view)
  enddef # }}}

  def DisableDiffView() # {{{
    this.diff_view = false
    this.WinSetDiff(this.windows.ans.winid, false)
    this.WinSetDiff(this.windows.stdout.winid, false)
  enddef # }}}

  def CallBack() # {{{
    if this.ui_visible
      this.DisableDiffView()
    endif
    for [name, win] in items(this.windows)
      if win != null_dict
        this.windows[name] = null_dict
      endif
    endfor
    this.ui_initialized = false
    this.ui_visible = false
    this.viewer_initialized = false
    this.viewer_visible = false
    this.update_testcase = -1 # Means nil
    this.latest_line = 0
  enddef # }}}

  def AdjustString(len: number, str: string, fchar: string): string # {{{
    var strlen = strchars(str)
    if strlen <= len
      return str .. repeat(fchar, len - strlen)
    else
      return strcharpart(str, 0, len - 1) .. "…"
    endif
  enddef # }}}

  def UpdateUI(line = -1) # {{{
    if !this.ui_visible || empty(this.runner.tcdata)
      return
    endif
    if line != -1 && line != this.latest_line
      this.latest_line = line
      this.update_testcase = line - 1
      this.update_details = true
    endif

    var compile_error = false
    if this.update_windows
      this.update_windows = false
      this.update_details = true

      var lines = []
      var hlregions = []

      for [tcindex, data] in items(this.runner.tcdata)
        var l = { header: "TC " .. data.tcnum, status: data.status, time: "" }
        if data.tcnum == "Compile"
          l.header = data.tcnum
          if this.runner.config.runner_ui.open_when_compilation_fails
                \ && !data.killed && has_key(data, "exit_code") && data.exit_code != 0
                \ && data.time != this.latest_compilation_timestamp
            if line('.') == 1
              this.update_testcase = 1
              compile_error = true
              this.latest_compilation_timestamp = data.time
            else
              this.update_testcase = -1
              this.update_windows = true
              setpos('.', [this.windows.tc.winid, 1, 0])
              return
            endif
          endif
        endif
        if has_key(data, 'time') && data.time != -1
          l.time = printf("%.3f seconds", data.time / 1000.0)
        endif
        add(lines, l)
        add(hlregions, { line: tcindex, start: 10, end: 10 + strlen(l.status), group: data.hlgroup })
      endfor

      var buffer_lines = []
      for l in lines
        add(buffer_lines, this.AdjustString(10, l.header, " ") .. this.AdjustString(10, l.status, " ") .. l.time)
      endfor

      setbufvar(this.windows.tc.bufnr, "&modifiable", true)
      setbufline(this.windows.tc.bufnr, 1, buffer_lines)
      deletebufline(this.windows.tc.bufnr, len(buffer_lines) + 1, "$")
      setbufvar(this.windows.tc.bufnr, "&modifiable", false)

      for hl in hlregions
        matchaddpos(hl.group, [[hl.line + 1, hl.start + 1, hl.end - hl.start]], 10, -1, { window: this.windows.tc.winid })
      endfor
    endif

    if this.update_details
      var testcase = this.update_testcase == -1 ? 0 : this.update_testcase
      var data = this.runner.tcdata[testcase]
      setbufvar(this.windows.tc.bufnr, "showing_data", data)
      if empty(data) | return | endif

      win_execute(this.windows.stdin.winid, $"buffer {data.stdin_bufnr == 0 ? this.windows.stdin.bufnr : data.stdin_bufnr}")

      win_execute(this.windows.stdout.winid, $"buffer {data.stdout_bufnr}")

      win_execute(this.windows.stderr.winid, $"buffer {data.stderr_bufnr}")

      win_execute(this.windows.ans.winid, $"buffer {data.ans_bufnr == 0 ? this.windows.ans.bufnr : data.ans_bufnr}")

    endif
    if compile_error
      tabnew
      execute "buffer " .. this.windows.stderr.bufnr
    endif
  enddef # }}}

endclass

export def New(runner: any): RunnerUI # {{{
  return RunnerUI.new(runner)
enddef # }}}
