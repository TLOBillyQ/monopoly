# language: zh-CN
# mutation-stamp: sha256=7c040f00a2a35127a8cac1fab0f9a03180f67f67fa74ec2c045ec18752488986
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "bbdacd16196cffd0afe6bd936a220ac5232efb86ba62c16257e4a46c9a0a47b6",
#   "feature_name": "主回合按钮",
#   "feature_path": "features/game/main_turn_buttons.feature",
#   "implementation_hash": "sha256:04566fcb95d8bac46b0182c25bbc7bd5de3f2e488b4571a3568eea8cdc05d121",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 0,
#       "name": "main_turn_buttons_001 回合开始时只展示行动按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "8a8b9e215bc5e9cfa3b8570c19caf42612dfc3741067cca5cf64168d044c9f56",
#       "tested_at": "2026-08-26T06:10:19Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 1,
#       "name": "main_turn_buttons_002 行动按钮跳过 pre-action 道具并投骰子",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "11bb714e9c81745d9c5f8f0e6bfeb927fc59fe3ef832f92837bd9db879dd01cf",
#       "tested_at": "2026-08-26T06:10:19Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 1,
#       "name": "main_turn_buttons_003 行动按钮在目标选择阶段隐藏",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "a8d278ffab00d2f7b930a0f8e52bbc9d60a8b4613da6746b37b6caeb04d25f5e",
#       "tested_at": "2026-08-26T06:10:19Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 4,
#       "name": "main_turn_buttons_004 投骰子后强制选择期间隐藏主按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "586dd7a2fa0d56d5b533bf160b6f58b96f486676f5f6b50f224567682adc28c8",
#       "tested_at": "2026-08-26T06:10:20Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "main_turn_buttons_005 强制选择完成后只展示结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "232939af64cf62e18011b7d14923374e074fe824f5d5c9c57c928382131a7c19",
#       "tested_at": "2026-08-26T06:10:20Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 1,
#       "name": "main_turn_buttons_006 结束按钮跳过 post-action 道具并结束回合",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "0a32855f4bc005781bbfd354362c00347862def4bfab98e0f9ffa73cb7b887f8",
#       "tested_at": "2026-08-26T06:10:20Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 1,
#       "name": "main_turn_buttons_007 道具目标选择阶段隐藏主按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "a9a016d7689e17724ace16f1520ff6694c3adf2a7e2d91e5091432d55a6d13de",
#       "tested_at": "2026-08-26T06:10:20Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 10,
#       "name": "main_turn_buttons_008 取消按钮在道具阶段取消道具使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 10,
#         "Survived": 0,
#         "Total": 10
#       },
#       "scenario_hash": "f793bd5194285868cbb516ea0b053fea4ee5c76c8de14c20f5497b394f266002",
#       "tested_at": "2026-08-26T06:10:21Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "main_turn_buttons_009 倒计时超时自动投骰子",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f9da972fa6371d9f42dc8ae3e6887618d43825dc8b98c35c4e5bcc7da63588bb",
#       "tested_at": "2026-08-26T06:10:21Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 0,
#       "name": "main_turn_buttons_010 倒计时超时自动结束回合",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "88fb0a6412769e1fdf17d9c0e3ef0c30bce499619cd17f8b3d6634dbfdf534fb",
#       "tested_at": "2026-08-26T06:10:21Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 0,
#       "name": "main_turn_buttons_011 输入锁定期间主按钮不可点击",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c3e2142b9fc8ea07178e2af7d4328ac250b481b6df84fd6d7799fde331b3d342",
#       "tested_at": "2026-08-26T06:10:21Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 2,
#       "name": "main_turn_buttons_012 双骰子卡皆持有且全程不使用时按钮从行动到结束的完整路径",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "f02c4110e29f4ebfcc3738b2b85380dd46ba34e82eea408c030afaf7eba91060",
#       "tested_at": "2026-08-26T06:10:21Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 2,
#       "name": "main_turn_buttons_013 道具后续选择阶段取消按钮亮起",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "2797e5d0ddc97cfc6b22a15f7f2555486c412cd45b9ead8c97bfce1ef0bf1f42",
#       "tested_at": "2026-08-26T06:10:22Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 3,
#       "name": "main_turn_buttons_014 取消按钮从道具后续选择返回道具使用阶段且卡牌未消耗",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "7ef256137b10919274d0ea3ee2bc0e29e2096ddfc797bfe6191e0e14bae3a056",
#       "tested_at": "2026-08-26T06:10:22Z"
#     },
#     {
#       "index": 14,
#       "mutation_count": 4,
#       "name": "main_turn_buttons_015 路障截停后主按钮隐藏至落地选择完毕",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "2f9771444753439f0398285510319864c5d635fc990cde2f60337e99a007389d",
#       "tested_at": "2026-08-26T06:10:23Z"
#     },
#     {
#       "index": 15,
#       "mutation_count": 3,
#       "name": "main_turn_buttons_016 可选行动阶段只展示结束按钮作为推进入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "5f93f76359886b3132f3293e8e7ec7e17a0a356aaa117bc07ea6e3de22a126f8",
#       "tested_at": "2026-08-26T06:10:23Z"
#     },
#     {
#       "index": 16,
#       "mutation_count": 4,
#       "name": "main_turn_buttons_017 点击结束按钮完成可选行动阶段",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "ef47d285a24c25a58e66c4579bf1c06eed47129fc23a7bec39bd8383c32d3f3e",
#       "tested_at": "2026-08-26T06:10:24Z"
#     },
#     {
#       "index": 17,
#       "mutation_count": 2,
#       "name": "main_turn_buttons_018 可选行动超时等价于完成可选行动阶段",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "64206aa0d3a58d1e44471d76244e1fd859849bc9845af9e6a9d1b14ba4dc7bad",
#       "tested_at": "2026-08-26T06:10:24Z"
#     },
#     {
#       "index": 18,
#       "mutation_count": 14,
#       "name": "main_turn_buttons_019 阻断状态隐藏结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 14,
#         "Survived": 0,
#         "Total": 14
#       },
#       "scenario_hash": "54f5e91ed51e7d183c701f255b702db011498838989d426671f218bd1d9334e4",
#       "tested_at": "2026-08-26T06:10:25Z"
#     },
#     {
#       "index": 19,
#       "mutation_count": 6,
#       "name": "main_turn_buttons_020 系统等待和空可选阶段不展示结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "14f7e5b79d1cbd5aac2c45242e295831fd72e25db686846f559d398d789834df",
#       "tested_at": "2026-08-26T06:10:25Z"
#     },
#     {
#       "index": 20,
#       "mutation_count": 8,
#       "name": "main_turn_buttons_021 通用二次确认屏显示时隐藏结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "0a17b837141843dd5e04332e501cb4e4e8ecf37da3ba8811ad2e41615fdd532e",
#       "tested_at": "2026-08-26T06:10:26Z"
#     }
#   ],
#   "tested_at": "2026-08-26T06:10:26Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 主回合按钮

  背景:
    假如 游戏已初始化标准棋盘
    并且 玩家角色ID为<观察角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 当前行动控制为人类

  # main_turn_buttons_001 回合开始时只展示行动按钮
  场景大纲: main_turn_buttons_001 回合开始时只展示行动按钮
    假如 玩家处于行动等待阶段
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已展示且可点击
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已隐藏
    当 触发基础屏行动按钮
    那么 玩家进入必经回合流程

  例子:
    | 观察角色ID | 角色ID |
    | 1          | 1      |

  # main_turn_buttons_002 行动按钮跳过 pre-action 道具并投骰子
  场景大纲: main_turn_buttons_002 行动按钮跳过 pre-action 道具并投骰子
    假如 玩家处于行动等待阶段
    并且 玩家背包中有<道具名>
    并且 <道具名>可在行动前使用
    当 触发基础屏行动按钮
    那么 玩家跳过 pre-action 道具使用
    并且 玩家投骰子并移动

  例子:
    | 观察角色ID | 角色ID | 道具名     |
    | 1          | 1      | 遥控骰子卡 |

  # main_turn_buttons_003 行动按钮在目标选择阶段隐藏
  场景大纲: main_turn_buttons_003 行动按钮在目标选择阶段隐藏
    假如 玩家处于行动等待阶段
    并且 玩家背包中有<道具名>
    并且 玩家点击道具槽位1进入目标选择
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已隐藏
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已展示且可点击

  例子:
    | 观察角色ID | 角色ID | 道具名 |
    | 1          | 1      | 路障卡 |

  # main_turn_buttons_004 投骰子后强制选择期间隐藏主按钮
  场景大纲: main_turn_buttons_004 投骰子后强制选择期间隐藏主按钮
    假如 玩家已投骰子并完成移动
    并且 玩家落点为<地块归属>
    当 <选择界面>显示时
    那么 基础屏行动按钮已隐藏
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已隐藏

  例子:
    | 观察角色ID | 角色ID | 地块归属         | 选择界面     |
    | 1          | 1      | 可购买的无主地块 | 买地选择界面 |
    | 1          | 1      | 自有可加盖地块   | 加盖选择界面 |

  # main_turn_buttons_005 强制选择完成后只展示结束按钮
  场景大纲: main_turn_buttons_005 强制选择完成后只展示结束按钮
    假如 玩家已投骰子并完成移动
    并且 所有强制落地选择已处理完毕
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已展示且可点击
    并且 基础屏行动按钮已隐藏
    并且 基础屏取消按钮已隐藏

  例子:
    | 观察角色ID | 角色ID |
    | 1          | 1      |

  # main_turn_buttons_006 结束按钮跳过 post-action 道具并结束回合
  场景大纲: main_turn_buttons_006 结束按钮跳过 post-action 道具并结束回合
    假如 玩家已投骰子并完成移动
    并且 所有强制落地选择已处理完毕
    并且 玩家背包中有<道具名>
    并且 <道具名>可在行动后使用
    当 触发基础屏结束按钮
    那么 玩家跳过 post-action 道具使用
    并且 当前回合结束
    并且 轮到下一玩家

  例子:
    | 观察角色ID | 角色ID | 道具名     |
    | 1          | 1      | 遥控骰子卡 |

  # main_turn_buttons_007 道具目标选择阶段隐藏主按钮
  场景大纲: main_turn_buttons_007 道具目标选择阶段隐藏主按钮
    假如 玩家已投骰子并完成移动
    并且 所有强制落地选择已处理完毕
    并且 玩家背包中有<道具名>
    并且 玩家点击道具槽位1进入目标选择
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已隐藏
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已展示且可点击

  例子:
    | 观察角色ID | 角色ID | 道具名 |
    | 1          | 1      | 路障卡 |

  # main_turn_buttons_008 取消按钮在道具阶段取消道具使用
  场景大纲: main_turn_buttons_008 取消按钮在道具阶段取消道具使用
    假如 玩家处于行动等待阶段
    并且 玩家背包中有<道具名>
    并且 玩家处于<道具名>的道具使用阶段
    当 触发基础屏取消按钮
    那么 取消该道具的使用
    并且 该道具未被消耗

  例子:
    | 观察角色ID | 角色ID | 道具名 |
    | 1          | 1      | 路障卡 |
    | 1          | 1      | 怪兽卡 |
    | 1          | 1      | 偷窃卡 |
    | 1          | 1      | 导弹卡 |
    | 1          | 1      | 均富卡 |
    | 1          | 1      | 流放卡 |
    | 1          | 1      | 查税卡 |
    | 1          | 1      | 请神卡 |
    | 1          | 1      | 穷神卡 |
    | 1          | 1      | 送神卡 |

  # main_turn_buttons_009 倒计时超时自动投骰子
  场景大纲: main_turn_buttons_009 倒计时超时自动投骰子
    假如 玩家处于行动等待阶段
    并且 倒计时已超时
    当 系统自动执行主按钮操作
    那么 玩家投骰子并移动

  例子:
    | 观察角色ID | 角色ID |
    | 1          | 1      |

  # main_turn_buttons_010 倒计时超时自动结束回合
  场景大纲: main_turn_buttons_010 倒计时超时自动结束回合
    假如 玩家已投骰子并完成移动
    并且 所有强制落地选择已处理完毕
    并且 倒计时已超时
    当 系统自动执行主按钮操作
    那么 当前回合结束
    并且 轮到下一玩家

  例子:
    | 观察角色ID | 角色ID |
    | 1          | 1      |

  # main_turn_buttons_011 输入锁定期间主按钮不可点击
  场景大纲: main_turn_buttons_011 输入锁定期间主按钮不可点击
    假如 玩家处于行动等待阶段
    并且 弹窗提示导致输入锁定
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已隐藏
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已隐藏

  例子:
    | 观察角色ID | 角色ID |
    | 1          | 1      |

  # main_turn_buttons_012 双骰子卡皆持有且全程不使用时按钮从行动到结束的完整路径
  场景大纲: main_turn_buttons_012 双骰子卡皆持有且全程不使用时按钮从行动到结束的完整路径
    假如 玩家处于行动等待阶段
    并且 玩家背包中有<道具名>
    并且 <道具名>可在行动前使用
    并且 玩家背包中还有<第二道具名>
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已展示且可点击
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已隐藏
    当 触发基础屏行动按钮
    那么 玩家跳过 pre-action 道具使用
    并且 玩家投骰子并移动
    假如 所有强制落地选择已处理完毕
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已展示且可点击
    并且 基础屏行动按钮已隐藏
    并且 基础屏取消按钮已隐藏
    当 触发基础屏结束按钮
    那么 玩家跳过 post-action 道具使用
    并且 当前回合结束
    并且 轮到下一玩家

  例子:
    | 观察角色ID | 角色ID | 道具名     | 第二道具名 |
    | 1          | 1      | 遥控骰子卡 | 骰子加倍卡 |

  # main_turn_buttons_013 道具后续选择阶段取消按钮亮起
  场景大纲: main_turn_buttons_013 道具后续选择阶段取消按钮亮起
    假如 玩家处于行动等待阶段
    并且 玩家背包中有<道具名>
    并且 玩家点击道具槽位1进入目标选择
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已隐藏
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已展示且可点击

  例子:
    | 观察角色ID | 角色ID | 道具名     |
    | 1          | 1      | 偷窃卡     |
    | 1          | 1      | 遥控骰子卡 |

  # main_turn_buttons_014 取消按钮从道具后续选择返回道具使用阶段且卡牌未消耗
  场景大纲: main_turn_buttons_014 取消按钮从道具后续选择返回道具使用阶段且卡牌未消耗
    假如 玩家处于行动等待阶段
    并且 玩家背包中有<道具名>
    并且 玩家点击道具槽位1进入目标选择
    当 触发基础屏取消按钮
    那么 玩家回到<道具名>的道具使用阶段
    并且 该道具未被消耗

  例子:
    | 观察角色ID | 角色ID | 道具名     |
    | 1          | 1      | 偷窃卡     |
    | 1          | 1      | 路障卡     |
    | 1          | 1      | 遥控骰子卡 |

  # main_turn_buttons_015 路障截停后主按钮隐藏至落地选择完毕
  场景大纲: main_turn_buttons_015 路障截停后主按钮隐藏至落地选择完毕
    假如 玩家已投骰子且移动被路障截停
    并且 玩家落点为<地块归属>
    当 路障触发动画播放时
    那么 基础屏行动按钮已隐藏
    并且 基础屏结束按钮已隐藏
    并且 基础屏取消按钮已隐藏
    当 <选择界面>显示时
    那么 基础屏行动按钮已隐藏
    假如 所有强制落地选择已处理完毕
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已展示且可点击

  例子:
    | 观察角色ID | 角色ID | 地块归属         | 选择界面     |
    | 1          | 1      | 可购买的无主地块 | 买地选择界面 |
    | 1          | 1      | 自有可加盖地块   | 加盖选择界面 |

  # main_turn_buttons_016 可选行动阶段只展示结束按钮作为推进入口
  场景大纲: main_turn_buttons_016 可选行动阶段只展示结束按钮作为推进入口
    假如 玩家处于包含<可选行动>的可选行动阶段
    并且 没有阻断性界面或动画等待
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已展示且可点击
    并且 基础屏结束按钮不额外写入文字
    并且 基础屏行动按钮未作为可点击推进入口
    并且 <可选行动>仍可作为主动选择入口

  例子:
    | 观察角色ID | 角色ID | 可选行动 |
    | 1          | 1      | 道具槽位 |
    | 1          | 1      | 选择控件 |
    | 1          | 1      | 落地选择 |

  # main_turn_buttons_017 点击结束按钮完成可选行动阶段
  场景大纲: main_turn_buttons_017 点击结束按钮完成可选行动阶段
    假如 玩家处于包含<可选行动>的可选行动阶段
    并且 没有阻断性界面或动画等待
    当 触发基础屏结束按钮
    那么 玩家完成可选行动阶段
    并且 当前待处理选择已按完成语义清除
    并且 没有打开二次确认弹窗
    并且 未派发通用结束动作
    并且 回合继续到<后续流程>
    并且 后续必经流程未被跳过

  例子:
    | 观察角色ID | 角色ID | 可选行动 | 后续流程         |
    | 1          | 1      | 道具槽位 | 投骰移动落地流程 |
    | 1          | 1      | 落地选择 | 回合清理流程     |

  # main_turn_buttons_018 可选行动超时等价于完成可选行动阶段
  场景大纲: main_turn_buttons_018 可选行动超时等价于完成可选行动阶段
    假如 玩家处于包含<可选行动>的可选行动阶段
    当 可选行动阶段超时
    那么 玩家完成可选行动阶段
    并且 当前待处理选择已按完成语义清除
    并且 未触发基础屏行动按钮
    并且 回合继续到<后续流程>

  例子:
    | 观察角色ID | 角色ID | 可选行动 | 后续流程 |
    | 1          | 1      | 道具槽位 | 必经流程 |

  # main_turn_buttons_019 阻断状态隐藏结束按钮
  场景大纲: main_turn_buttons_019 阻断状态隐藏结束按钮
    假如 玩家处于包含<可选行动>的可选行动阶段
    并且 <阻断状态>正在生效
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段

  例子:
    | 观察角色ID | 角色ID | 可选行动 | 阻断状态     |
    | 1          | 1      | 道具槽位 | 选择弹窗     |
    | 1          | 1      | 道具槽位 | 目标选择     |
    | 1          | 1      | 道具槽位 | 黑市界面     |
    | 1          | 1      | 道具槽位 | 弹窗提示     |
    | 1          | 1      | 道具槽位 | 行动动画     |
    | 1          | 1      | 道具槽位 | 移动动画     |
    | 1          | 1      | 道具槽位 | 落地视觉等待 |

  # main_turn_buttons_020 系统等待和空可选阶段不展示结束按钮
  场景大纲: main_turn_buttons_020 系统等待和空可选阶段不展示结束按钮
    假如 玩家处于<阶段状态>
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段
    并且 可选行动阶段不会停在空选择入口

  例子:
    | 观察角色ID | 角色ID | 阶段状态       |
    | 1          | 1      | 扣留等待       |
    | 1          | 1      | 医院等待       |
    | 1          | 1      | 山路等待       |
    | 1          | 1      | 回合间等待     |
    | 1          | 1      | 游戏结束       |
    | 1          | 1      | 空可选行动阶段 |

  # main_turn_buttons_021 通用二次确认屏显示时隐藏结束按钮
  场景大纲: main_turn_buttons_021 通用二次确认屏显示时隐藏结束按钮
    假如 玩家处于包含<可选行动>的可选行动阶段
    并且 通用二次确认屏因<触发源>而显示
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段

  例子:
    | 观察角色ID | 角色ID | 可选行动 | 触发源   |
    | 1          | 1      | 道具槽位 | 购买地块 |
    | 1          | 1      | 道具槽位 | 加盖建筑 |
    | 1          | 1      | 道具槽位 | 强征卡   |
    | 1          | 1      | 道具槽位 | 免税卡   |
