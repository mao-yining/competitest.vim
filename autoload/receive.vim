vim9script
# competitest receiver for Competitive Companion
# Handles problem/contest/testcase data from browser extension

export def Problem(args: list<string>): void
  # 实现接收单个问题的逻辑
  echo "Receiving problem from Competitive Companion..."
  # 这里会实现与 Competitive Companion 的集成
enddef

export def Contest(args: list<string>): void
  # 实现接收整个比赛的逻辑
  echo "Receiving contest from Competitive Companion..."
enddef

export def Testcase(args: list<string>): void
  # 实现接收单个测试用例的逻辑
  echo "Receiving testcase from Competitive Companion..."
enddef
