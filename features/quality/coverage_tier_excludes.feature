# language: zh-CN
# mutation-stamp: sha256=e599735c95b0dd0f058901ebd9776b8e72c0a11f8f0b3c16aa52c941cf6a4ad7
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "93da510e430d32ed1a4205d921d89fbf9bbe03a5a320c78350cb17ea87ece031",
#   "feature_name": "覆盖率 tier 文件级排除机制",
#   "feature_path": "features/quality/coverage_tier_excludes.feature",
#   "implementation_hash": "sha256:bf19adb408ab418908c65c45feab4b39873c738839ee953bb592d3936b5eb04e",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 0,
#       "name": "引入 excludes 字段",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9e9fcd44f94bf817f016bd3d6cb8a2f1b8cd0e73b30d1436f81a2be7d632f7b5",
#       "tested_at": "2026-07-07T02:55:38Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 3,
#       "name": "excludes 命中的文件不计入该 tier 统计",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "1933cb4f49a6e60481e8ab8bb4c1c76f0fff3bc414fc7140b0644a1bb54716aa",
#       "tested_at": "2026-07-07T02:55:39Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 2,
#       "name": "无 excludes 字段的 tier 行为不变",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "bf1070c5928929a77352c0664749dcfd07589d44c42c6e001f96dba63ce6600a",
#       "tested_at": "2026-07-07T02:55:40Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 16,
#       "name": "excludes 仅按完整文件路径精确匹配",
#       "result": {
#         "Errors": 0,
#         "Killed": 16,
#         "Survived": 0,
#         "Total": 16
#       },
#       "scenario_hash": "086c01514363b786bbf04d7bfd5aa71299d27775cfcb2630a6ce9aac491f4e46",
#       "tested_at": "2026-07-07T02:55:43Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "tier 配置 schema 错误时报错",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4b144ad58878b995bd2616f9c05ab39a68dacaa1b49b97d31f36766741e8288d",
#       "tested_at": "2026-07-07T02:55:43Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "应用项 — core_logic 排除 host_install",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "41c87daf365e55244a664a602b03c985164661057fdd6def6104e9c0c52a771d",
#       "tested_at": "2026-07-07T02:55:43Z"
#     }
#   ],
#   "tested_at": "2026-07-07T02:55:43Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 覆盖率 tier 文件级排除机制

背景:
  假如 tools/quality/crap/coverage_tiers.lua 是 tier 配置真源
  并且 tools/quality/crap.lua 通过 lockfile 中 crap4lua 的 _file_tier_index 做归属判定
  并且 现行匹配按目录前缀（prefix + 结尾"/"）执行

场景: 引入 excludes 字段
  假如 一个 tier 在配置中声明<excludes 字段>
  当 _file_tier_index 处理某源路径
  那么 若源路径匹配该 tier 的 includes 前缀
  并且 源路径同时等于<excludes 字段>中任一字面值
  并且 _file_tier_index 视为该 tier 不命中
  并且 继续检查后续 tier
  并且 若无后续 tier 命中，则归入 uncategorized

场景大纲: excludes 命中的文件不计入该 tier 统计
  假如 coverage_tiers.lua 中 tier <tier 名称>的 excludes 含<排除文件>
  并且 当前 crap 报告中<排除文件>missed_lines 为<missed 行数>
  当 执行 lua tools/quality/crap.lua summary
  那么 <tier 名称>的总分母不含<排除文件>
  并且 <tier 名称>的总分子不含<排除文件>
  并且 <排除文件>归入 uncategorized 桶

例子:
  | tier 名称   | 排除文件                     | missed 行数 |
  | core_logic  | src/app/host_install.lua     | 53          |

场景大纲: 无 excludes 字段的 tier 行为不变
  假如 tier <tier 名称>在配置中不声明 excludes 字段
  当 _file_tier_index 处理任一源路径
  那么 匹配逻辑与未引入 excludes 前完全一致
  并且 同一份输入产生相同的 tier 归属

例子:
  | tier 名称   |
  | host_bridge |
  | ui_surface  |

场景大纲: excludes 仅按完整文件路径精确匹配
  假如 tier <tier 名称>的 excludes 列出<排除项>
  并且 当前 crap 报告中存在路径<候选路径>
  当 _file_tier_index 处理<候选路径>
  那么 <候选路径>归属<是否被排除>

例子:
  | tier 名称   | 排除项                       | 候选路径                            | 是否被排除 |
  | core_logic  | src/app/host_install.lua     | src/app/host_install.lua            | 排除       |
  | core_logic  | src/app/host_install.lua     | src/app/host_install_helper.lua     | 不排除     |
  | core_logic  | src/app/host_install.lua     | src/app/other_install.lua           | 不排除     |
  | core_logic  | src/app/host_install.lua     | src/app/                            | 不排除     |

场景: tier 配置 schema 错误时报错
  假如 某 tier 的 excludes 字段不是数组
  当 加载 coverage_tiers.lua
  那么 工具退出码非 0
  并且 stderr 报告 schema 错误字面量
  并且 工具不继续生成 summary

场景: 应用项 — core_logic 排除 host_install
  假如 coverage_tiers.lua 中 core_logic tier 的 excludes 含 "src/app/host_install.lua"
  当 执行 lua tools/quality/crap.lua summary
  那么 core_logic 桶不含 src/app/host_install.lua
  并且 core_logic 的覆盖率较未排除时严格上升
  并且 src/app/host_install.lua 出现在 uncategorized 桶
  并且 uplift 量级与 53 / core_logic 总行数 一致（约 0.2pp）
