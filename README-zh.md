# CompetiTest.Vim

本项目受 <https://github.com/xeluxee/competitest.nvim> 启发。

`competitest.vim` 是一个测试用例管理和检查工具。它通过自动化测试用例管理相关的常见任务，帮助你在竞技编程比赛中节省时间。它可以编译、运行并测试你的解决方案，在所有可用测试用例上展示结果，并通过精美的交互式用户界面呈现。

## 功能特点

- 支持多语言：开箱即用支持 C、C++、Rust、Java 和 Python，其他语言也可配置
- 灵活。没有严格的命名规则，可选择是否使用固定文件夹结构。你可以自由选择源代码文件、测试用例、接收的问题和比赛的存放位置，以及程序的执行位置等
- 可配置（见[配置](#配置)）。你甚至可以[为每个文件夹单独配置](#本地配置)
- 轻松[添加](#添加或编辑测试用例)、[编辑](#添加或编辑测试用例)和[删除](#删除测试用例)测试用例
- [运行](#运行测试用例)你的程序在所有测试用例上，通过精美的交互式 UI 展示结果和执行数据
- [自动下载](#接收测试用例、问题和比赛)竞技编程平台上的测试用例、问题和比赛
- 接收问题和比赛的[模板](#接收问题和比赛的模板)
- 查看实际输出与预期输出的差异
- 与[状态栏和窗口栏集成](#状态栏和窗口栏集成)
- 可自定义的[高亮组](#高亮)

## 安装

要求: Vim > 9.1.2054，同时 receive 功能需要在环境变量中有 python。

本插件遵循标准运行时路径结构，因此可以通过多种插件管理器安装：

| 插件管理器        | 安装命令                                                                                                                                                                |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NeoBundle`       | `NeoBundle 'mao-yining/competitest.vim'`                                                                                                                                |
| `Vundle`          | `Plugin 'mao-yining/competitest.vim'`                                                                                                                                   |
| `Plug`            | `Plug 'mao-yining/competitest.vim'`                                                                                                                                     |
| `Dein`            | `call dein#add('mao-yining/competitest.vim')`                                                                                                                           |
| `minpac`          | `call minpac#add('mao-yining/competitest.vim')`                                                                                                                         |
| 原生 Vim 8 包管理 | `git clone https://github.com/mao-yining/competitest.vim ~/.vim/pack/dist/start/competitest.vim`<br/>运行`:helptags ~/.vim/pack/dist/start/competitest.vim/doc`生成帮助标签 |
| 手动安装          | 复制所有文件到你的 `~/.vim` 目录                                                                                                                                        |

### 使用说明

- 你的程序必须从 `stdin` 读取并输出到 `stdout`。如果使用 `stderr`，其内容也会被显示。
- 一个测试用例由输入和输出（包含正确答案）组成。
- 输入是测试用例必需的，而输出可以不提供。

#### 存储测试用例

- 文件命名需遵循规则才能被识别。假设你的文件名为 `task-A.cpp`。如果使用默认配置，与该文件关联的测试用例将命名为 `task-A_input0.txt`、`task-A_output0.txt`、`task-A_input1.txt`、`task-A_output1.txt` 等。计数从 0 开始。
- 当然文件名可以配置：见[配置](#配置)中的 `testcases_input_file_format` 和 `testcases_output_file_format`。
- 测试用例文件可以放在源代码文件同目录下，但你可以自定义它们的路径（见[配置](#配置)中的 `testcases_directory`）。

执行以下命令时，请确保焦点在包含源代码文件的缓冲区上。

### 添加或编辑测试用例

执行 `:CompetiTest add_testcase` 添加新测试用例。

执行 `:CompetiTest edit_testcase` 编辑现有测试用例。如果想直接在命令行指定测试用例编号，可以使用 `:CompetiTest edit_testcase {num}`。

在输入和输出窗口之间切换，可以按 `<C-h>`、`<C-l>` 或 `<C-i>`。保存并关闭测试用例编辑器，按 `<C-s>` 或 `:wq`。

当然这些快捷键可以自定义：见[配置](#配置)中的 `editor_ui` ➤ `normal_mode_mappings`

### 删除测试用例

执行 `:CompetiTest delete_testcase`。如果想直接在命令行指定测试用例编号，可以使用 `:CompetiTest delete_testcase {num}`。

### 运行测试用例

执行 `:CompetiTest run`。CompetiTest 的界面会出现，你可以通过将光标移动到条目上查看测试用例的详细信息。按 `q`、`Q` 或 `:q` 可以关闭 UI。

如果使用编译语言且不想重新编译程序，执行 `:CompetiTest run_no_compile`。

如果之前关闭了 UI 并想在不重新执行测试用例或重新编译的情况下重新打开它，执行 `:CompetiTest show_ui`。

#### 控制进程

- 按 `r` 重新运行一个测试用例
- 按 `R` 重新运行所有测试用例
- 按 `x` 终止与测试用例关联的进程
- 按 `X` 终止所有与测试用例关联的进程

#### 查看详情

- 按 `i` 或 `I` 在更大的窗口中查看输入
- 按 `a` 或 `A` 在更大的窗口中查看预期输出
- 按 `o` 或 `O` 在更大的窗口中查看 stdout
- 按 `e` 或 `E` 在更大的窗口中查看 stderr
- 按 `d` 或 `D` 切换实际输出与预期输出的差异视图

当然所有这些快捷键都可以自定义：见[配置](#配置)中的 `runner_ui` ➤ `mappings`

### 接收测试用例、问题和比赛

**注意：** 要使此功能正常工作，你需要在浏览器中安装 [competitive-companion](https://github.com/jmerle/competitive-companion) 扩展。

得益于与 [competitive-companion](https://github.com/jmerle/competitive-companion) 的集成，CompetiTest 可以从竞技编程平台下载内容：

- 执行 `:CompetiTest receive testcases` 仅接收测试用例（一次性）
- 执行 `:CompetiTest receive problem` 接收一个问题（一次性）（自动创建源代码文件及测试用例）
- 执行 `:CompetiTest receive contest` 接收整个比赛（一次性）（确保在比赛主页，而不是单个问题页面）
- 执行 `:CompetiTest receive status` 显示当前接收状态
- 执行 `:CompetiTest receive stop` 停止接收

执行这些命令后，点击浏览器中的绿色加号按钮开始下载。

更多自定义选项见[配置](#配置)中的接收选项。

#### 自定义文件夹结构

默认情况下，CompetiTest 将接收的问题和比赛存储在当前工作目录中。你可以通过选项 `received_problems_path`、`received_contests_directory` 和 `received_contests_problems_path` 更改此行为。更多细节见[接收修饰符](#接收修饰符)。

以下是一些建议：

- 固定接收问题的目录（非比赛）：

  ```vim
  received_problems_path: "$(HOME)/Competitive Programming/$(JUDGE)/$(CONTEST)/$(PROBLEM).$(FEXT)"
  ```

- 固定接收比赛的目录：

  ```vim
  received_contests_directory: "$(HOME)/Competitive Programming/$(JUDGE)/$(CONTEST)"
  ```

- 将比赛的每个问题放在不同目录：

  ```vim
  received_contests_problems_path: "$(PROBLEM)/main.$(FEXT)"
  ```

- Java 比赛的文件命名示例：

  ```vim
  received_contests_problems_path: "$(PROBLEM)/$(JAVA_MAIN_CLASS).$(FEXT)"
  ```

- 简化的文件名，适用于 Java 和其他语言，因为修饰符 `$(JAVA_TASK_CLASS)` 会从问题名中移除所有非字母和非数字字符，包括空格和标点：

  ```vim
  received_contests_problems_path: "$(JAVA_TASK_CLASS).$(FEXT)"
  ```

#### 接收问题和比赛的模板

下载问题或比赛时，可以为不同类型的文件配置源代码模板。见[配置](#配置)中的 `template_file` 选项。

[接收修饰符](#接收修饰符)可以在模板文件中使用，以插入接收问题的详细信息。启用此功能需将 `evaluate_template_modifiers` 设为 `true`。C++ 模板示例：

```cpp
// 问题: $(PROBLEM)
// 比赛: $(CONTEST)
// 平台: $(JUDGE)
// 网址: $(URL)
// 内存限制: $(MEMLIM)
// 时间限制: $(TIMELIM)
// 开始时间: $(DATE)

#include <iostream>
using namespace std;
int main() {
    cout << "这是一个模板文件" << endl;
    cerr << "问题名称是 $(PROBLEM)" << endl;
    return 0;
}
```

## 配置

### 完整配置

以下是 CompetiTest 的默认配置：

```vim
vim9script
g:competitest_configs = {
  local_config_file_name: ".competitest.vim",
  popup_borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
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
      view_answer: [ "a", "A" ],
      view_stdout: [ "o", "O" ],
      view_stderr: [ "e", "E" ],
      toggle_diff: [ "d", "D" ],
      close: [ "q", "Q", "ZZ", "ZQ" ],
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

#### 说明

- `local_config_file_name`：可以为每个不同的文件夹使用不同的配置。见[本地配置](#本地配置)
- `runner_ui`：与测试用例运行器用户界面相关的设置
  - `mappings`：测试用例选择器窗口的键盘映射
    - `run_again`：重新运行测试用例的快捷键
    - `run_all_again`：重新运行所有测试用例的快捷键
    - `kill`：终止测试用例的快捷键
    - `kill_all`：终止所有测试用例的快捷键
    - `view_input`：在更大窗口中查看输入（stdin）的快捷键
    - `view_answer`：在更大窗口中查看预期输出的快捷键
    - `view_stdout`：在更大窗口中查看程序输出（stdout）的快捷键
    - `view_stderr`：在更大窗口中查看程序错误（stderr）的快捷键
    - `toggle_diff`：切换实际输出与预期输出差异视图的快捷键
    - `close`：关闭运行器用户界面的快捷键
  - `open_when_compilation_fails`：编译失败时打开显示编译错误的查看器弹出窗口
- `save_current_file`：如果为 true，在运行测试用例前保存当前文件
- `save_all_files`：如果为 true，在运行测试用例前保存所有打开的文件
- `compile_directory`：编译器的执行目录，相对于当前文件的路径
- `compile_command`：为每种语言配置用于编译代码的命令，见[这里](#自定义编译和运行命令)
- `running_directory`：解决方案的执行目录，相对于当前文件的路径
- `run_command`：为每种语言配置用于运行解决方案的命令，见[这里](#自定义编译和运行命令)
- `multiple_testing`：同时运行多少个测试用例
  - 设为 `-1` 以充分利用可用并行性。通常同时运行的测试用例数量与 CPU 数量一致
  - 设为 `0` 如果你想同时运行所有测试用例
  - 设为任何正整数以同时运行该数量的测试用例
- `maximum_time`：进程的最大运行时间（毫秒）。如果超时，进程将被终止
- `output_compare_method`：如何比较给定输出（stdout）和预期输出。可以是表示方法的字符串，或自定义函数。可用选项如下：
  - `"exact"`：逐字符比较
  - `"squish"`：忽略所有行末空白字符比较
  - 自定义函数：可以使用接受两个参数的函数，两个字符串表示输出和预期输出。如果给定输出可接受则返回 true，否则返回 false。示例：
    ```vim
    {
        output_compare_method: (output: string, expected_output: string): bool => {
            if output == expected_output
                return true
            else
                return false
            endif
        },
    }
    ```
- `view_output_diff`：在各自的窗口中查看实际输出与预期输出的差异
- `testcases_directory`：测试用例文件的存放位置，相对于当前文件的路径
- `testcases_input_file_format`：表示测试用例输入文件应如何命名的字符串（见[文件格式修饰符](#文件格式修饰符)）
- `testcases_output_file_format`：表示测试用例输出文件应如何命名的字符串（见[文件格式修饰符](#文件格式修饰符)）
- `companion_port`：competitive companion 端口号
- `receive_print_message`：如果为 true，通知用户插件已准备好接收测试用例、问题和比赛，或它们刚刚被接收
- `template_file`：为接收的问题或比赛创建源文件时使用的模板。可以是以下之一：
  - `false`：不使用模板
  - 带有[文件格式修饰符](#文件格式修饰符)的字符串：当不同类型的模板有规律的文件命名时有用
    ```vim
    template_file: "~/path/to/template.$(FEXT)"
    ```
  - 带有路径的表格：将文件扩展名与模板文件关联的表格
    ```vim
    template_file: {
        c: "~/path/to/file.c",
        cpp: "~/path/to/file.cpp",
        py: "~/path/to/file.py",
    }
    ```
- `evaluate_template_modifiers`：是否在模板文件中评估[接收修饰符](#接收修饰符)
- `date_format`：用于格式化 `$(DATE)` 修饰符的字符串（见[接收修饰符](#接收修饰符)）。此函数使用 Vim 内置的 `strftime()`
- `received_files_extension`：接收问题的默认文件扩展名
- `received_problems_path`：接收的问题（非比赛）的存储路径。可以是以下之一：
  - 带有[接收修饰符](#接收修饰符)的字符串
  - 函数：接受两个参数的函数，一个包含[任务详情](https://github.com/jmerle/competitive-companion/#the-format)的表格和一个带有首选文件扩展名的字符串。应返回接收问题的绝对路径。示例：

    ```vim
    received_problems_path: (task, file_extension): string => {
      const parts = task.group->split(" - ") # Codeforces' contest
      return printf(
        "D:/Competitive-Programming/%s/%s/%s/_.%s",
        parts[0]->substitute('[<>:"/\\|?*#]', '_', 'g'), # judge platform
        parts->get(1, 'problems')->substitute('[<>:"/\\|?*#]', '_', 'g'),
        task.name->split()[0]->substitute('[#.]', '', 'g'),
        file_extension
      )
    },
    ```

- `received_problems_prompt_path`：是否询问用户确认接收问题的存储路径
- `received_contests_directory`：接收比赛的存储目录。可以是字符串或函数，与 `received_problems_path` 完全相同
- `received_contests_problems_path`：从比赛根目录的相对路径，接收比赛的每个问题按此选项存储。可以是字符串或函数，与 `received_problems_path` 完全相同
- `received_contests_prompt_directory`：是否询问用户确认接收比赛的存储目录
- `received_contests_prompt_extension`：是否在接收比赛时询问用户确认使用的文件扩展名
- `open_received_problems`：接收单个问题时自动打开源文件
- `open_received_contests`：接收比赛时自动打开源文件
- `replace_received_testcases`：此选项仅适用于接收测试用例时。如果为 true，用接收的测试用例替换现有测试用例，否则询问用户如何处理

### 本地配置

你可以为每个不同的文件夹创建名为 `.competitest.vim` 的文件（此名称可通过配置选项 `local_config_file_name` 更改）来使用不同的配置。它将影响该文件夹及其子文件夹中的每个文件。必须返回包含有效选项的表格，见以下示例。

```vim
{
    template_file: "D:/Competitive-Programming/Codeforces/template.$(FEXT)",
  output_compare_method: (output: string, ans: string) => tolower(output) == tolower(ans),
}
```

### 可用修饰符

修饰符是会被替换为另一个字符串的子字符串，具体取决于修饰符和上下文。它们用于调整某些选项。

#### 文件格式修饰符

你可以使用它们来[定义命令](#自定义编译和运行命令)或通过选项 `testcases_input_file_format` 和 `testcases_output_file_format` 自定义测试用例文件的命名。

| 修饰符        | 含义                       |
| ------------- | -------------------------- |
| `$()`         | 插入美元符号               |
| `$(HOME)`     | 用户主目录                 |
| `$(FNAME)`    | 文件名                     |
| `$(FNOEXT)`   | 不带扩展名的文件名         |
| `$(FEXT)`     | 文件扩展名                 |
| `$(FABSPATH)` | 当前文件的绝对路径         |
| `$(ABSDIR)`   | 包含文件的文件夹的绝对路径 |
| `$(TCNUM)`    | 测试用例编号               |

#### 接收修饰符

你可以使用它们来自定义选项 `received_problems_path`、`received_contests_directory`、`received_contests_problems_path` 以及[在模板文件中插入问题详情](#接收问题和比赛的模板)。另见[自定义接收问题和比赛的文件夹结构的技巧](#自定义文件夹结构)。

| 修饰符               | 含义                                                                                         |
| -------------------- | -------------------------------------------------------------------------------------------- |
| `$()`                | 插入美元符号                                                                                 |
| `$(HOME)`            | 用户主目录                                                                                   |
| `$(CWD)`             | 当前工作目录                                                                                 |
| `$(FEXT)`            | 首选文件扩展名                                                                               |
| `$(PROBLEM)`         | 问题名称，`name` 字段                                                                        |
| `$(GROUP)`           | 平台和比赛名称，`group` 字段                                                                 |
| `$(JUDGE)`           | 平台名称（`group` 的第一部分，连字符前）                                                     |
| `$(CONTEST)`         | 比赛名称（`group` 的第二部分，连字符后）                                                     |
| `$(URL)`             | 问题网址，`url` 字段                                                                         |
| `$(MEMLIM)`          | 可用内存，`memoryLimit` 字段                                                                 |
| `$(TIMELIM)`         | 时间限制，`timeLimit` 字段                                                                   |
| `$(JAVA_MAIN_CLASS)` | 几乎总是 "Main"，`mainClass` 字段                                                            |
| `$(JAVA_TASK_CLASS)` | 类名友好的问题名称版本，`taskClass` 字段                                                     |
| `$(DATE)`            | 当前日期和时间（基于 [`date_format`](#说明)），只能在[模板文件](#接收问题和比赛的模板)中使用 |

字段参考[接收的任务](https://github.com/jmerle/competitive-companion/#the-format)。

### 自定义编译和运行命令

默认支持 C、C++、Rust、Java 和 Python 等语言。

当然你可以自定义用于编译和运行程序的命令。你也可以添加默认不支持的语言。

```vim
{
    compile_command: {
        cpp: { exec: 'g++',           args: {'$(FNAME)', '-o', '$(FNOEXT)'} },
        some_lang: { exec: 'some_compiler', args: {'$(FNAME)'} },
    },
    run_command: {
        cpp      : { exec: './$(FNOEXT)' },
        some_lang: { exec: 'some_interpreter', args: {'$(FNAME)'} },
    },
}
```

见[文件格式修饰符](#文件格式修饰符)以更好地理解美元符号表示法的工作原理。

**注意：** 如果你的语言不需要编译，可以忽略 `compile_command` 部分。

如果你认为值得添加新语言作为默认支持的语言，请随时提交 PR 或问题。

## 状态栏和窗口栏集成

每个 UI 窗口都设置了特殊的文件类型。分别是 `competitest_testcases`、`competitest_out`、`competitest_in`、`competitest_err`、`competitest_ans`。

如果使用 `vim-airline`，可以设置：

```vim
if !exists("g:airline_filetype_overrides") # airline 插件
 g:airline_filetype_overrides = {}
endif
g:airline_filetype_overrides.competitest_in = [ '输入', '' ]
g:airline_filetype_overrides.competitest_out = [ '输出', '' ]
g:airline_filetype_overrides.competitest_ans = [ '答案', '' ]
g:airline_filetype_overrides.competitest_err = [ '错误', '' ]
g:airline_filetype_overrides.competitest_testcases = [ '测试用例', '' ]
```

## 高亮

你可以自定义 CompetiTest 的高亮组。它们的默认值为：

```vim
hi CompetiTestRunning cterm=bold     gui=bold
hi CompetiTestDone    cterm=none     gui=none
hi CompetiTestCorrect ctermfg=green  guifg=Green
hi CompetiTestWarning ctermfg=yellow guifg=Yellow
hi CompetiTestWrong   ctermfg=red    guifg=Red
```

## 贡献

如果你有任何建议或遇到任何问题，请随时提出新问题。

欢迎提交 Pull Requests！🎉

## 维护者

该项目目前由 Mao-Yining <mao.yining@outlook.com> 维护

## 许可证

GNU 通用公共许可证第 3 版（GPL v3）或任何更高版本

版权所有 © 2025-2026 Mao-Yining <mao.yining@outlook.com>
