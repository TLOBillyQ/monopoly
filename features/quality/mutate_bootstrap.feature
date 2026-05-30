# language: zh-CN

功能: src/ 树差分变异 manifest 一键 bootstrap

背景:
  假如 tools/quality/mutate_bootstrap.lua 已落地
  并且 该工具通过 git ls-files 枚举 src/**/*.lua
  并且 每个待写文件由 mutate4lua engine.update_manifest 写入 v2 manifest
  并且 工具不调用 git commit；commit 由操作者完成

场景大纲: 仅枚举 src 下追踪的 Lua 文件
  假如 git ls-files 输出包含<候选路径>
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 工具<是否处理><候选路径>

例子:
  | 候选路径                       | 是否处理 |
  | src/foundation/log.lua         | 处理     |
  | src/rules/market/effects.lua   | 处理     |
  | src/turn/loop/init.lua         | 处理     |
  | docs/architecture/boundaries.md | 不处理  |
  | spec/contract/state/x.lua      | 不处理   |
  | tools/quality/lint.lua         | 不处理   |
  | vendor/mutate4lua/lib/x.lua    | 不处理   |
  | tests/legacy_runner.lua        | 不处理   |

场景大纲: 无 manifest 的文件首次写入 v2
  假如 源文件<源文件>当前不含 mutate4lua manifest 尾块
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 源文件追加 mutate4lua-manifest 尾块
  并且 manifest version 字段为 2
  并且 manifest 不含 lastMutationStatus 字段
  并且 工具 summary 标记<源文件>为 written

例子:
  | 源文件                  |
  | src/foundation/log.lua  |
  | src/turn/loop/init.lua  |

场景大纲: 已有 v2 manifest 且匹配当前源码的文件保持幂等
  假如 源文件<源文件>已含 v2 manifest 且 scope hash 与当前源码一致
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 源文件字节级保持不变
  并且 工具 summary 标记<源文件>为 unchanged

例子:
  | 源文件                  |
  | src/foundation/log.lua  |

场景大纲: v1 manifest 升级到 v2
  假如 源文件<源文件>含 version=1 的 manifest 尾块
  并且 源码未发生语义变化
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 manifest 尾块的 version 字段改写为 2
  并且 每个 scope 的 id 字段与升级前一致
  并且 每个 scope 的 semanticHash 字段与升级前一致
  并且 manifest 不含 lastMutationStatus 字段
  并且 工具 summary 标记<源文件>为 migrated

例子:
  | 源文件                       |
  | src/rules/market/effects.lua |

场景大纲: manifest 尾块损坏的文件被跳过并报告
  假如 源文件<源文件>的 manifest 尾块呈现<损坏形式>
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 工具不修改<源文件>
  并且 stderr 包含<源文件>与<损坏形式>说明
  并且 工具继续处理其他文件
  并且 工具 summary 标记<源文件>为 skipped

例子:
  | 源文件                       | 损坏形式              |
  | src/foundation/log.lua       | 缺失结尾 ]] 标记      |
  | src/foundation/log.lua       | 起始标记后内容截断    |

场景大纲: 工具结束时输出 summary 且各类计数之和等于总文件数
  假如 git ls-files src/ 输出<总数>个 Lua 文件
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 stdout 包含字面量<总数>
  并且 stdout 同时包含 written / migrated / unchanged / skipped 四类计数
  并且 四类计数之和等于<总数>

例子:
  | 总数 |
  | 1    |
  | 50   |
  | 350  |

场景大纲: 退出码反映是否存在 skipped 项
  假如 工具运行后 summary 显示 skipped 计数为<skipped 计数>
  当 mutate_bootstrap.lua 结束
  那么 工具退出码为<退出码>

例子:
  | skipped 计数 | 退出码 |
  | 0            | 0      |
  | 1            | 0      |
  | 5            | 0      |

场景: 空 src 树时直接退出
  假如 git ls-files 输出不含 src/**/*.lua
  当 执行 lua tools/quality/mutate_bootstrap.lua
  那么 工具退出码为 0
  并且 stderr 包含"无 src 文件"提示字面量
  并且 工具不写任何 manifest 尾块

场景大纲: --dry-run 预览不写入
  假如 git ls-files 输出含<源文件>
  当 执行 lua tools/quality/mutate_bootstrap.lua --dry-run
  那么 源文件字节级保持不变
  并且 stdout 列出 will-write / will-migrate / will-unchanged / will-skip 计划
  并且 工具退出码为 0

例子:
  | 源文件                       |
  | src/foundation/log.lua       |
  | src/rules/market/effects.lua |
