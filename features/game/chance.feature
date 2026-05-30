# language: zh-CN
# mutation-stamp: sha256=462ef71d4452e635ecb7385d46641df5a3d5fdbfb653a581e7848dd128a0f7d9
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "3ceea544d5d8114a61ecddd77c867bb2082edd055d595fbda085df61d7563b98",
#   "feature_name": "机会卡",
#   "feature_path": "features/game/chance.feature",
#   "implementation_hash": "sha256:b72d2191c54331f4653ef651c09d9648df878d90bfee6552455a91043a9179b6",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 155,
#       "name": "策划案机会卡目录完整",
#       "result": {
#         "Errors": 0,
#         "Killed": 155,
#         "Survived": 0,
#         "Total": 155
#       },
#       "scenario_hash": "088935df5700fb9b61385dff4b6583410aced9d47aad86d23915009fc66e1491",
#       "tested_at": "2026-05-28T14:55:54Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "抽取机会卡按权重随机",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "20f69783650fddd9b3f975802a65d6b606503a251d4e51911145f92745cc1476",
#       "tested_at": "2026-05-28T14:55:54Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "天使守护免疫负面机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "da5d03ec8634593ed114068594ee10b61adc65331b7acc920c3894a76d03abc4",
#       "tested_at": "2026-05-28T14:55:54Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 4,
#       "name": "获得金币类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "fb90d19a0c6524c75f8fd4ee5f007c60bdfaf84bfcc2931feb85d7539a83ba60",
#       "tested_at": "2026-05-28T14:55:55Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 8,
#       "name": "支付金币类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "efee1ca912eed3a6fdb0c0553f7addb29e55598fe6434044fc08cb3368136d67",
#       "tested_at": "2026-05-28T14:55:56Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "支付金币后余额归零触发破产",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "50a470f5ad70d7a3abee414641a6714fe959379dbe8283e35071cb70a5a14d7a",
#       "tested_at": "2026-05-28T14:55:56Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 6,
#       "name": "按比例支付金币类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "814352384e28b996f16cad3932745c6d5e49ea23c895259add3e3c1d12a2bc46",
#       "tested_at": "2026-05-28T14:55:57Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 2,
#       "name": "财神倍增获得金币效果",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "4c5581b90517c1efdd80608f052617b93a0fb21ae2db8aad8adff82545276c23",
#       "tested_at": "2026-05-28T14:55:57Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 2,
#       "name": "穷神倍增支付金币效果",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "3d023f5ad0a952b40a055f897c6b663b12e576ebceb4a8e84a23b4c47e4da0e1",
#       "tested_at": "2026-05-28T14:55:57Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 4,
#       "name": "向他人支付金币类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "f53d8d9024de500f5836a11fe58b498582970da50ddb52d4932743bef4c16e26",
#       "tested_at": "2026-05-28T14:55:58Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 0,
#       "name": "向他人支付时深山中的对手不收钱",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "04b3203baa64573a504e100f303d90ffc833bbeebda5e4620c2c73953fcee59e",
#       "tested_at": "2026-05-28T14:55:58Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 10,
#       "name": "从他人收取金币类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 10,
#         "Survived": 0,
#         "Total": 10
#       },
#       "scenario_hash": "4675e13c6c6b5402360a4eb13ade5e0f190db5bd289c2ce9330f9d01a4d1d0f0",
#       "tested_at": "2026-05-28T14:55:59Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 8,
#       "name": "前进或后退步数类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "49d0d38194105e444940ae32b7056f6f786beefc51853eefb068ecbeaad49af7",
#       "tested_at": "2026-05-28T14:56:00Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 0,
#       "name": "强制传送类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f656de71360466df3a6b39fec4c67e87f105d65fb0f8b5591d9dfe474b1fc2a9",
#       "tested_at": "2026-05-28T14:56:00Z"
#     },
#     {
#       "index": 14,
#       "mutation_count": 0,
#       "name": "获得道具类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "ab2c4b419655bfc2bbb425a59e6cb682729d43f561240bce704584cf9468ea8c",
#       "tested_at": "2026-05-28T14:56:00Z"
#     },
#     {
#       "index": 15,
#       "mutation_count": 10,
#       "name": "丢弃道具类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 10,
#         "Survived": 0,
#         "Total": 10
#       },
#       "scenario_hash": "e04593d4003e77d0afe681d2baa191c45b9922e5538d14e621c6618c5d324142",
#       "tested_at": "2026-05-28T14:56:01Z"
#     },
#     {
#       "index": 16,
#       "mutation_count": 8,
#       "name": "丢弃地块类机会卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "79d2beffef6f587a96678607c31281ad5348b6f1ed70b5b6a2494a30d6a92081",
#       "tested_at": "2026-05-28T14:56:02Z"
#     },
#     {
#       "index": 17,
#       "mutation_count": 0,
#       "name": "台风摧毁沿途建筑",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "64f5271fdcd17952db8a730f05a3afd2778b9de0fb631ec31b508b6657f732b8",
#       "tested_at": "2026-05-28T14:56:02Z"
#     },
#     {
#       "index": 18,
#       "mutation_count": 0,
#       "name": "强制征地重置沿途地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c3c2a152bbb043485497ea7222364890851d7c508b15d4a61165b8bdd4b506d0",
#       "tested_at": "2026-05-28T14:56:02Z"
#     },
#     {
#       "index": 19,
#       "mutation_count": 0,
#       "name": "全体支付类机会卡影响所有未淘汰玩家",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4f14cab170e512989ce8d651e99a7a9b49d3bf76672838e1d619b37909c8a555",
#       "tested_at": "2026-05-28T14:56:02Z"
#     },
#     {
#       "index": 20,
#       "mutation_count": 0,
#       "name": "全体负面支付机会卡跳过拥有天使守护的对手",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "6d6037240fd1c796112f0cf3d48683d8f9bb4540514e6d467eedd48ded7cf057",
#       "tested_at": "2026-05-28T14:56:02Z"
#     },
#     {
#       "index": 21,
#       "mutation_count": 16,
#       "name": "穷神和财神影响向他人支付和从他人收取效果",
#       "result": {
#         "Errors": 0,
#         "Killed": 16,
#         "Survived": 0,
#         "Total": 16
#       },
#       "scenario_hash": "37cbd5911e6d1274fea9d8cd52ad4bdeac586361bd95f56be3c682ad186b0396",
#       "tested_at": "2026-05-28T14:56:04Z"
#     }
#   ],
#   "tested_at": "2026-05-28T14:56:04Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 机会卡

背景:
  假如 游戏已初始化标准棋盘
  并且 玩家落在机会格

场景大纲: 策划案机会卡目录完整
  假如 策划案机会卡目录包含<卡号>
  那么 机会卡<卡号>的效果为<效果>
  并且 机会卡<卡号>的目标为<目标>
  并且 机会卡<卡号>的参数为<参数>
  并且 机会卡<卡号>的负面标记为<负面>

例子:
  | 卡号 | 效果                      | 目标 | 参数 | 负面 |
  | 3001 | add_cash                  | self | 10000 | false |
  | 3002 | add_cash                  | self | 1000 | false |
  | 3003 | add_cash                  | self | 2000 | false |
  | 3004 | add_cash                  | self | 5000 | false |
  | 3005 | pay_cash                  | self | 10000 | true |
  | 3006 | pay_cash                  | self | 1000 | true |
  | 3007 | pay_cash                  | self | 2000 | true |
  | 3008 | pay_cash                  | self | 5000 | true |
  | 3009 | add_cash                  | all  | 3000 | false |
  | 3010 | pay_cash                  | all  | 3000 | true |
  | 3011 | percent_pay_cash          | all  | 20 | true |
  | 3012 | pay_others                | self | 3000 | true |
  | 3013 | collect_from_others       | self | 3000 | false |
  | 3017 | destroy_buildings_on_path | path | - | false |
  | 3018 | reset_tiles_on_path       | path | - | false |
  | 3019 | move_backward             | self | 1 | false |
  | 3020 | move_backward             | self | 2 | false |
  | 3021 | move_backward             | self | 3 | false |
  | 3022 | move_forward              | self | 1 | false |
  | 3023 | move_forward              | self | 2 | false |
  | 3024 | move_forward              | self | 3 | false |
  | 3025 | grant_item                | self | 2017 | false |
  | 3026 | grant_item                | self | 2018 | false |
  | 3027 | grant_item                | self | 2019 | false |
  | 3028 | discard_items             | self | 1 | true |
  | 3029 | discard_items             | self | 0 | true |
  | 3030 | discard_properties        | self | 1 | true |
  | 3031 | forced_move               | self | 36 | true |
  | 3032 | forced_move               | self | 37 | true |
  | 3033 | forced_move               | self | 38 | true |
  | 3034 | forced_move               | self | 39 | false |

场景: 抽取机会卡按权重随机
  当 落地结算执行
  那么 从机会卡池中按权重随机抽取一张
  并且 弹出机会卡展示弹窗
  并且 事件日志记录抽到的卡片

场景: 天使守护免疫负面机会卡
  假如 玩家拥有天使守护
  并且 抽到的机会卡标记为负面
  当 机会卡效果结算
  那么 负面效果无效
  并且 提示天使保护

场景大纲: 获得金币类机会卡
  假如 抽到的机会卡效果为获得<金额>金币
  当 机会卡效果结算
  那么 玩家获得<金额>金币
  并且 获得金额记为<验证金额>金币

例子:
  | 金额 | 验证金额 |
  | 1000 | 1000     |
  | 5000 | 5000     |

场景大纲: 支付金币类机会卡
  假如 抽到的机会卡效果为支付<金额>金币
  并且 玩家持有<余额>金币
  并且 玩家初始余额为<验证余额>金币
  当 机会卡效果结算
  那么 玩家扣除<金额>金币
  并且 实际扣除金额为<验证金额>金币

例子:
  | 金额 | 验证金额 | 余额  | 验证余额 |
  | 1000 | 1000     | 5000  | 5000     |
  | 3000 | 3000     | 10000 | 10000    |

场景: 支付金币后余额归零触发破产
  假如 抽到的机会卡效果为支付5000金币
  并且 玩家持有3000金币
  当 机会卡效果结算
  那么 玩家破产淘汰

场景大纲: 按比例支付金币类机会卡
  假如 抽到的机会卡效果为按<百分比>%支付金币
  并且 玩家持有<余额>金币
  当 机会卡效果结算
  那么 玩家扣除<扣除额>金币

例子:
  | 百分比 | 余额  | 扣除额 |
  | 50     | 10000 | 5000   |
  | 30     | 5000  | 1500   |

场景大纲: 财神倍增获得金币效果
  假如 玩家持有财神守护
  并且 抽到获得<基础金额>金币的机会卡
  当 机会卡效果结算
  那么 实际获得<实际金额>金币

例子:
  | 基础金额 | 实际金额 |
  | 1000     | 2000     |

场景大纲: 穷神倍增支付金币效果
  假如 玩家持有穷神
  并且 抽到支付<基础金额>金币的机会卡
  当 机会卡效果结算
  那么 实际扣除<实际金额>金币

例子:
  | 基础金额 | 实际金额 |
  | 1000     | 2000     |

场景大纲: 向他人支付金币类机会卡
  假如 抽到的机会卡效果为向每位玩家支付<金额>金币
  并且 游戏中有<其他玩家数>名未淘汰对手
  并且 当前对手数量为<验证其他玩家数>名
  当 机会卡效果结算
  那么 玩家向每位对手各支付<金额>金币
  并且 实际每对手支付为<验证金额>金币

例子:
  | 金额 | 验证金额 | 其他玩家数 | 验证其他玩家数 |
  | 500  | 500      | 3          | 3              |

场景: 向他人支付时深山中的对手不收钱
  假如 抽到向每位玩家支付500金币的机会卡
  并且 对手A在深山状态
  当 机会卡效果结算
  那么 对手A不收到任何金币

场景大纲: 从他人收取金币类机会卡
  假如 抽到的机会卡效果为向每位玩家收取<金额>金币
  并且 当前收取上限为<验证金额>金币
  并且 对手持有<对手余额>金币
  并且 对手起始余额为<验证对手余额>金币
  当 机会卡效果结算
  那么 玩家从每位对手收取最多<金额>金币
  并且 对手余额不足时只收取其全部余额
  并且 实际收取总额为<验证收取额>金币

例子:
  | 金额 | 验证金额 | 对手余额 | 验证对手余额 | 验证收取额 |
  | 1000 | 1000     | 5000     | 5000         | 1000       |
  | 1000 | 1000     | 500      | 500          | 500        |

场景大纲: 前进或后退步数类机会卡
  假如 抽到的机会卡效果为<移动方向><步数>步
  当 机会卡效果结算
  那么 玩家<移动方向><步数>步
  并且 实际移动方向为<验证移动方向>
  并且 实际移动步数为<验证步数>步
  并且 到达后触发落地结算

例子:
  | 移动方向 | 验证移动方向 | 步数 | 验证步数 |
  | 前进     | 前进         | 3    | 3        |
  | 后退     | 后退         | 2    | 2        |

场景: 强制传送类机会卡
  假如 抽到的机会卡效果为传送到指定格
  当 机会卡效果结算
  那么 玩家被传送到目标格
  并且 到达后触发落地结算

场景: 获得道具类机会卡
  假如 抽到的机会卡效果为获得指定道具
  并且 玩家背包未满
  当 机会卡效果结算
  那么 指定道具加入玩家背包

场景大纲: 丢弃道具类机会卡
  假如 抽到的机会卡效果为随机丢弃<数量>张道具
  并且 指定丢弃数为<验证数量>张
  并且 玩家持有<持有数>张道具
  并且 背包道具数为<验证持有数>张
  当 机会卡效果结算
  那么 玩家随机失去<实际丢弃>张道具

例子:
  | 数量 | 验证数量 | 持有数 | 验证持有数 | 实际丢弃 |
  | 2    | 2        | 5      | 5          | 2        |
  | 3    | 3        | 1      | 1          | 1        |

场景大纲: 丢弃地块类机会卡
  假如 抽到的机会卡效果为随机丢弃<数量>块地块
  并且 指定丢弃地块数为<验证数量>块
  并且 玩家拥有<持有数>块地块
  当 机会卡效果结算
  那么 玩家随机失去<实际丢弃>块地块
  并且 被丢弃的地块重置为无主状态

例子:
  | 数量 | 验证数量 | 持有数 | 实际丢弃 |
  | 1    | 1        | 3      | 1        |
  | 2    | 2        | 1      | 1        |

场景: 台风摧毁沿途建筑
  假如 抽到台风类机会卡
  并且 玩家本次移动经过的路径上有等级大于0的地块
  当 机会卡效果结算
  那么 路径上所有地块等级重置为0

场景: 强制征地重置沿途地块
  假如 抽到强制征地类机会卡
  并且 玩家本次移动经过的路径上有已购地块
  当 机会卡效果结算
  那么 路径上所有地块恢复初始状态

场景: 全体支付类机会卡影响所有未淘汰玩家
  假如 抽到的机会卡目标为全体
  并且 效果为支付1000金币
  当 机会卡效果结算
  那么 所有未淘汰玩家各扣除1000金币

场景: 全体负面支付机会卡跳过拥有天使守护的对手
  假如 玩家抽到负面全体支付1000金币的机会卡
  并且 游戏中有2名对手
  并且 对手B拥有天使守护
  并且 各对手初始持有5000金币
  当 机会卡效果结算
  那么 拥有天使守护的对手金币不变
  并且 无天使守护的对手被扣除1000金币

场景大纲: 穷神和财神影响向他人支付和从他人收取效果
  假如 玩家附有<神灵>
  并且 玩家神灵状态为<验证神灵>
  并且 抽到<效果类型>3000金币的多人机会卡
  并且 游戏中有1名持有10000金币的对手
  当 机会卡效果结算
  那么 对手的金币变化量为<变化量>

例子:
  | 神灵 | 验证神灵 | 效果类型       | 变化量 |
  | 穷神 | 穷神     | 向每位对手支付 | +6000  |
  | 财神 | 财神     | 从每位对手收取 | -6000  |
  | 穷神 | 穷神     | 从每位对手收取 | -3000  |
  | 财神 | 财神     | 向每位对手支付 | +3000  |
