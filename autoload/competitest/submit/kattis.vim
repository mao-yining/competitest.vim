vim9script
# File: autoload/competitest/submit/kattis.vim
# Author: Mao-Yining <mao.yining@outlook.com>
# Description: Kattis submit provider
# Last Modified: 2026-03-06

import autoload "../config.vim" as cfg
import autoload "../utils.vim"

var config: dict<any> = {}

# Language mapping
const LANGUAGE_GUESS: dict<string> = {
  c: "C",
  cc: "C++",
  cpp: "C++",
  cxx: "C++",
  "c++": "C++",
  cs: "C#",
  go: "Go",
  hs: "Haskell",
  java: "Java",
  js: "JavaScript (Node.js)",
  ts: "TypeScript",
  kt: "Kotlin",
  ml: "OCaml",
  pas: "Pascal",
  php: "PHP",
  pl: "Prolog",
  py: "Python 3",
  rb: "Ruby",
  rs: "Rust",
  scala: "Scala",
  sh: "Bash",
  swift: "Swift",
  lua: "Lua",
}

# Parse .kattisrc file
def ParseKattisrc(filepath: string): dict<any>
  if !filereadable(filepath)
    return null_dict
  endif

  var result: dict<any> = {
    user: {},
    kattis: {},
  }
  var current_section = ''

  for line in readfile(filepath)
    # Skip comments and empty lines
    if line =~ '^\s*#' || line =~ '^\s*$'
      continue
    endif

    # Section header
    const section = matchstr(line, '^\[\zs.\+\ze\]')
    if !empty(section)
      current_section = section
      continue
    endif

    # Key-value pair (supports both ':' and '=')
    const kv = matchlist(line, '^\s*\([^:=]\+\)\s*[:=]\s*\(.\+\)\s*$')
    if !empty(kv) && !empty(current_section)
      const key = trim(kv[1])
      const value = trim(kv[2])
      if current_section == 'user'
        result.user[key] = value
      elseif current_section == 'kattis'
        result.kattis[key] = value
      endif
    endif
  endfor

  return result
enddef

# Find .kattisrc file
def FindKattisrc(): string
  const locations = [
    expand('~/.kattisrc'),
    '/usr/local/etc/kattisrc',
    '.kattisrc',
  ]

  for path in locations
    if filereadable(path)
      return path
    endif
  endfor

  return null_string
enddef

# Setup provider
export def Setup(arg: dict<any>)
  const kattisrc_path = get(arg, 'config_file', null_string) ?? FindKattisrc()

  if empty(kattisrc_path)
    utils.EchoErr("No .kattisrc file found. Download from https://open.kattis.com/download/kattisrc")
  endif

  const kattisrc = ParseKattisrc(kattisrc_path)
  if empty(kattisrc)
    utils.EchoErr("Failed to parse .kattisrc file")
  endif

  if !has_key(kattisrc.user, 'username')
    utils.EchoErr(".kattisrc missing username")
  endif
  if !has_key(kattisrc.user, 'token') && !has_key(kattisrc.user, 'password')
    utils.EchoErr(".kattisrc missing token or password")
  endif

  config = {
    username: kattisrc.user.username,
    token: get(kattisrc.user, 'token', null_string),
    password: get(kattisrc.user, 'password', null_string),
    hostname: get(kattisrc.kattis, 'hostname', 'open.kattis.com'),
    loginurl: get(kattisrc.kattis, 'loginurl', ''),
    submissionurl: get(kattisrc.kattis, 'submissionurl', ''),
    submissionsurl: get(kattisrc.kattis, 'submissionsurl', ''),
  }

  if empty(config.loginurl)
    config.loginurl = $"https://{config.hostname}/login"
  endif
  if empty(config.submissionurl)
    config.submissionurl = $"https://{config.hostname}/submit"
  endif
  if empty(config.submissionsurl)
    config.submissionsurl = $"https://{config.hostname}/submissions"
  endif
enddef
Setup(cfg.GetGlobalConfig().submit.kattis)

# Check if provider can handle submission
export def CanSubmit(Bufnr: number, ProblemId: string): list<any>
  const filepath = bufname(Bufnr)
  if empty(filepath)
    return [false, "Buffer has no associated file"]
  endif

  if empty(config)
    return [false, "Kattis not configured. Check .kattisrc"]
  endif

  return [true, '']
enddef

# Guess language from file extension
def GuessLanguage(Filepath: string): string
  const ext = fnamemodify(Filepath, ":e")->tolower()
  return get(LANGUAGE_GUESS, ext, ext->substitute('^.', '\u&', ''))
enddef

# Guess problem ID from filename
def GuessProblemId(Filepath: string, ProblemId: string): string
  if !empty(ProblemId)
    return ProblemId
  endif
  return fnamemodify(Filepath, ":t:r")->tolower()
enddef

# Guess mainclass for languages that need it
def GuessMainclass(Language: string, Files: list<string>): string
  const GUESS_MAINFILE: dict<bool> = {
    "Ada": true,
    "Bash": true,
    "JavaScript (Node.js)": true,
    "Common Lisp": true,
    "Lua": true,
    "Pascal": true,
    "Perl": true,
    "PHP": true,
    "Python 2": true,
    "Python 3": true,
    "Ruby": true,
    "Rust": true,
  }

  const GUESS_MAINCLASS: dict<bool> = {
    "Elixir": true,
    "Erlang": true,
    "Java": true,
    "Kotlin": true,
    "Scala": true,
  }

  if has_key(GUESS_MAINFILE, Language) && len(Files) > 1
    return fnamemodify(Files[0], ":t")
  endif

  if has_key(GUESS_MAINCLASS, Language)
    for file in Files
      const lines = readfile(file)
      const content = lines->join("\n")
      if Language == "Kotlin"
        const basename = fnamemodify(file, ":t:r")
        return basename->substitute('^.', '\u&', '') .. "Kt"
      elseif content =~ 'main\s*('
        return fnamemodify(file, ":t:r")
      endif
    endfor
    return fnamemodify(Files[0], ":t:r")
  endif

  return ''
enddef

# Login to Kattis (async)
def LoginAsync(CallBack: func(string))
  const cookie_file = tempname()

  var args: list<string> = [
    '-sS',
    '-c', cookie_file,
    '-d', $"user={config.username}",
    '-d', 'script=true',
  ]

  if !empty(config.token)
    args->add('-d')
    args->add($"token={config.token}")
  elseif !empty(config.password)
    args->add('-d')
    args->add($"password={config.password}")
  endif

  args->add(config.loginurl)

  var stdout_data: list<string> = []
  var stderr_data: list<string> = []

  const job = job_start(['curl'] + args, {
    out_cb: (_, data: string) => {
      add(stdout_data, data)
    },
    err_cb: (_, data: string) => {
      add(stderr_data, data)
    },
    exit_cb: (_, status: number) => {
      if status == 0
        CallBack(cookie_file)
      else
        CallBack(null_string)
      endif
    }
  })

  if job_status(job) != 'run'
    CallBack(null_string)
  endif
enddef

# Submit multiple files
export def SubmitMultiple(Files: list<string>, ProblemId: string, CallBack: func(dict<any>))
  # Detect language
  const language = GuessLanguage(Files[0])

  # Detect problem ID
  const problem = GuessProblemId(Files[0], ProblemId)
  if empty(problem)
    CallBack({
      success: false,
      message: "Could not detect problem ID",
    })
    return
  endif

  # Guess mainclass if needed
  const mainclass = GuessMainclass(language, Files)

  # Define callback for login completion
  def LoginComplete(cookies: string)
    if empty(cookies)
      CallBack({
        success: false,
        message: "Login failed",
        error: "Check your .kattisrc credentials",
      })
      return
    endif

    var args: list<string> = [
      '-sS',
      '-b', cookies,
      '-F', 'submit=true',
      '-F', 'submit_ctr=2',
      '-F', $"language={language}",
      '-F', $"mainclass={mainclass}",
      '-F', $"problem={problem}",
      '-F', 'tag=',
      '-F', 'script=true',
    ]

    for file in Files
      args->add('-F')
      args->add($"sub_file[]=@{file}")
    endfor

    args->add(config.submissionurl)

    var stdout_data: list<string> = []
    var stderr_data: list<string> = []

    const job = job_start(['curl'] + args, {
      out_cb: (_, data: string) => {
        add(stdout_data, data)
      },
      err_cb: (_, data: string) => {
        add(stderr_data, data)
      },
      exit_cb: (_, status: number) => {
        delete(cookies)

        if status != 0
          CallBack({
            success: false,
            message: "Submission request failed",
            error: stderr_data->join("\n")})
          return
        endif

        const response = stdout_data->join("\n")
        const submission_id = matchstr(response, 'Submission ID: \zs\d\+\ze')

        if empty(submission_id)
          # Clean up HTML tags
          const error_msg = response
            ->substitute('<br />', "\n", 'g')
            ->substitute('<[^>]\+>', '', 'g')
          CallBack({
            success: false,
            message: "Kattis rejected submission",
            error: error_msg})
          return
        endif

        CallBack({
          success: true,
          submission_id: submission_id,
          message: $"Submitted {len(Files) == 1 ? 'file' : len(Files) .. ' files'} to problem {problem}"})
      }
    })
  enddef

  # Start login process
  LoginAsync(LoginComplete)
enddef

# Submit single file
export def Submit(Bufnr: number, ProblemId: string, CallBack: func(dict<any>))
  const filepath = bufname(Bufnr)
  SubmitMultiple([filepath], ProblemId, CallBack)
enddef

# Get submission status
export def GetStatus(SubmissionId: string, CallBack: func(dict<any>))
  const url = $"https://open.kattis.com/submissions/{SubmissionId}?json"

  # Define callback for login completion
  def LoginComplete(cookies: string)
    if empty(cookies)
      CallBack({})
      return
    endif

    const args: list<string> = ['-sS', '-b', cookies, url]

    var stdout_data: list<string> = []
    var stderr_data: list<string> = []

    const job = job_start(['curl'] + args, {
      out_cb: (_, data: string) => {
        add(stdout_data, data)
      },
      err_cb: (_, data: string) => {
        add(stderr_data, data)
      },
      exit_cb: (_, status: number) => {
        delete(cookies)

        if status != 0
          CallBack({})
          return
        endif

        const response = stdout_data->join("\n")
        try
          const status_data = json_decode(response)

          # Parse test results from row_html
          var test_results: list<string> = []
          if has_key(status_data, 'row_html')
            var pos = 1
            while pos > 0
              const match = matchstr(status_data.row_html, '<i class="\zs[^"]*\ze"', pos)
              if empty(match)
                break
              endif
              pos = matchend(status_data.row_html, '<i class="[^"]*"', pos)
              if match =~ 'accepted'
                test_results->add('AC')
              elseif match =~ 'rejected'
                test_results->add('WA')
              endif
            endwhile
          endif

          const testcase_total = status_data->get('row_html', '')
            ->count('<i') - 1

          # Status mapping
          const STATUS_MAP: dict<string> = {
            0: "New",
            1: "New",
            2: "Waiting for compile",
            3: "Compiling",
            4: "Waiting for run",
            5: "Running",
            6: "Judge Error",
            8: "Compile Error",
            9: "Run Time Error",
            10: "Memory Limit Exceeded",
            11: "Output Limit Exceeded",
            12: "Time Limit Exceeded",
            13: "Illegal Function",
            14: "Wrong Answer",
            16: "Accepted"}

          CallBack({
            status_id: status_data.status_id,
            status_text: get(STATUS_MAP, status_data.status_id, $"Unknown ({status_data.status_id})"),
            test_cases_done: get(status_data, 'testcase_index', 0),
            test_cases_total: testcase_total,
            test_results: test_results,
            done: status_data.status_id > 5})
        catch
          CallBack({})
        endtry
      }
    })
  enddef

  # Start login process
  LoginAsync(LoginComplete)
enddef
