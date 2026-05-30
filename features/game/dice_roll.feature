# language: zh-CN
# mutation-stamp: sha256=3c7479b5ec4a0353a118a60ac9fa0e56baa72cf5e95e1f2e23806c37f06ad584
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "骰子投掷",
#   "feature_path": "features/game/dice_roll.feature",
#   "implementation_hash": "sha256:1f35efa23387a09f03bbba022bad9bc087d1c71421f089aa1e0fa23d5474f4ce",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 9,
#       "name": "玩家掷骰子前进",
#       "result": {
#         "Errors": 0,
#         "Killed": 9,
#         "Survived": 0,
#         "Total": 9
#       },
#       "scenario_hash": "0fe39542bedbe0f7c4594342c189fdb35dfe16f8e1fc400a1a82bfd2d6435b6f",
#       "tested_at": "2026-05-28T14:55:37Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 20,
#       "name": "玩家前进超过起点时绕圈",
#       "result": {
#         "Errors": 0,
#         "Killed": 20,
#         "Survived": 0,
#         "Total": 20
#       },
#       "scenario_hash": "d4768fe478720bac681fe23687e54a2ad27eee4cce1dcd3c48eb211df87d0326",
#       "tested_at": "2026-05-28T14:55:39Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:55:39Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 骰子投掷

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 玩家掷骰子前进
  假如 当前玩家位于位置<起始位置>
  当 玩家掷出<步数>
  那么 玩家位于位置<目标位置>

例子:
  | 起始位置 | 步数 | 目标位置 |
  | 0        | 3    | 3        |
  | 5        | 7    | 12       |
  | 13       | 3    | 16       |

场景大纲: 玩家前进超过起点时绕圈
  假如 当前玩家位于位置<起始位置>
  并且 棋盘共有<途经格数>格
  当 玩家掷出<步数>
  那么 玩家位于位置<目标位置>
  但是 玩家经过起点<距离>次

例子:
  | 起始位置 | 途经格数 | 步数 | 目标位置 | 距离 |
  | 27       | 32   | 5    | 0        | 1            |
  | 29       | 32   | 3    | 0        | 1            |
  | 25       | 32   | 9    | 2        | 1            |
  | 0        | 32   | 3    | 3        | 0            |
