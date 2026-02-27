# UI 节点引用层重构：对齐 UIManagerNodes v2

本可执行计划是活文档。实施过程中必须持续更新"进度""意外与发现""决策日志""结果与复盘"。

本文件遵循 `.agents/harness/PLANS.md`。输入依据：`.agents/research.md`（2026-02-27）。


## 目的 / 全局视角

`Data/UIManagerNodes.lua` 是 Eggitor 插件导出的 UI 节点注册表，是 presentation 层查询所有 UI 节点的唯一数据源。数据源已更新到 v2（179 节点），系统性地给节点添加了屏幕前缀（`基础_`、`黑市_`、`始终显示_` 等）。当前代码中的节点名几乎全部与数据源不匹配，运行时 `query_node` 返回 nil，所有 UI 功能静默失效。

改完后的可观察结果：presentation 层中所有节点名与数据源一致，`query_node` 能正确返回节点对象，回归测试通过。同时落地 7 项功能决策（移除取消按钮、扩展槽位等），使代码与 Eggitor 设计同步。

验收方式：运行 `lua tests/internal/dep_rules.lua` 输出 `dep_rules ok`；运行 `lua tests/regression.lua` 输出 `All regression checks passed`；全文搜索无残留旧节点名。


## 进度

- [ ] 里程碑 M1：重写 shared 层节点常量（UINodes、UIAliases、MarketLayout）
- [ ] 里程碑 M2：更新硬编码引用（UITurnEffects、ActionAnim、ActionAnimDice）
- [ ] 里程碑 M3：更新 UI 状态构建（state.lua、assets.lua）
- [ ] 里程碑 M4：适配消费端（移除 cancel/confirm/body/no_action 相关逻辑）
- [ ] 验证：dep_rules + regression + 残留搜索


## 意外与发现

（实施时填写）


## 决策日志

- 决策：popup 和 player_choice 不需要取消按钮。
  理由：数据源中卡牌展示屏和玩家选择屏没有独立取消按钮节点，UI 设计已移除此交互。popup 通过 dismiss_nodes（灰底/图片点击）关闭。
  日期/作者：2026-02-27 / 用户。

- 决策：行动日志切换入口从双节点（倒计时时钟 + 行动日志按钮）缩减为单节点（`始终显示_行动日志图标`）。
  理由：`倒计时时钟` 在数据源中不存在。`始终显示_行动日志图标` 是 EButton 类型，足够承担切换功能。
  日期/作者：2026-02-27 / 用户。

- 决策：`基础_无法行动提示` 废弃，复用 `基础_行动提示` 显示无法行动文本。
  理由：数据源中无此节点。行动提示节点已存在且功能相近，可复用。
  日期/作者：2026-02-27 / 用户。

- 决策：`玩家选择_副标题` 废弃。
  理由：数据源中无此节点，UI 设计已去掉副标题文本。
  日期/作者：2026-02-27 / 用户。

- 决策：骰子动画简化，移除摇骰子结束特效 1/2。
  理由：数据源中无 `骰子-摇骰子结束特效1/2`，改为旋转结束后直接显示点数。
  日期/作者：2026-02-27 / 用户。

- 决策：玩家选择槽位从 3 扩展到 4。
  理由：数据源已有 `玩家选择_槽位4`。
  日期/作者：2026-02-27 / 用户。

- 决策：`位置_确认按钮` 不接入代码。
  理由：当前位置选择流程不需要确认步骤。
  日期/作者：2026-02-27 / 用户。


## 结果与复盘

（完成时填写）


## 背景与导读

本仓库是一个大富翁游戏，使用 Lua 编写，运行在 EggyGo 引擎上。presentation 层（`src/presentation/`）负责将游戏状态渲染到 UI 上，并捕获玩家点击事件。

**数据来源**：`Data/UIManagerNodes.lua` — Eggitor 插件自动导出的节点注册表，key 是节点 ID，value 是 `{中文名, 类型}` 二元组。引擎的 `UIManager.query_nodes_by_name(中文名)` 依赖此表查找节点。

**节点引用架构**：代码不直接硬编码中文节点名，而是通过以下文件做语义映射：

`src/presentation/shared/UINodes.lua` 是核心常量表，定义了所有语义 key 到中文节点名的映射（如 `buttons.action = "行动按钮"`）。它被 presentation 层中大约 15 个文件 require。

`src/presentation/shared/UIAliases.lua` 提供英文别名到中文名的映射（如 `btn_next → "行动按钮"`），供外部或快捷引用使用。

`src/presentation/shared/MarketLayout.lua` 专门定义黑市屏的节点布局（10 个购买项、10 个标签、10 个底框等）。

此外还有两处硬编码中文名未通过 UINodes：`src/presentation/ui/UITurnEffects.lua` 硬编码了 4 个高亮动效名和 3 个行动提示名；`src/presentation/render/ActionAnim.lua` 硬编码了 9 个骰子屏节点名。

`src/presentation/api/ui_view_service/state.lua` 中的 `build_ui_state()` 构建初始 UI 状态对象，其中包含道具槽位名、popup_screen、choice_screens 等结构，它们引用 UINodes 中的值。

`src/presentation/api/ui_view_service/assets.lua` 中的 `init_ui_assets()` 硬编码了 `"道具槽位" .. index` 来初始化道具图标。

消费端文件通过读取上述常量来操作 UI 节点（设置文本、可见性、触控等）。当节点名与数据源不匹配时，`query_node` 返回 nil，操作静默失败。


## 工作计划


### 里程碑 M1：重写 shared 层节点常量

本里程碑将 UINodes、UIAliases、MarketLayout 三个文件中的所有中文节点名更新为数据源 v2 的实际值。完成后，所有通过这三个文件间接引用节点的代码将自动获得正确的名称。

**文件 1：`src/presentation/shared/UINodes.lua`**

整文件重写。以下列出每个字段的目标值。

`nodes.canvas`：新增 `dice = "骰子屏"`，其余 9 个 canvas 名称不变（数据源一致）。

`nodes.action_log`：删除 `toggle_image` 字段（`倒计时时钟` 不存在）。`toggle_button` 改为 `"始终显示_行动日志图标"`。`log_label` 保持 `"日志"`。`toggle_targets` 改为只包含 `toggle_button` 一个元素的数组。

`nodes.buttons`：`action` 从 `"行动按钮"` 改为 `"基础_行动按钮"`。`auto` 从 `"托管按钮"` 改为 `"始终显示_托管按钮"`。`close` 从 `"关闭"` 改为 `"黑市_关闭"`。删除 `cancel` 字段（popup/player_choice 不需要取消按钮）。`building_confirm`、`building_cancel`、`remote_cancel` 不变。

`nodes.labels`：`auto` 从 `"托管_文本"` 改为 `"始终显示_文本"`。`countdown` 从 `"倒计时文本"` 改为 `"基础_倒计时"`。删除 `no_action` 字段。

新增 `nodes.action_prompt` 分组，将原本散布在 UITurnEffects.lua 中的硬编码名收入此处：`label = "基础_行动提示"`，`effect = "基础_行动提示特效"`（原 `基础_星星中心爆开`），`other_player = "基础_其他玩家行动提示"`。

`nodes.effects`：`auto` 从 `"基础屏-AI托管光效"` 改为 `"始终显示_托管按钮特效"`。新增 `player_highlight` 数组：`{ "基础_玩家1行动动效", "基础_玩家2行动动效", "基础_玩家3行动动效", "基础_玩家4行动动效" }`（原 `基础_玩家N高亮光效`）。

`nodes.choice.player`：删除 `body` 字段。删除 `cancel` 字段。`slots` 扩展为 4 个元素，追加 `"玩家选择_槽位4"`。`root` 和 `title` 不变。

`nodes.choice.target`：`slots` 从 `"位置前1"` 等改为 `"位置_前1"` 等（加下划线）。`under` 从 `"位置脚下"` 改为 `"位置_脚下"`。删除 `cancel` 字段。`root`、`title`、`body` 不变。

`nodes.choice.remote` 和 `nodes.choice.building`：所有字段不变（数据源一致）。

`nodes.popup`：删除 `confirm` 字段。`root`、`title`、`card`、`dismiss_nodes` 不变。

`nodes.bankruptcy`：不变。

`nodes.panel`：6 个格式字符串全部加 `基础_` 前缀，如 `"玩家%s名字"` 改为 `"基础_玩家%s名字"`。

新增 `nodes.dice` 分组：`screen = "骰子屏"`，`spin = "骰子_旋转中"`，`faces = { "骰子_点数1", "骰子_点数2", "骰子_点数3", "骰子_点数4", "骰子_点数5", "骰子_点数6" }`。

`required_click_nodes` 函数：移除 `nodes.buttons.cancel` 条目。追加 `nodes.choice.player.slots[4]`。`toggle_targets` 迭代自动适配（只有 1 个元素）。

**文件 2：`src/presentation/shared/UIAliases.lua`**

`alias_map` 中的静态映射全部更新：`btn_next → "基础_行动按钮"`，`btn_auto → "始终显示_托管按钮"`，`panel_turn → "基础_倒计时"`，`market_confirm_button → "黑市_购买按钮"`，`market_cancel_button → "黑市_关闭"`，`market_price_label → "黑市_售价"`，`market_selected_card → "黑市_选中卡牌"`。

item_slot 循环：`"道具槽位" .. idx` 改为 `"基础_道具槽位" .. idx`。

panel_player 循环：`"玩家" .. idx` 改为 `"基础_玩家" .. idx`（影响名字、现金、地块数量、总资产 4 个条目）。

market_item 循环：`"黑市购买项"` 改为 `"黑市_购买项"`，`"道具名称"` 改为 `"黑市_道具名称"`，`"底框"` 改为 `"黑市_底框"`。

**文件 3：`src/presentation/shared/MarketLayout.lua`**

`confirm_button` 从 `"黑市购买按钮"` 改为 `"黑市_购买按钮"`。`cancel_button` 从 `"关闭"` 改为 `"黑市_关闭"`。`price_label` 从 `"售价：100"` 改为 `"黑市_售价"`。`selected_card` 和 `icon_placeholder` 从 `"选中卡牌"` 改为 `"黑市_选中卡牌"`。`title` 从 `"黑市"` 保持不变（这是显示文本不是节点名）。

`item_buttons`：`"黑市购买项N"` 改为 `"黑市_购买项N"`。`item_labels`：`"道具名称N"` 改为 `"黑市_道具名称N"`。`item_frames`：`"底框N"` 改为 `"黑市_底框N"`。

M1 完成证明：UINodes、UIAliases、MarketLayout 中所有中文名都能在 `Data/UIManagerNodes.lua` 中找到精确匹配（除 `日志` 和 canvas 名外，它们本身不变）。


### 里程碑 M2：更新硬编码引用

本里程碑消除 UITurnEffects 和 ActionAnim/ActionAnimDice 中的硬编码中文名，改为引用 UINodes 常量。

**文件 4：`src/presentation/ui/UITurnEffects.lua`**

在文件顶部添加 `local ui_nodes = require("src.presentation.shared.UINodes")`。

将 `highlight_nodes` 数组从硬编码 4 个字符串改为 `ui_nodes.effects.player_highlight`。

将 `_get_prompt_nodes()` 中 `runtime.query_node("基础_星星中心爆开")` 改为 `runtime.query_node(ui_nodes.action_prompt.effect)`；`runtime.query_node("基础_行动提示")` 改为 `runtime.query_node(ui_nodes.action_prompt.label)`。

将 `_get_other_action_prompt_label_node()` 中 `runtime.query_node("基础_其他玩家行动提示")` 改为 `runtime.query_node(ui_nodes.action_prompt.other_player)`。

**文件 5：`src/presentation/render/ActionAnim.lua`**

删除 `dice_screen_nodes` 局部表。在文件顶部添加 `local ui_nodes = require("src.presentation.shared.UINodes")`。

将 `handlers.play_roll_dice_screen` 调用中传入的 `dice_screen_nodes = dice_screen_nodes` 改为 `dice_screen_nodes = ui_nodes.dice`。

**文件 6：`src/presentation/render/ActionAnimDice.lua`**

在 `play_roll_dice_screen` 函数中，移除对 `dice_nodes.fx_end_1` 和 `dice_nodes.fx_end_2` 的所有引用。具体改动：

第 43-44 行删除 `fx_end_1 = runtime.query_node(dice_nodes.fx_end_1)` 和 `fx_end_2 = ...`。第 53-54 行删除 `nodes.fx_end_1.visible = false` 和 `nodes.fx_end_2.visible = false`。第 77-78 行删除 `nodes.fx_end_1.visible = true` 和 `nodes.fx_end_2.visible = true`。第 93-94 行删除 `nodes.fx_end_1.visible = false` 和 `nodes.fx_end_2.visible = false`。

M2 完成证明：`src/presentation/` 中不再有任何直接硬编码的中文节点名（除了日志文本和 `"确定"` / `"取消"` 等 UI 显示文本）。


### 里程碑 M3：更新 UI 状态构建

本里程碑更新 state.lua 和 assets.lua 中构建的初始 UI 状态对象，使其引用新的 UINodes 值。

**文件 7：`src/presentation/api/ui_view_service/state.lua`**

`item_slots` 数组：`"道具槽位N"` 改为 `"基础_道具槽位N"`（5 个条目）。

`popup_screen` 对象：删除 `confirm = ui_nodes.popup.confirm` 一行（字段已从 UINodes 移除）。

`choice_screens` 中 `player` screen：删除 `body` 行（`ui_nodes.choice.player.body` 已不存在）。删除 `cancel` 行（`ui_nodes.choice.player.cancel` 已不存在）。

`choice_screens` 中 `target` screen：删除 `cancel` 行（`ui_nodes.choice.target.cancel` 已不存在）。

`auto_control_nodes`：已通过 UINodes 间接引用，无需额外改动（`ui_nodes.buttons.auto` 和 `ui_nodes.labels.auto` 已在 M1 更新）。

**文件 8：`src/presentation/api/ui_view_service/assets.lua`**

第 18 行 `core.set_item_slot_image("道具槽位" .. tostring(index), image_key)` 改为 `core.set_item_slot_image("基础_道具槽位" .. tostring(index), image_key)`。

M3 完成证明：`build_ui_state()` 返回的对象中所有节点名与数据源一致。


### 里程碑 M4：适配消费端

本里程碑更新所有读取被移除字段（cancel、confirm、body、no_action、toggle_image）的消费端文件。

**文件 9：`src/presentation/interaction/UIEventBindings.lua`**

`register_node_click` 函数中，移除对 `ui_nodes.action_log.toggle_image` 的所有特殊日志分支（第 31-32 行和第 43-44 行和第 50-51 行中判断 `name == ui_nodes.action_log.toggle_image` 的 if 分支）。保留对 `toggle_button` 的日志。

`enable_action_log_toggle_touch` 函数：`toggle_targets` 现在只有 1 个元素，逻辑自动适配，不需要修改函数签名。但可以简化内部逻辑，移除多节点回退路径（可选优化，非必须）。

**文件 10：`src/presentation/interaction/UITouchPolicy.lua`**

`set_action_log_toggle_touch` 函数第 40 行的 fallback `or { ui_nodes.action_log.toggle_button, ui_nodes.action_log.toggle_image }` 改为 `or { ui_nodes.action_log.toggle_button }`，因为 `toggle_image` 字段已删除。

**文件 11：`src/presentation/interaction/UIInputLockPolicy.lua`**

移除第 33-35 行 `popup_screen.confirm` 相关逻辑：`if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then ui:set_touch_enabled(ui.popup_screen.confirm, _can_popup_confirm()) end`。popup 关闭改为通过 dismiss_nodes 点击实现（已在 PopupIntents.lua 中注册）。

移除第 63-66 行同样的 `popup_screen.confirm` 输入锁例外逻辑。

保留第 69 行 `set_auto_controls_touch` 和第 70 行 `set_action_log_toggle_touch` 例外。

**文件 12：`src/presentation/interaction/intent_builders/BasicIntents.lua`**

移除第 51-58 行的 `ui_nodes.buttons.cancel` route spec（整个 `{ name = ui_nodes.buttons.cancel, build_intent = ... }` 块）。这个 route spec 原本处理 popup_confirm 和 choice_cancel，popup 关闭已由 PopupIntents 的 dismiss_nodes 处理，choice_cancel 不再需要。

**文件 13：`src/presentation/ui/PopupRenderer.lua`**

`show_popup` 函数中，第 163 行 `ui:set_button(popup.confirm, payload.button_text or "确认")` 删除（confirm 字段已移除）。

`hide_popup` 函数不需要改动（不引用 confirm）。

**文件 14：`src/presentation/ui/choice_screen_service/openers.lua`**

`open_player_or_remote_screen` 函数中：删除第 37-38 行对 `screen.body` 的 set_label 调用（player screen 不再有 body；remote screen 仍有 body，需要条件判断：仅当 `screen.body` 存在时才 set_label）。删除第 58-65 行对 `screen.cancel` 的整个 if 块（player screen 不再有 cancel；remote screen 仍有 cancel，需要条件判断：仅当 `screen.cancel` 存在时才处理）。由于 player 和 remote 共用此函数，改为用 nil 检查保护：`if screen.body then ui:set_label(screen.body, ...) end` 和 `if screen.cancel then ... end`。这样 player（无 body/cancel）和 remote（有 body/cancel）都能正确处理。

`open_target_screen` 函数中：删除第 122-127 行对 `screen.cancel` 的整个块。target screen 不再有 cancel。

**文件 15：`src/presentation/ui/UIPanelPresenter.lua`**

第 170-173 行原本操作 `ui_nodes.labels.countdown` 和 `ui_nodes.labels.no_action`。`countdown` 已在 M1 中更新为新名。`no_action` 已删除，改为复用 `action_prompt.label`：将第 172-173 行 `ui:set_visible(ui_nodes.labels.no_action, ...)` 和 `ui:set_label(ui_nodes.labels.no_action, ...)` 改为操作 `ui_nodes.action_prompt.label`。注意 `action_prompt.label` 同时被 UITurnEffects 使用，需确保 UIPanelPresenter 在 no_action 为 false 时不会覆盖 UITurnEffects 设置的行动提示文本。做法是：当 `no_action_visible == true` 时，设置该节点文本为 no_action_text 并显示；当 `no_action_visible == false` 时，不操作此节点（由 UITurnEffects 控制）。

M4 完成证明：所有消费端代码不再引用已删除的字段，不会触发 nil 错误。


## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

M1：

1. 编辑 `src/presentation/shared/UINodes.lua`，按上述规格重写。
2. 编辑 `src/presentation/shared/UIAliases.lua`，按上述规格重写。
3. 编辑 `src/presentation/shared/MarketLayout.lua`，按上述规格重写。

M2：

4. 编辑 `src/presentation/ui/UITurnEffects.lua`，引入 ui_nodes，消除硬编码。
5. 编辑 `src/presentation/render/ActionAnim.lua`，引用 `ui_nodes.dice` 替代局部表。
6. 编辑 `src/presentation/render/ActionAnimDice.lua`，移除 `fx_end_1/fx_end_2`。

M3：

7. 编辑 `src/presentation/api/ui_view_service/state.lua`，更新 item_slots 和移除 confirm/body/cancel。
8. 编辑 `src/presentation/api/ui_view_service/assets.lua`，更新道具槽位前缀。

M4：

9. 编辑 `src/presentation/interaction/UIEventBindings.lua`，移除 toggle_image 分支。
10. 编辑 `src/presentation/interaction/UITouchPolicy.lua`，更新 fallback。
11. 编辑 `src/presentation/interaction/UIInputLockPolicy.lua`，移除 popup confirm 逻辑。
12. 编辑 `src/presentation/interaction/intent_builders/BasicIntents.lua`，移除 cancel route。
13. 编辑 `src/presentation/ui/PopupRenderer.lua`，移除 confirm 按钮操作。
14. 编辑 `src/presentation/ui/choice_screen_service/openers.lua`，条件化 body/cancel。
15. 编辑 `src/presentation/ui/UIPanelPresenter.lua`，no_action 逻辑改用 action_prompt.label。


## 验证与验收

运行以下命令（工作目录 `/Users/billyq/Dev/Github/Lua/monopoly`）：

    lua tests/internal/dep_rules.lua

预期输出：`dep_rules ok`。

    lua tests/regression.lua

预期输出：`All regression checks passed (154)` 或更高数字。

残留搜索：在 `src/` 中搜索以下旧节点名，预期零匹配：

    倒计时时钟  倒计时文本  "行动按钮"  "托管按钮"  "取消按钮"
    售价：100   "选中卡牌"  AI托管光效  玩家选择_副标题
    基础_无法行动  骰子-骰子  骰子-旋转  骰子-摇

如果回归数字下降，需逐条排查失败用例。如果 dep_rules 失败，说明某个 interaction 文件错误引用了 game 层模块。


## 可重复性与恢复

每个里程碑独立可提交。如果某个里程碑导致回归失败，只需 `git checkout` 回退该里程碑涉及的文件。文件列表按里程碑：

M1：`UINodes.lua`、`UIAliases.lua`、`MarketLayout.lua`。
M2：`UITurnEffects.lua`、`ActionAnim.lua`、`ActionAnimDice.lua`。
M3：`state.lua`、`assets.lua`。
M4：`UIEventBindings.lua`、`UITouchPolicy.lua`、`UIInputLockPolicy.lua`、`BasicIntents.lua`、`PopupRenderer.lua`、`openers.lua`、`UIPanelPresenter.lua`。


## 产物与备注

数据源基线（v2，179 节点）：`Data/UIManagerNodes.lua`，commit 已入库。

research 文档：`.agents/research.md`，包含完整更名表和决策记录。


## 接口与依赖

本轮不新增依赖，不改公开接口。UIViewService 对外 API 签名不变。UINodes 的导出表结构有以下变化：

删除的字段：`action_log.toggle_image`、`buttons.cancel`、`labels.no_action`、`effects.auto`（路径不变但值改了）、`choice.player.body`、`choice.player.cancel`、`choice.target.cancel`、`popup.confirm`。

新增的字段：`canvas.dice`、`action_prompt`（整个分组）、`effects.player_highlight`、`dice`（整个分组）、`choice.player.slots[4]`。

所有消费端必须适配这些字段变化，这是 M4 的工作范围。
