# language: zh-CN
# mutation-stamp: sha256=f0a88f8dc3884229d6076afcfb676b2ef5db778172ac1f20572119c46152ef68
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "破产判定",
#   "feature_path": "features/game/bankruptcy.feature",
#   "implementation_hash": "sha256:dc77d575570a195aca0a05a4e6d230afb1838a53409ed12b8119c40f9e47080d",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 15,
#       "name": "支付超过余额时破产",
#       "result": {
#         "Errors": 0,
#         "Killed": 15,
#         "Survived": 0,
#         "Total": 15
#       },
#       "scenario_hash": "a25e4b4a15abf4a8c2d850536b42b3ba9b78daca997339ca2e9038b531dfcb13",
#       "tested_at": "2026-05-28T14:55:34Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "机会卡支付他人效果中途破产则停止后续支付",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "b3680dc40647070cf45cc217c8460fba6c210ffeb8e12c3e176013b3f5c47f81",
#       "tested_at": "2026-05-28T14:55:34Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "机会卡收取他人效果中无力支付者破产",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "abe359a7887893d9ab229a7486343c0ea7fbe22335c8a2d18bf820ad8d1d3a85",
#       "tested_at": "2026-05-28T14:55:34Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "落在医院费用不足触发破产",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "80a297a05755304ee076dd1f5120dcf26ab2e16f18dcdd9fd26b6a8231839df4",
#       "tested_at": "2026-05-28T14:55:34Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:55:34Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 破产判定

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 支付超过余额时破产
  假如 玩家持有<余额>金币
  并且 玩家初始余额为<验证余额>金币
  当 玩家需要支付<金额>
  并且 应支付金额为<验证金额>金币
  那么 玩家<结果>

例子:
  | 余额 | 验证余额 | 金额 | 验证金额 | 结果   |
  | 100  | 100      | 200  | 200      | 破产   |
  | 500  | 500      | 200  | 200      | 存活   |
  | 0    | 0        | 100  | 100      | 破产   |

场景: 机会卡支付他人效果中途破产则停止后续支付
  假如 玩家持有800金币
  并且 抽到的机会卡效果为向每位玩家支付500金币
  并且 游戏中有3名未淘汰对手
  当 机会卡效果结算
  那么 玩家向第一位对手支付500金币后破产
  并且 后续对手不再收到支付

场景: 机会卡收取他人效果中无力支付者破产
  假如 抽到的机会卡效果为向每位玩家收取1000金币
  并且 对手A持有500金币
  当 机会卡效果结算
  那么 对手A支付全部500金币后破产淘汰
  并且 玩家收到对手A的500金币

场景: 落在医院费用不足触发破产
  假如 玩家持有0金币
  当 玩家因效果被送往医院且需支付住院费
  那么 玩家破产淘汰
