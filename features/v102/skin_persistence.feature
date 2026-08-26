# language: zh-CN
# mutation-stamp: sha256=b143267a9a8fba43cb017d98a39dd7dbf16c3cc088ed7eb471d373410417a9cc
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "皮肤购买存档",
#   "feature_path": "features/v102/skin_persistence.feature",
#   "implementation_hash": "sha256:c273772eae260d3552514a3820b5fbea7f5ce3b472e4797466e195c0a8fbb1b6",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 14,
#       "name": "付费购买的皮肤在重新开局后仍归玩家持有",
#       "result": {
#         "Errors": 0,
#         "Killed": 14,
#         "Survived": 0,
#         "Total": 14
#       },
#       "scenario_hash": "7b4c4187621cb8d96ae4b89e8fda870f6eb653a3e6afabc16170e5dc7295d109",
#       "tested_at": "2026-05-31T13:20:47Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 6,
#       "name": "重新开局自动穿上上次装备的皮肤并还原宿主模型",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "3f7976c19ee1b01ed92286195f60003a6c186c863aa7f213215a57fcdea05041",
#       "tested_at": "2026-05-31T13:20:48Z"
#     }
#   ],
#   "tested_at": "2026-05-31T13:20:48Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

# 付费购买的皮肤写入宿主存档，第二次开局读回；记住上次装备并在重载时
# 自动穿上、还原宿主模型。免费/非购买解锁不写存档。

功能: 皮肤购买存档

  背景:
    假如 游戏已初始化标准棋盘

  # ── 购买持有持久化：第二次开局读回 ─────────────────────────

  场景大纲: 付费购买的皮肤在重新开局后仍归玩家持有
    假如 皮肤目录共有<皮肤数>款皮肤
    并且 玩家角色ID为<角色ID>
    并且 玩家打开皮肤商店
    并且 玩家付费购买槽位<槽位>的皮肤
    并且 玩家付费购买槽位<占用槽位>的皮肤
    当 玩家重新开局并打开皮肤商店
    那么 槽位<验证槽位>的皮肤已归玩家持有
    并且 皮肤卡牌槽位<验证槽位>按钮文本为"<按钮文本>"
    并且 皮肤总页数为<总页数>

  例子:
    | 皮肤数 | 角色ID | 槽位 | 验证槽位 | 占用槽位 | 按钮文本 | 总页数 |
    | 6      | 1      | 1    | 1        | 2        | 穿上     | 1      |
    | 6      | 2      | 3    | 3        | 4        | 穿上     | 1      |

  # ── 装备持久化 + 重载自动穿上并还原宿主模型 ────────────────

  场景大纲: 重新开局自动穿上上次装备的皮肤并还原宿主模型
    假如 皮肤目录共有<皮肤数>款皮肤
    并且 玩家角色ID为<角色ID>
    并且 玩家打开皮肤商店
    并且 玩家付费购买槽位<槽位>的皮肤
    并且 换装回调已注册
    当 玩家重新开局并打开皮肤商店
    那么 槽位<槽位>的皮肤已装备成功
    并且 皮肤卡牌槽位<槽位>按钮文本为"<按钮文本>"
    并且 换装回调收到的皮肤产品ID为<产品ID>
    并且 皮肤总页数为<总页数>

  例子:
    | 皮肤数 | 角色ID | 槽位 | 按钮文本 | 产品ID | 总页数 |
    | 6      | 1      | 1    | 脱下     | skin_1 | 1      |
