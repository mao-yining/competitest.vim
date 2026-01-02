vim9script
# File: autoload/competitest/widgets.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: CompetiTest UI Module Testcase editor and picker.
# Last Modified: 2026-01-02

import autoload "./config.vim"
import autoload "./testcases.vim"
import autoload "./utils.vim"

export def Editor(bufnr: number, tcnum: number): void # {{{
  const [input_path, output_path] = testcases.IOFileLocate(bufnr, tcnum)

  tabnew

  # Set input buffer
  const input_win = win_getid()
  execute("edit " .. input_path)
  setlocal bufhidden=delete
  setlocal autowrite
  setlocal filetype=competitest_in

  vsplit

  # Set output buffer
  const output_win = win_getid()
  execute("edit " .. output_path)
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
      win_execute(winid, $"nnoremap <buffer><nowait> {action} <Cmd>write <Bar> tabclose<CR>")
    endfor
    for action in mappings.cancel
      win_execute(winid, $"nnoremap <buffer><nowait> {action} <Cmd>tabclose<CR>")
    endfor
  enddef # }}}

  const mappings = config.GetBufferConfig(bufnr).editor_ui.normal_mode_mappings
  SetKeymaps(input_win, output_win, mappings)
  SetKeymaps(output_win, input_win, mappings)
enddef # }}}

export def Picker(bufnr: number, tctbl: dict<any>, title: string, CallBack: func(number)): void # {{{
  if empty(tctbl)
    utils.EchoErr("picker: there's no testcase to pick from.")
    return
  endif

  var menu_items = []
  for tcnum in tctbl->keys()->sort("N")
    menu_items->add({ text: "Testcase " .. tcnum, num: tcnum })
  endfor

  const popup_borderchars = config.GetBufferConfig(bufnr).popup_borderchars
  const popup = popup_menu(menu_items, {
    title: $" {empty(title) ? "Testcase Picker" : title} ",
    borderchars: popup_borderchars,
    callback: (_, result) => {
      if result > 0
        CallBack(menu_items[result - 1].num->str2nr())
      endif
    }
  })
enddef # }}}
