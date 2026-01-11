# 架构设计评审（Hollywood 原则 / DIP / SOLID）

> 目的：从 **好莱坞原则（Don’t call us, we’ll call you）**、**依赖倒置（DIP）** 与 **SOLID** 的角度，审视当前代码库的结构健康度，明确风险与下一步重构方向。
>
> 范围：本评审基于当前 `src/` 下的代码结构（`core/`、`gameplay/`、`visual/`、`config/`、`util/`）及脚本 `scripts/regression.lua`。

---

## 0. 当前结构概览（事实层）

- `src/config/*`：静态配置（地块/地图/道具/机会卡/常量等）。
- `src/core/*`：纯数据结构（`Board/Tile/Player/Dice/Inventory`）。
- `src/gameplay/*`：规则与运行流程（Turn phases、services、effects、store/sync、rng）。
- `src/visual/*`：Love2D 渲染与输入（`love_layer/layout/renderers/modal/auto_runner/ui_state`）。
- `src/app.lua`：组装器（组装 Board/Players/Store/RNG/TurnManager，并调用 `sync_all`）。

### 已经做对的点（值得保留）

- **Love2D 依赖隔离良好**：绝大多数 `love.*` 仅出现在 `src/visual/*`。
- **UI 端口注入**：`game.ui_hooks` 作为“可选适配器”，使 gameplay 不必 `require` UI 层（方向符合 DIP）。
- **Store + Sync 的形态已出现**：具备“可快照/可恢复”的基础（尽管一致性仍需加强）。
- **RNG 可重放**：`src/gameplay/rng.lua` + `Dice.roll(..., rng)` 为确定性模拟奠基。

---

## 1. 好莱坞原则（Hollywood Principle）

> 核心：上层 orchestrator “调用”下层，**不要让领域逻辑主动驱动 UI**；同时当出现“等待输入”的流程时，系统应自然进入 `wait` 状态，而不是继续推进。

### 发现

1) **gameplay 直接调用 UI hook，但流程不会真正等待输入**

- `src/gameplay/effect.lua`：`Effect.resolve(..., choose_fn)` 假设 `choose_fn` 能“异步回调”把选择结果带回来。
- `src/gameplay/turn/land.lua`：构造 chooser 后调用 `Effect.resolve(...)`，但没有 `wait_choice` phase；回合会直接进入 `end_turn`。
- `src/gameplay/services/item_service.lua`：`use_missile/use_pass_players/select_player` 等在 gameplay 内直接触发弹窗/选择。

**结果：**
- “选择”发生在 UI 层之后，gameplay 已经推进完；选择的回调可能在不合适的时间修改状态（典型症状：看起来需要等待点击，但实际上回合已结束/已换人）。

2) `AutoRunner` 目前走“模拟输入”是正确方向，但 gameplay 的选择机制仍不具备等待语义

- `src/visual/auto_runner.lua` / `src/visual/love_layer.lua`：自动模式用派发 action 模拟点击/按键，这一点符合好莱坞原则的“上层调度输入”。
- 但 gameplay 侧没有“暂停并等待选择”的状态机支撑，因此自动/手动都只能通过“回调注入”绕过等待。

### 建议（P0）

- 引入 **显式的 `wait_choice` phase / pending-action**：
  - gameplay 在需要选择时不再调用 UI，而是写入 store：`turn.pending_choice = { id, prompt, options... }` 并返回 `"wait_choice"`。
  - UI 渲染/输入只负责把选择结果（`confirm/select/cancel`）以“action”形式送回 gameplay（例如 `game:dispatch(action)` 或 `TurnManager:dispatch(action)`）。
  - flow 在 `wait_choice` 中只有在收到选择 action 时才推进。

这会把“等待输入”变成一等公民，从根上解决目前的时序问题，并同时让 AI/自动运行可复用同一套 action 通道。

---

## 2. 依赖倒置（Dependency Inversion Principle）

> 核心：高层模块不应该依赖低层模块的具体实现；二者都应依赖抽象（接口/端口/协议）。

### 发现

1) `game.ui_hooks` 是正向实践，但目前是“半抽象”

- 优点：gameplay 不依赖 Love2D。
- 问题：hook 的调用发生在 services 内部，且缺少等待语义；同时 hook 的参数形态不统一（`push_popup` vs `request_choice` 的 payload 结构各异）。

2) services 之间存在硬依赖 + 循环依赖迹象

- `src/gameplay/services/chance_service.lua` 用延迟 `require` 避免循环（`TileService = nil -- 延迟加载以避免循环`）。
- `TileService` 又依赖 `ChanceService/ItemService/MarketService/StatusService` 等，耦合度较高。

3) 随机源注入不一致（影响可重放与测试）

- `Dice.roll(..., rng)` 支持注入 RNG。
- `ChanceService.draw_card()` 未使用 `game.rng`（走 `math.random` 的默认路径），会破坏回放一致性。

### 建议（P0/P1）

- **统一端口层**：定义 gameplay 可调用的端口（例如 `ports.ui`, `ports.random`, `ports.log`），由 `App.new` 组装注入；services 只依赖端口，不 `require` 其它 service。
- **把 RNG 作为强制依赖**：所有抽卡/随机都走 `game.rng`（包括 chance、market 策略等）。
- **消除延迟 require**：用 `ctx.services`（组装阶段注入）替代 `require` 互相引用，降低循环依赖风险。

---

## 3. SOLID 审查（逐条）

### S — 单一职责（SRP）

**问题：一个模块同时承担“规则 + UI 交互 + AI 策略”。**

- `src/gameplay/services/item_service.lua`：
  - 规则（使用道具产生的效果）
  - 交互（目标选择弹窗）
  - 策略（`auto_pre_action` 决策）

**影响：**
- 文件增长快、修改风险高；新增道具易引入回归（if/elseif 链膨胀）。

**建议（P1）：**
- 拆为：
  - `src/gameplay/item_effects/*`：纯效果（apply(ctx)），不触达 UI。
  - `src/gameplay/item_interactions/*`：把“需要选择”的道具包装成 action/choice 流程。
  - `src/gameplay/ai/item_policy.lua`：自动策略（根据 state 产出 action）。

### O — 开闭原则（OCP）

**问题：新增道具/机会卡依赖修改巨大 if/elseif 分支。**

- `ItemService.use_item`、`ChanceService.resolve` 都是分支驱动。

**建议（P1）：**
- 使用注册表（`handlers[item_id] = function(ctx) ... end`、`chance_handlers[effect] = ...`）或 effect 统一框架扩展点。

### L — 里氏替换（LSP）

本项目以 table-struct + 函数为主，不存在典型继承体系；主要风险来自“隐式协议”：

- `ui_hooks.request_choice` 的 opts 在不同调用点结构不一致，会导致某些适配器无法“替换”。

建议：把 hook payload 定义成稳定协议（同一字段含义、可选字段、默认行为）。

### I — 接口隔离（ISP）

目前 `ui_hooks` 合并了弹窗/选择等能力；对纯 CLI/纯脚本运行时，不一定需要全部 UI 能力。

建议：将 UI 端口拆成更小的接口：

- `ui.show_popup(payload)`
- `ui.request_choice(payload)`（返回 action / 写入 store pending_choice）

同时提供 no-op 实现用于脚本环境。

### D — 依赖倒置（DIP）

与第 2 节相同：**已有雏形，但应继续把“具体 service require”替换为“注入的抽象端口”。**

---

## 4. 一致性/正确性风险清单（P0）

1) **回合结束逻辑存在两套实现，`commit_state` 的调用路径不统一**

- `TurnManager:end_turn(...)` 会 `commit_state`，但 `Flow` 的 `end_turn` state 当前走的是 `src/gameplay/turn/end_turn.lua`（不 commit）。
- 这会导致 store 与 runtime 状态无法保证在“每回合结束”一致落盘。

2) **`turn.phase` 的真相源不明确**

- `TurnManager:run_turn` 会写 `store.turn.phase`。
- `App:commit_state` 却写 `store.turn.phase = self.phase or "start"`，但 `game.phase` 并没有在流程中被维护。

建议：明确 “phase 只存在 store” 或 “phase 只存在 runtime”，并保持单向同步。

3) **Chance 抽卡不走 `game.rng`**

- 回放不可重现；测试波动。

---

## 5. 推荐的落地路线（与 backlog 对齐）

### P0（先救时序与一致性）

- 交互等待：引入 `wait_choice`（store pending_choice + action 驱动）。
- 统一 `end_turn`：保证每回合结束都会 `commit_state`，并统一 phase 写入。
- Chance/随机：chance 抽取等统一注入 `game.rng`。

### P1（结构拆分与可扩展）

- 道具/机会卡注册表化 + 拆分 SRP。
- TileService 与 land_effects 完成迁移，避免双份规则。
- 用 services 注入消除循环依赖与延迟 require。

### P2（工程化）

- 更新 README 中的目录指引（当前仍提及旧 `src/ui`、`src/services`）。
- 扩充回归脚本覆盖“等待选择”的路径（确保自动/手动一致）。

---

## 6. 验收标准（建议）

- 任意需要选择的效果：回合流程必须进入 `wait_choice`，没有选择不会推进到下一阶段/下一玩家。
- 自动运行与手动输入共享同一 action 通道。
- `lua scripts/regression.lua` 在固定 seed 下可 100% 重放，且不会出现偶发差异。

