# language: zh-CN
# mutation-stamp: sha256=a836a8e69915dda7802f803868026cb8e9a0430038c43d623542728bff77aacb
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "313adb4543f85e8047d998cbff303f23887755734cac80fe8cfbf12576f148ba",
#   "feature_name": "棋盘移动",
#   "feature_path": "features/game/movement.feature",
#   "implementation_hash": "sha256:d062d65338eb8b372916d7af938568df21cf72a44c6b47382024af5cff42f986",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 12,
#       "name": "玩家按骰子点数前进",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "370320a25228b824dc0acb299967432a77d51734b04e30b9e281f83b33e9c1c7",
#       "tested_at": "2026-05-27T16:00:49Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 4,
#       "name": "经过起点获得金币奖励",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "32068c4a8cdd7f5b8c2e1ea6dbc567b176bd374d059bc1f145dd18095072dd23",
#       "tested_at": "2026-05-27T16:00:49Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "持有财神经过起点奖励翻倍",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "1b67125f36de8e8420454a6be4ae6b16562b37b4c12903db391923084c7d7e5c",
#       "tested_at": "2026-05-27T16:00:49Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 8,
#       "name": "路障中断移动",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "4afcc3163c7b054cfb244a71bf173047750de40f2ae12a6ce70819ce5d9dbe23",
#       "tested_at": "2026-05-27T16:00:51Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "天使守护不免疫路障",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "7b533534e38cd29041e2265fda5de953d09e500e1d1f665b85f1aab5ee1e1113",
#       "tested_at": "2026-05-27T16:00:51Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 5,
#       "name": "地雷触发后玩家住院",
#       "result": {
#         "Errors": 0,
#         "Killed": 5,
#         "Survived": 0,
#         "Total": 5
#       },
#       "scenario_hash": "ff02ec8115d59bbfac97bee5bde4e92ca719d1eda0296c0ee4ac0fb58c2560ed",
#       "tested_at": "2026-05-27T16:00:52Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "地雷布置者在布置回合和下一己方回合免疫自己的地雷",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "d159a0bc9f973b7ecc59453da9d18975115b297793efea42a46ac475b33616c7",
#       "tested_at": "2026-05-27T16:00:52Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "地雷布置者第三己方回合不再免疫",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "fc41393b741d08f97cf1c2282fe48f810ca69c427ea7dfd7fc254a3b3be71c8c",
#       "tested_at": "2026-05-27T16:00:52Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "同格路障和地雷按顺序触发",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "b8d1f8919d94a88068969cf7025648ae7a718f61ca53d92d4a4a5b47d22f2c39",
#       "tested_at": "2026-05-27T16:00:52Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 4,
#       "name": "经过黑市自动打开并中断移动",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "cb9fe4c41a0e594f5d7e2be853a9ee7f2138050d7fdf38969927a27909ac8323",
#       "tested_at": "2026-05-27T16:00:52Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 4,
#       "name": "分支路口按奇偶选择路径",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "f898270fc86a938c6806116b4a5632f3df85ce5f95b22c77cd53fe61003773f6",
#       "tested_at": "2026-05-27T16:00:53Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 4,
#       "name": "后退移动",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "37b57d1315977cb7e4ddf32a72a2f29155dacbb9db8b005c17f9f2806b88a30c",
#       "tested_at": "2026-05-27T16:00:54Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 0,
#       "name": "落在起点格也获得经过起点奖励",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "73515cad82c1b1ac3356c5825a6a0f26925c78345c18de6224f15d3a9a3b79a2",
#       "tested_at": "2026-05-27T16:00:54Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 0,
#       "name": "黑市格有地雷时先触发地雷后跳过黑市",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "fda31c325e5ba8e897bb33ecf4cfdd3ab819cde096441e2a9211be0c50c41241",
#       "tested_at": "2026-05-27T16:00:54Z"
#     },
#     {
#       "index": 14,
#       "mutation_count": 0,
#       "name": "天使守护免疫黑市格地雷后正常进入黑市",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e8a007d620dc1cd9d599a2b1186e35c8e36a8e9a75a7e0269d3ef0c210b67110",
#       "tested_at": "2026-05-27T16:00:54Z"
#     },
#     {
#       "index": 15,
#       "mutation_count": 0,
#       "name": "从黑市恢复移动时保持原方向和剩余步数",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "fbc79b6bc1914579804d63019205ca762369f8fe57a7ce2cb5dda1ec923dd248",
#       "tested_at": "2026-05-27T16:00:54Z"
#     }
#   ],
#   "tested_at": "2026-05-27T16:00:54Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 棋盘移动

背景:
  假如 游戏已初始化标准棋盘
  并且 当前玩家位于起点

场景大纲: 玩家按骰子点数前进
  假如 玩家当前位于格子<起始位置>
  当 玩家移动<步数>步
  那么 玩家到达格子<目标位置>
  并且 移动路径经过<途经格数>个格子

例子:
  | 起始位置 | 步数 | 目标位置 | 途经格数 |
  | 1        | 3    | 42       | 3        |
  | 4        | 6    | 9        | 6        |
  | 5        | 1    | 6        | 1        |

场景大纲: 经过起点获得金币奖励
  假如 玩家位于起点前<距离>格
  当 玩家移动<步数>步经过起点
  那么 玩家经过起点<经过次数>次
  并且 玩家获得<奖励金额>金币

例子:
  | 距离 | 步数 | 经过次数 | 奖励金额 |
  | 2    | 4    | 1        | 2000     |

场景: 持有财神经过起点奖励翻倍
  假如 玩家当前位于起点前2格
  并且 玩家持有财神守护
  当 玩家移动3步经过起点
  那么 玩家获得的经过起点奖励是基础值的2倍

场景大纲: 路障中断移动
  假如 玩家当前位于格子<起始位置>
  并且 格子<路障位置>放置了路障
  当 玩家移动<步数>步
  那么 玩家停在格子<路障位置>
  并且 路障被清除
  并且 继续访问路障所在格事件
  并且 剩余<剩余步数>步未消耗

例子:
  | 起始位置 | 路障位置 | 步数 | 剩余步数 |
  | 1        | 3        | 6    | 4        |
  | 5        | 6        | 4    | 3        |

场景: 天使守护不免疫路障
  假如 玩家当前位于格子1
  并且 格子3放置了路障
  并且 玩家仅拥有天使守护
  当 玩家移动6步
  那么 玩家仍停在格子3
  并且 路障被清除

场景大纲: 地雷触发后玩家住院
  假如 玩家当前位于格子<起始位置>
  并且 格子<地雷位置>放置了对手的已激活地雷
  当 玩家移动<步数>步到达地雷位置
  那么 地雷被触发并清除
  并且 玩家被送往医院
  并且 玩家需停留<住院回合>回合
  并且 剩余<剩余步数>步未消耗

例子:
  | 起始位置 | 地雷位置 | 步数 | 住院回合 | 剩余步数 |
  | 2        | 3        | 1    | 2        | 0        |

场景: 地雷布置者在布置回合和下一己方回合免疫自己的地雷
  假如 玩家在本回合布置了地雷于格子5
  当 下一己方回合玩家移动经过格子5
  那么 地雷不触发

场景: 地雷布置者第三己方回合不再免疫
  假如 玩家在之前的回合布置了地雷于格子5
  并且 已过去2个己方回合
  当 玩家移动经过格子5
  那么 地雷正常触发
  并且 玩家被送往医院

场景: 同格路障和地雷按顺序触发
  假如 格子3同时放置了路障和对手的已激活地雷
  当 玩家移动到格子3
  那么 路障先触发并清除
  并且 然后地雷触发
  并且 玩家被送往医院

场景大纲: 经过黑市自动打开并中断移动
  假如 玩家当前位于格子<起始位置>
  并且 格子<黑市位置>是黑市格
  当 玩家移动<步数>步经过黑市
  那么 移动暂停在黑市格
  并且 黑市窗口自动打开
  并且 剩余<剩余步数>步待消耗

例子:
  | 起始位置 | 黑市位置 | 步数 | 剩余步数 |
  | 1        | 42       | 6    | 3        |

场景大纲: 分支路口按奇偶选择路径
  假如 玩家当前位于分支入口格
  并且 分支入口连接外圈和内圈
  当 玩家移动且分支奇偶为<奇偶值>
  那么 玩家进入<选择路径>

例子:
  | 奇偶值 | 选择路径 |
  | 偶数   | 内圈     |
  | 奇数   | 外圈     |

场景大纲: 后退移动
  假如 玩家当前位于格子<起始位置>
  并且 玩家面朝<面朝方向>
  当 玩家后退<步数>步
  那么 玩家到达格子<目标位置>
  并且 后退不改变玩家面朝方向

例子:
  | 起始位置 | 面朝方向 | 步数 | 目标位置 |
  | 6        | 左       | 2    | 4        |

场景: 落在起点格也获得经过起点奖励
  假如 玩家当前位于起点前3格
  当 玩家移动恰好3步到达起点
  那么 玩家获得经过起点的金币奖励

场景: 黑市格有地雷时先触发地雷后跳过黑市
  假如 玩家当前位于格子1
  并且 格子42是黑市格
  并且 格子42同时放置了对手的已激活地雷
  当 玩家移动到格子42
  那么 地雷被触发并清除
  并且 玩家被送往医院
  并且 不打开黑市窗口

场景: 天使守护免疫黑市格地雷后正常进入黑市
  假如 玩家当前位于格子1
  并且 格子42是黑市格
  并且 格子42同时放置了对手的已激活地雷
  并且 玩家拥有天使守护且可抵御路障
  当 玩家移动到格子42
  那么 地雷不触发
  并且 黑市窗口自动打开

场景: 从黑市恢复移动时保持原方向和剩余步数
  假如 玩家经过黑市格时移动被中断
  并且 剩余3步未消耗
  当 玩家关闭黑市继续移动
  那么 玩家沿原方向继续前进3步
  并且 分支奇偶状态保持不变
