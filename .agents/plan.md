# 卡牌选择路径修复：可执行计划

更新时间：2026-02-28
负责人：Codex + 项目维护者
适用范围：`src/presentation/**`、`src/game/**`（仅 choice 路由与 UI 交互）

---

## 1. 背景与目标

### 已确认问题
1. 位置选择屏/遥控骰子屏被当作通用卡牌选择屏使用。
2. 当存在可出卡牌时，应在基础屏通过 `基础_可出牌外框*` 高亮并点击直接选择。

### 目标（全代码库，不限 test_profile）
1. 卡牌可选场景只走基础屏，不再回落到任何专用选择屏。
2. 位置选择屏/遥控骰子屏仅用于其专属业务流程。
3. 卡牌选择行为为“高亮可选 + 单击直选 + 无二次确认”。

---

## 2. 约束与设计决策

1. `item_phase_choice` 统一路由到 `base_inline`（新约定）。
2. 专用屏路由白名单：
   - `market_buy -> market`
   - `item_target_player -> player`
   - `roadblock_target|demolish_target -> target`
   - `remote_dice_value -> remote`
   - `landing_optional_effect|land_optional_effect` 且仅 `buy_land|upgrade_land` -> building
3. 未命中白名单的 choice 不允许回落到 `target/remote/player/building`，默认 `base_inline`。
4. 基础屏点击卡槽仍经过 `TurnDispatchValidator` 的 owner/option 校验。

---

## 3. 里程碑执行计划

## M1：路由契约收敛（先堵住错误弹窗）

### 改动文件
1. `src/game/flow/intent/IntentDispatcher.lua`
2. `src/presentation/interaction/UIChoiceRoutePolicy.lua`
3. `src/presentation/ui/choice_screen_service/openers.lua`
4. `src/presentation/ui/UIModalPresenter.lua`

### 执行步骤
1. 在游戏侧为 `item_phase_choice` 显式注入 `route_key = "base_inline"`。
2. 展示侧 `UIChoiceRoutePolicy.resolve` 增加 `base_inline`，并把 unknown fallback 从 `target` 改为 `base_inline`。
3. `open_choice_modal` 在 `base_inline` 下不打开任何 choice screen。
4. 若当前有遗留 choice screen 激活，进入 `base_inline` 时主动关闭并回到基础画布。

### 验收标准
1. `item_phase_choice` 期间 `state.ui.active_choice_screen_key == nil`。
2. 不再出现“位置选择屏/遥控骰子屏被通用复用”。

### 提交信息
`fix(choice-route): enforce base-inline route and remove modal fallback`

---

## M2：基础屏可出牌外框与直选链路

### 改动文件
1. `src/presentation/api/ui_view_service/state.lua`
2. `src/presentation/api/ui_view_service/item_slots.lua`
3. `src/presentation/ui/UIPanelPresenter.lua`
4. `src/presentation/interaction/intent_builders/ItemSlotIntents.lua`
5. `src/presentation/shared/UINodes.lua`（仅引用，不新增跨 canvas 耦合）

### 执行步骤
1. 在 UI state 中显式维护 `card_outlines`（与 `item_slots` 同索引）。
2. 基于 `choice.kind == "item_phase_choice"` + `choice.options` 计算可用道具集合。
3. 仅高亮可用槽位对应的 `基础_可出牌外框*`。
4. 仅可用槽位可点击；不可用槽位外框隐藏且不可点击。
5. 点击后直接派发 `choice_select`，不弹确认框。

### 验收标准
1. 可出牌时只见基础屏外框提示。
2. 点击高亮槽位立即完成选择。
3. 不可出牌槽位无触发。

### 提交信息
`feat(base-ui): highlight playable card outlines and direct select`

---

## M3：测试补齐与全场景回归

### 改动文件
1. `tests/suites/presentation_ui.lua`
2. `tests/suites/gameplay.lua`
3. `tests/internal/dep_rules.lua`（如需添加路由契约检查）

### 执行步骤
1. 新增 `item_phase_choice -> base_inline` 路由断言。
2. 新增“专用屏白名单”参数化测试，覆盖所有 choice kind。
3. 新增“unknown kind 不回落 target”测试。
4. 新增“外框显示/触控/直选”测试。
5. 保留并验证 `roadblock_target`、`demolish_target`、`remote_dice_value` 专用屏行为。

### 验收命令
```bash
lua tests/suites/presentation_ui.lua
lua tests/suites/gameplay.lua
lua tests/regression.lua
```

### 提交信息
`test(choice-route): add whitelist and base-inline regression coverage`

---

## M4：联调、发布与回滚预案

### 联调步骤
1. 启动本地对局并覆盖至少三类流程：
   - 道具阶段可出牌
   - 路障/导弹目标选择
   - 遥控骰子点数选择
2. 人工确认：
   - 可出牌只在基础屏外框体现
   - 专用流程只弹对应专用屏
   - 高频点击不会出现串屏

### 发布步骤
1. 按 M1 -> M2 -> M3 顺序合并。
2. 每个里程碑单独提交并通过对应测试。
3. 部署前跑一次 `lua tests/regression.lua`。

### 回滚方案
1. 若线上出现选择失效：优先回滚 M2（外框与触控层）。
2. 若线上出现弹窗路径异常：回滚 M1（路由契约层）。
3. 回滚后保留测试代码，作为后续修复护栏。

---

## 4. 验收清单（最终）

1. 任意可出牌场景均不弹位置选择屏/遥控骰子屏。
2. 基础屏 `基础_可出牌外框*` 仅高亮可出牌项。
3. 点击可出牌项后立即完成选择，无二次确认。
4. 专用屏仅在其专属 kind 触发。
5. 全量回归通过：
   - `lua tests/suites/presentation_ui.lua`
   - `lua tests/suites/gameplay.lua`
   - `lua tests/regression.lua`

---

## 5. 执行顺序与提交节奏

执行顺序：`M1 -> M2 -> M3 -> M4`

建议提交：
1. `fix(choice-route): enforce base-inline route and remove modal fallback`
2. `feat(base-ui): highlight playable card outlines and direct select`
3. `test(choice-route): add whitelist and base-inline regression coverage`
