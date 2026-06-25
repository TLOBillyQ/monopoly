# language: zh-CN
# mutation-stamp: sha256=b3ebd8cc4b70d48dcb91b08cd72ae28653e10770a442134125a74d82f854f197
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "可选行动阶段结束按钮",
#   "feature_path": "features/v102/optional_action_end_button.feature",
#   "implementation_hash": "sha256:0c0dbd260162a84d0dd3a5112c2b30bee43c9ec9f2d29e13a28bc544dc10e1df",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 1,
#       "name": "optional_action_end_button_001 行动等待只展示行动按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "ef9847a88fa5f87d5c900a3d5f4a9e7a982d71e83b0b324cfe8479603950cd06",
#       "tested_at": "2026-06-23T03:28:07Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 6,
#       "name": "optional_action_end_button_002 可选行动阶段只展示结束按钮作为推进入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "bbf25eb35672f718101711607fba310eb17343acec2d6c57c4dbc79c4f9cf20d",
#       "tested_at": "2026-06-24T08:08:00Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 6,
#       "name": "optional_action_end_button_003 点击结束按钮完成可选行动阶段",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "ccf798f1cb0c4f5234258b2105e738863812134c76d86002d4cdeec95cac8e9e",
#       "tested_at": "2026-06-23T03:28:08Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 3,
#       "name": "optional_action_end_button_004 可选行动超时等价于完成可选行动阶段",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "1374fd0c799eca8b6a083cbf638e3b93baf19244cbbd16c99e5c0e6971f95baf",
#       "tested_at": "2026-06-23T03:28:08Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 24,
#       "name": "optional_action_end_button_005 阻断状态隐藏结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 24,
#         "Survived": 0,
#         "Total": 24
#       },
#       "scenario_hash": "489387795878d41ea3cf8d1cf0ce90d039db29eee2ee59498a33a2f362679a0a",
#       "tested_at": "2026-06-23T03:28:10Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 15,
#       "name": "optional_action_end_button_006 非手动当前玩家隐藏结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 15,
#         "Survived": 0,
#         "Total": 15
#       },
#       "scenario_hash": "56ffac24e451181ccab7c2e88b24d0f3598210c05b0fdc4dc61538374a851943",
#       "tested_at": "2026-06-23T03:28:11Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 12,
#       "name": "optional_action_end_button_007 系统等待和空可选阶段不展示结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "f944427dc43eaffab39943bd6ec076bac9fc3a5cb39ee505028ef1ef8e9fcfd6",
#       "tested_at": "2026-06-23T03:28:12Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 3,
#       "name": "optional_action_end_button_008 旁观身份只展示被动提示",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "baa19587bcac56a120620dff920badbc5189fefe8b64f313ff69a80d6c5fc4d0",
#       "tested_at": "2026-06-23T03:28:13Z"
#     }
#   ],
#   "tested_at": "2026-06-24T08:08:00Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 可选行动阶段结束按钮

  背景:
    假如 游戏已初始化标准棋盘

  # optional_action_end_button_001 行动等待只展示行动按钮
  场景大纲: optional_action_end_button_001 行动等待只展示行动按钮
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 当前行动控制为人类
    并且 玩家处于行动等待阶段
    当 基础屏为该玩家刷新
    那么 基础屏行动按钮已展示且可点击
    并且 基础屏结束按钮已隐藏
    当 触发基础屏行动按钮
    那么 玩家进入必经回合流程

  例子:
    | 角色ID |
    | 1      |

  # optional_action_end_button_002 可选行动阶段只展示结束按钮作为推进入口
  场景大纲: optional_action_end_button_002 可选行动阶段只展示结束按钮作为推进入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 当前行动控制为人类
    并且 玩家处于包含<可选行动>的可选行动阶段
    并且 没有阻断性界面或动画等待
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已展示且可点击
    并且 基础屏结束按钮不额外写入文字
    并且 基础屏行动按钮未作为可点击推进入口
    并且 <可选行动>仍可作为主动选择入口

  例子:
    | 角色ID | 可选行动 |
    | 1      | 道具槽位 |
    | 1      | 选择控件 |
    | 1      | 落地选择 |

  # optional_action_end_button_003 点击结束按钮完成可选行动阶段
  场景大纲: optional_action_end_button_003 点击结束按钮完成可选行动阶段
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 当前行动控制为人类
    并且 玩家处于包含<可选行动>的可选行动阶段
    并且 没有阻断性界面或动画等待
    当 触发基础屏结束按钮
    那么 玩家完成可选行动阶段
    并且 当前待处理选择已按完成语义清除
    并且 没有打开二次确认弹窗
    并且 未派发通用结束动作
    并且 回合继续到<后续流程>
    并且 后续必经流程未被跳过

  例子:
    | 角色ID | 可选行动 | 后续流程 |
    | 1      | 道具槽位 | 投骰移动落地流程 |
    | 1      | 落地选择 | 回合清理流程     |

  # optional_action_end_button_004 可选行动超时等价于完成可选行动阶段
  场景大纲: optional_action_end_button_004 可选行动超时等价于完成可选行动阶段
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 当前行动控制为人类
    并且 玩家处于包含<可选行动>的可选行动阶段
    当 可选行动阶段超时
    那么 玩家完成可选行动阶段
    并且 当前待处理选择已按完成语义清除
    并且 未触发基础屏行动按钮
    并且 回合继续到<后续流程>

  例子:
    | 角色ID | 可选行动 | 后续流程 |
    | 1      | 道具槽位 | 必经流程 |

  # optional_action_end_button_005 阻断状态隐藏结束按钮
  场景大纲: optional_action_end_button_005 阻断状态隐藏结束按钮
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 玩家处于包含<可选行动>的可选行动阶段
    并且 <阻断状态>正在生效
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段

  例子:
    | 角色ID | 可选行动 | 阻断状态     |
    | 1      | 道具槽位 | 选择弹窗     |
    | 1      | 道具槽位 | 二次确认弹窗 |
    | 1      | 道具槽位 | 目标选择     |
    | 1      | 道具槽位 | 黑市界面     |
    | 1      | 道具槽位 | 弹窗提示     |
    | 1      | 道具槽位 | 行动动画     |
    | 1      | 道具槽位 | 移动动画     |
    | 1      | 道具槽位 | 落地视觉等待 |

  # optional_action_end_button_006 非手动当前玩家隐藏结束按钮
  场景大纲: optional_action_end_button_006 非手动当前玩家隐藏结束按钮
    假如 玩家角色ID为<观察角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    并且 行动角色处于包含<可选行动>的可选行动阶段
    并且 当前行动控制为<行动控制>
    当 基础屏为观察玩家刷新
    那么 基础屏当前行动角色ID为<预期行动角色ID>
    并且 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段
    并且 基础屏只展示被动当前回合提示

  例子:
    | 观察角色ID | 行动角色ID | 预期行动角色ID | 可选行动 | 行动控制 |
    | 4          | 1          | 1              | 道具槽位 | 人类     |
    | 1          | 1          | 1              | 道具槽位 | AI       |
    | 1          | 1          | 1              | 道具槽位 | 托管     |

  # optional_action_end_button_007 系统等待和空可选阶段不展示结束按钮
  场景大纲: optional_action_end_button_007 系统等待和空可选阶段不展示结束按钮
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 玩家处于<阶段状态>
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段
    并且 可选行动阶段不会停在空选择入口

  例子:
    | 角色ID | 阶段状态       |
    | 1      | 扣留等待       |
    | 1      | 医院等待       |
    | 1      | 山路等待       |
    | 1      | 回合间等待     |
    | 1      | 游戏结束       |
    | 1      | 空可选行动阶段 |

  # optional_action_end_button_008 旁观身份只展示被动提示
  场景大纲: optional_action_end_button_008 旁观身份只展示被动提示
    假如 观察身份为<观察身份>
    并且 当前轮到角色ID为<行动角色ID>
    并且 行动角色处于包含<可选行动>的可选行动阶段
    并且 当前行动控制为人类
    当 基础屏为观察身份刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段
    并且 基础屏只展示被动当前回合提示

  例子:
    | 观察身份 | 行动角色ID | 可选行动 |
    | 旁观角色 | 1          | 道具槽位 |
