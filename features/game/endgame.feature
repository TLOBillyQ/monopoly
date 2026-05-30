# language: zh-CN
# mutation-stamp: sha256=85b3e0f5ef7259bd47397ec4a62b54d7423096bc40285f678e2411888a859181
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "终局与淘汰",
#   "feature_path": "features/game/endgame.feature",
#   "implementation_hash": "sha256:e1f90063238b206ffc515ca5b5d13d6542c9a31d37b78d9edc0ca4a31ced0182",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 4,
#       "name": "仅剩一名玩家时该玩家获胜",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "e84576bd67fbeaa0691bb914affc17a3dfb10b498c2a458c4de26fb8cd8362dc",
#       "tested_at": "2026-05-28T14:55:30Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 10,
#       "name": "游戏时间结束时资产最高者获胜",
#       "result": {
#         "Errors": 0,
#         "Killed": 10,
#         "Survived": 0,
#         "Total": 10
#       },
#       "scenario_hash": "353519394ff50ea4b6cbddaa83d56e5dc8dca646eb6e465f2366a3b772b0356e",
#       "tested_at": "2026-05-28T14:55:31Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "游戏时间结束时资产相同则并列获胜",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "645c001e2ca6e1115eff1328fac34aa72834312f7dbff5e95017fe8042dca6be",
#       "tested_at": "2026-05-28T14:55:31Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 6,
#       "name": "总资产等于现金加地块总投入",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "66314b3acf1bff128b27714d79d6b3d4756972492bc78e316212422a580735b1",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "破产淘汰清空地块所有权",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "b4da4ae7431d64b1e658cd7ca2cb7fa1536b4deeb7c51a031dd9b150d1140d6a",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "破产淘汰清空背包和神灵",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9adcbde664223685ae271b202bd3f615b3e583609bf6c3bde2785d72c88e98e4",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "已淘汰玩家从所有格子占位中移除",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "eacb3611085c56f5a4edd3a6684c057bbe7983f5ff39daa866662e19d525b646",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "游戏结束后不再检查胜利条件",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "353727fb6fdc31e51d763aa8358f7d890524a878cfd1804ab64be4882e1c9db7",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 4,
#       "name": "落在医院或深山触发停留",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "603397e9fc5546a54e95711cb629c6d18b0180eddcfd6ba5a204f8c6834a0c40",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 0,
#       "name": "落在医院时先支付5000金币医药费",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "5f2fc2cd24142928860559e7d6de23b0ff96e98ab6706f96a0ff5ac03898e947",
#       "tested_at": "2026-05-28T14:55:32Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 2,
#       "name": "天使守护不免疫医院和深山停留",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "7889766445bbc2e22190100dfd3ab1fd1c286da44a4124409def752589ee24c0",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 0,
#       "name": "游戏时间结束时所有玩家均已淘汰则无人获胜",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "8da36d381973dc7fc954a0bbd6bb2d6053d3d3d91438f2ba04db80551cfddfbd",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 0,
#       "name": "获胜玩家看到胜利结算面板",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "7217c56041e115aed68f96ef4bcc01ff1130b4ca60073e5b66f1378e3b9de3ff",
#       "tested_at": "2026-05-28T14:55:33Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 0,
#       "name": "落败玩家看到失败结算面板",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e1c76f9c3ce9ee8bf552865cd0a1517ff3be05f5027b3c55c0550652b862d2e6",
#       "tested_at": "2026-05-28T14:55:33Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:55:33Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 终局与淘汰

背景:
  假如 游戏已初始化标准棋盘

场景大纲: 仅剩一名玩家时该玩家获胜
  假如 游戏有<玩家人数>名玩家
  并且 <淘汰人数>名玩家已被淘汰
  当 胜利条件检查执行
  那么 唯一存活玩家获胜
  并且 游戏标记为已结束

例子:
  | 玩家人数 | 淘汰人数 |
  | 4        | 3        |
  | 2        | 1        |

场景大纲: 游戏时间结束时资产最高者获胜
  假如 游戏时间上限为<时间上限>秒
  并且 当前游戏时间已达到<时间上限>秒
  并且 游戏时间上限记录为<验证时间上限>秒
  并且 存活玩家的总资产分别为<资产列表>
  并且 存活玩家资产逐一为<验证资产列表>
  当 胜利条件检查执行
  那么 资产最高的玩家获胜
  并且 获胜者资产为<验证最高资产>
  并且 游戏标记为已结束

例子:
  | 时间上限 | 验证时间上限 | 资产列表          | 验证资产列表      | 验证最高资产 |
  | 900      | 900          | 50000,30000,20000 | 50000,30000,20000 | 50000        |
  | 900      | 900          | 80000,40000       | 80000,40000       | 80000        |

场景: 游戏时间结束时资产相同则并列获胜
  假如 游戏时间已结束
  并且 两名玩家总资产相同且为最高
  当 胜利条件检查执行
  那么 两名玩家并列获胜

场景大纲: 总资产等于现金加地块总投入
  假如 玩家持有<现金>金币
  并且 玩家拥有地块总投入为<地块投入>
  当 计算总资产
  那么 总资产为<总资产>

例子:
  | 现金  | 地块投入 | 总资产 |
  | 10000 | 5000     | 15000  |
  | 0     | 20000    | 20000  |

场景: 破产淘汰清空地块所有权
  假如 玩家拥有3块地块
  当 执行破产淘汰清算
  那么 玩家的所有地块重置为无主
  并且 地块等级重置为0

场景: 破产淘汰清空背包和神灵
  假如 玩家持有道具且附有神灵
  当 执行破产淘汰清算
  那么 玩家的背包被清空
  并且 玩家的神灵被移除

场景: 已淘汰玩家从所有格子占位中移除
  假如 玩家位于格子5
  当 执行破产淘汰清算
  那么 格子5的占位列表不再包含该玩家

场景: 游戏结束后不再检查胜利条件
  假如 游戏已标记为结束
  当 再次检查胜利条件
  那么 直接返回已结束状态
  并且 不重复判定胜者

场景大纲: 落在医院或深山触发停留
  假如 玩家落在<格子类型>
  当 落地效果执行
  那么 玩家被扣留<停留回合>回合

例子:
  | 格子类型 | 停留回合 |
  | 医院     | 2        |
  | 深山     | 2        |

场景: 落在医院时先支付5000金币医药费
  假如 玩家持有10000金币
  当 玩家落在医院格
  那么 玩家支付5000金币医药费
  并且 玩家需停留2回合

场景大纲: 天使守护不免疫医院和深山停留
  假如 玩家拥有天使守护
  并且 玩家落在<格子类型>
  当 落地效果执行
  那么 玩家被扣留2回合

例子:
  | 格子类型 |
  | 医院     |
  | 深山     |

场景: 游戏时间结束时所有玩家均已淘汰则无人获胜
  假如 游戏时间已结束
  并且 所有玩家均已被淘汰
  当 胜利条件检查执行
  那么 获胜者列表为空
  并且 游戏标记为已结束

场景: 获胜玩家看到胜利结算面板
  假如 游戏已结束
  并且 玩家是获胜者
  当 结算画面显示
  那么 玩家进入胜利结算面板

场景: 落败玩家看到失败结算面板
  假如 游戏已结束
  并且 玩家不是获胜者
  当 结算画面显示
  那么 玩家进入失败结算面板
