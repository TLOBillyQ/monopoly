# language: zh-CN
# mutation-stamp: sha256=6e42dcd4764bcfa973b14f1fbde0d6bb7690b4f94255d3508c68ed8624999bae
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "付费货币购买",
#   "feature_path": "features/game/paid_currency.feature",
#   "implementation_hash": "sha256:640c742c794029b44a5cb8d1e4c5f77e589d6321c29bbcb0901ae32ba0490bb8",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 0,
#       "name": "付费道具购买通过宿主支付面板发起",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "2d28700bb0a1a135badbc595446d2e59570e301950af3c72dff1e8628516dc7e",
#       "tested_at": "2026-05-28T14:55:39Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "支付回调到达后道具入库并消耗全局限额",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "09eec3930fed4ec628be953a63e0cf45c0fdcdbe193395c4cbc7c2062bbdd911",
#       "tested_at": "2026-05-28T14:55:39Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "缺少商品映射时付费购买被拒绝",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c086ac8beda78ad380b46a4282fb443c3fd5789b3ee57c93c18fb87fc2a50f44",
#       "tested_at": "2026-05-28T14:55:39Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "同一商品缺少映射的警告仅记录一次",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "ad595c534d79c558cc440826c1ddad92428584130898c2986993f43df99ae84a",
#       "tested_at": "2026-05-28T14:55:39Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "付费购买进行中时重复请求被阻断",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e2d0b8ae00893ea914bcfdc9502b4a3665eb07649287c86982f7223d94a28990",
#       "tested_at": "2026-05-28T14:55:39Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "购买超时后恢复购买能力",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9e838dd628c685cab888181a3390de1423bbd2e94f24bd169ce47eac2658e22c",
#       "tested_at": "2026-05-28T14:55:39Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "同一商品在回调后可连续多次购买",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "fe5b824eab5569c624e08cae4062958ae7ba8c3657bb9911c5a01c5e38df5eac",
#       "tested_at": "2026-05-28T14:55:39Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:55:39Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 付费货币购买

背景:
  假如 游戏已初始化标准棋盘

场景: 付费道具购买通过宿主支付面板发起
  假如 黑市中存在付费货币商品
  当 玩家选择购买该付费道具
  那么 宿主支付面板被打开一次
  并且 黑市选择窗口保持开放等待支付回调

场景: 支付回调到达后道具入库并消耗全局限额
  假如 玩家已发起付费道具购买
  当 宿主支付回调成功到达
  那么 道具被加入玩家背包
  并且 该商品全局库存减少1

场景: 缺少商品映射时付费购买被拒绝
  假如 付费道具在宿主商品列表中没有对应映射
  当 玩家尝试购买该付费道具
  那么 购买被拒绝
  并且 支付面板不被打开
  并且 系统记录缺少映射的警告

场景: 同一商品缺少映射的警告仅记录一次
  假如 付费道具在宿主商品列表中没有对应映射
  当 玩家连续两次尝试购买该付费道具
  那么 缺少映射的警告仅被记录一次

场景: 付费购买进行中时重复请求被阻断
  假如 玩家已发起付费道具购买且回调尚未到达
  当 玩家再次尝试购买同一付费道具
  那么 第二次请求被拒绝
  并且 支付面板不被再次打开

场景: 购买超时后恢复购买能力
  假如 玩家已发起付费道具购买且回调尚未到达
  并且 购买请求已超时
  当 玩家再次尝试购买该付费道具
  那么 购买请求被正常发起
  并且 支付面板被打开

场景: 同一商品在回调后可连续多次购买
  假如 黑市中存在付费货币商品且库存充足
  当 玩家完成第一次付费购买并收到回调
  并且 玩家发起第二次相同商品的付费购买并收到回调
  那么 玩家背包中收到两件该道具
  并且 该商品全局库存减少2
