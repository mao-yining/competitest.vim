vim9script
# File: autoload\competitest\widgets.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: CompetiTest UI Module Testcase editor and picker.
# Last Modified: 2025-09-20

import autoload './config.vim' as cfg
import autoload './testcases.vim'
import autoload './utils.vim'

export def Editor(bufnr: number = 0, tcnum: number = 0): void # {{{
  const [input_path, output_path] = testcases.IOFileLocate(bufnr, tcnum)

  tabnew

  # Set input buffer
  const input_win = win_getid()
  execute('edit ' .. input_path)
  setlocal bufhidden=delete
  setlocal autowrite
  setlocal filetype=competitest_in

  vsplit

  # Set output buffer
  const output_win = win_getid()
  execute('edit ' .. output_path)
  setlocal bufhidden=delete
  setlocal autowrite
  setlocal filetype=competitest_ans

  win_gotoid(input_win)

  # Set key mappings
  def SetKeymaps(winid: number, other_winid: number, mappings: dict<any>) # {{{
    for action in mappings.switch_window
      win_execute(winid, $"nnoremap <buffer><nowait> {action} <Cmd>call win_gotoid({other_winid})<CR>")
    endfor
    for action in mappings.save_and_close
      win_execute(winid, $"nnoremap <buffer><nowait> {action} <Cmd>write<CR><Cmd>tabclose<CR>")
    endfor
    for action in mappings.cancel
      win_execute(winid, $"nnoremap <buffer><nowait> {action} <Cmd>tabclose<CR>")
    endfor
  enddef # }}}

  const mappings = cfg.GetBufferConfig(bufnr).editor_ui.normal_mode_mappings
  SetKeymaps(input_win, output_win, mappings)
  SetKeymaps(output_win, input_win, mappings)
enddef # }}}

export def Picker(bufnr: number, tctbl: dict<any>, title: string, CallBack: func): void # {{{
  if empty(tctbl)
    utils.EchoErr("picker: there's no testcase to pick from.")
    return
  endif

  const menu_items = (): list<dict<any>> => {
    var res = []
    for tcnum in keys(tctbl)
      res->add({ text: 'Testcase ' .. tcnum, data: str2nr(tcnum) })
    endfor
    return res
  }()->sort((u, v) => {
    return u.data < v.data ? -1 : 1
  })

  const config = cfg.GetBufferConfig(bufnr)
  const popup = popup_menu(menu_items, {
    title: $" {empty(title) ? "Testcase Picker" : title} ",
    border: [],
    borderchars: utils.GetBorderChars(config.floating_border),
    borderhighlight: [config.floating_border_highlight],
    callback: (id, result) => {
      if result > 0
        CallBack(menu_items[result - 1].data)
      endif
    }
  })
enddef # }}}
