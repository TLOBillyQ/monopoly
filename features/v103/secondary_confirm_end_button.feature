# language: zh-CN
# mutation-stamp: sha256=68d5c67206ae4c02ecc411eec832d13bc40a0b39b9748c8465a06f920c8e955d
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "75ff20c554347ca10368213cc0e1051762616793c3a60397e8349dff1a609ef0",
#   "feature_name": "通用二次确认屏隐藏结束按钮",
#   "feature_path": "features/v103/secondary_confirm_end_button.feature",
#   "implementation_hash": "sha256:84ff2720ccf3373896bf19ea1ac732f9d638c2383c71fac6f2958c8d6bb71a3a",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 12,
#       "name": "secondary_confirm_end_button_001 通用二次确认屏显示时隐藏结束按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "9f1a370dbd99b049c6f9bad6b0035e861dec82a737afaf9174d349e48a2b83c5",
#       "tested_at": "2026-07-07T03:00:02Z"
#     }
#   ],
#   "tested_at": "2026-07-07T03:00:02Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 通用二次确认屏隐藏结束按钮

  背景:
    假如 游戏已初始化标准棋盘
    并且 玩家角色ID为<角色ID>
    并且 当前轮到角色ID为<角色ID>
    并且 当前行动控制为人类
    并且 玩家处于包含<可选行动>的可选行动阶段

  # secondary_confirm_end_button_001 通用二次确认屏显示时隐藏结束按钮
  场景大纲: secondary_confirm_end_button_001 通用二次确认屏显示时隐藏结束按钮
    假如 通用二次确认屏因<触发源>而显示
    当 基础屏为该玩家刷新
    那么 基础屏结束按钮已隐藏
    并且 基础屏结束按钮不可派发完成可选行动阶段

  例子:
    | 触发源   | 角色ID | 可选行动 |
    | 购买地块 | 1      | 道具槽位 |
    | 加盖建筑 | 1      | 道具槽位 |
    | 强征卡   | 1      | 道具槽位 |
    | 免税卡   | 1      | 道具槽位 |
