# 弹窗屏（modal_choice 与 modal_popup）

弹窗由两个根节点组成：选择弹窗 `modal_choice` 与确认弹窗 `modal_popup`。二者均由 Lua 直接控制显示与隐藏。

## 选择弹窗（modal_choice）

结构建议：
- modal_choice（EImage，根）
  - choice_title（ELabel）
  - choice_body（ELabel）
  - choice_cancel（EButton）
  - choice_option_1（EButton）
  - choice_option_2（EButton）
  - choice_option_3（EButton）
  - choice_option_4（EButton）

显示与隐藏：
- 打开：`EggyLayer:_open_choice_modal`
- 关闭：`EggyLayer:_close_choice_modal`

点击事件（已注册）：
- choice_option_1 -> `choice_select`
- choice_option_2 -> `choice_select`
- choice_option_3 -> `choice_select`
- choice_option_4 -> `choice_select`
- choice_cancel -> `choice_cancel`（当 `allow_cancel ~= false`）

## 确认弹窗（modal_popup）

结构建议：
- modal_popup（ECanvas，根）
  - popup_title（ELabel）
  - popup_body（ELabel）
  - popup_confirm（EButton）
  - popup_confirm_alt（EButton，备用确认）
  - popup_card（EImage）

显示与隐藏：
- 打开：`EggyLayer:push_popup`
- 关闭：`EggyLayer:close_popup`

点击事件（已注册）：
- popup_confirm -> 关闭弹窗
- popup_confirm_alt -> 关闭弹窗

备注：
- 如果只需要一个确认按钮，仍建议保留 `popup_confirm_alt` 为空节点，避免命名缺失。
