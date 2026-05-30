# language: zh-CN
# mutation-stamp: sha256=de295e8e712e17ad216b227b42e2d2c27bec405e0a1737cc328a75b855802967
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "41a1310face39a86c9c1753418b407174152c4916cae0b21a6b72721856c7ab9",
#   "feature_name": "Gherkin 变异状态输出",
#   "feature_path": "features/swarmforge/acceptance_mutator_status.feature",
#   "implementation_hash": "sha256:4b95c787bafbaa6112679c0afca296dbb7a045f8cc5f2e543ab8d2e74824b04b",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 4,
#       "name": "状态输出不污染最终报告",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "0bab9d0901acff5973793f4717b4cf2dcd6dda61fc187719ea590c1459608e30",
#       "tested_at": "2026-05-25T11:46:43Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 5,
#       "name": "差分跳过数量进入状态输出",
#       "result": {
#         "Errors": 0,
#         "Killed": 5,
#         "Survived": 0,
#         "Total": 5
#       },
#       "scenario_hash": "7db5c5c3e8b05b8a9401489684055ec487dc8a396f9fdc31211f187eddb03ec9",
#       "tested_at": "2026-05-25T11:46:45Z"
#     }
#   ],
#   "tested_at": "2026-05-27T11:50:52Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: Gherkin 变异状态输出

背景:
  假如 仓库启用了 SwarmForge 迁移工作流

场景大纲: 状态输出不污染最终报告
  假如 验收变异样例包含<变异总数>个可执行变异
  当 执行 Gherkin mutator 时启用<状态间隔>状态间隔并请求<报告格式>报告
  那么 mutator 命令成功完成
  并且 标准错误输出包含状态行
  并且 状态行包含总数<变异总数>和完成数<变异总数>
  并且 状态行包含状态间隔<期望状态间隔>
  并且 标准输出保持为<报告格式>报告
  并且 标准输出不包含状态行

例子:
  | 变异总数 | 状态间隔 | 期望状态间隔 | 报告格式 |
  | 2        | 30s      | 30s          | JSON     |

场景大纲: 差分跳过数量进入状态输出
  假如 验收变异样例已经有成功差分基线
  当 执行 Gherkin mutator 时启用<状态间隔>状态间隔并请求<报告格式>报告
  那么 mutator 命令成功完成
  并且 标准错误输出包含状态行
  并且 状态行包含跳过场景数<跳过场景数>和跳过变异数<跳过变异数>
  并且 状态行包含状态间隔<期望状态间隔>
  并且 标准输出保持为<报告格式>报告
  并且 标准输出不包含状态行

例子:
  | 状态间隔 | 期望状态间隔 | 报告格式 | 跳过场景数 | 跳过变异数 |
  | 30s      | 30s          | JSON     | 1          | 2          |
