# 开发反馈深度分析与任务拆解（2026-03-05）

本文件是研究结论，不是执行计划。执行安排见 `.agents/plan.md`。

数据来源：`大富翁开发反馈.xlsx`，共 20 条反馈（13 Bug + 6 优化 + 1 隐含数据错误）。本研究逐条对照代码库现状，定位根因、评估影响范围，并拆解为可执行开发任务。


---


## 1. 总结

20 条反馈中发现了 2 个确认的逻辑错误（税务局破产 BUG-07 根因已定位到代码行级别）、1 个数据配置错误（机会卡 tile ID 互换）、若干 UI 可见性与流程控制问题。按风险排序后建议分 4 批交付：P0 紧急修复（2 项）→ P1 功能修复（6 项）→ P2 体验修复与优化（9 项）→ P3 增强（3 项）。


---


## 2. P0 — 紧急修复


### 2.1 BUG-02：付费通道不可用

模块：`src/game/systems/commerce/PaidCurrencyBridge.lua`

现状分析：付费流程经过 `PaidCurrencyBridge.open_purchase_panel()` 调用宿主平台 API `role.show_goods_purchase_panel(goods_id, show_time)`。此调用依赖外部宿主环境（Eggy 平台 GameAPI），如果宿主未正确注入 `show_goods_purchase_panel` 方法或商品 ID 配置不匹配，整个支付流程无法发起。购买面板打开后，余额同步依赖 `EVENT.SPEC_ROLE_PURCHASE_GOODS` 回调事件。

涉及文件：
- `src/game/systems/commerce/PaidCurrencyBridge.lua:192-205` — 打开购买面板
- `src/game/systems/market/service/Context.lua:108-112` — 触发入口
- `src/game/systems/market/service/Purchase.lua:58` — 购买流程中调用
- `Config/RuntimePaidGoods.lua` — 商品 ID 与货币映射配置

排查方向：需确认宿主环境是否正确注册了 `show_goods_purchase_panel`，以及 `RuntimePaidGoods.lua` 中的 `goods_id` 是否与平台商品后台一致。此问题大概率是宿主集成配置问题而非代码逻辑 Bug。

开发任务：
1. 在 `PaidCurrencyBridge.open_purchase_panel()` 增加详细错误日志，区分"方法不存在"、"调用失败"、"商品 ID 无效"三种情况。
2. 与平台方核对 `RuntimePaidGoods.lua` 中 `金豆`/`乐园币` 的 goods_id 配置。
3. 验证 `EVENT.SPEC_ROLE_PURCHASE_GOODS` 回调是否在购买完成后正确触发余额同步。


### 2.2 BUG-07：税务局扣钱过多直接破产 + 机会卡跳转错误

此条包含两个独立 Bug，均已定位到代码行级别。

#### Bug A：税务局无条件触发破产（根因已确认）

模块：`src/game/systems/land/LandRules.lua:143-157` + `src/game/systems/land/LandEvents.lua:21-24`

根因：`execute_pay_tax()` 在返回事件时，**无条件**将 `bankrupt_reason` 写入 extra 参数（第 155 行）。而 `LandEvents.lua:21` 的判断是 `if result.bankrupt_reason then`，由于该字段始终为非 nil 字符串，条件永远为真，导致每次税务局扣款后都执行 `bankruptcy.eliminate()`。

对比租金逻辑（同文件 117-131 行）：租金先检查 `player_balance >= rent`，余额充足时正常扣款返回（不设 `bankrupt_reason`）；余额不足时才设置 `bankrupt_reason`。税务局代码缺少了这个条件判断。

实际税率为 50%（`Config/Generated/Constants.lua:12` 中 `tax_rate = 0.5`），扣除后玩家应剩余约 50% 资金，但因 `bankrupt_reason` 无条件传递，即使余额 3 万+仍被判定破产。

修复方案：在 `execute_pay_tax()` 中，扣款后检查玩家余额是否 <= 0，仅在余额耗尽时才传递 `bankrupt_reason`。

涉及文件：
- `src/game/systems/land/LandRules.lua:143-157` — 修复点
- `src/game/systems/land/LandEvents.lua:21-24` — 消费端（无需改动，逻辑正确）
- `src/game/core/runtime/player_state/BalanceOps.lua:37-39` — `deduct_player_cash` 允许负值（无下限保护）

#### Bug B：机会卡目的地 tile ID 互换（数据配置错误）

模块：`Config/Generated/ChanceCards.lua:32-34`

根因：卡牌 3031（"你突然晕倒了，被送入医院"）的 `destination_tile_id = 38`（实际是税务局），卡牌 3033（"你收到税务通知，立刻赶往税务局"）的 `destination_tile_id = 36`（实际是医院）。两张卡的目的地完全互换。

验证依据：`Config/Generated/Tiles.lua` 中 tile 36 = 医院（type="hospital"），tile 38 = 税务局（type="tax"）。

修复方案：交换两张卡的 `destination_tile_id`：卡 3031 → 36（医院），卡 3033 → 38（税务局）。


---


## 3. P1 — 功能修复


### 3.1 BUG-01：其他玩家能看到当前玩家的二次弹窗

模块：`src/presentation/ui/choice_screen_service/common.lua:165-184`

现状分析：二次确认弹窗通过 `switch_modal_canvas()` 显示，内部调用 `runtime.for_each_role_or_global()` 并根据 `ctx.can_operate` 判断是否显示。`UIRoleContext.lua:28` 设置 `can_operate = (role_id == current_player_id)`。理论上只有当前操作玩家能看到。

可能原因：某些调用路径未走 `switch_modal_canvas()` 而直接使用了 `coordinator.switch(ui, target)`（广播模式，第 47-86 行），导致所有玩家同时看到。需排查 `PreConfirmFlow.enter()` 和 `open_pre_confirm_screen()` 的具体调用链。

涉及文件：
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua:86` — 设置 `_pre_confirm_active`
- `src/presentation/ui/choice_screen_service/openers.lua:146,179` — `switch_modal_canvas` 调用
- `src/presentation/interaction/UICanvasCoordinator.lua:47-124` — `switch` vs `switch_for_role`
- `src/presentation/state/UIRoleContext.lua:19-45` — `can_operate` 判定

开发任务：排查所有打开二次确认屏的路径，确保均走 `switch_modal_canvas`（角色级）而非 `switch`（广播级）。


### 3.2 BUG-03：官方商城购买后弹窗未关闭

模块：`src/presentation/render/MarketView.lua` + `src/presentation/ui/MarketModalRenderer.lua`

现状分析：购买完成后应调用 `MarketModalRenderer.close_market_panel(state)` → `market_view.close_market_panel(state)` → `modal_state.close_choice(state)`。如果购买走的是付费通道（`PaidCurrencyBridge`），购买结果通过异步回调返回，可能未触发关闭逻辑。

开发任务：在付费通道购买成功回调中，确保触发 `close_market_panel` 或刷新市场界面。


### 3.3 BUG-06：路障生效时动画和状态不同步

模块：`src/game/flow/turn/TurnMove.lua:91-96` + `src/presentation/render/ActionAnim.lua:33`

现状分析：路障命中时，`Movement.lua` 立即停止移动并返回 `stopped_on_roadblock = true`。`TurnMove.lua:92-94` 设置 `stay_turns = 1`。动画层通过 `action_anim_port.queue()` 播放路障动画（时长 1.0 秒）。反馈描述的"额外停留一个回合且不能加盖建筑"其实是**设计预期行为**（路障扣留 1 回合），但动画播放可能未等待完成就切换了状态。

开发任务：
1. 确认路障动画播放完毕后才推进回合状态（检查 `ActionAnimOverlayRuntime` 的 duration 同步）。
2. 如果"额外停留不能建筑"不是预期行为，需调整 `TurnMove.lua` 中 `stay_turns` 设置逻辑。


### 3.4 BUG-08：出局玩家回合仍需等待倒计时/点骰子

模块：`src/game/flow/turn/TurnStart.lua:26-30`

现状分析：`TurnStart.lua:26` 检查 `player.eliminated`，如果为 true 则设置 `skipped = true` 并返回 `"end_turn"`。逻辑上应完全跳过出局玩家的回合。

可能原因：presentation 层的倒计时/骰子 UI 可能在 game 层返回 `end_turn` 之前就已经显示。`TickChoiceTimeout.lua` 可能在收到 `end_turn` 信号之前已启动倒计时。或者 `TurnEngine.lua:54-63` 的 `next_player()` 循环未正确跳过出局玩家。

涉及文件：
- `src/game/runtime/TurnEngine.lua:54-63` — 玩家轮转
- `src/game/flow/turn/TurnStart.lua:26-30` — 出局判断
- `src/game/flow/turn/TickChoiceTimeout.lua` — 倒计时

开发任务：排查 `next_player()` 是否在 presentation 层显示 UI 之前完成出局检查，以及 `TickChoiceTimeout` 是否在 `skipped` 回合仍触发。


### 3.5 BUG-10：黑市翻页未生效

模块：`src/presentation/render/MarketView.lua:151-197`

现状分析：当前黑市 UI 固定显示 10 个 slot（`黑市_购买项1` 到 `黑市_购买项10`），直接遍历 `market.options` 填充。代码中**未发现任何翻页逻辑**（无 `page_index`、`next_page`、`prev_page` 实现）。如果商品总数超过 10，后续商品不可见。

开发任务：
1. 在 `MarketView.lua` 中实现翻页状态（page_index）和翻页切换逻辑。
2. 在黑市 UI 中添加翻页按钮并绑定 intent。
3. 修改 `Eligibility.lua` 的 limit 参数支持分页查询。


### 3.6 BUG-13：触发道具询问后点确定不能直接使用

模块：`src/presentation/interaction/ui_intent_dispatcher/ItemPhaseAskFlow.lua`

现状分析：道具询问流程分两步——先弹出"是否使用道具？"（`ItemPhaseAskFlow`），玩家点确定后设置 `_item_phase_confirmed = true` 并关闭弹窗（第 11-13 行），然后回到 `UIModalPresenter.lua:67` 清除 `_item_phase_confirmed`，重新渲染道具选择界面。此时玩家还需要再点击具体卡牌才能使用。

这是**两步流程设计**（确认意图 → 选择具体卡牌），而非 Bug。但用户体验上，点"确定"后期望直接使用。问题在于当玩家只有一张可用道具时，仍需两次操作。

开发任务：当可用道具仅 1 张时，点确定后自动选中该道具并直接使用，跳过二次选择。


---


## 4. P2 — 体验修复与优化


### 4.1 BUG-04：领先者皇冠未显示

涉及文件：
- `Data/UIManagerNodes.lua:37,57,59,155` — 皇冠节点定义（`基础_玩家1皇冠` 等，EImage 类型）
- `src/presentation/` — 未找到皇冠渲染/更新逻辑代码

根因判断：皇冠 UI 节点已在 UIManagerNodes 中定义，但 presentation 层缺少根据玩家资产排名动态显示/隐藏皇冠的逻辑。

开发任务：在排行或回合结算时，计算当前领先玩家，调用 `ui:set_visible(crown_node, true/false)` 控制皇冠显示。


### 4.2 BUG-05：手机端道具卡外框错位

涉及文件：
- `src/presentation/canvas/base/nodes.lua:15-22` — `基础_可出牌外框1~5`
- `Data/UIManagerNodes.lua` — 外框 EImage 节点

属于 UI 布局适配问题，需在不同分辨率下调试外框位置。开发任务为 UI 侧调整。


### 4.3 BUG-09：基础屏头像无法显示

涉及文件：
- `src/presentation/state/UIRoleAvatar.lua` — 头像 key 清洗与 texture 设置
- `src/presentation/canvas/base/nodes.lua:13` — `基础_玩家X头像`
- `Data/UIManagerNodes.lua:67,90,139,172` — 头像 EImage 节点

现状分析：`UIRoleAvatar.lua` 使用 `set_node_texture_native_size()` 渲染头像。低分辨率下可能因 native size 超出容器或纹理加载失败导致不显示。反馈提到"需要换实现方式"。

开发任务：调查低分辨率下 native size 与容器的兼容性，考虑改用固定尺寸渲染。


### 4.4 BUG-11：走到黑市后仍需额外点骰子才能结束回合

涉及文件：
- `src/game/systems/movement/Movement.lua:57-79` — `_check_market` 在**经过**时触发中断
- `src/game/flow/turn/TurnMove.lua:116-133` — 黑市中断后返回 `"wait_choice"` 并附带 `next_state = "move"` 继续剩余步数

现状分析：黑市中断设计为"经过时触发"（`step < steps` 条件），完成购物后恢复剩余步数继续移动。但当点数正好落在黑市格子时（`step == steps`），`_check_market` 不会触发中断（因为 `step >= steps` 条件排除了最后一步）。此时黑市通过 landing 流程触发。landing 流程完成后可能未正确推进回合至 `end_turn`，导致需要额外操作。

开发任务：排查黑市 landing 流程（而非 interrupt 流程）完成后的回合状态转移，确保 landing 完成后直接进入 `end_turn`。


### 4.5 BUG-12：使用路障卡时可选格子重叠

涉及文件：
- `src/game/systems/items/ItemRoadblock.lua` — `candidates()` 生成候选列表
- `src/game/systems/choices/ChoiceHandlers/ItemChoiceHandler.lua:179-212` — 生成 `choice_spec`

现状分析：`ItemRoadblock.candidates()` 扫描前后各 3 步的格子，按优先级排序后返回。UI 层将候选列表渲染为选择按钮。问题可能是多个候选格子的 UI 定位逻辑有误，或棋盘坐标到屏幕坐标的转换未区分不同格子位置。

开发任务：排查路障卡选择 UI 的格子定位渲染逻辑，确保每个候选格子有独立的显示位置。


### 4.6 OPT-01：卡牌展示时间增加 1 秒

涉及文件：`Config/GameplayRules.lua:11`

当前值：`action_anim_default_seconds = 1.0`。修改为 `2.0` 即可。同时检查 `popup_auto_close_seconds = 1.0`（第 10 行）是否也需调整。


### 4.7 OPT-03：地块与玩家颜色一致性

涉及文件：`src/presentation/shared/PlayerColors.lua:4-9`

当前配色：玩家 1 = 0x4fc3f7（青）、玩家 2 = 0x81c784（绿）、玩家 3 = 0xffb74d（橙）、玩家 4 = 0xe57373（红）。反馈称座标颜色为红/黄/蓝/紫，地块颜色为红/绿/蓝/紫，黄≠绿对应不上。

开发任务：与美术确认统一配色方案后，修改 `PlayerColors.lua` 中 `index_colors` 和 `owner_colors`。


### 4.8 OPT-04：收钱表现增强（UI 和效果音）

涉及文件：
- `src/game/systems/chance/handlers/CashHandlers.lua:8-33` — 收钱事件发射
- `src/presentation/render/ActionAnim.lua` — 动画注册

当前收钱仅通过事件文本 `"获得 X 金币"` 通知。需新增：(1) 金币飞入动画，(2) 效果音播放调用。

开发任务：在 `ActionAnim` 注册 `cash_receive` 动画类型，并在 presentation 层添加音效播放逻辑。


### 4.9 OPT-05：破产页面展示延长 2 秒

涉及文件：
- `src/presentation/ui/PopupRenderer.lua:156-171` — 破产弹窗渲染
- `Config/GameplayRules.lua:9` — `auto_popup_min_visible_seconds = 3.0`

当前破产弹窗可能使用 `popup_auto_close_seconds = 1.0` 控制关闭。需确认破产弹窗使用哪个时间参数，并增加 2 秒。


---


## 5. P3 — 增强需求


### 5.1 OPT-02：角色头上称号位置上移

涉及文件：
- `Data/UIManagerNodes.lua` — 玩家名字 ELabel 节点（`基础_玩家X名字`）
- `src/presentation/canvas/base/nodes.lua:9-12`

UI 布局调整，需在引擎编辑器中修改节点 Y 坐标。


### 5.2 OPT-06：黑市支持一次购买多张道具卡

涉及文件：
- `src/game/systems/market/service/Purchase.lua` — 单次单品购买
- `src/presentation/render/MarketView.lua` — 单选 UI
- `src/presentation/canvas/market/intents.lua` — `market_confirm` 只传单个 `option_id`

当前架构仅支持单品购买。需要较大改动：多选 UI、批量验证、批量扣款、批量入库。建议作为独立功能迭代。


### 5.3 OPT-07：黑市去掉座驾分页

涉及文件：`Config/Generated/Market.lua` — `page = "座驾商店"` 条目

当前市场配置中有 `道具商店` 和 `座驾商店` 两个 page。去掉座驾分页可通过：(1) 在 UI 层过滤掉 `page == "座驾商店"` 的 tab 按钮，或 (2) 将座驾条目的 `market_enabled` 设为 false。


---


## 6. 任务总览

| 编号 | 优先级 | 类型 | 标题 | 改动规模 | 关键文件 |
|---|---|---|---|---|---|
| BUG-02 | P0 | 排查+配置 | 付费通道不可用 | 小 | PaidCurrencyBridge.lua, RuntimePaidGoods.lua |
| BUG-07a | P0 | 逻辑修复 | 税务局无条件破产 | 最小（3-5行） | LandRules.lua:143-157 |
| BUG-07b | P0 | 数据修复 | 机会卡目的地互换 | 最小（2行） | ChanceCards.lua:32-34 |
| BUG-01 | P1 | 排查+修复 | 二次弹窗可见性 | 小 | UICanvasCoordinator.lua, openers.lua |
| BUG-03 | P1 | 流程修复 | 商城购买后未关闭 | 小 | MarketView.lua, PaidCurrencyBridge.lua |
| BUG-06 | P1 | 同步修复 | 路障动画状态不同步 | 中 | TurnMove.lua, ActionAnimOverlayRuntime.lua |
| BUG-08 | P1 | 排查+修复 | 出局玩家回合未跳过 | 小 | TurnEngine.lua, TurnStart.lua |
| BUG-10 | P1 | 新功能 | 黑市翻页 | 中 | MarketView.lua, Eligibility.lua |
| BUG-13 | P1 | 流程优化 | 道具单张自动使用 | 小 | ItemPhaseAskFlow.lua, UIModalPresenter.lua |
| BUG-04 | P2 | 新功能 | 皇冠显示 | 中 | 新增渲染逻辑 |
| BUG-05 | P2 | UI适配 | 道具卡外框错位 | 小 | UI 布局调整 |
| BUG-09 | P2 | UI适配 | 基础屏头像 | 中 | UIRoleAvatar.lua |
| BUG-11 | P2 | 流程修复 | 黑市landing回合 | 小 | TurnMove.lua, Movement.lua |
| BUG-12 | P2 | UI修复 | 路障卡格子重叠 | 小 | ItemRoadblock.lua, UI 定位 |
| OPT-01 | P2 | 配置 | 卡牌展示+1秒 | 最小（1行） | GameplayRules.lua |
| OPT-03 | P2 | 配置 | 颜色一致性 | 最小 | PlayerColors.lua |
| OPT-04 | P2 | 新功能 | 收钱UI+音效 | 中 | ActionAnim.lua, 新增音效逻辑 |
| OPT-05 | P2 | 配置 | 破产展示延长 | 最小（1行） | GameplayRules.lua 或 PopupRenderer.lua |
| OPT-02 | P3 | UI调整 | 称号位置上移 | 小 | UIManagerNodes（编辑器） |
| OPT-06 | P3 | 新功能 | 黑市批量购买 | 大 | Purchase.lua, MarketView.lua, intents.lua |
| OPT-07 | P3 | 配置 | 黑市去掉座驾分页 | 最小 | Market.lua 或 MarketView.lua |


---


## 7. 关键发现

发现 1（已确认 Bug）：`LandRules.execute_pay_tax()` 第 155 行 `bankrupt_reason` 无条件传入 `_build_land_event` 的 extra，导致 `LandEvents.lua:21` 的 `if result.bankrupt_reason then` 永远为真。对比同文件租金逻辑（117-131 行），租金在余额充足时不设置 `bankrupt_reason`。税务局代码缺少余额判断分支。

发现 2（已确认数据错误）：`ChanceCards.lua` 第 32-34 行，卡 3031（医院事件）指向 tile 38（税务局），卡 3033（税务局事件）指向 tile 36（医院）。两张卡的 `destination_tile_id` 互换。`Tiles.lua` 确认 tile 36 = 医院，tile 38 = 税务局。

发现 3（架构约束）：黑市 UI 完全缺少翻页实现，10 slot 硬编码在 `MarketLayout.lua` 和 `MarketView.lua` 中，需要新增分页状态管理。

发现 4（设计确认）：路障命中后的 1 回合停留（`stay_turns = 1`）和停留期间不能操作是**预期设计**，不是 Bug。但动画同步可能有时序问题。

发现 5（流程设计）：道具询问是两步流程设计（确认意图 → 选卡），BUG-13 描述的"需要再点一次卡牌"是预期行为，优化方向是单张可用时自动跳过选择步。

发现 6（皇冠功能缺失）：`Data/UIManagerNodes.lua` 中定义了皇冠 EImage 节点，但 `src/presentation/` 中找不到任何显示/隐藏皇冠的渲染代码，说明该功能尚未实现。
