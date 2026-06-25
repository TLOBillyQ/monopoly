# language: zh-CN
# mutation-stamp: sha256=8d39192b0b4fd490538297adf9c4e19e49aa3ab8a5b0aa267e334b4e1aa4debf
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "a0f74d8330fc037bc985ed90066364bc1ede0f4445cabc3cf950e7bcdf9f7292",
#   "feature_name": "src/ 树差分变异 manifest 一键 bootstrap",
#   "feature_path": "features/quality/mutate_bootstrap.feature",
#   "implementation_hash": "sha256:60e58474c8510e786be1c74f89bd41f64e1afa56cb6be41cce0f3d285fe6e5c5",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 16,
#       "name": "仅枚举 src 下追踪的 Lua 文件",
#       "result": {
#         "Errors": 0,
#         "Killed": 16,
#         "Survived": 0,
#         "Total": 16
#       },
#       "scenario_hash": "a5fb374296e420baed6b36a485b766f3a70359abedd3ebfb45fa18e05db16809",
#       "tested_at": "2026-06-25T12:35:26Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 2,
#       "name": "无 manifest 的文件首次写入 v2",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "62faeb0a442bb447a8fc7c5c0f2e2569d7534b9a35e5e8ac98369180c772b687",
#       "tested_at": "2026-06-25T12:35:30Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 1,
#       "name": "已有 v2 manifest 且匹配当前源码的文件保持幂等",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "5deee648bed108578ec170ab2550a69387d0a46f9354d83326fd4c4e9805ecb0",
#       "tested_at": "2026-06-25T12:35:32Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 1,
#       "name": "v1 manifest 升级到 v2",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "5893d85a36bf49496dba399db4123db0ae467f0509ee26dc350fc1f6ce1bfaf6",
#       "tested_at": "2026-06-25T12:35:35Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 4,
#       "name": "manifest 尾块损坏的文件被跳过并报告",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "ff46d0770014fe7f0aafd40e51caa1df3e62cf9fb91676d625bd6b4efb676d53",
#       "tested_at": "2026-06-25T12:35:44Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 3,
#       "name": "工具结束时输出 summary 且各类计数之和等于总文件数",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "d6ba05e25ee9adc80da66c73f4b101d9607a974c8caa94fe8dbd9f23df832b5f",
#       "tested_at": "2026-06-25T12:35:50Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "无 skipped 项时退出码为 0",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "d9ca3d64906566b8948b38b78b53868a59631ded60479078593ecb6a11a08cab",
#       "tested_at": "2026-06-25T12:35:50Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 2,
#       "name": "有 skipped 项时退出码仍为 0",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "2974c9e40d69d5bb66a567cfaf0095e6009243c109b52fe1ec6fbd7b68e8cccd",
#       "tested_at": "2026-06-25T12:35:54Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "空 src 树时直接退出",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "491d97c2fd5aff8653b5596d558d7719acd838c2632a83be6ae46c4d917a3351",
#       "tested_at": "2026-06-25T12:35:54Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 2,
#       "name": "--dry-run 预览不写入",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "05a5d8b80ca2e3ba63cdee0a3a05f2303e4680c31178e91e43df6255ae57f1ae",
#       "tested_at": "2026-06-25T12:35:58Z"
#     }
#   ],
#   "tested_at": "2026-06-25T12:35:58Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: src/ 树差分变异 manifest 一键 bootstrap

背景:
  假如 tools/quality/mutate_bootstrap.lua 已落地
  并且 该工具通过 git ls-files 枚举 src/**/*.lua
  并且 每个待写文件由 lockfile 中 mutate4lua engine.update_manifest 写入 v2 manifest
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
  | swarmforge/tools.lock          | 不处理   |
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

场景: 无 skipped 项时退出码为 0
  假如 工具运行后 summary 显示 skipped 计数为0
  当 mutate_bootstrap.lua 结束
  那么 工具退出码为 0

场景大纲: 有 skipped 项时退出码仍为 0
  假如 工具运行后 summary 显示正 skipped 计数为<skipped 计数>
  当 mutate_bootstrap.lua 结束
  那么 工具退出码为 0

例子:
  | skipped 计数 |
  | 1            |
  | 5            |

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
