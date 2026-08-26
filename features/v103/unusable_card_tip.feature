# language: zh-CN
# mutation-stamp: sha256=ec0ed838938ab59b20402d7cdcc5e4b9a401f73fa0f23cd1b63fee9c20258e4a
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "8b2f544b12cf00fa2d960b568ed5adaf730ffdecf31881d209d512fc56212ca7",
#   "feature_name": "不可用道具卡点击原因提示",
#   "feature_path": "features/v103/unusable_card_tip.feature",
#   "implementation_hash": "sha256:4748d23e93cf12c6ae06d83ef9d121983c0e38a1bda9c23819a99aae4112686b",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 32,
#       "name": "unusable_card_tip_001 点击无合适目标的道具卡弹出无法使用提示",
#       "result": {
#         "Errors": 0,
#         "Killed": 32,
#         "Survived": 0,
#         "Total": 32
#       },
#       "scenario_hash": "47b77492f993aec467e9cbe200cdc6c5d972b0951cb38439d590b8f677064ee3",
#       "tested_at": "2026-07-22T02:44:02Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 2,
#       "name": "unusable_card_tip_002 点击当前阶段不可用的道具弹出阶段不合法提示",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "f4d026ee0e58545cfec26b3e57c721bb7abb97814d9b3a55eb2d39771cc3fbe5",
#       "tested_at": "2026-07-22T02:44:02Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 3,
#       "name": "unusable_card_tip_003 可用道具卡点击直接进入使用流程",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "60fb3702497ccf06dc4d7c2d06b12a27e67f3d36b8df82b196dd73714ae55adc",
#       "tested_at": "2026-07-22T02:44:03Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 8,
#       "name": "unusable_card_tip_004 可选行动阶段外点击道具卡提示阶段不合法",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "fb9e7b46e3be0451b4acdaf99ed6f65f69c365e456cff4b575fa41aca5d1e084",
#       "tested_at": "2026-07-22T02:44:03Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "unusable_card_tip_005 托管中阶段外点击道具卡照常提示",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "bab6a0e34035f69b403cb3876fd8ad30d73a15a31ddabcbf920ac65b10c40f79",
#       "tested_at": "2026-07-22T02:44:03Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "unusable_card_tip_006 弹层显示期间点击道具槽位无提示",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "accf17362617e286adfb09f57dbfb6bd2af5d13077f1161923c135be3fb541ec",
#       "tested_at": "2026-07-22T02:44:03Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "unusable_card_tip_007 阶段外点击空道具槽位无反馈",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "273451a4a3e0a5aa2d7da60d16a8ec9477ca62571c1c4f75aee0c65afa90ec39",
#       "tested_at": "2026-07-22T02:44:03Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 1,
#       "name": "unusable_card_tip_008 强征卡站在对手地上现金不足提示余额不足",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "ba0069f1574a0ee71f4bc34e7cd0d4f23502f214b812505997b8a83caaf6a095",
#       "tested_at": "2026-07-22T02:44:04Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 1,
#       "name": "unusable_card_tip_009 同组效果卡本回合已用提示同组已用文案",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "c746207ba371957d357cbb53ce38ac8fa3d084ea94956400ffde047f2b579d4a",
#       "tested_at": "2026-07-22T02:44:04Z"
#     }
#   ],
#   "tested_at": "2026-07-22T02:44:04Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 不可用道具卡点击原因提示

  背景:
    假如 游戏已初始化标准棋盘
    并且 玩家角色ID为1

  # unusable_card_tip_001 点击无合适目标的道具卡弹出无法使用提示
  # 编排纪律(ADR 0038):局面步骤必须先于持卡开窗——窗口 offer 面在开窗那一刻物化,
  # 断言的是「窗口打开那一刻的局面判定」;开窗后才铺局面属编排违例(#216 假绿)。
  场景大纲: unusable_card_tip_001 点击无合适目标的道具卡弹出无法使用提示
    假如 当前轮到角色ID为1
    并且 当前行动控制为人类
    并且 玩家处于包含道具槽位的可选行动阶段
    并且 <无目标局面>
    并且 玩家在槽位1持有<道具>
    当 玩家点击道具槽位1
    那么 提示"没有合适的目标，该卡当前无法使用"已显示
    并且 道具操作面板未弹出
    并且 槽位1仍持有<道具>

  例子:
    | 道具   | 无目标局面                 |
    | 请神卡 | 所有对手都没有神灵         |
    | 请神卡 | 所有对手都只有穷神         |
    | 送神卡 | 自己没有穷神附身           |
    | 送神卡 | 所有对手都有天使守护       |
    | 穷神卡 | 所有对手都有天使守护       |
    | 偷窃卡 | 所有对手都没有道具         |
    | 偷窃卡 | 所有对手都有天使守护       |
    | 均富卡 | 所有对手都有天使守护       |
    | 流放卡 | 所有对手都有天使守护       |
    | 查税卡 | 所有对手都有天使守护       |
    | 查税卡 | 所有对手都已出局           |
    | 导弹卡 | 所有对手都有天使守护       |
    | 路障卡 | 前后三格内没有可放置的格子 |
    | 怪兽卡 | 附近没有可拆除的建筑       |
    | 强征卡 | 自己不站在对手地上         |
    | 免费卡 | 自己不站在对手地上         |

  # unusable_card_tip_002 点击当前阶段不可用的道具弹出阶段不合法提示
  场景大纲: unusable_card_tip_002 点击当前阶段不可用的道具弹出阶段不合法提示
    假如 当前轮到角色ID为1
    并且 当前行动控制为人类
    并且 玩家处于包含道具槽位的可选行动阶段
    并且 玩家在槽位1持有<道具>
    当 玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"已显示
    并且 道具操作面板未弹出
    并且 槽位1仍持有<道具>

  例子:
    | 道具       |
    | 免税卡     |
    | 骰子加倍卡 |

  # unusable_card_tip_003 可用道具卡点击直接进入使用流程
  场景大纲: unusable_card_tip_003 可用道具卡点击直接进入使用流程
    假如 当前轮到角色ID为1
    并且 当前行动控制为人类
    并且 玩家处于包含道具槽位的可选行动阶段
    并且 玩家在槽位1持有<道具>
    并且 <道具>当前可用
    当 玩家点击道具槽位1
    那么 玩家进入<道具>的使用流程
    并且 道具操作面板未弹出

  例子:
    | 道具       |
    | 遥控骰子卡 |
    | 路障卡     |
    | 查税卡     |

  # unusable_card_tip_004 可选行动阶段外点击道具卡提示阶段不合法
  场景大纲: unusable_card_tip_004 可选行动阶段外点击道具卡提示阶段不合法
    假如 玩家在槽位1持有<道具>
    并且 当前处于<阶段外时段>
    当 玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"已显示
    并且 道具操作面板未弹出
    并且 槽位1仍持有<道具>

  例子:
    | 道具   | 阶段外时段             |
    | 请神卡 | 自己回合的行动等待阶段 |
    | 免费卡 | 自己回合的行动等待阶段 |
    | 路障卡 | 他人回合               |
    | 免税卡 | 他人回合               |

  # unusable_card_tip_005 托管中阶段外点击道具卡照常提示
  场景: unusable_card_tip_005 托管中阶段外点击道具卡照常提示
    假如 玩家在槽位1持有请神卡
    并且 玩家托管状态为开启
    并且 当前处于自己回合的行动等待阶段
    当 玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"已显示
    并且 道具操作面板未弹出

  # unusable_card_tip_006 自己屏幕上有弹层期间点击道具槽位无提示
  场景: unusable_card_tip_006 自己屏幕上有弹层期间点击道具槽位无提示
    假如 玩家在槽位1持有请神卡
    并且 当前处于他人回合
    并且 自己屏幕上有弹层正在显示
    当 玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"未显示
    并且 道具操作面板未弹出

  # unusable_card_tip_007 阶段外点击空道具槽位无反馈
  场景: unusable_card_tip_007 阶段外点击空道具槽位无反馈
    假如 玩家道具槽位1为空
    并且 当前处于他人回合
    当 玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"未显示
    并且 道具操作面板未弹出

  # unusable_card_tip_008 强征卡站在对手地上现金不足提示余额不足
  # 编排纪律(ADR 0038,#224):局面先于持卡开窗——断言的是开窗那一刻的 offer 面。
  场景大纲: unusable_card_tip_008 强征卡站在对手地上现金不足提示余额不足
    假如 当前轮到角色ID为1
    并且 当前行动控制为人类
    并且 玩家处于包含道具槽位的可选行动阶段
    并且 自己站在对手地上且现金不足以支付强征费用
    并且 玩家在槽位1持有<道具>
    当 玩家点击道具槽位1
    那么 提示"你的现金不足，该卡当前无法使用"已显示
    并且 道具操作面板未弹出
    并且 槽位1仍持有<道具>

  例子:
    | 道具   |
    | 强征卡 |

  # unusable_card_tip_009 同组效果卡本回合已用提示同组已用文案
  # 编排纪律(ADR 0038,#224):局面先于持卡开窗;目标卡同组已用即不可 offer,
  # 开窗依赖填充卡回退(#216)。
  场景大纲: unusable_card_tip_009 同组效果卡本回合已用提示同组已用文案
    假如 当前轮到角色ID为1
    并且 当前行动控制为人类
    并且 玩家处于包含道具槽位的可选行动阶段
    并且 本回合已使用过<道具>
    并且 玩家在槽位1持有<道具>
    当 玩家点击道具槽位1
    那么 提示"本回合已使用过同类效果的卡，该卡当前无法使用"已显示
    并且 道具操作面板未弹出
    并且 槽位1仍持有<道具>

  例子:
    | 道具       |
    | 遥控骰子卡 |

  # unusable_card_tip_010 对手屏幕上有弹层时自己的点击照常提示
  # 模态画布逐席位切(choice_helpers.switch_modal_canvas 只给操作席切模态屏,旁观者
  # 留在基础屏),对手的选择屏/黑市/弹窗没盖住我的屏幕,我的点击不该被连坐静默。
  场景: unusable_card_tip_010 对手屏幕上有弹层时自己的点击照常提示
    假如 玩家在槽位1持有请神卡
    并且 当前处于他人回合
    并且 对手屏幕上有弹层正在显示
    当 玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"已显示
    并且 道具操作面板未弹出

  # unusable_card_tip_011 点击事件未携带身份时按无主处理静默
  # #341:解析链只到 client_role 为止——事件解析不出身份即返回 nil,点击按
  # 无主处理(与空槽位同口径静默),不得把 A 的点击当成 B 的。#601 退役
  # 「上一次点击者缓存」后,跨点击的身份污染通道整体消失,本场景钉终态语义。
  场景大纲: unusable_card_tip_011 点击事件未携带身份时按无主处理静默
    假如 玩家在槽位1持有<道具>
    并且 当前处于他人回合
    当 点击事件未携带身份的玩家点击道具槽位1
    那么 提示"现阶段该卡无法使用"未显示
    并且 道具操作面板未弹出
    并且 槽位1仍持有<道具>

  例子:
    | 道具   |
    | 请神卡 |
    | 免税卡 |
