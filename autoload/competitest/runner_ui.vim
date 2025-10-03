vim9script
# File: autoload\competitest\runner_ui.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: A class show information of runner.
# Last Modified: 2025-10-03

import autoload './runner.vim' as r

export class RunnerUI
  # variables {{{
  var runner: r.TCRunner
  var visible: bool = false
  var viewer_content: string = null_string
  var diff_view: bool = false
  var update_details: bool = false
  var update_testcase: number = -1 # Means nil
  var windows: dict<any> = {}
  var latest_line: number
  var latest_compilation_timestamp: float = 0.0
  var showing_data: r.TestcaseData = null_object
  # }}}

  def new(this.runner) # {{{
    this.diff_view = this.runner.config.view_output_diff
  enddef # }}}

  def Show() # {{{
    if !this.visible
      # Create a New Tab {{{
      const bufnr = this.runner.bufnr
      execute("tabnew Testcases" .. bufnr)
      const new_tab = tabpagenr()
      execute($"autocmd WinClosed <buffer> call getbufvar({bufnr}, 'competitest_runner').ui.CallBack()")
      this.windows.tc = { winid: win_getid(), bufnr: bufnr() }
      setlocal nobuflisted
      setlocal diffopt+=iwhiteeol
      setlocal diffopt+=iblank
      setlocal filetype=competitest_testcases
      set winwidth=37 # Testcases windows width

      silent rightbelow vsplit Output
      this.windows.stdout = { winid: win_getid(), bufnr: bufnr() }
      setlocal filetype=competitest_out

      silent rightbelow split Input
      this.windows.stdin = { winid: win_getid(), bufnr: bufnr() }
      setlocal filetype=competitest_in

      wincmd l | silent rightbelow vsplit Errors
      this.windows.stderr = { winid: win_getid(), bufnr: bufnr() }
      setlocal filetype=competitest_err

      wincmd k | silent rightbelow vsplit Answer
      this.windows.ans = { winid: win_getid(), bufnr: bufnr() }
      setlocal filetype=competitest_ans
      # }}}

      for [name, win] in items(this.windows)
        setbufvar(win.bufnr, "&buftype", "nofile")
        setbufvar(win.bufnr, "&swapfile", false)
        setbufvar(win.bufnr, "&buflisted", false)
        setbufvar(win.bufnr, "&bufhidden", "hide")
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
      # {{{ set kaymaps
      for map in get(runner_ui_mappings, 'close', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>tabclose<CR>")
      endfor
      for map in get(runner_ui_mappings, 'kill', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').KillProcess(line('.') - 1)<CR>")
      endfor
      for map in get(runner_ui_mappings, 'kill_all', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').KillAllProcesses()<CR>")
      endfor
      for map in get(runner_ui_mappings, 'run_again', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').RunTestcase(line('.') - 1)<CR>")
      endfor
      for map in get(runner_ui_mappings, 'run_all_again', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').RunTestcases()<CR>")
      endfor
      for map in get(runner_ui_mappings, 'toggle_diff', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ui.ToggleDiffView()<CR>")
      endfor
      for map in get(runner_ui_mappings, 'view_answer', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ui.WinView('ans')<CR>")
      endfor
      for map in get(runner_ui_mappings, 'view_input', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ui.WinView('stdin')<CR>")
      endfor
      for map in get(runner_ui_mappings, 'view_stdout', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ui.WinView('stdout')<CR>")
      endfor
      for map in get(runner_ui_mappings, 'view_stderr', [])
        execute($"nnoremap <buffer><nowait> {map} <Cmd>call getbufvar({bufnr}, 'competitest_runner').ui.WinView('stderr')<CR>")
      endfor

      execute($"autocmd CursorMoved <buffer> call getbufvar({bufnr}, 'competitest_runner').ui.Update(line('.'))")
      # }}}

      this.visible = true
      this.Update()
    elseif this.visible
      win_gotoid(this.windows.tc.winid)
    endif

    if this.diff_view
      this.diff_view = false
      this.ToggleDiffView()
    endif
  enddef # }}}

  def WinView(name: string) # {{{
    if name == "ans" && this.showing_data.tcnum != "Compile"
      execute($"tabnew +buffer {this.showing_data.ans_bufname}")
    elseif name == "stdin" && this.showing_data.tcnum != "Compile"
      execute($"tabnew +buffer {this.showing_data.stdin_bufname}")
    elseif name == "stdout"
      execute($"tabnew +buffer {this.showing_data.stdout_bufname}")
    elseif name == "stderr"
      execute($"tabnew +buffer {this.showing_data.stderr_bufname}")
    else
      echo $"Has no {name} buffer!"
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
    if this.visible
      this.DisableDiffView()
    endif
    for [name, win] in items(this.windows)
      if win != null_dict
        this.windows[name] = null_dict
      endif
    endfor
    this.visible = false
    this.update_testcase = -1 # Means nil
    this.latest_line = 0
  enddef # }}}

  def AdjustString(len: number, str: string, fchar: string): string # {{{
    const strlen = strchars(str)
    if strlen <= len
      return str .. repeat(fchar, len - strlen)
    else
      return strcharpart(str, 0, len - 1) .. "…"
    endif
  enddef # }}}

  def Update(line = -1) # {{{
    if !this.visible || empty(this.runner.tcdata)
      return
    endif
    if line != -1 && line != this.latest_line
      this.latest_line = line
      this.update_testcase = line - 1
      this.update_details = true
    endif

    var compile_error = false
    this.update_details = true

    var lines = []
    var hlregions = []

    for [tcindex, data] in items(this.runner.tcdata)
      var l = { header: "TC " .. data.tcnum, status: data.status, time: "" }
      if data.tcnum == "Compile"
        l.header = data.tcnum
        if this.runner.config.runner_ui.open_when_compilation_fails
            && !data.killed && data.exit_code != 0
            && data.time != this.latest_compilation_timestamp
          if line('.') == 1
            this.update_testcase = 0
            compile_error = true
            this.latest_compilation_timestamp = data.time
          else
            this.update_testcase = -1
            setpos('.', [this.windows.tc.winid, 1, 0])
            return
          endif
        endif
      endif
      if data.time != -1
        l.time = printf("%.3f seconds", data.time / 1000.0)
      endif
      add(lines, l)
      add(hlregions, { line: tcindex, start: 10, end: 10 + strlen(l.status), group: data.hlgroup })
    endfor

    var buffer_lines = []
    for l in lines
      add(buffer_lines, this.AdjustString(10, l.header, " ") .. this.AdjustString(10, l.status, " ") .. l.time)
    endfor

    # add first, delete next to keep cursor's position
    setbufvar(this.windows.tc.bufnr, "&modifiable", true)
    setbufline(this.windows.tc.bufnr, 1, buffer_lines)
    deletebufline(this.windows.tc.bufnr, len(buffer_lines) + 1, "$")
    setbufvar(this.windows.tc.bufnr, "&modifiable", false)

    for hl in hlregions
      matchaddpos(hl.group, [[hl.line + 1, hl.start + 1, hl.end - hl.start]], 10, -1, { window: this.windows.tc.winid })
    endfor

    if this.update_details
      const testcase = this.update_testcase == -1 ? 0 : this.update_testcase
      const data = this.runner.tcdata[testcase]
      this.showing_data = data
      win_execute(this.windows.stdin.winid, $"buffer {data.stdin_bufnr == 0 ? this.windows.stdin.bufnr : data.stdin_bufnr}")
      win_execute(this.windows.stdout.winid, $"buffer {data.stdout_bufnr}")
      win_execute(this.windows.stderr.winid, $"buffer {data.stderr_bufnr}")
      win_execute(this.windows.ans.winid, $"buffer {data.ans_bufnr == 0 ? this.windows.ans.bufnr : data.ans_bufnr}")

      if compile_error
        tabnew
        execute "buffer " .. data.stderr_bufnr
      endif
    endif
  enddef # }}}
endclass
