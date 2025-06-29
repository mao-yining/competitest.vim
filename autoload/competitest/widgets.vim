vim9script
# File: widgets.vim
# Author: mao-yining
# Description: CompetiTest UI Module Testcase editor and picker
# Last Modified: 2025-07-02

import autoload './config.vim' as cfg
import autoload './testcases.vim'
import autoload './utils.vim' as utils

export def Editor(bufnr: number = 0, tcnum: number = 0): void # {{{
  var [input_path, output_path] = testcases.IOFileLocate(bufnr, tcnum)

  tabnew
  var new_tab = tabpagenr()
  vsplit

  var input_win = win_getid(1)  # First window in tab
  var output_win = win_getid(2) # Second window in tab

  # Create input buffer
  win_execute(input_win, 'edit ' .. input_path)
  var input_bufnr = winbufnr(input_win)
  setbufvar(input_bufnr, '&bufhidden', 'delete') # Delete when window closes
  setbufvar(input_bufnr, '&autowrite', true) # Save when window closes
  setbufvar(input_bufnr, '&filetype', "competitest_in")

  # Create output buffer
  win_execute(output_win, 'edit ' .. output_path)
  var output_bufnr = winbufnr(output_win)
  setbufvar(output_bufnr, '&bufhidden', 'delete') # Delete when window closes
  setbufvar(output_bufnr, '&autowrite', true) # Save when window closes
  setbufvar(output_bufnr, '&filetype', "competitest_ans")

  win_gotoid(input_win)

  # Set key mappings
  def SetKeymaps(winid: number, other_winid: number, mappings: dict<any>): void # {{{
    for [_, action] in items(mappings.switch_window)
      win_execute(winid, $"nnoremap <buffer> {action} <Cmd>call win_gotoid({other_winid})<CR>")
    endfor
    for [_, action] in items(mappings.save_and_close)
      win_execute(winid, $"nnoremap <buffer> {action} <Cmd>write<CR><Cmd>tabclose<CR>")
    endfor
    for [_, action] in items(mappings.cancel)
      win_execute(winid, $"nnoremap <buffer> {action} <Cmd>tabclose<CR>")
    endfor
  enddef # }}}

  var config = cfg.GetBufferConfig(bufnr)
  SetKeymaps(input_win, output_win, config.editor_ui.normal_mode_mappings)
  SetKeymaps(output_win, input_win, config.editor_ui.normal_mode_mappings)
enddef # }}}

export def Picker(bufnr: number, tctbl: dict<any>, title: string, CallBack: func): void # {{{
  if empty(tctbl)
    echoerr "there's no testcase to pick from."
    return
  endif

  var menu_items = []
  for [tcnum, _] in items(tctbl)
    add(menu_items, { text: 'Testcase ' .. tcnum, data: str2nr(tcnum) })
  endfor
  menu_items->sort((u, v) => {
    return u.data < v.data ? -1 : 1
  })

  var config = cfg.GetBufferConfig(bufnr)
  var [vim_width, vim_height] = utils.GetUISize()
  var popup = popup_menu(menu_items, {
    title: title != '' ? ' ' .. title .. ' ' : ' Testcase Picker ',
    border: [],
    borderchars: utils.GetBorderChars(config.floating_border),
    borderhighlight: [config.floating_border_highlight],
    callback: (id, result) => {
      if result > 0
        CallBack(menu_items[result - 1].data)
      endif
    }
  })
  setbufvar(winbufnr(popup), '&filetype', 'CompetiTestPicker')
enddef # }}}
