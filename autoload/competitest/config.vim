vim9script

import autoload './utils.vim'

# Default configuration structure
const default_config = { # {{{
  local_config_file_name: ".competitest.vim",
  floating_border: "rounded",
  floating_border_highlight: "FloatBorder",
  editor_ui: {
    normal_mode_mappings: {
      switch_window: ["<C-h>", "<C-l>", "<C-i>"],
      save_and_close: "<C-s>",
      cancel: ["q", "Q"],
    },
  },
  runner_ui: {
    mappings: {
      run_again: "r",
      run_all_again: "R",
      kill: "x",
      kill_all: "X",
      view_input: [ "i", "I" ],
      view_output: [ "a", "A" ],
      view_stdout: [ "o", "O" ],
      view_stderr: [ "e", "E" ],
      toggle_diff: [ "d", "D" ],
      close: [ "q", "Q" ],
    },
    open_when_compilation_fails: true,
  },
  save_current_file: true,
  save_all_files: false,
  compile_directory: ".",
  compile_command: {
    c: { exec: "gcc", args: ["-Wall", "$(FNAME)", "-o", "$(FNOEXT)"] },
    cpp: { exec: "g++", args: ["-Wall", "$(FNAME)", "-o", "$(FNOEXT)"] },
    rust: { exec: "rustc", args: ["$(FNAME)"] },
    java: { exec: "javac", args: ["$(FNAME)"] },
  },
  running_directory: ".",
  run_command: {
    c: { exec: "./$(FNOEXT)" },
    cpp: { exec: "./$(FNOEXT)" },
    rust: { exec: "./$(FNOEXT)" },
    python: { exec: "python", args: ["$(FNAME)"] },
    java: { exec: "java", args: ["$(FNOEXT)"] },
  },
  multiple_testing: -1,
  maximum_time: 5000,
  output_compare_method: "squish",
  view_output_diff: false,
  testcases_auto_detect_storage: true,
  testcases_input_file_format: "$(FNOEXT)$(TCNUM).in",
  testcases_output_file_format: "$(FNOEXT)$(TCNUM).ans",
  testcases_directory: ".",
  companion_port: 27121,
  receive_print_message: true,
  template_file: false,
  evaluate_template_modifiers: true,
  date_format: "%c",
  received_files_extension: "cpp",
  received_problems_path: "$(CWD)/$(PROBLEM).$(FEXT)",
  received_problems_prompt_path: true,
  received_contests_directory: "$(CWD)",
  received_contests_problems_path: "$(PROBLEM).$(FEXT)",
  received_contests_prompt_directory: true,
  received_contests_prompt_extension: true,
  open_received_problems: true,
  open_received_contests: true,
  replace_received_testcases: false,
} # }}}

# Module-level variables
export var current_setup: dict<any> = null_dict

# Recursively extend two dictionaries
def RecursiveExtend(base: dict<any>, overrides: dict<any>): dict<any> # {{{
  var ret = deepcopy(base)
  for [key, value] in items(overrides)
    if type(value) == v:t_dict && has_key(ret, key) && type(ret[key]) == v:t_dict
      ret[key] = RecursiveExtend(ret[key], value)
    else
      ret[key] = deepcopy(value)
    endif
  endfor
  return ret
enddef # }}}

# Notify a warning message
def NotifyWarning(msg: string) # {{{
  echohl WarningMsg
  echo "CompetiTest.nvim: " .. msg
  echohl None
enddef # }}}

# Update configuration table with new options
export def UpdateConfigTable(cfg_tbl: dict<any> = null_dict, opts: dict<any> = null_dict): dict<any> # {{{
  if opts == null_dict
    return deepcopy(cfg_tbl ?? default_config)
  endif

  var base_cfg = cfg_tbl ?? default_config
  var opts_copy = deepcopy(opts)
  var new_config = RecursiveExtend(base_cfg, opts_copy)

  # Handle compile_command args replacement
  if has_key(opts, 'compile_command') && type(opts.compile_command) == v:t_dict
    for lang in keys(opts.compile_command)
      if type(opts.compile_command[lang]) == v:t_dict && has_key(opts.compile_command[lang], 'args')
        new_config.compile_command[lang].args = deepcopy(opts.compile_command[lang].args)
      endif
    endfor
  endif

  # Handle run_command args replacement
  if has_key(opts, 'run_command') && type(opts.run_command) == v:t_dict
    for lang in keys(opts.run_command)
      if type(opts.run_command[lang]) == v:t_dict && has_key(opts.run_command[lang], 'args')
        new_config.run_command[lang].args = deepcopy(opts.run_command[lang].args)
      endif
    endfor
  endif

  return new_config
enddef # }}}

# Load local configuration for a directory
export def LoadLocalConfig(directory: string): dict<any> # {{{
  var prev_len = -1
  var dir = directory
  while prev_len != len(dir)
    prev_len = len(dir)
    var config_file: string
    if current_setup == null_dict
      config_file = dir .. "/" .. default_config.local_config_file_name
    else
      config_file = dir .. "/" .. current_setup.local_config_file_name
    endif
    if utils.DoesFileExist(config_file)
      var local_config = eval(join(readfile(config_file), " \n"))
      if type(local_config) != v:t_dict
        echo "LoadLocalConfig: '" .. config_file .. "' doesn't return a dict."
        return null_dict
      endif
      return local_config
    endif
    dir = fnamemodify(dir, ":h")
  endwhile
  return null_dict
enddef # }}}

# Load and extend local configuration
export def LoadLocalConfigAndExtend(directory: string): dict<any> # {{{
  return UpdateConfigTable(current_setup, LoadLocalConfig(directory))
enddef # }}}

# Load buffer configuration
export def LoadBufferConfig(bufnr: number) # {{{
  var directory = bufname(bufnr)->fnamemodify(":p:h")
  setbufvar(bufnr, "competitest_configs", LoadLocalConfigAndExtend(directory))
enddef # }}}

# Get buffer configuration
export def GetBufferConfig(bufnr: number): dict<any> # {{{
  if !exists("getbufvar(bufnr, 'competitest_configs'")
    LoadBufferConfig(bufnr)
  endif
  return getbufvar(bufnr, "competitest_configs")
enddef # }}}

