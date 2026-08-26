# language: zh-CN
# mutation-stamp: sha256=48186179076c09398b2e331421e056021da5b216f8ba54de016615c42214f368
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "签到奖励发放",
#   "feature_path": "features/v102/sign_in.feature",
#   "implementation_hash": "sha256:24630924c9dedf6c3c29c6714929ff3a016ece2f2037c21292af248ee6deb701",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 21,
#       "name": "领取每日签到奖励发放对应金币",
#       "result": {
#         "Errors": 0,
#         "Killed": 21,
#         "Survived": 0,
#         "Total": 21
#       },
#       "scenario_hash": "d82207e6833ea59b68cebd1007d22eb27f9277bb5508c84a8d3338d0b76bd2c5",
#       "tested_at": "2026-05-29T15:09:31Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "未配置奖励的签到事件不发放金币",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "8c28e5dd17b7529f41338d7784d5a7a707f5c5ad33f50c51b07acf02d43dd1dc",
#       "tested_at": "2026-05-29T15:09:31Z"
#     }
#   ],
#   "tested_at": "2026-05-29T15:09:31Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end
功能: 签到奖励发放

# 宿主签到面板在玩家领取某天奖励时触发自定义事件 RewardDay1..RewardDay7。
# 本规格描述 Lua 侧收到该事件后给领取玩家发放对应金币的行为。
# 「每天首次登录弹窗」与「当天是否可领」的门槛由宿主面板管理，不在本规格范围。

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 领取每日签到奖励发放对应金币
  假如 玩家当前金币为<之前金币>
  当 玩家领取第<签到天数>天签到奖励
  那么 玩家当前金币为<之后金币>

例子:
  | 签到天数 | 之前金币 | 之后金币 |
  | 1        | 0        | 500      |
  | 2        | 0        | 1000     |
  | 3        | 0        | 2000     |
  | 4        | 0        | 4000     |
  | 5        | 0        | 6000     |
  | 6        | 0        | 8000     |
  | 7        | 1000     | 11000    |

场景: 未配置奖励的签到事件不发放金币
  假如 玩家当前金币为 500
  当 触发一个未配置奖励的签到事件
  那么 玩家当前金币保持 500 不变
