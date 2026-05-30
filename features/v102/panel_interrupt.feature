# language: zh-CN
# mutation-stamp: sha256=07ba506abcd97710a213432e27950f53bd8bb3c8149f3b3e1bbe642a8bd9e5af
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "基础屏面板打断行为",
#   "feature_path": "features/v102/panel_interrupt.feature",
#   "implementation_hash": "38dbf4c90aa976a445e9f9b5dc88b2451e76678babdf1334419d84b5c597293d",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 4,
#       "name": "回合外打开的基础屏面板在其他玩家行动时保持开启",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "5994f114c33663d785b6d2c03672aaa8bb40d2aa94302ae716ccaad215ccd59e",
#       "tested_at": "2026-05-24T07:44:32Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 4,
#       "name": "其他玩家的黑市屏打开时基础屏面板保持开启",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "f9e2a7cda05814c5736cedd04091b713ab66c4558641909b16678cf40d66c5e7",
#       "tested_at": "2026-05-24T07:44:33Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 27,
#       "name": "玩家自己的非黑市结算不关闭基础屏面板",
#       "result": {
#         "Errors": 0,
#         "Killed": 27,
#         "Survived": 0,
#         "Total": 27
#       },
#       "scenario_hash": "fadea38e76d57878b8e7f6aab1487a8dce4e5270bc40a5778d621296d2799443",
#       "tested_at": "2026-05-24T07:44:37Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 6,
#       "name": "玩家自己的黑市屏打开时关闭基础屏面板",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "6645836200ee603527b42d3ef671fbc5a3452b4ad9d69c43245c4dd25563c1d1",
#       "tested_at": "2026-05-24T07:44:38Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 9,
#       "name": "自己的黑市屏正在显示时阻止打开基础屏面板",
#       "result": {
#         "Errors": 0,
#         "Killed": 9,
#         "Survived": 0,
#         "Total": 9
#       },
#       "scenario_hash": "9cf262d31bf2d685d658ae9f0f3bc28df62b31537f342063ff42634d7ea31312",
#       "tested_at": "2026-05-24T07:44:39Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 4,
#       "name": "其他玩家的黑市屏正在显示时仍可打开基础屏面板",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "b5d0e9aa2258eec3928dbbb02437facd0774a0a1c071586cca68932a79beb255",
#       "tested_at": "2026-05-24T07:44:40Z"
#     }
#   ],
#   "tested_at": "2026-05-24T07:44:40Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 基础屏面板打断行为

  背景:
    假如 游戏已初始化标准棋盘

  场景大纲: 回合外打开的基础屏面板在其他玩家行动时保持开启
    假如 玩家角色ID为<角色ID>
    并且 玩家在回合外打开<面板>
    当 轮到其他玩家行动
    那么 <面板>屏幕已开启

  例子:
    | 角色ID | 面板     |
    | 1      | 道具图鉴 |
    | 1      | 行动日志 |

  场景大纲: 其他玩家的黑市屏打开时基础屏面板保持开启
    假如 玩家角色ID为<角色ID>
    并且 玩家在回合外打开<面板>
    当 其他玩家的黑市屏打开
    那么 <面板>屏幕已开启

  例子:
    | 角色ID | 面板     |
    | 1      | 道具图鉴 |
    | 1      | 行动日志 |

  场景大纲: 玩家自己的非黑市结算不关闭基础屏面板
    假如 玩家角色ID为<角色ID>
    并且 玩家打开<面板>
    当 玩家自己的<结算>结算开始
    那么 <面板>屏幕已开启

  例子:
    | 角色ID | 面板     | 结算 |
    | 1      | 道具图鉴 | 机会 |
    | 1      | 道具图鉴 | 弹窗 |
    | 1      | 道具图鉴 | 移动 |
    | 1      | 皮肤商店 | 机会 |
    | 1      | 皮肤商店 | 弹窗 |
    | 1      | 皮肤商店 | 移动 |
    | 1      | 行动日志 | 机会 |
    | 1      | 行动日志 | 弹窗 |
    | 1      | 行动日志 | 移动 |

  场景大纲: 玩家自己的黑市屏打开时关闭基础屏面板
    假如 玩家角色ID为<角色ID>
    并且 玩家打开<面板>
    当 玩家自己的黑市屏打开
    那么 <面板>屏幕已关闭

  例子:
    | 角色ID | 面板     |
    | 1      | 道具图鉴 |
    | 1      | 皮肤商店 |
    | 1      | 行动日志 |

  场景大纲: 自己的黑市屏正在显示时阻止打开基础屏面板
    假如 玩家角色ID为<角色ID>
    并且 玩家自己的黑市屏正在显示
    当 触发基础屏<面板>按钮
    那么 <面板>屏幕已关闭
    并且 提示"<提示文本>"已显示

  例子:
    | 角色ID | 面板     | 提示文本         |
    | 1      | 道具图鉴 | 结算中，稍后再开 |
    | 1      | 皮肤商店 | 结算中，稍后再开 |
    | 1      | 行动日志 | 结算中，稍后再开 |

  场景大纲: 其他玩家的黑市屏正在显示时仍可打开基础屏面板
    假如 玩家角色ID为<角色ID>
    并且 其他玩家的黑市屏正在显示
    当 触发基础屏<面板>按钮
    那么 <面板>屏幕已开启

  例子:
    | 角色ID | 面板     |
    | 1      | 道具图鉴 |
    | 1      | 行动日志 |
