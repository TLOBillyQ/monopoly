# language: zh-CN
# mutation-stamp: sha256=185f390ecef771b73a2117925fa21c799a00e16fc1135bf60a220a5863dc5456
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "52dc083a506bab756711dea32f42176c36b7f433da5498f702949a19f42b722b",
#   "feature_name": "开局初始化",
#   "feature_path": "features/game/setup.feature",
#   "implementation_hash": "sha256:8ac6a9de513a4636a907ca858bf495f72a3a914251fcc1079dd16d35ce9de07b",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 6,
#       "name": "有效玩家人数为2到4人",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "48859e72bac09bc1b0626dd176e8992993c95f14cefd434ebea679940a857836",
#       "tested_at": "2026-05-28T14:56:05Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "单人开局自动补足3个电脑角色",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "231f2eb6e0b3d97cde19541e8fa4e3cbcce0e10650c54d661e9377fb47c04e90",
#       "tested_at": "2026-05-28T14:56:05Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 2,
#       "name": "角色开局状态一致",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "3c9de4730205b31d9143a4541df91acfb001c35a955958a1ef2fa598fea5abb2",
#       "tested_at": "2026-05-28T14:56:05Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 2,
#       "name": "少于1名或多于4名报名玩家时拒绝开局",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "473e8db64e607fbfa085df3e5b8b9a519ea2c9318cecfe2c2dfc59dcd81a87b8",
#       "tested_at": "2026-05-28T14:56:05Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:56:05Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 开局初始化

背景:
  假如 游戏配置为标准大富翁模式

场景大纲: 报名真人不足时补足电脑角色到4人
  假如 本局报名真人玩家数为<报名人数>
  当 游戏初始化
  那么 本局行动角色数为4
  并且 其中电脑角色数为<电脑数>
  并且 游戏允许开始

例子:
  | 报名人数 | 电脑数 |
  | 0        | 4      |
  | 1        | 3      |
  | 2        | 2      |
  | 3        | 1      |
  | 4        | 0      |

场景: 报名真人超过4人时截断为4个行动角色
  假如 本局报名真人玩家数为5
  当 游戏初始化
  那么 本局行动角色数为4
  并且 游戏允许开始

场景: 全部4个开局角色状态一致
  当 游戏初始化为标准四人局
  那么 每名角色出生在起点
  并且 每名角色初始金币为100000
  并且 每名角色初始地块数为0
  并且 每名角色初始道具数为0
  并且 每名角色道具卡槽上限为5
