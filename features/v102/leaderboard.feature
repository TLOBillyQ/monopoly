# language: zh-CN
# mutation-stamp: sha256=69436afd1bb39a71d7d68ee9451ec0f6023089a9bb5d93191539377dceff5c88
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "排行榜数据累计",
#   "feature_path": "features/v102/leaderboard.feature",
#   "implementation_hash": "sha256:a2367d59bc322a82b88cf22295f6bd247544fe512b20ea37e8dea16e2da4980a",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 9,
#       "name": "获胜玩家的胜利次数累加一次",
#       "result": {
#         "Errors": 0,
#         "Killed": 9,
#         "Survived": 0,
#         "Total": 9
#       },
#       "scenario_hash": "f37527f12b99c6c50067dbb81f3faccb1339acb90d0d088b4b5a8ec2f6b7522a",
#       "tested_at": "2026-05-29T15:03:40Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 6,
#       "name": "在场玩家的剩余总资产累计入富豪榜",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "8dd525e9ad4554f458f716f7115dae094eb900f4a24c169c71ba3191f7743dd8",
#       "tested_at": "2026-05-29T15:03:41Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 4,
#       "name": "中途退出的玩家剩余资产不计入富豪榜",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "ec65b31d8d2eab120cfc5be9b080f076168c562f00f1f7e392c4d0458ecf1549",
#       "tested_at": "2026-05-29T15:03:42Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "并列获胜时每名获胜者的胜利次数各加一",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9950ded6934251a5317fc00db964aea7df8531491a8ef8fecadb716b6c5f2989",
#       "tested_at": "2026-05-29T15:03:42Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "重复结算不重复累计",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "3d459f726f3ff3beb8b01739b9c775ed1ed7b4a7b358f42736a3793aead6e199",
#       "tested_at": "2026-05-29T15:03:42Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "未开启自定义存档时跳过排行榜结算",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c16eb5d38715eab15f8a35dd53d88464a67c59349f4658ffa7f7b7b2bbd301e5",
#       "tested_at": "2026-05-29T15:03:42Z"
#     }
#   ],
#   "tested_at": "2026-05-29T15:03:42Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end
功能: 排行榜数据累计

# 排行榜由宿主榜单控件从自定义玩家存档读取并排序展示：
# 胜利次数（存档 1001，整数）驱动胜利榜，剩余总资产（存档 1002，整数）驱动富豪榜。
# 本规格只描述每局游戏结束时这两个存档值的累计行为，不描述宿主榜单的渲染与排序。

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 获胜玩家的胜利次数累加一次
  假如 玩家本局之前的胜利次数为<之前胜利次数>
  并且 玩家本局<胜负结果>
  当 排行榜结算执行
  那么 玩家本局之后的胜利次数为<之后胜利次数>

例子:
  | 之前胜利次数 | 胜负结果 | 之后胜利次数 |
  | 0            | 获胜     | 1            |
  | 3            | 获胜     | 4            |
  | 3            | 未获胜   | 3            |

场景大纲: 在场玩家的剩余总资产累计入富豪榜
  假如 玩家本局之前的累计资产为<之前累计资产>
  并且 玩家本局结束时仍在场
  并且 玩家本局结束时的剩余总资产为<本局剩余资产>
  当 排行榜结算执行
  那么 玩家本局之后的累计资产为<之后累计资产>

例子:
  | 之前累计资产 | 本局剩余资产 | 之后累计资产 |
  | 0            | 50000        | 50000        |
  | 50000        | 30000        | 80000        |

场景大纲: 中途退出的玩家剩余资产不计入富豪榜
  假如 玩家本局之前的累计资产为<之前累计资产>
  并且 玩家本局中途退出且退出时仍持有可观剩余资产
  当 排行榜结算执行
  那么 玩家本局之后的累计资产为<之后累计资产>

例子:
  | 之前累计资产 | 之后累计资产 |
  | 50000        | 50000        |
  | 0            | 0            |

场景: 并列获胜时每名获胜者的胜利次数各加一
  假如 本局两名玩家并列获胜
  并且 每名获胜者本局之前的胜利次数为 2
  当 排行榜结算执行
  那么 每名获胜者本局之后的胜利次数为 3

场景: 重复结算不重复累计
  假如 玩家本局已完成排行榜结算
  当 排行榜结算再次执行
  那么 玩家的胜利次数不再增加
  并且 玩家的累计资产不再增加

场景: 未开启自定义存档时跳过排行榜结算
  假如 宿主未开启自定义存档
  当 排行榜结算执行
  那么 不写入任何排行榜存档
