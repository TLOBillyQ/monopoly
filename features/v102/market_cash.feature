# language: zh-CN
# mutation-stamp: sha256=9e007a5c599104cbb04392ac8a1e6c4742565b041a07bcd2e2e92f069b0b89ce
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "黑市现金显示",
#   "feature_path": "features/v102/market_cash.feature",
#   "implementation_hash": "sha256:810836eec8f825767ad17daa0bd3ce94aba3a0ae0dc7a759c05fab16b35e30dd",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 12,
#       "name": "黑市开启时显示操作玩家当前现金",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "df2d6fa37b54c45f30af73110a251cecb670af5e34a2e98e95392a3bd6e5dde9",
#       "tested_at": "2026-05-27T15:21:31Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 4,
#       "name": "现金不足时黑市仍可开启",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "1181c21e98f97be07957853dc7f1e397bb1821a1336b4fd3b46b96c902f4e27c",
#       "tested_at": "2026-05-27T15:21:32Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 4,
#       "name": "购买道具后黑市现金同步更新",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "d5af60fea2157d2482deabf1f43780713c17d62b50c823a1a06c0ccf146b6ed7",
#       "tested_at": "2026-05-27T15:21:32Z"
#     }
#   ],
#   "tested_at": "2026-05-27T15:21:32Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 黑市现金显示

  背景:
    假如 游戏已初始化标准棋盘

  场景大纲: 黑市开启时显示操作玩家当前现金
    假如 玩家角色ID为<角色ID>
    并且 当前角色ID为<验证角色ID>
    并且 玩家当前现金为<设置金额>
    当 黑市向玩家开放
    那么 黑市现金显示区显示金额<显示金额>

  例子:
    | 角色ID | 验证角色ID | 设置金额 | 显示金额 |
    | 1      | 1          | 1000     | 1000     |
    | 1      | 1          | 500      | 500      |
    | 2      | 2          | 3000     | 3000     |

  场景大纲: 现金不足时黑市仍可开启
    假如 玩家角色ID为<角色ID>
    并且 当前角色ID为<验证角色ID>
    并且 玩家当前现金为<设置金额>
    当 黑市向玩家开放
    那么 黑市现金显示区显示金额<显示金额>

  例子:
    | 角色ID | 验证角色ID | 设置金额 | 显示金额 |
    | 1      | 1          | 0        | 0        |

  场景大纲: 购买道具后黑市现金同步更新
    假如 玩家当前现金为<设置金额>
    当 玩家在黑市成功购买一个道具
    并且 黑市现金显示区刷新
    那么 黑市现金显示区显示金额<显示金额>

  例子:
    | 设置金额 | 显示金额 |
    | 10000    | 5000     |
    | 20000    | 15000    |
