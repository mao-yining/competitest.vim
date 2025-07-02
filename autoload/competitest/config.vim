vim9script

import autoload './utils.vim' as utils

# Define type constants for clarity
const t_dict = type({})
const t_list = type([])

# Default configuration structure
const default_config = {
  local_config_file_name: ".competitest.lua",
  floating_border: "rounded",
  floating_border_highlight: "FloatBorder",
  picker_ui: {
    width: 0.2,
    height: 0.3,
    mappings: {
      focus_next: ["j", "<down>", "<Tab>"],
      focus_prev: ["k", "<up>", "<S-Tab>"],
      close: ["<esc>", "<C-c>", "q", "Q"],
      submit: "<cr>",
    },
  },
  editor_ui: {
    popup_width: 0.4,
    popup_height: 0.6,
    show_nu: true,
    show_rnu: false,
    normal_mode_mappings: {
      switch_window: ["<C-h>", "<C-l>", "<C-i>"],
      save_and_close: "<C-s>",
      cancel: ["q", "Q"],
    },
    insert_mode_mappings: {
      switch_window: ["<C-h>", "<C-l>", "<C-i>"],
      save_and_close: "<C-s>",
      cancel: "<C-q>",
    },
  },
  runner_ui: {
    interface: "split",
    selector_show_nu: false,
    selector_show_rnu: false,
    show_nu: true,
    show_rnu: false,
    mappings: {
      run_again: "R",
      run_all_again: "<C-r>",
      kill: "K",
      kill_all: "<C-k>",
      view_input: ["i", "I"],
      view_output: ["a", "A"],
      view_stdout: ["o", "O"],
      view_stderr: ["e", "E"],
      toggle_diff: ["d", "D"],
      close: ["q", "Q"],
    },
    viewer: {
      width: 0.5,
      height: 0.5,
      show_nu: true,
      show_rnu: false,
      open_when_compilation_fails: true,
    },
  },
  popup_ui: {
    total_width: 0.8,
    total_height: 0.8,
    layout: [
      [3, "tc"],
      [4, [[1, "so"], [1, "si"]]],
      [4, [[1, "eo"], [1, "se"]]],
    ],
  },
  split_ui: {
    position: "right",
    relative_to_editor: true,
    total_width: 0.3,
    vertical_layout: [
      [1, "tc"],
      [1, [[1, "so"], [1, "eo"]]],
      [1, [[1, "si"], [1, "se"]]],
    ],
    total_height: 0.4,
    horizontal_layout: [
      [2, "tc"],
      [3, [[1, "so"], [1, "si"]]],
      [3, [[1, "eo"], [1, "se"]]],
    ],
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
  # testcases_use_single_file: false,
  testcases_auto_detect_storage: true,
  # testcases_single_file_format: "$(FNOEXT).testcases",
  testcases_input_file_format: "$(FNOEXT)$(TCNUM).in",
  testcases_output_file_format: "$(FNOEXT)$(TCNUM).ans",
  testcases_directory: ".",
  companion_port: 27121,
  receive_print_message: true,
  start_receiving_persistently_on_setup: false,
  template_file: false,
  evaluate_template_modifiers: false,
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
}

# Module-level variables
export var current_setup: dict<any> = null_dict
export var buffer_configs: dict<dict<any>> = {}

# Deep copy a value
def Deepcopy(orig: any): any
  if type(orig) == t_dict
    var copy = {}
    for key in keys(orig)
      copy[key] = Deepcopy(orig[key])
    endfor
    return copy
  elseif type(orig) == t_list
    var copy = []
    for val in orig
      add(copy, Deepcopy(val))
    endfor
    return copy
  else
    return orig
  endif
enddef

# Recursively extend two dictionaries
def RecursiveExtend(base: dict<any>, overrides: dict<any>): dict<any>
  var ret = Deepcopy(base)
  for [key, value] in items(overrides)
    if type(value) == t_dict && has_key(ret, key) && type(ret[key]) == t_dict
      ret[key] = RecursiveExtend(ret[key], value)
    else
      ret[key] = Deepcopy(value)
    endif
  endfor
  return ret
enddef

# Notify a warning message
def NotifyWarning(msg: string)
  echohl WarningMsg
  echo "CompetiTest.nvim: " .. msg
  echohl None
enddef

# Update configuration table with new options
export def UpdateConfigTable(cfg_tbl: dict<any> = null_dict, opts: dict<any> = null_dict): dict<any>
  if opts == null_dict
    return Deepcopy(cfg_tbl ?? default_config)
  endif

  # Check for deprecated options
  if  has_key(opts, 'runner_ui') &&
      type(opts.runner_ui) == t_dict &&
      has_key(opts.runner_ui, 'viewer') &&
      type(opts.runner_ui.viewer) == t_dict &&
      has_key(opts.runner_ui.viewer, 'close_mappings')
    NotifyWarning("option 'runner_ui.viewer.close_mappings' is deprecated.\nPlease use 'runner_ui.mappings.close' instead.")
  endif

  var base_cfg = cfg_tbl ?? default_config
  var opts_copy = Deepcopy(opts)
  var new_config = RecursiveExtend(base_cfg, opts_copy)

  # Handle compile_command args replacement
  if has_key(opts, 'compile_command') && type(opts.compile_command) == t_dict
    for lang in keys(opts.compile_command)
      if type(opts.compile_command[lang]) == t_dict && has_key(opts.compile_command[lang], 'args')
        new_config.compile_command[lang].args = Deepcopy(opts.compile_command[lang].args)
      endif
    endfor
  endif

  # Handle run_command args replacement
  if has_key(opts, 'run_command') && type(opts.run_command) == t_dict
    for lang in keys(opts.run_command)
      if type(opts.run_command[lang]) == t_dict && has_key(opts.run_command[lang], 'args')
        new_config.run_command[lang].args = Deepcopy(opts.run_command[lang].args)
      endif
    endfor
  endif

  return new_config
enddef

# Load local configuration for a directory
export def LoadLocalConfig(directory: string): dict<any>
  var prev_len = -1
  var dir = directory
  while prev_len != len(dir)
    prev_len = len(dir)
    var config_file: string
    if current_setup == {}
      config_file = dir .. "/" .. default_config.local_config_file_name
    else
      config_file = dir .. "/" .. current_setup.local_config_file_name
    endif
    if utils.DoesFileExist(config_file)
      var local_config = eval(join(readfile(config_file), "\n"))
      if type(local_config) != t_dict
        echo "LoadLocalConfig: '" .. config_file .. "' doesn't return a dict."
        return null_dict
      endif
      return local_config
    endif
    dir = fnamemodify(dir, ":h")
  endwhile
  return null_dict
enddef

# Load and extend local configuration
export def LoadLocalConfigAndExtend(directory: string): dict<any>
  return UpdateConfigTable(current_setup, LoadLocalConfig(directory))
enddef

# Load buffer configuration
export def LoadBufferConfig(bufnr: number)
  var directory = bufname(bufnr)->fnamemodify(":p:h")
  buffer_configs[bufnr] = LoadLocalConfigAndExtend(directory)
enddef

# Get buffer configuration
export def GetBufferConfig(bufnr: number): dict<any>
  if !has_key(buffer_configs, bufnr)
    LoadBufferConfig(bufnr)
  endif
  return buffer_configs[bufnr]
enddef

