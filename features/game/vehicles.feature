# language: zh-CN
# mutation-stamp: sha256=d3f5a660d52a7f2fa5f44b2fdab0f12d22a6988f0f9ff784e281cded98b7c898
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "座驾系统",
#   "feature_path": "features/game/vehicles.feature",
#   "implementation_hash": "sha256:482f9d265de57020a18d119010d7d41402aa4bf1cf0b22b828d4a5f70e375151",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 6,
#       "name": "座驾决定行动前可投骰子数量",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "99394ea335ec366b4fa86aeb2c0d10a8aec39cbab9196fa2ef0585f1fdf811b1",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "黑市付费座驾通过宿主支付面板发起购买",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4b25d2f1c498fac2b83089f368cf881de19549187c8f0f3ec0cccee16b7e65f4",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "支付回调成功后玩家装备付费座驾",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "0ef76e8ced255d626e2a90d5f33e0f414339838c2195e547bbc6b70e670756b8",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "地雷摧毁普通座驾并送玩家住院",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "18bbd19fb807ea06c5c3645627710b272c29aa3a56f9f92b7d21a6c1c587941e",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "地雷不能摧毁不可摧毁座驾",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "3f7464e9ac8c99c10f2d1e7a1a5d785633cad297eacce3094d8f0083f9b7ffea",
#       "tested_at": "2026-05-28T14:55:33Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:55:33Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 座驾系统

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 座驾决定行动前可投骰子数量
  假如 玩家装备座驾<座驾名>
  并且 该座驾配置骰子数为<骰子数>
  当 玩家进入行动前阶段
  那么 玩家本次可投骰子数量为<骰子数>

例子:
  | 座驾名   | 骰子数 |
  | 无座驾   | 1      |
  | 普通座驾 | 2      |
  | 强化座驾 | 3      |

场景: 黑市付费座驾通过宿主支付面板发起购买
  假如 黑市中存在付费座驾商品
  当 玩家选择购买该付费座驾
  那么 宿主支付面板被打开一次
  并且 黑市窗口保持开放等待支付回调

场景: 支付回调成功后玩家装备付费座驾
  假如 玩家已发起付费座驾购买
  当 宿主支付回调成功到达
  那么 该座驾归玩家持有
  并且 玩家装备该座驾

场景: 地雷摧毁普通座驾并送玩家住院
  假如 玩家装备可摧毁座驾
  并且 玩家落在已激活地雷格
  当 地雷效果结算
  那么 玩家座驾被摧毁
  并且 玩家被送往医院
  并且 玩家需停留2回合

场景: 地雷不能摧毁不可摧毁座驾
  假如 玩家装备不可摧毁座驾
  并且 玩家落在已激活地雷格
  当 地雷效果结算
  那么 玩家座驾仍然装备中
  并且 玩家不被送往医院
