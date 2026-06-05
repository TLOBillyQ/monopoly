# language: zh-CN

功能: SwarmForge 上游拓扑一致性

背景:
  假如 SwarmForge 上游 README 是当前行为基线

# SwarmForge 上游拓扑一致性 001 配置决定角色拓扑
场景大纲: SwarmForge 上游拓扑一致性 001 配置决定角色拓扑
  假如 swarmforge.conf 定义角色<角色>使用后端<后端>和工作树<工作树>
  并且 项目存在角色提示文件<提示文件>
  当 SwarmForge 启动该配置
  那么 运行时创建 tmux 会话<会话>
  并且 该角色读取<提示文件>和 layered constitution
  并且 该角色在<启动目录>中启动

例子:
  | 角色      | 后端   | 工作树    | 提示文件                       | 会话                    | 启动目录              |
  | specifier | codex  | master    | swarmforge/specifier.prompt    | swarmforge-specifier    | 主工作目录            |
  | coder     | codex  | coder     | swarmforge/coder.prompt        | swarmforge-coder        | .worktrees/coder      |
  | cleaner   | codex  | cleaner   | swarmforge/cleaner.prompt      | swarmforge-cleaner      | .worktrees/cleaner    |
  | architect | codex  | architect | swarmforge/architect.prompt    | swarmforge-architect    | .worktrees/architect  |
  | hardender | codex  | hardender | swarmforge/hardender.prompt    | swarmforge-hardender    | .worktrees/hardender  |
  | QA        | codex  | QA        | swarmforge/QA.prompt           | swarmforge-QA           | .worktrees/QA         |

# SwarmForge 上游拓扑一致性 002 任意角色由本地提示文件约束
场景大纲: SwarmForge 上游拓扑一致性 002 任意角色由本地提示文件约束
  假如 swarmforge.conf 定义角色<角色>使用后端<后端>和工作树<工作树>
  当 SwarmForge 校验项目配置
  那么 配置要求存在提示文件<提示文件>
  并且 角色集合不限制为固定内置角色

例子:
  | 角色        | 后端   | 工作树     | 提示文件                       |
  | architect   | codex  | architect  | swarmforge/architect.prompt    |
  | research    | grok   | research   | swarmforge/research.prompt     |
  | release     | claude | release    | swarmforge/release.prompt      |

# SwarmForge 上游拓扑一致性 003 新目录首次启动会初始化仓库
场景大纲: SwarmForge 上游拓扑一致性 003 新目录首次启动会初始化仓库
  假如 工作目录不是 git 仓库
  当 SwarmForge 首次启动
  那么 工作目录被初始化为 git 仓库
  并且 初始分支名为master
  并且 路径<本地运行路径>写入 git ignore
  并且 首次启动创建初始提交

例子:
  | 本地运行路径    |
  | .swarmforge/    |
  | .worktrees/     |
  | swarmtools/     |
  | logs/           |
  | agent_context/  |

# SwarmForge 上游拓扑一致性 004 工作树只为命名工作树创建
场景大纲: SwarmForge 上游拓扑一致性 004 工作树只为命名工作树创建
  假如 swarmforge.conf 定义角色<角色>使用工作树<工作树>
  当 SwarmForge 准备角色工作目录
  那么 工作树创建行为为<创建行为>
  并且 角色启动目录为<启动目录>

例子:
  | 角色        | 工作树     | 创建行为                    | 启动目录              |
  | coder       | coder      | 创建.worktrees/coder        | .worktrees/coder      |
  | specifier   | master     | 不创建.worktrees/master     | 主工作目录            |
  | observer    | none       | 不创建.worktrees/none       | 主工作目录            |

# SwarmForge 上游拓扑一致性 005 通知助手使用项目本地状态
场景大纲: SwarmForge 上游拓扑一致性 005 通知助手使用项目本地状态
  假如 SwarmForge 已为角色<目标角色>记录会话<目标会话>
  并且 handoff 消息保存在<消息文件>
  当 发送通知到<目标>
  那么 notify-agent 从项目本地 tmux socket 发送消息
  并且 消息内容来自<消息文件>
  并且 目标解析为<目标会话>

例子:
  | 目标角色 | 目标 | 目标会话             | 消息文件                  |
  | coder    | coder | swarmforge-coder     | tmp/coder-handoff.txt     |
  | coder    | 2     | swarmforge-coder     | tmp/coder-handoff.txt     |
  | QA       | QA    | swarmforge-QA        | tmp/QA-handoff.txt        |
  | QA       | 6     | swarmforge-QA        | tmp/QA-handoff.txt        |

# SwarmForge 上游拓扑一致性 006 tmux 状态隔离并尊重索引设置
场景大纲: SwarmForge 上游拓扑一致性 006 tmux 状态隔离并尊重索引设置
  假如 项目路径为<项目路径>
  并且 tmux 配置使用窗口索引<窗口索引>和 pane 索引<pane索引>
  当 SwarmForge 向角色<角色>发送启动或通知命令
  那么 命令使用项目专属 tmux socket
  并且 tmux 目标地址为<目标地址>

例子:
  | 项目路径      | 窗口索引 | pane索引 | 角色  | 目标地址                  |
  | /repo/game    | 0        | 0        | coder | swarmforge-coder:0.0      |
  | /repo/game    | 1        | 1        | coder | swarmforge-coder:1.1      |
  | /repo/game    | 1        | 1        | QA    | swarmforge-QA:1.1         |
