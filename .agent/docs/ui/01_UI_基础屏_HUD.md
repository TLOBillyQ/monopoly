# UI：基础屏（HUD）

对应策划：回合制；行动前/行动中/行动后三阶段；道具卡槽 5；骰子 1~3；投掷按钮；结束回合按钮；10 秒默认确认；提示/Toast。

## Root

- `Canvas_GameHUD`（`ECanvas`）

## 层级结构（命名 / 类型）

```text
Canvas_GameHUD (ECanvas)
└─ Img_HUD_Root (EImage)
   ├─ Img_HUD_BG (EImage)
   ├─ Img_HUD_PlayerBar (EImage)                  # 2~4人信息区
   │  ├─ Img_HUD_Player_01 (EImage)
   │  │  ├─ Img_HUD_Player_01_Avatar (EImage)
   │  │  ├─ Lbl_HUD_Player_01_Name (ELabel)
   │  │  ├─ Lbl_HUD_Player_01_Cash (ELabel)       # 现金
   │  │  └─ Lbl_HUD_Player_01_State (ELabel)      # 停留/附身/破产等
   │  ├─ Img_HUD_Player_02 (EImage) ...
   │  ├─ Img_HUD_Player_03 (EImage) ...
   │  └─ Img_HUD_Player_04 (EImage) ...
   ├─ Img_HUD_ItemBar (EImage)                    # 道具栏（5槽）
   │  ├─ Img_HUD_ItemSlot_01 (EImage)             # 可点击（打开“使用/丢弃”二选一）
   │  │  ├─ Img_HUD_ItemSlot_01_Icon (EImage)
   │  │  └─ Lbl_HUD_ItemSlot_01_Badge (ELabel)    # 可选：数量/角标
   │  ├─ Img_HUD_ItemSlot_02 (EImage)
   │  ├─ Img_HUD_ItemSlot_03 (EImage)
   │  ├─ Img_HUD_ItemSlot_04 (EImage)
   │  └─ Img_HUD_ItemSlot_05 (EImage)
   ├─ Img_HUD_DicePanel (EImage)                  # 行动前：骰子+投掷
   │  ├─ Img_HUD_Dice_01 (EImage)                 # 1~3 个，按座驾配置显示
   │  ├─ Img_HUD_Dice_02 (EImage)
   │  ├─ Img_HUD_Dice_03 (EImage)
   │  ├─ Lbl_HUD_DiceHint (ELabel)                # 遥控骰子引导：“点击骰子可更改点数”
   │  └─ Btn_HUD_Roll (EButton)                   # “投掷”
   ├─ Img_HUD_TurnPanel (EImage)                  # 行动后：结束回合
   │  └─ Btn_HUD_EndTurn (EButton)                # “结束回合”
   ├─ Img_HUD_Timer (EImage)
   │  └─ Lbl_HUD_TimerText (ELabel)               # “剩余10秒…”
   └─ Img_HUD_Toast (EImage)
      └─ Lbl_HUD_ToastText (ELabel)
```

## 交互点（可点击）

- `Btn_HUD_Roll`
- `Btn_HUD_EndTurn`
- `Img_HUD_ItemSlot_01..05`
- `Img_HUD_Dice_01..03`（仅在使用“遥控骰子卡”后允许点击改点数）

## 显隐规则（建议）

- 行动前：`Img_HUD_DicePanel.visible=true`，`Img_HUD_TurnPanel.visible=false`
- 行动中（全自动）：两面板都隐藏或禁用；仅允许展示提示
- 行动后：`Img_HUD_TurnPanel.visible=true`，`Img_HUD_DicePanel.visible=false`

