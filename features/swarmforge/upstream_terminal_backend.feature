# language: zh-CN

功能: SwarmForge 上游终端后端一致性

背景:
  假如 SwarmForge 上游 README 是当前行为基线

# SwarmForge 上游终端后端一致性 001 环境变量覆盖终端后端
场景大纲: SwarmForge 上游终端后端一致性 001 环境变量覆盖终端后端
  假如 环境变量SWARMFORGE_TERMINAL为<环境值>
  当 SwarmForge 选择终端后端
  那么 选择的终端后端为<后端>

例子:
  | 环境值           | 后端              |
  | ghostty          | ghostty           |
  | terminal-app     | terminal-app      |
  | windows-terminal | windows-terminal  |
  | none             | none              |

# SwarmForge 上游终端后端一致性 002 默认终端后端按本机能力选择
场景大纲: SwarmForge 上游终端后端一致性 002 默认终端后端按本机能力选择
  假如 未设置SWARMFORGE_TERMINAL
  并且 本机终端能力为<本机能力>
  当 SwarmForge 选择终端后端
  那么 选择的终端后端为<后端>

例子:
  | 本机能力        | 后端              |
  | AppleScript     | terminal-app      |
  | WindowsTerminal | windows-terminal  |
  | 无自动化终端    | none              |

# SwarmForge 上游终端后端一致性 003 后端能力决定启动和监控方式
场景大纲: SwarmForge 上游终端后端一致性 003 后端能力决定启动和监控方式
  假如 终端后端<后端>声明可打开会话<可打开会话>
  并且 终端后端<后端>声明可跟踪窗口<可跟踪窗口>
  当 SwarmForge 打开角色终端
  那么 终端行为为<终端行为>
  并且 watchdog 行为为<watchdog行为>

例子:
  | 后端             | 可打开会话 | 可跟踪窗口 | 终端行为                 | watchdog行为       |
  | terminal-app     | 是         | 是         | 每个角色打开可跟踪窗口   | 启动watchdog       |
  | ghostty          | 是         | 是         | 每个角色打开可跟踪标签   | 启动watchdog       |
  | windows-terminal | 是         | 否         | 每个角色打开窗口         | 跳过watchdog       |
  | none             | 否         | 否         | 当前 shell 附加 cleanup  | 跳过watchdog       |

# SwarmForge 上游终端后端一致性 004 watchdog 恢复非 cleanup 窗口
场景大纲: SwarmForge 上游终端后端一致性 004 watchdog 恢复非 cleanup 窗口
  假如 watchdog 正在跟踪 cleanup 窗口<cleanup窗口>和角色窗口<角色窗口>
  当 角色窗口<角色窗口>关闭
  那么 watchdog 重新打开同一 tmux 会话
  并且 窗口状态文件更新为<新窗口记录>

例子:
  | cleanup窗口 | 角色窗口 | 新窗口记录                  |
  | win-1       | win-2    | 角色窗口使用新稳定窗口id    |

# SwarmForge 上游终端后端一致性 005 cleanup 窗口关闭会终止整个 swarm
场景大纲: SwarmForge 上游终端后端一致性 005 cleanup 窗口关闭会终止整个 swarm
  假如 watchdog 正在跟踪 cleanup 窗口<cleanup窗口>和角色窗口<角色窗口>
  当 cleanup窗口<cleanup窗口>关闭
  那么 watchdog 关闭所有配置的 tmux 会话
  并且 watchdog 关闭剩余的已跟踪窗口

例子:
  | cleanup窗口 | 角色窗口 |
  | win-1       | win-2    |
