# Eggy 适配层 action 同步方案

## 目标

把 Eggy 适配层的“动作表现”与 gameplay 的“回合推进/等待态”对齐，确保同一个动作在 **UI 表现、动画等待、规则推进** 三端有一致的触发点与完成信号，避免卡死、提前推进或重复执行。

## 现状差异（按现有代码可观察到的症状）

1. **等待态与动作表现脱节**  
   gameplay 在 `wait_move_anim`/`wait_action_anim`/`wait_choice` 等状态等待完成信号，但 Eggy 层的动画表现或 UI 行为可能没有及时发送对应 `*_done` 动作，导致回合停滞或重复触发。

2. **UI 事件的动作语义不统一**  
   Eggy Runtime 直接使用节点名/事件名分发 action，容易出现同一 UI 事件在不同位置映射出不同动作的情况，导致 gameplay 对 action 的识别分支不稳定。

3. **自动推进与等待态冲突**  
   AutoRunner 只看节奏，不感知 `wait_*` 状态，可能在动画或选择等待期间触发 `next`，造成 gameplay 与表现层不同步。

4. **选择态来源双通道**  
   规则层通过 `IntentDispatcher` 与 `store.turn.pending_choice` 同时驱动选择 UI，若未统一同步点，会出现 UI 重复打开、未关闭或超时选择与最新 choice 不一致的问题。

## 同步点设计（核心）

以下同步点以 **gameplay 的等待态** 为核心，每个等待态都有明确的“开始信号/完成信号”。Eggy 适配层只负责表现与回传，不改变规则层的行为。

### 1. Action 输入同步点（UI → gameplay）

**目标**：所有 UI 事件都归一成统一 action 结构，稳定进入 `Game:dispatch_action` 或 `Game:advance_turn`。

- 统一入口：`src/adapters/eggy/eggy_runtime.lua` 的 UI 事件回调。
- 统一 action 结构：`{ type="ui_button", id="next" }`、`{ type="choice_select", choice_id=..., option_id=... }` 等。
- 强制映射表：UI 事件名必须先经过“事件映射层”，再进入 `EggyLayer:dispatch_action`。
- 同步点：**UI 触发事件的瞬间**，必须写清楚对应的 `action.type/id`，防止同名事件在不同逻辑分支产出不同动作。

### 2. 选择等待同步点（gameplay ↔ Eggy）

**开始信号（gameplay → Eggy）**
- `IntentDispatcher` 触发 `need_choice`，或 `store.turn.pending_choice` 有新 id。

**完成信号（Eggy → gameplay）**
- `choice_select` / `choice_cancel` 发送到 `Game:dispatch_action`。

**同步规则**
- 以 `choice.id` 为唯一主键；若 ID 不一致，Eggy 侧必须重新打开 UI 并重置计时器。
- 只有当 `pending_choice` 消失后，UI 才可关闭。
- 选择超时必须对 **当前 ID** 生效，避免过期的 choice 触发。

### 3. 移动动画同步点（gameplay ↔ Eggy）

**开始信号**
- `turn_move.lua` 写入 `store.turn.move_anim`，并带 `seq`。

**完成信号**
- Eggy 动画结束后派发 `{ type="move_anim_done", seq=... }`。

**同步规则**
- `seq` 是唯一对齐标识：Eggy 必须只确认当前 `seq`，避免旧动画重复确认。
- 如果动画播放失败或无法获取单位，必须立刻回传 `move_anim_done`，避免 gameplay 卡在 `wait_move_anim`。

### 4. 动作动画同步点（gameplay ↔ Eggy）

**开始信号**
- `Game:queue_action_anim` 写入 `store.turn.action_anim`，带 `seq` 与 `kind`。

**完成信号**
- Eggy 动画完成后派发 `{ type="action_anim_done", seq=... }`。

**同步规则**
- 对齐 `seq`，并且只在 `turn.phase == "wait_action_anim"` 时响应。
- 如果没有可播放动画（例如占位的 tips），仍需返回一个 **确定的 duration** 或立即确认。

### 5. 自动推进同步点（AutoRunner → gameplay）

**目标**：防止自动推进在等待态触发。

**同步规则**
- AutoRunner 触发前先检查 `store.turn.phase`：  
  - `wait_choice` / `wait_move_anim` / `wait_action_anim` 期间禁止自动 `next`。  
  - 仅在非等待态且无弹窗时触发 `ui_button next`。
- 对自动动作同样走 `dispatch_action`，保持 action 输入通路一致。

### 6. UI 刷新同步点（gameplay → Eggy）

**目标**：确保表现层刷新与 gameplay 状态一致，不在动画过程中错误刷新。

**同步规则**
- 在 `wait_move_anim` 期间，棋盘 UI 只做位置动画，不刷新静态文本。
- 在 `wait_action_anim` 期间，UI 允许刷新文字，但不得修改正在播放的动画对象。
- 进入/离开 `wait_*` 时，记录 phase 变化，离开后触发一次完整 `refresh_view`。

## 行为对齐清单（可执行验收项）

1. **任何 action 进入 gameplay 前都有统一结构**（type + id/choice_id/seq）。  
2. **每个等待态都有且仅有一个完成信号**：  
   - wait_choice → choice_select/cancel  
   - wait_move_anim → move_anim_done  
   - wait_action_anim → action_anim_done  
3. **动画失败时仍能推进回合**（立即确认）。  
4. **自动推进不会越过等待态**。  
5. **选择 UI 不会重复打开或被旧 ID 关闭**。  

## 建议实现步骤（最小变更路径）

1. 在 Eggy Runtime 增加“事件映射层”，集中维护 UI 事件 → action 的唯一映射。
2. 在 `EggyLayer:tick` 中，根据 `store.turn.phase` 抑制 AutoRunner。
3. 在 `AdapterLayer.step_move_anim` / `step_action_anim` 中确保失败兜底立即确认。
4. 在选择逻辑中增加 `choice.id` 对齐校验，确保超时/关闭动作对齐当前 choice。
5. 在 UI 刷新中区分 `wait_move_anim` 与普通刷新，避免表现与规则状态冲突。

## 验收方式（建议）

1. 人工演示：
   - 连续点击 `next`，应看到回合推进且无卡顿。
   - 触发骰子/道具动作时，应等待动画结束后进入下一阶段。
   - 触发选择时，UI 只出现一次，超时后自动推进且不会复现旧选择。
2. 日志/调试：
   - 每个 `wait_*` 进入时打印对应 `seq` 与 choice_id。
   - 每个 `*_done` 触发时打印同样的标识，确保一一对应。

## 备注

以上同步方案不改变 gameplay 的规则，只约束 Eggy 适配层的 **动作输入与表现确认时机**。执行后可以明显减少“动画或 UI 表现与回合推进不同步”的问题。
