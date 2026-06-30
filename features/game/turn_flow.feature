# language: zh-CN
# mutation-stamp: sha256=72d2d0936ca9f8c732342401bdf928fd5654e1c7e068655a8783597a55717ea2
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "回合流程",
#   "feature_path": "features/game/turn_flow.feature",
#   "implementation_hash": "sha256:c5fa14fef9fe19aa0b5591375687a38100265d1242f9d3aef2ac6d961237969a",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 12,
#       "name": "玩家按顺序轮流行动",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "be7ae6eaa37352b7b02cbfe6b5fc3e10012f40116aa980b767f0e0c52c2727f2",
#       "tested_at": "2026-05-30T04:03:30Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "已淘汰玩家的回合被跳过",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "6064d9a88abfb157749abf4a9711aa984c1eff21f9a187ff8976f6dbdc37dfe1",
#       "tested_at": "2026-05-30T04:03:30Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 4,
#       "name": "被扣留玩家无法行动且剩余回合递减",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "1629dc0f6f048ceb491b354de380beb72539f512719e2b5c53648855406eba98",
#       "tested_at": "2026-05-30T04:03:30Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "扣留结束后恢复正常行动",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c9f2603d21e3fe91b408e09d364ef9bd2c2c0a943ecb09ce74a8f2ddcde89fbf",
#       "tested_at": "2026-05-30T04:03:30Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "回合结束时清除临时状态",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "396db964f3d22bed0618e5a36cba028727abd8e6473e25291b01ff1ef0e20fb3",
#       "tested_at": "2026-05-30T04:03:30Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 1,
#       "name": "标准回合阶段按序执行",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "225a248734bbc294e5372424749f6d768aeda096cf3bde254223c086192ced6e",
#       "tested_at": "2026-05-30T04:03:31Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "黑市售罄时落地自动跳过选择",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "fa855972ec9522991f36c5a02614f39a479b79a3cb2f7d1e03d734182976ae40",
#       "tested_at": "2026-05-30T04:03:31Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "落在对手地块且持有免租卡时自动消耗",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "26a5322aed8253e3efe83dab80c4c39174087b775f8a9289afdc5fd626c77230",
#       "tested_at": "2026-05-30T04:03:31Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "落在对手地块持有强夺卡和免租卡时优先提示强夺",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "ea68240485ca4a264492a3e59bcf68d4da5db674703e8440cc387211c4d63f7e",
#       "tested_at": "2026-05-30T04:03:31Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 15,
#       "name": "选择超时后系统自动决定",
#       "result": {
#         "Errors": 0,
#         "Killed": 15,
#         "Survived": 0,
#         "Total": 15
#       },
#       "scenario_hash": "cf96e6f8faa83b9142aea2f155cc5863a771d4bb2b79bdf11fc8cb5ce1ae9dc2",
#       "tested_at": "2026-05-30T14:36:16Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 0,
#       "name": "回合间有短暂等待间隔",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e9123fd1dbb7c7f37b3ebf8bf4e286e6ce8890a1d078cc813d9afae2951438be",
#       "tested_at": "2026-05-30T04:03:32Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 0,
#       "name": "路障停留不影响下一回合行动",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "542062b16b738f13fd2d52cf925e22597eb568445b9229add3c3d1e410e57aeb",
#       "tested_at": "2026-05-30T04:03:32Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 0,
#       "name": "选择超时温和跳过不扣玩家金币",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "b1c61aa2943f7aa863653367153e3d8255c865f0810364dd479f36ef797f2d48",
#       "tested_at": "2026-05-30T04:03:32Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 0,
#       "name": "道具目标选择超时后退还预消耗道具",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e76020aadcd4b26ad6adecd3dcbcc39b6c0fb97a02521bf60234bf32106f0bad",
#       "tested_at": "2026-05-30T04:03:32Z"
#     },
#     {
#       "index": 14,
#       "mutation_count": 12,
#       "name": "超时倒计时分阶段发出警告",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "58f643533999d88dcc062719852c1ee6a14f41d40e7c7177baafff7c861e019c",
#       "tested_at": "2026-05-30T14:36:19Z"
#     },
#     {
#       "index": 15,
#       "mutation_count": 0,
#       "name": "超时自动结算后关闭选择弹窗",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "3f6c313d1ad258e9590cad9534af7c9581159a10359c2ffb4dc8cb2284282fcc",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 16,
#       "mutation_count": 0,
#       "name": "黑市浏览期间行动计时器不暂停",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "455b079f19fa4a3a1ad9ddf9bd10a4873dc04269a62add637241a0e4f3d6cd84",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 17,
#       "mutation_count": 0,
#       "name": "阻断性提示显示完毕前回合不切换",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4e3451312f5dc8883df43c504ee06a3d20f21bf6d17c7a050f41d51b5cc5cf06",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 18,
#       "mutation_count": 0,
#       "name": "电脑玩家自动购买可负担的无主地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "5772aca4ba0717bf8989143985b581cb5678ab6614a2ab72045cf49f2e0eb8e5",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 19,
#       "mutation_count": 0,
#       "name": "电脑玩家自动升级可负担的自有地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9efac923904d144bd58b9bda1699542f1aecc76c181081ee2ef47e15a148e8ef",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 20,
#       "mutation_count": 0,
#       "name": "电脑玩家落在对手地块时自动使用免租卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "36c93172ddef0126f336563904252b8bd7ce23203b002b2a8689afa5bd1cec57",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 21,
#       "mutation_count": 0,
#       "name": "电脑玩家按优先级主动使用背包中的主动道具",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "54684e40d480fb9c451d3ae780b323d6a3ea13f7213d47c4b5eead3cadeea867",
#       "tested_at": "2026-05-30T04:03:33Z"
#     },
#     {
#       "index": 22,
#       "mutation_count": 26,
#       "name": "电脑玩家主动道具优先级",
#       "result": {
#         "Errors": 0,
#         "Killed": 26,
#         "Survived": 0,
#         "Total": 26
#       },
#       "scenario_hash": "2b8fd15344e059a06a90e4fbe8fe8821a662be2cf171df05e02511962c8c7349",
#       "tested_at": "2026-05-30T04:03:34Z"
#     }
#   ],
#   "tested_at": "2026-05-30T14:36:19Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 回合流程

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 玩家按顺序轮流行动
  假如 游戏有<玩家人数>名玩家参与
  并且 游戏当前玩家数为<验证玩家人数>名
  并且 当前是玩家<当前玩家>的回合
  当 回合结束
  那么 下一回合轮到玩家<下一玩家>

例子:
  | 玩家人数 | 验证玩家人数 | 当前玩家 | 下一玩家 |
  | 4        | 4            | 1        | 2        |
  | 4        | 4            | 4        | 1        |
  | 2        | 2            | 1        | 2        |

场景: 已淘汰玩家的回合被跳过
  假如 四人human局中玩家2已被淘汰
  并且 当前是玩家1的回合
  当 玩家1的回合结束
  那么 跳过玩家2直接轮到玩家3

场景大纲: 被扣留玩家无法行动且剩余回合递减
  假如 玩家需停留<剩余回合>回合
  当 该玩家的回合开始
  那么 玩家无法掷骰和移动
  并且 剩余停留回合变为<减后回合>
  并且 回合直接结束

例子:
  | 剩余回合 | 减后回合 |
  | 3        | 2        |
  | 1        | 0        |

场景: 扣留结束后恢复正常行动
  假如 玩家剩余停留回合为1
  当 该玩家的扣留回合结束
  并且 下一次轮到该玩家
  那么 玩家可以正常掷骰

场景大纲: 扣留提示按含当前回合口径显示剩余回合
  假如 玩家落在医院被扣留
  当 进入第<扣留回合序号>个扣留回合
  那么 扣留提示显示剩余回合为<显示剩余回合>

例子:
  | 扣留回合序号 | 显示剩余回合 |
  | 1            | 2            |
  | 2            | 1            |

场景: 回合结束时清除临时状态
  假如 玩家本回合使用了遥控骰子
  并且 玩家本回合触发了骰子加倍卡
  当 玩家的回合结束
  那么 遥控骰子效果被清除
  并且 骰子加倍倍率重置为1

场景大纲: 标准回合阶段按序执行
  假如 玩家未被扣留且未被淘汰
  当 玩家的回合开始
  那么 依次经过阶段<阶段序列>

例子:
  | 阶段序列 |
  | 开始 → 等待行动 → 掷骰 → 移动 → 落地 → 结束 |

场景: 黑市售罄时落地自动跳过选择
  假如 玩家落在黑市格
  并且 黑市所有商品已售罄
  当 回合落地结算执行
  那么 不弹出购买选择
  并且 回合直接进入结束阶段

场景: 落在对手地块且持有免租卡时自动消耗
  假如 玩家本回合落在对手拥有的地块
  并且 玩家持有免租卡
  当 回合落地结算执行
  那么 免租卡被自动消耗
  并且 不需要玩家手动选择
  并且 玩家不支付租金

场景: 落在对手地块持有强夺卡和免租卡时优先提示强夺
  假如 玩家本回合落在对手拥有的地块
  并且 玩家同时持有强夺卡和免租卡
  当 回合落地结算执行
  那么 先弹出强夺卡使用提示
  并且 若玩家拒绝强夺则自动消耗免租卡
  并且 玩家不支付租金

场景大纲: 选择超时后系统自动决定
  假如 玩家面临<选择类型>选择
  并且 当前选择类型为<验证选择类型>
  并且 超时时间为<超时秒数>秒
  并且 选择超时配置为<验证超时秒数>秒
  当 玩家在超时时间内未操作
  那么 系统在剩余<警告秒数>秒时发出警告
  并且 超时后自动执行默认选项

例子:
  | 选择类型     | 验证选择类型 | 超时秒数 | 验证超时秒数 | 警告秒数 |
  | 普通选择     | 普通选择     | 15       | 15           | 5        |
  | 黑市购买     | 黑市购买     | 60       | 60           | 5        |
  | 道具目标选择 | 道具目标选择 | 15       | 15           | 5        |

场景: 回合间有短暂等待间隔
  假如 回合间等待时间已配置
  当 当前玩家的回合结束
  那么 经过等待间隔后下一玩家回合才开始

场景: 路障停留不影响下一回合行动
  假如 玩家本回合因路障停止移动
  当 下一回合轮到该玩家
  那么 玩家可以正常掷骰和移动
  并且 不会被额外扣留

场景: 选择超时温和跳过不扣玩家金币
  假如 玩家面临黑市购买选择
  并且 玩家当前金币为5000
  当 超时未操作系统自动跳过
  那么 玩家金币仍为5000

场景: 道具目标选择超时后道具未被消耗仍留存背包
  假如 玩家持有一张需指定目标的道具
  并且 玩家已发起使用但尚未选定目标
  当 目标选择超时系统自动取消
  那么 该道具未被消耗仍在玩家背包

场景大纲: 超时倒计时分阶段发出警告
  假如 玩家面临选择且超时时间为<超时秒数>秒
  并且 选择超时配置为<验证超时秒数>秒
  当 剩余时间降至<警告阈值>秒
  那么 倒计时状态变为<警告级别>
  并且 每个警告级别仅触发一次

例子:
  | 超时秒数 | 验证超时秒数 | 警告阈值 | 警告级别 |
  | 15       | 15           | 5        | 警告     |
  | 15       | 15           | 3        | 紧急     |
  | 15       | 15           | 0        | 到期     |

场景: 超时自动结算后关闭选择弹窗
  假如 玩家面临选择且弹窗已打开
  当 选择超时系统自动决定
  那么 选择弹窗被关闭
  并且 待处理选择指示被清除

场景: 黑市浏览期间行动计时器不暂停
  假如 玩家路过黑市且黑市窗口打开
  当 行动计时器运行中
  那么 计时器继续倒计时不暂停

场景: 阻断性提示显示完毕前回合不切换
  假如 当前玩家的回合已结束
  并且 正在显示阻断性游戏提示
  当 回合间等待时间到期
  那么 等待提示显示完毕后才切换到下一玩家回合

场景: 电脑玩家自动购买可负担的无主地块
  假如 本回合行动玩家是电脑
  并且 电脑玩家持有充足金币
  当 电脑玩家落在无主地块
  那么 系统自动执行购买

场景: 电脑玩家自动升级可负担的自有地块
  假如 本回合行动玩家是电脑
  并且 电脑玩家持有充足金币
  当 电脑玩家落在自有可升级地块
  那么 系统自动执行升级

场景: 电脑玩家落在对手地块时自动使用免租卡
  假如 本回合行动玩家是电脑
  并且 电脑玩家持有免租卡
  当 电脑玩家落在需付租金的对手地块
  那么 系统自动消耗免租卡

场景: 电脑玩家在道具使用阶段消耗满足触发条件的主动道具
  假如 本回合行动玩家是电脑
  并且 电脑玩家背包中持有满足触发条件的主动道具
  当 电脑玩家的道具使用阶段执行
  那么 该道具被自动消耗

场景大纲: 电脑玩家在触发条件满足时消耗对应主动道具
  假如 本回合行动玩家是电脑
  并且 电脑玩家背包中持有<道具>
  并且 棋盘状态满足<触发条件>
  当 电脑玩家的道具使用阶段执行
  那么 该<道具>被消耗

例子:
  | 道具       | 触发条件                         |
  | 遥控骰子卡 | 移动范围内存在道具格             |
  | 路障卡     | 前方存在道具格                   |
  | 偷窃卡     | 存在持有道具的其他玩家           |
  | 怪兽卡     | 前后3格内存在他人等级最高的建筑  |
  | 均富卡     | 电脑玩家不是现金最多的角色       |
  | 流放卡     | 存在其他现金最多的角色           |
  | 导弹卡     | 前后3格内存在他人等级最高的建筑  |
  | 查税卡     | 存在其他现金最多的角色           |
  | 请神卡     | 其他角色附有天使                 |
  | 请神卡     | 其他角色附有财神且无人附有天使   |
  | 送神卡     | 电脑玩家附有穷神且存在现金最多对手 |
  | 穷神卡     | 存在其他现金最多的角色           |
  | 其他卡     | 道具当前可用                     |
