# language: zh-CN
# mutation-stamp: sha256=9e31639afed9ab59cc4f42a62c5cc7e5629c83e0c88f5a6349c8d525d56e98ad
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "553774f141cd98b72cfeffac54c6cb0bf7ef2134541fa07dbe7a5fba958f6a02",
#   "feature_name": "基础整数解析",
#   "feature_path": "features/a-feature.feature",
#   "implementation_hash": "eb4934fea69986f4bc661fc94bd1269aca9bafd5a96925766c8f1c905c83adca",
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
#       "tested_at": "2026-05-26T11:52:55Z"
#     }
#   ],
#   "tested_at": "2026-05-26T14:28:39Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

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
