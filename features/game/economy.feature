# language: zh-CN
# mutation-stamp: sha256=5dfb3654f5da89e34b13cd0e24ed60bce2b2b53bf806ed4a16ce78c2c67f83a5
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "5b037c24216528d6c466d0a0abe521596cd4d2f826832e04aee6f4ffcf1ae241",
#   "feature_name": "经济系统",
#   "feature_path": "features/game/economy.feature",
#   "implementation_hash": "sha256:090a3272b504ed76b59f1d357b236bffa69be56cf22e2af9813d459407792c85",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 8,
#       "name": "购买无主地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "bfd80994986d75570add1c339c6a1b579fdae8853c9c9e60c234795a5c56e267",
#       "tested_at": "2026-06-24T16:00:49Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "余额不足时无法购买地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "12944c011f16b9418eb71434a5fbcaad5448164297dbfccf2e011438320f6e22",
#       "tested_at": "2026-06-24T16:00:49Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 18,
#       "name": "升级自有地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 18,
#         "Survived": 0,
#         "Total": 18
#       },
#       "scenario_hash": "6546f15d2301e54dbfb9ff167e506f616aba0fd8a9b249c0cd69513b2a057b96",
#       "tested_at": "2026-06-24T16:00:53Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "地块已达最高等级时无法升级",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f56c49188ea0fdae10fec8bdf5b0be05418cd8a51fe4441a3b55e5659d8ed75e",
#       "tested_at": "2026-06-24T16:00:53Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 12,
#       "name": "单块地块按地价和加盖次数计算租金",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "964f9adb8cf9120defac31f41e2de187f8c3f4607144304bea62ab1503832cc5",
#       "tested_at": "2026-06-24T16:00:55Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 8,
#       "name": "连片地块租金为各块租金之和",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "7444c9cbb36d6347fbead9e1eedf35f478df5c0ddeb296400b5ce8b9b9eaaf30",
#       "tested_at": "2026-06-24T16:00:57Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 9,
#       "name": "神灵倍增租金",
#       "result": {
#         "Errors": 0,
#         "Killed": 9,
#         "Survived": 0,
#         "Total": 9
#       },
#       "scenario_hash": "db1ea2cec764123fd94eb39379f654da5d215381dbce8c84130b1c9e75bd2b8b",
#       "tested_at": "2026-06-24T16:00:59Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "房东在深山时租金不收取",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "0fbe76bc8a70000517e8c06fc29c583075e04e279fc11cbeaf24a83d6c919f7f",
#       "tested_at": "2026-06-24T16:00:59Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 6,
#       "name": "税务局按比例收税",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "02449a1a0fd64f3bd428d0b9ba9d5ea0bee0a19f565d081042521928f76f83b8",
#       "tested_at": "2026-06-24T16:01:00Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 0,
#       "name": "天使守护不免疫税务局",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "0c39d06c292d8ca79623d814e54eb63bb99eebc7d9fb5fe95a90873a2b6d4cad",
#       "tested_at": "2026-06-24T16:01:00Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 0,
#       "name": "持有免税卡时弹出使用提示",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "5017b50e9166b668c678d06874980c97e7083a87ca35a29c9d41be22f326c7b7",
#       "tested_at": "2026-06-24T16:01:00Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 14,
#       "name": "强夺卡支付总投入获得对手地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 14,
#         "Survived": 0,
#         "Total": 14
#       },
#       "scenario_hash": "b55734b8c9eda22f20d548005fcadb218994606da9be9cca114951782ca142c8",
#       "tested_at": "2026-06-24T16:01:03Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 0,
#       "name": "强夺卡余额不足时无法使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4e97a665fc1536d85fd763c27b8cf27616782d0221631749e1b41bb30c7126a7",
#       "tested_at": "2026-06-24T16:01:03Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 8,
#       "name": "支付租金后资金不足触发破产",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "7b8006eaa11e9e600e77d0298e08ca45c64e0f1cde2b37003aef465506131c0a",
#       "tested_at": "2026-06-24T16:01:05Z"
#     },
#     {
#       "index": 14,
#       "mutation_count": 0,
#       "name": "余额为零时落在税务局触发破产",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c33ed33fe75b9bdf87f961ef256c3139fce36aa5c464187c070a4ebdcca1d347",
#       "tested_at": "2026-06-24T16:01:05Z"
#     },
#     {
#       "index": 15,
#       "mutation_count": 0,
#       "name": "房东已淘汰时租金不收取",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e93d43949650b09f5bc100a7dd34226eb0f76e505ea728fc334313212373a0be",
#       "tested_at": "2026-06-24T16:01:05Z"
#     }
#   ],
#   "tested_at": "2026-06-24T16:01:05Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 经济系统

背景:
  假如 游戏已初始化标准棋盘
  并且 棋盘包含地块邻接关系

场景大纲: 购买无主地块
  假如 玩家持有<余额>金币
  并且 玩家初始余额为<验证余额>金币
  并且 玩家落在价格为<地价>的无主地块
  并且 地块价格为<验证地价>金币
  当 玩家选择购买
  那么 玩家扣除<地价>金币
  并且 玩家成为该地块的所有者

例子:
  | 余额  | 验证余额 | 地价 | 验证地价 |
  | 5000  | 5000     | 2000 | 2000     |
  | 10000 | 10000    | 3000 | 3000     |

场景: 余额不足时无法购买地块
  假如 玩家持有1000金币
  并且 玩家落在价格为2000的无主地块
  当 玩家选择购买
  那么 购买失败并提示余额不足

场景大纲: 升级自有地块
  假如 玩家拥有一块等级为<当前等级>的地块
  并且 该地块的下一级升级费为<升级费>
  并且 当前升级费为<验证升级费>金币
  并且 玩家持有<余额>金币
  并且 玩家初始余额为<验证余额>金币
  当 玩家选择升级
  那么 地块等级变为<新等级>
  并且 玩家扣除<升级费>金币

例子:
  | 当前等级 | 升级费 | 验证升级费 | 余额  | 验证余额 | 新等级 |
  | 0        | 1000   | 1000       | 5000  | 5000     | 1      |
  | 1        | 1500   | 1500       | 5000  | 5000     | 2      |
  | 2        | 2000   | 2000       | 5000  | 5000     | 3      |

场景: 地块已达最高等级时无法升级
  假如 玩家拥有的地块已达最高等级
  当 玩家尝试升级
  那么 升级选项不可用

场景大纲: 单块地块按地价和加盖次数计算租金
  假如 该地块购买价为<地价>
  并且 地块加盖次数为<加盖次数>
  并且 地块属于对手
  当 玩家落在该地块
  那么 玩家支付租金<应付租金>给对手

例子:
  | 地价 | 加盖次数 | 应付租金 |
  | 100  | 0        | 50       |
  | 100  | 1        | 100      |
  | 100  | 2        | 200      |
  | 100  | 3        | 400      |

场景大纲: 连片地块租金为各块租金之和
  假如 对手拥有<连片数>块相邻地块
  并且 相邻地块数量为<验证连片数>块
  并且 各块租金分别为<各块租金>
  当 玩家落在其中任一块
  那么 玩家支付的租金为<总租金>

例子:
  | 连片数 | 验证连片数 | 各块租金    | 总租金 |
  | 2      | 2          | 100,200     | 300    |
  | 3      | 3          | 100,200,400 | 700    |

场景大纲: 神灵倍增租金
  假如 玩家落在对手拥有的地块
  并且 单块基础租金为<基础租金>
  并且 <神灵条件>
  当 租金结算执行
  那么 实际支付租金为<实际租金>

例子:
  | 基础租金 | 神灵条件               | 实际租金 |
  | 100      | 租户持有穷神           | 200      |
  | 100      | 房东持有财神           | 200      |
  | 100      | 租户持有穷神且房东持有财神 | 400      |

场景: 房东在深山时租金不收取
  假如 对手拥有一块地块
  并且 对手当前在深山状态
  当 玩家落在该地块
  那么 租金不收取
  并且 事件日志显示房东在深山

场景大纲: 税务局按比例收税
  假如 玩家持有<余额>金币
  并且 税率为50%
  当 玩家落在税务局格
  那么 玩家被收取<税金>金币

例子:
  | 余额  | 税金 |
  | 10000 | 5000 |
  | 3000  | 1500 |
  | 1     | 0    |

场景: 天使守护不免疫税务局
  假如 玩家持有10000金币
  并且 玩家附有天使守护
  并且 税率为50%
  当 玩家落在税务局格
  那么 玩家被收取5000金币

场景: 持有免税卡时弹出使用提示
  假如 玩家落在税务局格
  并且 玩家持有免税卡
  当 落地结算执行
  那么 弹出免税卡使用选择
  并且 若玩家确认则消耗免税卡并免税

场景大纲: 强夺卡支付总投入获得对手地块
  假如 对手的地块等级为<等级>
  并且 对手地块等级为<验证等级>
  并且 地块购买价为<地价>
  并且 各级累计升级费为<累计升级费>
  并且 玩家持有<余额>金币
  并且 玩家初始余额为<验证余额>金币
  当 玩家使用强夺卡
  那么 玩家支付<总投入>金币给对手
  并且 地块所有权转移给玩家

例子:
  | 等级 | 验证等级 | 地价 | 累计升级费 | 余额  | 验证余额 | 总投入 |
  | 0    | 0        | 2000 | 0          | 5000  | 5000     | 2000   |
  | 2    | 2        | 2000 | 2500       | 10000 | 10000    | 4500   |

场景: 强夺卡余额不足时无法使用
  假如 对手的地块总投入为5000
  并且 玩家持有3000金币
  当 玩家尝试使用强夺卡
  那么 强夺卡不可用

场景大纲: 支付租金后资金不足触发破产
  假如 玩家持有<余额>金币
  并且 应付租金为<应付租金>
  并且 应付租金记为<验证应付租金>金币
  当 租金结算执行
  那么 房东收到<实收金额>金币
  并且 玩家破产淘汰

例子:
  | 余额 | 应付租金 | 验证应付租金 | 实收金额 |
  | 500  | 1000     | 1000         | 500      |
  | 0    | 200      | 200          | 0        |

场景: 余额为零时落在税务局触发破产
  假如 玩家持有0金币
  并且 税率为50%
  当 玩家落在税务局格
  那么 税金为0
  并且 玩家因余额为零而破产淘汰

场景: 房东已淘汰时租金不收取
  假如 对手拥有一块地块
  并且 对手已被淘汰
  当 玩家落在该地块
  那么 租金不收取
