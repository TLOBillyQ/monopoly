# language: zh-CN
# mutation-stamp: sha256=dcd7b22fda0d07106a52bcf1f5781b4d90d34f2208a76e19dfcffcdc4caf3938
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "ca3d163bab055381827226140568f3bef7eaac187cebd76878e0b63e9e442356",
#   "feature_name": "切换行动日志显示",
#   "feature_path": "features/v102/action_log_toggle.feature",
#   "implementation_hash": "sha256:9c0eaf3fa6eb642fb085aa7df859c4d5643d9c65f732e193208aca2a0adc8911",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 4,
#       "name": "action_log_toggle_001 触发行动日志入口翻转当前角色的行动日志显隐",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "1d0c9be264a69f885044a6c7313a9a777f3e5b225a927344e4985e0c7bc4b3ad",
#       "tested_at": "2026-07-07T02:59:48Z"
#     }
#   ],
#   "tested_at": "2026-07-07T02:59:48Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 切换行动日志显示

  # action_log_toggle_001 触发行动日志入口翻转当前角色的行动日志显隐
  场景大纲: action_log_toggle_001 触发行动日志入口翻转当前角色的行动日志显隐
    假如 游戏已初始化标准棋盘
    并且 玩家角色ID为1
    并且 该玩家的行动日志当前<初始状态>
    当 该玩家触发切换行动日志
    那么 该玩家的行动日志变为<结果状态>

  例子:
    | 初始状态 | 结果状态 |
    | 隐藏     | 显示     |
    | 显示     | 隐藏     |
