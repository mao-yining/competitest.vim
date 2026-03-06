vim9script
# File: autoload/competitest/submit.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Submit solutions to online judges
# Last Modified: 2026-03-06

import autoload "./config.vim"
import autoload "./utils.vim"
import autoload "./submit/kattis.vim" as kattis

# Provider registry
var providers: dict<dict<any>> = {}

# Initialize providers
def InitProviders()
  providers = {
    kattis: {
      name: 'kattis',
      supports_multiple_files: true,
      can_submit: kattis.CanSubmit,
      submit: kattis.Submit,
      submit_multiple: kattis.SubmitMultiple,
      get_status: kattis.GetStatus,
    },
  }
enddef
InitProviders()

# List all registered providers
export def ListProviders(): string
  return providers->keys()->join("\n")
enddef

# Get provider by name
export def GetProvider(Name: string): dict<any>
  return providers->get(Name, null_dict)
enddef

# Submit single file
export def Submit(ProviderName: string, Bufnr: number, ProblemId: string, _multi: bool)
  const provider = GetProvider(ProviderName ?? 'kattis')
  if provider == null_dict
    utils.EchoErr($"submit: provider '{ProviderName}' not found")
    return
  endif

  const filepath = bufname(Bufnr)
  if empty(filepath)
    utils.EchoErr("submit: buffer has no associated file")
    return
  endif

  # Check if provider can handle this submission
  const [can_submit, reason] = provider.can_submit(Bufnr, ProblemId)
  if !can_submit
    utils.EchoErr($"submit: {reason}")
    return
  endif

  # Show initial notification
  utils.EchoMsg("Submitting...")

  # Perform async submission
  def SubmitComplete(result: dict<any>)
    if result.success
      var msg = "Submitted successfully!"
      if has_key(result, 'submission_id') && !empty(result.submission_id)
        if provider.name == 'kattis'
          const url = $"https://open.kattis.com/submissions/{result.submission_id}"
          msg ..= $" - View: {url}"
        else
          msg ..= $" (ID: {result.submission_id})"
        endif
      endif
      utils.EchoMsg(msg)

      # Start status polling if supported
      if has_key(provider, 'get_status') && has_key(result, 'submission_id')
        PollSubmissionStatus(provider, result.submission_id)
      endif
    else
      utils.EchoErr($"Submission failed: {result.message}")
      if has_key(result, 'error')
        utils.EchoErr(result.error)
      endif
    endif
  enddef

  provider.submit(Bufnr, ProblemId, SubmitComplete)
enddef

# Submit multiple files
export def SubmitMultiple(ProviderName: string, Bufnr: number, ProblemId: string)
  const provider = GetProvider(ProviderName ?? 'kattis')
  if provider == null_dict
    utils.EchoErr($"submit: provider '{ProviderName}' not found")
    return
  endif

  if !provider.supports_multiple_files
    utils.EchoErr($"submit: provider '{ProviderName}' does not support multi-file submissions")
    return
  endif

  const filepath = bufname(Bufnr)
  if empty(filepath)
    utils.EchoErr("submit: buffer has no associated file")
    return
  endif

  const dir = fnamemodify(filepath, ":h")
  const ext = fnamemodify(filepath, ":e")

  # Find all files with same extension in directory
  const files = glob($"{dir}/*.{ext}", false, true)
  if empty(files)
    utils.EchoErr($"submit: no files found with extension .{ext}")
    return
  endif

  # Define callback for file picker
  def PickerComplete(selected_files: list<string>)
    if empty(selected_files)
      return
    endif

    # Show initial notification
    utils.EchoMsg($"Submitting {len(selected_files)} file(s)...")

    def SubmitComplete(result: dict<any>)
      if result.success
        var msg = $"Submitted {len(selected_files)} file(s) successfully!"
        if has_key(result, 'submission_id') && !empty(result.submission_id)
          if provider.name == 'kattis'
            const url = $"https://open.kattis.com/submissions/{result.submission_id}"
            msg ..= $" - View: {url}"
          else
            msg ..= $" (ID: {result.submission_id})"
          endif
        endif
        utils.EchoMsg(msg)

        # Start status polling if supported
        if has_key(provider, 'get_status') && has_key(result, 'submission_id')
          PollSubmissionStatus(provider, result.submission_id)
        endif
      else
        utils.EchoErr($"Submission failed: {result.message}")
        if has_key(result, 'error')
          utils.EchoErr(result.error)
        endif
      endif
    enddef

    provider.submit_multiple(selected_files, ProblemId, SubmitComplete)
  enddef

  # Show file picker
  PickerFiles(files, filepath, PickerComplete)
enddef

# Poll submission status
def PollSubmissionStatus(provider: dict<any>, submission_id: string)
  var poll_count = 0
  const max_polls = 240  # 60 seconds at 250ms interval
  var completed = false
  var consecutive_failures = 0
  const max_consecutive_failures = 5

  const submission_url = provider.name == 'kattis'
    ? $"https://open.kattis.com/submissions/{submission_id}"
    : null_string

  # Define status update function
  def StatusUpdate(status: dict<any>)
    if completed
      return
    endif

    if empty(status)
      consecutive_failures += 1
      if consecutive_failures >= max_consecutive_failures
        completed = true
        if submission_url != null_string
          utils.EchoWarn($"Failed to track submission - View at: {submission_url}")
        else
          utils.EchoWarn("Failed to track submission status")
        endif
      endif
      return
    endif

    consecutive_failures = 0

    if status.done
      completed = true
      var msg = status.status_text

      # Add test case info for failures
      if status.status_text !~ 'Accept' && has_key(status, 'test_cases_total')
        const failed = status.test_cases_total - (status.test_cases_done ?? 0)
        if failed > 0
          msg ..= $" (failed {failed}/{status.test_cases_total} test cases)"
        elseif has_key(status, 'test_cases_done')
          msg ..= $" ({status.test_cases_done}/{status.test_cases_total} test cases)"
        endif
      endif

      if status.status_text =~ 'Accept'
        utils.EchoMsg(msg)
      else
        utils.EchoErr(msg)
      endif
    endif
  enddef

  # Define timer callback
  def TimerHandler(_: number)
    if completed
      return
    endif

    poll_count += 1

    # Timeout
    if poll_count > max_polls
      completed = true
      if submission_url != null_string
        utils.EchoWarn($"Submission tracking timed out - View at: {submission_url}")
      else
        utils.EchoWarn("Submission tracking timed out")
      endif
      return
    endif

    provider.get_status(submission_id, StatusUpdate)
  enddef

  # Create timer
  const timer = timer_start(250, TimerHandler, { repeat: -1 })
enddef

# File picker using popup menu
def PickerFiles(Files: list<string>, CurrentFile: string, CallBack: func(list<string>))
  var items: list<dict<any>> = []
  var selected: dict<bool> = {}

  for file in Files
    const basename = fnamemodify(file, ":t")
    selected[file] = file == CurrentFile
    items->add({
      text: (selected[file] ? "[x] " : "[ ] ") .. basename,
      file: file
    })
  endfor

  const bufnr = bufnr()
  const popup_borderchars = config.GetBufferConfig(bufnr)->get('popup_borderchars',
    ["─", "│", "─", "│", "╭", "╮", "╯", "╰"])

  const max_width = max(items->mapnew((_, v: dict<any>): number => strwidth(v.text))) + 4
  const height = min([len(items), 20])

  const popup = popup_create(items->mapnew((_, v: dict<any>): string => v.text), {
    line: "cursor+1",
    col: "cursor",
    pos: "topleft",
    border: [],
    borderchars: popup_borderchars,
    title: " Select Files (Space: toggle, Enter: submit) ",
    padding: [0, 1, 0, 1],
    mapping: 0,
    maxheight: height,
    minwidth: max_width,
    filter: (win, key) => {
      if key == "\<Space>"
        const curline = getcurpos(win)[1]
        if curline >= 1 && curline <= len(items)
          const file = items[curline - 1].file
          selected[file] = !selected->get(file, false)
          const basename = fnamemodify(file, ":t")
          items[curline - 1].text = (selected[file] ? "[x] " : "[ ] ") .. basename
          win->popup_settext(items->mapnew((_, v: dict<any>): string => v.text))
          win->cursor(curline, 1)
        endif
        return true
      endif
      return popup_filter_menu(win, key)
    },
    callback: (_, result: number) => {
      if result == -1
        CallBack([])
      endif
    },
    cursorline: true,
    cursorlinehl: "PopupSelected",
  })
  for i in range(len(items))
    if items[i].file == CurrentFile
      popup->cursor(i + 1, 1)
      break
    endif
  endfor
enddef
