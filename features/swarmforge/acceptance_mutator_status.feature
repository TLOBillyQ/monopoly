# language: zh-CN
# mutation-stamp: sha256=711edfc0b47a7d818581e3e32bf60735dbfd1e496122f434658091ce067d6454
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "41a1310face39a86c9c1753418b407174152c4916cae0b21a6b72721856c7ab9",
#   "feature_name": "Gherkin 变异状态输出",
#   "feature_path": "features/swarmforge/acceptance_mutator_status.feature",
#   "implementation_hash": "sha256:a5bed72dced7be646d888ef36796c73f5f2367ad662b9ecf5016a6994f1c7118",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 2,
#       "name": "状态输出不污染最终报告",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "c1730b77642b7186ab87d352d84312ab9402b0ab43e93c5a5570a6cbc321e750",
#       "tested_at": "2026-05-31T13:50:04Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 3,
#       "name": "差分跳过数量进入状态输出",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "cd2cea71d3479f50bf9acdac79e69f543cce67a82b2ea9940b2a592b8ec9198f",
#       "tested_at": "2026-05-31T13:50:07Z"
#     }
#   ],
#   "tested_at": "2026-05-31T13:50:07Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: Gherkin 变异状态输出

背景:
  假如 仓库启用了 SwarmForge 迁移工作流

场景大纲: 状态输出不污染最终报告
  假如 验收变异样例包含<变异总数>个可执行变异
  当 执行 Gherkin mutator 时启用30s状态间隔并请求<报告格式>报告
  那么 mutator 命令成功完成
  并且 标准错误输出包含状态行
  并且 状态行包含总数<变异总数>和完成数<变异总数>
  并且 状态行包含已耗时
  并且 标准输出保持为<报告格式>报告
  并且 标准输出不包含状态行

例子:
  | 变异总数 | 报告格式 |
  | 2        | JSON     |

场景大纲: 差分跳过数量进入状态输出
  假如 验收变异样例已经有成功差分基线
  当 执行 Gherkin mutator 时启用30s状态间隔并请求<报告格式>报告
  那么 mutator 命令成功完成
  并且 标准错误输出包含状态行
  并且 状态行包含跳过场景数<跳过场景数>和跳过变异数<跳过变异数>
  并且 状态行包含已耗时
  并且 标准输出保持为<报告格式>报告
  并且 标准输出不包含状态行

例子:
  | 报告格式 | 跳过场景数 | 跳过变异数 |
  | JSON     | 1          | 2          |
