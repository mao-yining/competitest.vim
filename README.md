# CompetiTest.Vim

## Competitive Programming with Vim Made Easy

A refactation of <https://github.com/xeluxee/competitest.nvim> in vim9script.

`competitest.vim` is a testcase manager and checker. It saves you time in
competitive programming contests by automating common tasks related to testcase
management. It can compile, run and test your solutions across all the
available testcases, displaying results in a nice interactive user interface.

## Features

- Multiple languages supported: it works out of the box with C, C++, Rust, Java and Python, but other languages can be configured
- Flexible. No strict file-naming rules, optional fixed folder structure. You can choose where to put the source code file, the testcases, the received problems and contests, where to execute your programs and much more
- Configurable (see [Configuration](#configuration)). You can even configure [every folder individually](#local-configuration)
- Testcases can be stored in a single file or in multiple text files, see [usage notes](#usage-notes)
- Easily [add](#add-or-edit-a-testcase), [edit](#add-or-edit-a-testcase) and [delete](#remove-a-testcase) testcases
- [Run](#run-testcases) your program across all the testcases, showing results and execution data in a nice interactive UI
- [Download](#receive-testcases-problems-and-contests) testcases, problems and contests automatically from competitive programming platforms
- [Templates](#templates-for-received-problems-and-contests) for received problems and contests
- View diff between actual and expected output
- [Customizable interface](#customize-ui-layout) that resizes automatically when Neovim window is resized
- Integration with [statusline and winbar](#statusline-and-winbar-integration)
- Customizable [highlight groups](#highlights)

## Installation

**NOTE:** this plugins requires Vim > 9.1
This plugin follows the standard runtime path structure, and as such it can be
installed with a variety of plugin managers:

| Plugin Manager                              | Install with...                                                                                                                                                                               |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NeoBundle`                                 | `NeoBundle 'mao-yining/competitest.vim'`                                                                                                                                                      |
| `Vundle`                                    | `Plugin 'mao-yining/competitest.vim'`                                                                                                                                                         |
| `Plug`                                      | `Plug 'mao-yining/competitest.vim'`                                                                                                                                                           |
| `Dein`                                      | `call dein#add('mao-yining/competitest.vim')`                                                                                                                                                 |
| `minpac`                                    | `call minpac#add('mao-yining/competitest.vim')`                                                                                                                                               |
| pack feature (native Vim 8 package feature) | `git clone https://github.com/mao-yining/competitest.vim ~/.vim/pack/dist/start/competitest.vim`<br/>Remember to run `:helptags ~/.vim/pack/dist/start/vim-airline/doc` to generate help tags |
| manual                                      | copy all of the files into your `~/.vim` directory                                                                                                                                            |

### Usage Notes

- Your programs must read from `stdin` and print to `stdout`. If `stderr` is used its content will be displayed
- A testcase is made by an input and an output (containing the correct answer)
- Input is necessary for a testcase to be considered, while an output hasn't to be provided necessarily

#### Storing Testcases

- Files naming shall follow a rule to be recognized. Let's say your file is
  called `task-A.cpp`. If using the default configuration testcases associated
  with that file will be named `task-A_input0.txt`, `task-A_output0.txt`,
  `task-A_input1.txt`, `task-A_output1.txt` and so on. The counting starts from 0.

- Of course files naming can be configured: see `testcases_input_file_format`
  and `testcases_output_file_format` in [configuration](#configuration)
- Testcases files can be put in the same folder of the source code file, but
  you can customize their path (see `testcases_directory` in [configuration]
  (#configuration))

When launching the following commands make sure the focused buffer is the one containing the source code file.

### Add or Edit a Testcase

Launch `:CompetiTest add_testcase` to add a new testcase.

Launch `:CompetiTest edit_testcase` to edit an existing testcase. If you want
to specify testcase number directly in the command line you can use `:
CompetiTest edit_testcase x`, where `x` is a number representing the testcase
you want to edit.

To jump between input and output windows press either `<C-h>`, `<C-l>`, or
`<C-i>`. To save and close testcase editor press `<C-s>` or `:wq`.

Of course these keybindings can be customized: see `editor_ui`
➤ `normal_mode_mappings` and `editor_ui` ➤ `insert_mode_mappings` in
[configuration](#configuration)

### Remove a Testcase

Launch `:CompetiTest delete_testcase`. If you want to specify testcase number
directly in the command line you can use `:CompetiTest delete_testcase x`,
where `x` is a number representing the testcase you want to remove.

### Run Testcases

Launch `:CompetiTest run`. CompetiTest's interface will appear and you'll be
able to view details about a testcase by moving the cursor over its entry. You
can close the UI by pressing `q`, `Q` or `:q`.

If you're using a compiled language and you don't want to recompile your
program launch `:CompetiTest run_no_compile`.

If you have previously closed the UI and you want to re-open it without
re-executing testcases or recompiling launch `:CompetiTest show_ui`.

#### Control Processes

- Run again a testcase by pressing `r`
- Run again all testcases by pressing `R`
- Kill the process associated with a testcase by pressing `x`
- Kill all the processes associated with testcases by pressing `X`

#### View Details

- View input in a bigger window by pressing `i` or `I`
- View expected output in a bigger window by pressing `a` or `A`
- View stdout in a bigger window by pressing `o` or `O`
- View stderr in a bigger window by pressing `e` or `E`
- Toggle diff view between actual and expected output by pressing `d` or `D`

Of course all these keybindings can be customized: see `runner_ui` ➤ `mappings`
in [configuration](#configuration)

### Receive Testcases, Problems and Contests

**NOTE:** to get this feature working you need to install
[competitive-companion](https://github.com/jmerle/competitive-companion)
extension in your browser.

Thanks to its integration with [competitive-companion](https: //github.com/jmerle/competitive-companion),
CompetiTest can download contents
from competitive programming platforms:

- Launch `:CompetiTest receive testcases` to only receive testcases _once_
- Launch `:CompetiTest receive problem` to receive a problem _once_ (source file is automatically created along with testcases)
- Launch `:CompetiTest receive contest` to receive an entire contest _once_ (make sure to be on the homepage of the contest, not of a single problem)
- Launch `:CompetiTest receive status` to show current receive status
- Launch `:CompetiTest receive stop` to stop receiving

After launching one of these commands click on the green plus button in your browser to start downloading.

For further customization see receive options in [configuration](#configuration).

#### Customize Folder Structure

By default CompetiTest stores received problems and contests in current working
directory. You can change this behavior through the options
`received_problems_path`, `received_contests_directory` and
`received_contests_problems_path`. See [receive modifiers](#receive-modifiers)
for further details.

Here are some tips:

- Fixed directory for received problems (not contests):

  ```vim
  received_problems_path: "$(HOME)/Competitive Programming/$(JUDGE)/$(CONTEST)/$(PROBLEM).$(FEXT)"
  ```

- Fixed directory for received contests:

  ```vim
  received_contests_directory: "$(HOME)/Competitive Programming/$(JUDGE)/$(CONTEST)"
  ```

- Put every problem of a contest in a different directory:

  ```vim
  received_contests_problems_path: "$(PROBLEM)/main.$(FEXT)"
  ```

- Example of file naming for Java contests:

  ```vim
  received_contests_problems_path: "$(PROBLEM)/$(JAVA_MAIN_CLASS).$(FEXT)"
  ```

- Simplified file names, it works with Java and any other language because the
  modifier `$(JAVA_TASK_CLASS)` is generated from problem name removing all
  non-alphabetic and non-numeric characters, including spaces and punctuation:

  ```vim
  received_contests_problems_path: "$(JAVA_TASK_CLASS).$(FEXT)"
  ```

#### Templates for Received Problems and Contests

When downloading a problem or a contest, source code templates can be
configured for different file types. See `template_file` option in
[configuration](#configuration).

[Receive modifiers](#receive-modifiers) can be used inside template files to
insert details about received problems. To enable this feature set
`evaluate_template_modifiers` to `true`. Template example for C++:

```cpp
// Problem: $(PROBLEM)
// Contest: $(CONTEST)
// Judge: $(JUDGE)
// URL: $(URL)
// Memory Limit: $(MEMLIM)
// Time Limit: $(TIMELIM)
// Start: $(DATE)

#include <iostream>
using namespace std;
int main() {
    cout << "This is a template file" << endl;
    cerr << "Problem name is $(PROBLEM)" << endl;
    return 0;
}
```

## Configuration

### Full Configuration

Here you can find CompetiTest default configuration

```vim
const default_config = {
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
}
```

#### Explanation

- `local_config_file_name`: you can use a different configuration for every different folder. See [local configuration](#local-configuration)
- `floating_border_highlight`: the highlight group used for popups border
- `runner_ui`: settings related to testcase runner user interface
  - `mappings`: keyboard mappings used in testcase selector window
    - `run_again`: keymaps to run again a testcase
    - `run_all_again`: keymaps to run again all testcases
    - `kill`: keymaps to kill a testcase
    - `kill_all`: keymaps to kill all testcases
    - `view_input`: keymaps to view input (stdin) in a bigger window
    - `view_output`: keymaps to view expected output in a bigger window
    - `view_stdout`: keymaps to view programs's output (stdout) in a bigger window
    - `view_stderr`: keymaps to view programs's errors (stderr) in a bigger window
    - `toggle_diff`: keymaps to toggle diff view between actual and expected output
    - `close`: keymaps to close runner user interface
  - `open_when_compilation_fails`: open viewer popup showing compilation errors when compilation fails
- `save_current_file`: if true save current file before running testcases
- `save_all_files`: if true save all the opened files before running testcases
- `compile_directory`: execution directory of compiler, relatively to current file's path
- `compile_command`: configure the command used to compile code for every different language, see [here](#customize-compile-and-run-commands)
- `running_directory`: execution directory of your solutions, relatively to current file's path
- `run_command`: configure the command used to run your solutions for every different language, see [here](#customize-compile-and-run-commands)
- `multiple_testing`: how many testcases to run at the same time
  - set it to `-1` to make the most of the amount of available parallelism. Often the number of testcases run at the same time coincides with the number of CPUs
  - set it to `0` if you want to run all the testcases together
  - set it to any positive integer to run that number of testcases contemporarily
- `maximum_time`: maximum time, in milliseconds, given to processes. If it's exceeded process will be killed
- `output_compare_method`: how given output (stdout) and expected output should
  be compared. It can be a string, representing the method to use, or a custom
  function. Available options follows:

  - `"exact"`: character by character comparison
  - `"squish"`: compare stripping extra white spaces and newlines
  - custom function: you can use a function accepting two arguments, two
    strings representing output and expected output. It should return true if
    the given output is acceptable, false otherwise. Example:

    ```vim
    {
        output_compare_method: (output: string, expected_output: string): bool => {
            if output == expected_output then
                return true
            else
                return false
            end
        },
    }
    ```

- `view_output_diff`: view diff between actual output and expected output in their respective windows
- `testcases_directory`: where testcases files are located, relatively to current file's path
- `testcases_use_single_file`: if true testcases will be stored in a single file instead of using multiple text files. If you want to change the way already existing testcases are stored see [conversion](#convert-testcases)
- `testcases_auto_detect_storage`: if true testcases storage method will be detected automatically. When both text files and single file are available, testcases will be loaded according to the preference specified in `testcases_use_single_file`
- `testcases_single_file_format`: string representing how single testcases files should be named (see [file-format modifiers](#file-format-modifiers))
- `testcases_input_file_format`: string representing how testcases input files should be named (see [file-format modifiers](#file-format-modifiers))
- `testcases_output_file_format`: string representing how testcases output files should be named (see [file-format modifiers](#file-format-modifiers))
- `companion_port`: competitive companion port number
- `receive_print_message`: if true notify user that plugin is ready to receive testcases, problems and contests or that they have just been received
- `template_file`: templates to use when creating source files for received problems or contests. Can be one of the following:

  - `false`: do not use templates
  - string with [file-format modifiers](#file-format-modifiers): useful when templates for different file types have a regular file naming

    ```vim
    template_file: "~/path/to/template.$(FEXT)"
    ```

  - table with paths: table associating file extension to template file

    ```vim
    template_file: {
        c: "~/path/to/file.c",
        cpp: "~/path/to/file.cpp",
        py: "~/path/to/file.py",
    }
    ```

- `evaluate_template_modifiers`: whether to evaluate [receive modifiers](#receive-modifiers) inside a template file or not
- `date_format`: string used to format `$(DATE)` modifier (see [receive modifiers](#receive-modifiers)). This function use Vim's builtin `strftime()`
- `received_files_extension`: default file extension for received problems
- `received_problems_path`: path where received problems (not contests) are stored. Can be one of the following:

  - string with [receive modifiers](#receive-modifiers)
  - function: function accepting two arguments, a table with [task details](https://github.com/jmerle/competitive-companion/#the-format) and a string with preferred file extension. It should return the absolute path to store received problem. Example:

    ```vim
    received_problems_path: (task, file_extension): string => {
      var hyphen = stridx(task.group, " - ")
      var judge: string
      var contest: string
      if hyphen == -1
        judge = task.group
        contest = "problems"
      else
        judge = strpart(task.group, 0, hyphen)
        contest = strpart(task.group, hyphen + 3)
      endif

      var safe_contest = substitute(substitute(contest, '[<>:"/\\|?*]', '_', 'g'), '#', '', 'g')
      var safe_name = substitute(substitute(task.name, '[<>:"/\\|?*]', '_', 'g'), '#', '', 'g')

      return printf(
        "D:/Competitive-Programming/%s/%s/%s/_.%s",
        judge,
        safe_contest,
        safe_name,
        file_extension
      )
    },
    ```

- `received_problems_prompt_path`: whether to ask user confirmation about path where the received problem is stored or not
- `received_contests_directory`: directory where received contests are stored. It can be string or function, exactly as `received_problems_path`
- `received_contests_problems_path`: relative path from contest root directory, each problem of a received contest is stored following this option. It can be string or function, exactly as `received_problems_path`
- `received_contests_prompt_directory`: whether to ask user confirmation about the directory where received contests are stored or not
- `received_contests_prompt_extension`: whether to ask user confirmation about what file extension to use when receiving a contest or not
- `open_received_problems`: automatically open source files when receiving a single problem
- `open_received_contests`: automatically open source files when receiving a contest
- `replace_received_testcases`: this option applies when receiving only testcases. If true replace existing testcases with received ones, otherwise ask user what to do

### Local Configuration

You can use a different configuration for every different folder by creating
a file called `.competitest.vim` (this name can be changed configuring the
option `local_config_file_name`). It will affect every file contained in that
folder and in subfolders. A table containing valid options must be returned,
see the following example.

```vim
{
    template_file: "D:/Competitive-Programming/Codeforces/template.$(FEXT)",
  output_compare_method: (output: string, ans: string) => tolower(output) == tolower(ans),
}
```

### Available Modifiers

Modifiers are substrings that will be replaced by another string, depending on
the modifier and the context. They're used to tweak some options.

#### File-format Modifiers

You can use them to [define commands](#customize-compile-and-run-commands) or
to customize testcases files naming through options `testcases_input_file_format` and `testcases_output_file_format`.

| Modifier      | Meaning                                    |
| ------------- | ------------------------------------------ |
| `$()`         | insert a dollar                            |
| `$(HOME)`     | user home directory                        |
| `$(FNAME)`    | file name                                  |
| `$(FNOEXT)`   | file name without extension                |
| `$(FEXT)`     | file extension                             |
| `$(FABSPATH)` | absolute path of current file              |
| `$(ABSDIR)`   | absolute path of folder that contains file |
| `$(TCNUM)`    | testcase number                            |

#### Receive Modifiers

You can use them to customize the options `received_problems_path`,
`received_contests_directory`, `received_contests_problems_path` and to [insert
problem details inside template files] (#templates-for-received-problems-and-contests). See also [tips for customizing
folder structure for received problems and contests] (#customize-folder-structure).

| Modifier             | Meaning                                                                                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `$()`                | insert a dollar                                                                                                                                            |
| `$(HOME)`            | user home directory                                                                                                                                        |
| `$(CWD)`             | current working directory                                                                                                                                  |
| `$(FEXT)`            | preferred file extension                                                                                                                                   |
| `$(PROBLEM)`         | problem name, `name` field                                                                                                                                 |
| `$(GROUP)`           | judge and contest name, `group` field                                                                                                                      |
| `$(JUDGE)`           | judge name (first part of `group`, before hyphen)                                                                                                          |
| `$(CONTEST)`         | contest name (second part of `group`, after hyphen)                                                                                                        |
| `$(URL)`             | problem url, `url` field                                                                                                                                   |
| `$(MEMLIM)`          | available memory, `memoryLimit` field                                                                                                                      |
| `$(TIMELIM)`         | time limit, `timeLimit` field                                                                                                                              |
| `$(JAVA_MAIN_CLASS)` | almost always "Main", `mainClass` field                                                                                                                    |
| `$(JAVA_TASK_CLASS)` | classname-friendly version of problem name, `taskClass` field                                                                                              |
| `$(DATE)`            | current date and time (based on [`date_format`](#explanation)), it can be used only inside [template files](#templates-for-received-problems-and-contests) |

Fields are referred to [received tasks](https://github.com/jmerle/competitive-companion/#the-format).

### Customize Compile and Run Commands

Languages as C, C++, Rust, Java and Python are supported by default.

Of course you can customize commands used for compiling and for running your
programs. You can also add languages that aren't supported by default.

```vim
{
    compile_command: {
        cpp      : { exec: 'g++',           args: {'$(FNAME)', '-o', '$(FNOEXT)'} },
        some_lang: { exec: 'some_compiler', args: {'$(FNAME)'} },
    },
    run_command: {
        cpp      : { exec: './$(FNOEXT)' },
        some_lang: { exec: 'some_interpreter', args: {'$(FNAME)'} },
    },
}
```

See [file-format modifiers](#file-format-modifiers) to better understand how
dollar notation works.

**NOTE:** if your language isn't compiled you can ignore `compile_command`
section.

Feel free to open a PR or an issue if you think it's worth adding a new
language among default ones.

## Statusline and Winbar Integration

Each UI windows is set with a special filetype. Each is
`competitest\_testcases` , `competitest\_out` , `competitest\_in`
, `competitest\_err` , `competitest\_ans`.

If you use `vim-airline`, you can set:

```vim
if !exists("g:airline_filetype_overrides") # airline plugins
 g:airline_filetype_overrides = {}
endif
g:airline_filetype_overrides.competitest_in = [ 'Input', '' ]
g:airline_filetype_overrides.competitest_out = [ 'Output', '' ]
g:airline_filetype_overrides.competitest_ans = [ 'Answer', '' ]
g:airline_filetype_overrides.competitest_err = [ 'Errors', '' ]
g:airline_filetype_overrides.competitest_testcases = [ 'Testcases', '' ]
```

## Highlights

You can customize CompetiTest highlight groups. Their default values are:

```vim
hi CompetiTestRunning cterm=bold     gui=bold
hi CompetiTestDone    cterm=none     gui=none
hi CompetiTestCorrect ctermfg=green  guifg=#00ff00
hi CompetiTestWarning ctermfg=yellow guifg=orange
hi CompetiTestWrong   ctermfg=red    guifg=#ff0000
```

## Contributing

If you have any suggestion to give or if you encounter any trouble don't
hesitate to open a new issue.

Pull Requests are welcome! 🎉

## Maintainers

The project is currently being maintained by Mao-Yining <mao.yining@outlook.com>

## License

GNU General Public License version 3 (GPL v3) or, at your option, any later version

Copyright © 2025 Mao-Yining <mao.yining@outlook.com>

CompetiTest.vim is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

CompetiTest.vim is distributed in the hope that it will be useful, but
**without any warranty**; without even the implied warranty of
**merchantability**or **fitness for a particular purpose**. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License
along with CompetiTest.Vim. If not, see <https://www.gnu.org/licenses/>.
