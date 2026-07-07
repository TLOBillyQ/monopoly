# language: zh-CN
# mutation-stamp: sha256=00030d254adb2f3c188023910a8ece04dfe6962e8ab9340f5250fe3dd109c1a9
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "分享任务宿主管理奖励",
#   "feature_path": "features/v102/share_task.feature",
#   "implementation_hash": "sha256:5920db00644a179e07fb40066d6dbb6ab5e172d28080e28a7e18ab3073d7e423",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 30,
#       "name": "share_task-001 分享任务配置由宿主按进度发放对应货币",
#       "result": {
#         "Errors": 0,
#         "Killed": 30,
#         "Survived": 0,
#         "Total": 30
#       },
#       "scenario_hash": "48f6d17742a1e2fb373d8ba94f111adb13a4b9d6e66055f62222cd536ad8d30d",
#       "tested_at": "2026-07-07T03:00:00Z"
#     }
#   ],
#   "tested_at": "2026-07-07T03:00:00Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end
功能: 分享任务宿主管理奖励

# 编辑器「任务配置」由宿主负责统计分享次数、邀请进入人数与货币发放。
# 本规格描述仓库必须镜像并保护的任务配置，不描述 Lua 侧重复统计或发奖。

背景:
  假如 游戏已初始化标准棋盘

# share_task-001
场景大纲: share_task-001 分享任务配置由宿主按进度发放对应货币
  假如 宿主已配置<任务周期>分享任务<任务名称>
  并且 任务按<进度来源>累计进度
  当 任务进度达到<目标进度>
  那么 宿主任务奖励货币数量为<奖励货币>
  并且 Lua侧不额外发放分享任务货币

例子:
  | 任务周期 | 任务名称 | 进度来源           | 目标进度 | 奖励货币 |
  | 每日     | 每日分享 | 分享次数           | 1        | 1000     |
  | 永久     | 邀请1人  | 首次进入地图的人数 | 1        | 1800     |
  | 永久     | 邀请3人  | 首次进入地图的人数 | 3        | 6800     |
  | 永久     | 邀请5人  | 首次进入地图的人数 | 5        | 12800    |
  | 永久     | 邀请10人 | 首次进入地图的人数 | 10       | 36800    |
  | 永久     | 邀请20人 | 首次进入地图的人数 | 20       | 99800    |
