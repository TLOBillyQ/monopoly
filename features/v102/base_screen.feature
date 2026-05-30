# language: zh-CN
# mutation-stamp: sha256=f8e901a09f3e2ae4f7c56848d100d0d9f9a1be3db367f519b61b134af380d4ac
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "基础屏",
#   "feature_path": "features/v102/base_screen.feature",
#   "implementation_hash": "09f85f70b4d2f5befdfb7054a89211311d03d574c140044ed563a60e167569e4",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 6,
#       "name": "托管按钮只显示固定文案",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "ac8c2a48cb61b45bd945ebc794d128906b2c3f014dbeea180542f0b9d202f3f0",
#       "tested_at": "2026-05-25T07:35:40Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 12,
#       "name": "自己回合内隐藏皮肤入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "57050eed8476831bf400ecca58335cb96cde47ee7f74676d0a719cb3dd97b2b8",
#       "tested_at": "2026-05-25T07:35:42Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 12,
#       "name": "非自己回合展示皮肤入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "aa4567ead7b8f6b445a119200bd15c136799338a3ae8e615c760dd2d0edff184",
#       "tested_at": "2026-05-25T07:35:44Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 16,
#       "name": "非自己回合时即使输入门已锁皮肤入口仍展示",
#       "result": {
#         "Errors": 0,
#         "Killed": 16,
#         "Survived": 0,
#         "Total": 16
#       },
#       "scenario_hash": "5d8951a85c7e8831bd112b01a8834e444a940a257d8c7035839f0b3710b9574e",
#       "tested_at": "2026-05-25T07:35:46Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 6,
#       "name": "自己回合内即使输入门已锁皮肤入口仍隐藏",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "96771fa1d39b528524bfd22dbe37a0d0554918e37b9f4f0655b2772a1208cca0",
#       "tested_at": "2026-05-25T07:35:47Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 16,
#       "name": "刷新后应用输入锁仍展示非自己回合皮肤入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 16,
#         "Survived": 0,
#         "Total": 16
#       },
#       "scenario_hash": "b12dc535cc3ff1ad15caca1a885bd58680bd38e1b46b03779d6caf365593aa84",
#       "tested_at": "2026-05-25T07:35:49Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 12,
#       "name": "刷新后应用输入锁仍隐藏自己回合皮肤入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "0950da48e40901fafa70a37750536195b21375d88835a46e2b9989228500eae0",
#       "tested_at": "2026-05-25T07:35:51Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 24,
#       "name": "刷新后应用输入锁仍保留基础屏辅助入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 24,
#         "Survived": 0,
#         "Total": 24
#       },
#       "scenario_hash": "96a791603d3846ef8407c2e5d001c196e77056da9e76175e505288f1da06a42b",
#       "tested_at": "2026-05-25T07:35:54Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 6,
#       "name": "未定回合时隐藏皮肤入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "99b0797fd9d0f1f188ec4eabb18455fabea1dd0aa7a1829b515b0f801bd02fb2",
#       "tested_at": "2026-05-25T07:35:55Z"
#     }
#   ],
#   "tested_at": "2026-05-25T07:35:55Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 基础屏

  背景:
    假如 游戏已初始化标准棋盘

  场景大纲: 托管按钮只显示固定文案
    假如 玩家角色ID为<角色ID>
    并且 玩家托管状态为<托管状态>
    当 基础屏刷新
    那么 基础屏托管按钮文字为"<按钮文字>"

  例子:
    | 角色ID | 托管状态 | 按钮文字 |
    | 1      | 关闭     | 托管     |
    | 2      | 开启     | 托管     |

  场景大纲: 自己回合内隐藏皮肤入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    当 基础屏为该玩家刷新
    那么 基础屏皮肤<节点>已隐藏

  例子:
    | 角色ID | 行动角色ID | 节点 |
    | 1      | 1          | 按钮 |
    | 1      | 1          | 文字 |
    | 2      | 2          | 按钮 |
    | 2      | 2          | 文字 |

  场景大纲: 非自己回合展示皮肤入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    当 基础屏为该玩家刷新
    那么 基础屏皮肤<节点>已展示

  例子:
    | 角色ID | 行动角色ID | 节点 |
    | 1      | 2          | 按钮 |
    | 1      | 2          | 文字 |
    | 2      | 1          | 按钮 |
    | 2      | 1          | 文字 |

  场景大纲: 非自己回合时即使输入门已锁皮肤入口仍展示
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    并且 输入门已锁
    当 基础屏为该玩家刷新
    那么 基础屏当前行动角色ID为<预期行动角色ID>
    并且 基础屏皮肤<节点>已展示

  例子:
    | 角色ID | 行动角色ID | 预期行动角色ID | 节点 |
    | 1      | 2          | 2              | 按钮 |
    | 1      | 2          | 2              | 文字 |
    | 2      | 3          | 3              | 按钮 |
    | 2      | 3          | 3              | 文字 |

  场景大纲: 自己回合内即使输入门已锁皮肤入口仍隐藏
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    并且 输入门已锁
    当 基础屏为该玩家刷新
    那么 基础屏皮肤<节点>已隐藏

  例子:
    | 角色ID | 行动角色ID | 节点 |
    | 1      | 1          | 按钮 |
    | 1      | 1          | 文字 |

  # 输入锁只锁操作触摸，不接管皮肤入口显隐。
  # 皮肤入口显隐只由基础屏回合视角决定：自己回合隐藏，非自己回合展示。
  场景大纲: 刷新后应用输入锁仍展示非自己回合皮肤入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    当 基础屏刷新后应用输入锁
    那么 基础屏当前行动角色ID为<预期行动角色ID>
    并且 基础屏皮肤<节点>已展示

  例子:
    | 角色ID | 行动角色ID | 预期行动角色ID | 节点 |
    | 1      | 2          | 2              | 按钮 |
    | 1      | 2          | 2              | 文字 |
    | 2      | 3          | 3              | 按钮 |
    | 2      | 3          | 3              | 文字 |

  场景大纲: 刷新后应用输入锁仍隐藏自己回合皮肤入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    当 基础屏刷新后应用输入锁
    那么 基础屏皮肤<节点>已隐藏

  例子:
    | 角色ID | 行动角色ID | 节点 |
    | 1      | 1          | 按钮 |
    | 1      | 1          | 文字 |
    | 2      | 2          | 按钮 |
    | 2      | 2          | 文字 |

  # 输入锁下仍保留基础屏辅助入口。
  # 行动按钮和道具槽被锁；浏览、托管、日志入口不由输入锁关闭。
  场景大纲: 刷新后应用输入锁仍保留基础屏辅助入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<行动角色ID>
    当 基础屏刷新后应用输入锁
    那么 基础屏当前行动角色ID为<预期行动角色ID>
    并且 基础屏<入口>未被输入锁隐藏
    并且 基础屏<入口>未被输入锁禁用

  例子:
    | 角色ID | 行动角色ID | 预期行动角色ID | 入口     |
    | 1      | 2          | 2              | 道具图鉴 |
    | 1      | 2          | 2              | 托管按钮 |
    | 1      | 2          | 2              | 行动日志 |
    | 2      | 1          | 1              | 道具图鉴 |
    | 2      | 1          | 1              | 托管按钮 |
    | 2      | 1          | 1              | 行动日志 |

  场景大纲: 未定回合时隐藏皮肤入口
    假如 玩家角色ID为<角色ID>
    并且 当前轮次未定
    当 基础屏为该玩家刷新
    那么 基础屏皮肤<节点>已隐藏

  例子:
    | 角色ID | 节点 |
    | 1      | 按钮 |
    | 1      | 文字 |
    | 2      | 按钮 |
