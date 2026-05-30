# language: zh-CN
# mutation-stamp: sha256=70d17f79193c1761476fa9944fcb180228b2a07e17ff673c9762b0c044536920
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "1659cf5069120db228d4e3ac02d538432e5374323b5ddb9d03c01e67fe397822",
#   "feature_name": "PR 改动文件差分变异门禁",
#   "feature_path": "features/quality/verify_mutation_diff.feature",
#   "implementation_hash": "sha256:1e892c030ec094f2187bf10192072c6500ae997827e857d125b7917aee606f48",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 12,
#       "name": "仅扫描 src 内的 Lua 文件",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "0de1b6501b7616e9412c0f1cd81861c15c4c589b25f23447329ac730dedbca9d",
#       "tested_at": "2026-05-28T14:54:25Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 9,
#       "name": "survived mutant 触发 warn 而非 fail",
#       "result": {
#         "Errors": 0,
#         "Killed": 9,
#         "Survived": 0,
#         "Total": 9
#       },
#       "scenario_hash": "91e81a21fb9bb643f140696b21dfbfa89ebce22fe37fd15caacc1fbcdcb34479",
#       "tested_at": "2026-05-28T14:54:26Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 6,
#       "name": "全 kill 与零 site 静默通过",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "3e6d6b6b93f9861cda0fde57b943f66373ae7a6dd6b2198d3245dcf5116ad1c0",
#       "tested_at": "2026-05-28T14:54:27Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 1,
#       "name": "新增的 src/ 文件按全量变异处理",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "914e7d7a2323b1afacdc6e7ab30321c98ca3c1ca1ef7bda70b0a046ac420839d",
#       "tested_at": "2026-05-28T14:54:27Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 1,
#       "name": "已删除的 src 文件跳过",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "c16bb7694cda47066e319020d9dbf86f65e86a90b38e1d9c7c692102bd362079",
#       "tested_at": "2026-05-28T14:54:27Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 1,
#       "name": "baseline 失败是硬错误",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "4e2fe7c771aea1a60d54b7a576eecda1daf340327231cb536bb93ac94b5a5be5",
#       "tested_at": "2026-05-28T14:54:28Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "无 src 变更时直接通过",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "ea9874bc52e1accfed57ea83f35f258742e4cb1c8307502bd5f5f110924923ed",
#       "tested_at": "2026-05-28T14:54:28Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 3,
#       "name": "基准引用可通过 --base 覆盖",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "10db4ef43a69d009d13118aff0e4f98d7bc4cee8e87150ae499fa6f8b03e7de4",
#       "tested_at": "2026-05-28T14:54:28Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 2,
#       "name": "JSON 输出聚合每个改动文件结果",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "fa350dd44fa1704ec5022a76b2737c8cc98ac2c1378f6ebfb3ce4bee6bb6ff75",
#       "tested_at": "2026-05-28T14:54:29Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:54:29Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: PR 改动文件差分变异门禁

背景:
  假如 tools/quality/verify_mutation_diff.lua 已落地
  并且 该工具以 git diff <基准引用>...HEAD 取得变更集
  并且 默认基准引用为 main
  并且 tools/quality/mutate.lua 提供差分 default 的单文件变异 CLI

场景大纲: 仅扫描 src 内的 Lua 文件
  假如 git diff main...HEAD 输出包含路径<diff 路径>
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具<是否调用> tools/quality/mutate.lua 处理该路径

例子:
  | diff 路径                              | 是否调用 |
  | src/rules/market/effects.lua           | 调用     |
  | src/foundation/log.lua                 | 调用     |
  | docs/decisions/0004-differential-mutation-testing.md | 不调用 |
  | spec/contract/state/state_machine.lua  | 不调用   |
  | tools/quality/verify_full.lua          | 不调用   |
  | features/game/dice.feature             | 不调用   |

场景大纲: survived mutant 触发 warn 而非 fail
  假如 git diff main...HEAD 列出<改动文件>
  并且 改动文件的 mutate 运行产生<survived 数>个 survived
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具退出码为<退出码>
  并且 stderr 包含<改动文件>路径
  并且 stderr 包含 survived 计数字面量

例子:
  | 改动文件                | survived 数 | 退出码 |
  | src/foundation/log.lua  | 1           | 0      |
  | src/foundation/log.lua  | 3           | 0      |
  | src/foundation/log.lua  | 7           | 0      |

场景大纲: 全 kill 与零 site 静默通过
  假如 git diff main...HEAD 列出<改动文件>
  并且 改动文件的 mutate 运行<结果>
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具退出码为 0
  并且 stderr 不含<禁词>

例子:
  | 改动文件                | 结果         | 禁词    |
  | src/foundation/log.lua  | 全 kill      | survived |
  | src/foundation/log.lua  | 差分零位点   | survived |

场景大纲: 新增的 src/ 文件按全量变异处理
  假如 git diff main...HEAD 报告新增<新增文件>
  并且 新增文件不含 mutate4lua manifest 尾块
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具调用 tools/quality/mutate.lua 处理<新增文件>
  并且 该次调用执行全量变异（无 manifest 视作全 scope changed）
  并且 工具不把"无 manifest"视作错误

例子:
  | 新增文件                |
  | src/foundation/new.lua  |

场景大纲: 已删除的 src 文件跳过
  假如 git diff main...HEAD 报告<被删文件>已删除
  并且 工作树不再有<被删文件>
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具不调用 mutate.lua 处理<被删文件>
  并且 工具不报告"文件不存在"为错误

例子:
  | 被删文件                     |
  | src/foundation/retired.lua   |

场景大纲: baseline 失败是硬错误
  假如 git diff main...HEAD 列出<改动文件>
  并且 改动文件的 mutate 运行 baseline 阶段返回非零退出码
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具退出码为 1
  并且 stderr 包含<改动文件>路径
  并且 工具中止并不继续后续文件

例子:
  | 改动文件                 |
  | src/foundation/log.lua   |

场景: 无 src 变更时直接通过
  假如 git diff main...HEAD 输出不含 src/**/*.lua 路径
  当 执行 lua tools/quality/verify_mutation_diff.lua
  那么 工具退出码为 0
  并且 工具不调用 tools/quality/mutate.lua
  并且 stderr 包含"无 src 变更"提示字面量

场景大纲: 基准引用可通过 --base 覆盖
  假如 当前分支与<基准>存在差异
  当 执行 lua tools/quality/verify_mutation_diff.lua --base <基准>
  那么 工具采用 git diff <基准>...HEAD 作为变更集
  并且 default 基准为 main 不变

例子:
  | 基准              |
  | main              |
  | origin/main       |
  | release-2026-q2   |

场景大纲: JSON 输出聚合每个改动文件结果
  假如 git diff main...HEAD 列出<改动文件>
  当 执行 lua tools/quality/verify_mutation_diff.lua --json
  那么 stdout 输出 JSON
  并且 JSON 含每个改动文件的字段<必含字段>

例子:
  | 改动文件                | 必含字段                                                  |
  | src/foundation/log.lua  | file / total_sites / killed / survived / timeout / score  |
