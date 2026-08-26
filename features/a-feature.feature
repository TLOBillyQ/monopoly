# language: zh-CN
# mutation-stamp: sha256=c471d65c02f94245a49fbca9e124c8b3d5c790ad7386f0f32b267fe4ed12593b
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "553774f141cd98b72cfeffac54c6cb0bf7ef2134541fa07dbe7a5fba958f6a02",
#   "feature_name": "基础整数解析",
#   "feature_path": "features/a-feature.feature",
#   "implementation_hash": "sha256:d92821a1503aeed9bcb156f0cd0e9e35379b33cd840fb6fcbb1a39e96a8d7457",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 4,
#       "name": "解析整数文本",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "7162af13a3eeee134d85ebbc3c78419a94afbbaa8e707dfb04081ca74cc324eb",
#       "tested_at": "2026-08-26T11:20:35Z"
#     }
#   ],
#   "tested_at": "2026-08-26T11:20:35Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

# 保留依据(2026-08-26 收尾卡):本文件是 acceptance-mutate 的 --feature 默认探针
# (tools/packages/acceptance_mutate/mutate_lane.lua DEFAULT_FEATURE,与 APS 参考
# 实现一致),步骤走验收引擎内建件 tools/packages/acceptance/builtin_steps.lua。
# 不进 features/manifest.lua 是刻意形态:它只证明差分变异车道
# parser→generator→runner 链路能跑,不承担产品行为。清理 feature 时不要删。

功能: 基础整数解析

背景:
  假如 项目验收步骤已加载

场景大纲: 解析整数文本
  假如 文本值为<原始文本>
  当 项目将文本转换为整数
  那么 整数结果为<整数结果>

例子:
  | 原始文本 | 整数结果 |
  | 12       | 12       |
  | -7       | -7       |
