vim9script
# Vim global plugin for competitive programing
# Last Change:  2025-06-29
# Maintainer:   毛同学 <stu_mao@outlook.com>
# License:  This file is placed in the public domain.

# [1] 默认配置
if !exists('g:competitest_default_config')
  g:competitest_default_config = {
    runner_language: {
      cpp:    'g++ -std=c++17 -O2 -Wall -o $out$ $in$ && ./$out$',
      python: 'python3 $in$',
      java:   'javac $in$ && java $in:r$',
    },
    testcase_dir: 'testcases',
    template_dir: 'templates',
    accept_prefix: 'accept_',
    ui_style: 'floating',
  }
endif

# [2] 主命令定义
command! -nargs=* -complete=customlist,CompetiTestComplete CompetiTest HandleCommand(<f-args>)

# [3] 自动补全函数（仅一级命令）
def CompetiTestComplete(ArgLead: string, CmdLine: string, CursorPos: number): list<string>
  # 获取命令行中已输入的单词列表
  var words = split(CmdLine, '\s\+')

  # 计算当前参数位置（跳过主命令）
  var arg_index = len(words) - 1
  if ArgLead != ''
    arg_index -= 1  # 如果正在输入当前参数，调整索引
  endif

  # 一级命令列表
  var primary_commands = ['run', 'show_ui', 'add_test', 'accept', 'setup', 'help', 'receive']

  # receive 的二级子命令
  var receive_subcommands = ['problem', 'contest', 'testcase']

  # 确定需要补全的内容
  if arg_index == 0
    # 补全一级命令
    if ArgLead == ''
      return primary_commands
    endif
    return filter(primary_commands, (_, v) => v =~? '^' .. ArgLead)

  elseif arg_index == 1 && words[1] == 'receive'
    # 在 receive 命令后补全二级子命令
    if ArgLead == ''
      return receive_subcommands
    endif
    return filter(receive_subcommands, (_, v) => v =~? '^' .. ArgLead)

  else
    # 其他情况不提供补全
    return []
  endif
enddef

# [4] 命令处理器
def HandleCommand(...args: list<string>): void
  if len(args) == 0
    echohl WarningMsg
    echo "Available subcommands: run, show_ui, add_test, accept, setup, help, receive"
    echohl None
    return
  endif

  const subcmd = args[0]->tolower()
  const remaining_args = args[1 : ]

  try
    if subcmd == 'run'
      # 新的run行为：显示UI并运行所有测试
      competitest#ui#Show([])
      competitest#runner#RunAll()
    elseif subcmd == 'show_ui'
      competitest#ui#Show(remaining_args)
    elseif subcmd == 'add_test'
      competitest#testcases#AddTestcase()
    elseif subcmd == 'accept'
      competitest#testcases#AcceptCurrent(remaining_args)
    elseif subcmd == 'setup'
      if len(remaining_args) > 0
        competitest#Setup(eval(remaining_args[0]))
      else
        competitest#Setup()
      endif
    elseif subcmd == 'receive'
      HandleReceiveCommand(remaining_args)
    elseif subcmd == 'help'
      ShowHelp()
    else
      echoerr $'Unknown subcommand: {subcmd}'
    endif
  catch /^CompetiTest:/
    echoerr v:exception
  endtry
enddef

# [5] 处理receive命令（有二级子命令）
def HandleReceiveCommand(args: list<string>): void
  if len(args) == 0
    echohl WarningMsg
    echo "Available receive types: problem, contest, testcase"
    echohl None
    return
  endif

  const receive_type = args[0]->tolower()
  const remaining_args = args[1 : ]

  if receive_type == 'problem'
    competitest#receive#Problem(remaining_args)
  elseif receive_type == 'contest'
    competitest#receive#Contest(remaining_args)
  elseif receive_type == 'testcase'
    competitest#receive#Testcase(remaining_args)
  else
    echoerr $'Unknown receive type: {receive_type} (use: problem/contest/testcase)'
  endif
enddef

# [6] 帮助信息
def ShowHelp(): void
  const help_text = [
    "CompetiTest Commands:",
    "  :CompetiTest run         - 显示UI并运行所有测试用例",
    "  :CompetiTest show_ui     - 显示UI窗口",
    "  :CompetiTest add_test    - 添加新测试用例",
    "  :CompetiTest accept [id] - 接受当前输出为预期结果",
    "  :CompetiTest setup {cfg} - 更新配置",
    "  :CompetiTest help        - 显示帮助信息",
    "",
    "Receive Commands (for Competitive Companion):",
    "  :CompetiTest receive problem    - 接收单个问题",
    "  :CompetiTest receive contest    - 接收整个比赛",
    "  :CompetiTest receive testcase   - 接收单个测试用例",
    "",
    "Manual Keymap Examples:",
    "  nnoremap <LocalLeader>ctr :CompetiTest run<CR>",
    "  nnoremap <LocalLeader>ctn :CompetiTest add_test<CR>",
    "  nnoremap <LocalLeader>ctp :CompetiTest receive problem<CR>"
  ]
  echo help_text->join("\n")
enddef

# [7] 初始化
augroup CompetiTestInit
  autocmd!
  autocmd VimEnter * {
    if exists('g:competitest_config')
      competitest#Setup(g:competitest_config)
    else
      competitest#Setup()
    endif
  }
augroup END
