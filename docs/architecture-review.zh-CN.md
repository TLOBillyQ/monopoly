# 架构设计评审（Hollywood 原则 / DIP / SOLID）

> 目的：用“可执行”的方式描述当前 `src/` 的架构现状、主要风险与改造路线；评审维度是 **Hollywood 原则**、**依赖倒置（DIP）** 与 **SOLID**。
>
> 范围：以当前分支代码为准（`src/app.lua`、`src/core/*`、`src/gameplay/*`、`src/visual/*`、`src/config/*`、`scripts/regression.lua`）。
>
> 约束：优先对齐 `docs/backlog.md` 的 **M1（不改玩法）**：本评审的 P0/P1 建议都以“结构与稳定性”为目标，不引入新玩法。

---

## 1. TL;DR（结论先行）

- 架构“主干”已成型：`Store + RNG + Flow/TurnManager + wait_choice` 让 **可复现** 与 **可等待交互** 成为一等能力。
- 最大风险在“模块耦合方式”而非玩法：services 之间仍以 `require` 直接互相引用（含潜在循环），导致改动半径大、难测。
- UI 侧已经以 `game.ui_hooks` 做到“可选适配”，但 gameplay 内仍会直接触发 UI（如 `push_popup`），属于可接受但需要规范化的“出口”。
- 下一步（M1 内可做）：
  - 把“服务引用”从 `require` 迁移到 `game.services` 注入（先消循环、再减耦）。
  - 明确“存档/回放”的真实边界：哪些字段属于 **Store**（事实），哪些属于 **runtime**（可重建）。
  - 补齐最小回归脚本覆盖 `wait_choice` 路径，锁住架构不倒退。

---

## 2. 现状概览（事实层：以代码为准）

### 2.1 目录职责

- `src/config/*`：静态配置（地块、道具、机会卡、常量等）。
- `src/core/*`：纯模型与基础能力（`Board/Tile/Player/Dice/Inventory`）。
- `src/gameplay/*`：规则、流程、持久化与服务（`flow/turn/*/services/*/rng/store/sync/choice`）。
- `src/visual/*`：Love2D 渲染与输入适配（UI 层）。
- `src/app.lua`：组装器（创建 `game`、注入 services、创建 `TurnManager`、执行 `Sync.sync_all`）。

### 2.2 运行时对象与单一事实来源

- **事实（可存档/可复现）**：在 `Store`（`src/gameplay/store.lua`）里，主要路径：
  - `turn.phase / turn.current_player_index / turn.pending_choice / turn.choice_seq / turn.turn_count`
  - `players[*].cash/position/properties/status`
  - `board.tiles / board.overlays`
  - `rng`（`src/gameplay/rng.lua` 的 `{seed,state}`）
- **运行时（可重建）**：`game.board`（路径与 tile 对象）、`game.players`（Player 实例）、`game.occupants`（位置到玩家映射）、`TurnManager.flow`（协程状态机运行态）。

`Sync.sync_all`（`src/gameplay/sync.lua`）目前做的是“最小可用”的重建：玩家/地块/overlays/turn_count/rng + `rebuild_occupants()`。

---

## 3. 核心链路（流程与交互的真实形态）

### 3.1 回合流程（状态机）

`TurnManager`（`src/gameplay/services/turn_manager.lua`）基于 `Flow`（`src/gameplay/flow.lua`）驱动：

- `start`：处理跳过（出局/扣留）+ 自动前置道具 `ItemService.auto_pre_action`。
- `roll`：`Dice.roll(dice_count, override, game.rng)`，保证随机可复现。
- `move`：`MovementService.move(..., { branch_parity = raw_total })`，产出 `move_result`（visited/encountered/passed_start）。
- `land`：先 `TileService.resolve`（格子类型事件、偷窃、黑市等），再 `LandResolver.resolve`（land_effects：租金/税/购买/升级/起点等）。
- `wait_choice`：当 `Choice.open` 写入 `turn.pending_choice` 后，流程停在此；收到 action 后由 `ChoiceResolver.resolve` 消费并恢复到 `resume_state`。
- `end_turn`：`turn/end_turn.lua` tick 状态、清理临时标记、切到下一玩家并 `commit_state()`。

### 3.2 “等待选择”机制（Hollywood 原则的落地点）

- `Choice.open` 只写入 `Store.turn.pending_choice`（`src/gameplay/choice.lua`）。
- `TurnManager:dispatch(action)` 把 action 填入 `pending_action` 并推进 flow；若 flow 不在运行但 choice 存在，则直接走 `ChoiceResolver` 防止自动模式卡死。
- `wait_choice` 状态会忽略“过期 action”（通过 `choice_id` 校验），并支持 cancel（`choice_cancel` 或 `option_id=nil`）。

这条链路保证：**规则层不会“拉 UI”，只会进入 wait 状态；是否、何时产生 action 由上层输入/自动运行决定。**

### 3.3 UI 端口（当前形态）

- gameplay 侧通过 `src/gameplay/ui.lua` 间接调用 `game.ui_hooks.push_popup/request_choice`。
- 是否打开选择弹窗由 `game.ui_enabled` 控制；无 UI 时通常走“默认行为”（例如可选行动选择第一个可用项）。

---

## 4. 评审：Hollywood / DIP / SOLID

### 4.1 Hollywood 原则（Don’t call us, we’ll call you）

**做得好的：**

- `wait_choice` 成为正式 phase，且 choice 本身存放在 Store（可回放/可恢复）。
- 自动与手动共享同一 action 通道（`TurnManager:dispatch`）。

**仍需规范的：**

- services 内部仍会直接发 `UI.push_popup(...)`（例如 `ItemService`），这不破坏流程正确性，但会让“无 UI 环境”与“录制/回放”更难一致。

### 4.2 依赖倒置 DIP（高层依赖抽象，不依赖细节）

**现状：既有雏形，也有反例。**

- 正向：UI 已经是“端口”（`game.ui_hooks`），gameplay 不 `require visual`。
- 反向：services 之间大量直接 `require`（例如 `ChanceService` 直接 `require ItemService/MovementService/LandResolver`；`TileService` 顶部 `require ItemService/StatusService`），导致耦合链长、潜在循环依赖只能用“局部延迟 require”兜底。

**改造方向（不改玩法）：**

- 以 `game.services` 作为“依赖注入容器”（已在 `src/app.lua` 存在），逐步把 cross-service 引用从 `require("src.gameplay.services.X")` 改为 `get_service(game, "x")`。
- 统一“副作用出口”为端口：UI、日志、随机源都通过 `game.*` 注入；services 只依赖 `game` 与数据模型。

### 4.3 SOLID（以 Lua 项目语境解读）

#### S — SRP 单一职责

- `ItemService` 同时承担：道具规则、交互（Choice/UI）、自动策略（`auto_pre_action`）、以及部分“场景规则”（偷窃路过玩家）。
- 风险：文件过大（`src/gameplay/services/item_service.lua` 已 >600 行），改动容易引发回归。

#### O — OCP 开闭原则

- 已改进：机会卡 `effect_handlers`、道具 `item_handlers/post_consume_handlers` 是典型“注册表扩展点”。
- 仍可提升：`ItemService.apply_target_item_effect` 仍是 if/elseif 链（属于可接受的过渡态）。

#### L — LSP 里氏替换

- 本项目没有继承体系，LSP 的主要风险来自“隐式协议”。
- 当前最重要的协议是 `pending_choice` 的 schema 与 action schema（`choice_id/option_id/type`）。建议把协议写进文档并在回归脚本里覆盖。

#### I — ISP 接口隔离

- `ui_hooks` 目前只有两类能力（popup/choice），已经足够小；但建议明确：gameplay 只能调用 `src/gameplay/ui.lua`，不允许直接触达 hooks。

#### D — DIP 依赖倒置

- 结论同 4.2：下一阶段的“结构工作”应以 **消除 cross-service require** 为中心。

---

## 5. 风险清单（按严重性排序）

### P0（M1 必做：稳定性/可维护性）

- services 互相 `require` 导致潜在循环与隐式初始化顺序问题（最容易在小改动后爆炸）。
- “事实 vs 运行态”边界不清：`Sync.sync_all` 是最小对齐，但尚未明确哪些字段必须同步、哪些可重建。
- `wait_choice` 路径的回归覆盖不足：一旦 UI/auto/choice_id 处理变动，容易出现“卡死/跳过/重复消费”。

### P1（M1 可做：结构健康度）

- `ItemService` 职责过重；建议拆分为“规则/交互/策略”三块（可以先拆文件，不改接口）。
- `UI.push_popup` 在 services 内零散调用：建议集中到“事件/日志”或统一端口，便于禁用 UI 时行为一致。

### P2（后续迭代）

- 更完整的存档/回放：将 `turn.phase/current_player_index/pending_choice` 的同步/恢复策略做成明确规范，并扩充 sync_all。

---

## 6. 落地路线（与 `docs/backlog.md` 的 M1 对齐）

### 6.1 P0 任务（建议拆成多 PR）

- 任务 A：建立“依赖规则”与快速自检
  - 规则：`gameplay/*` 禁止 `require visual/*`；services 之间禁止直接 `require` 彼此（改为 `game.services.*`）。
  - 自检：在 `scripts/` 增加一个轻量脚本，扫描 `src/gameplay/services/*.lua` 的 `require("src.gameplay.services.")` 并报警（不需要完美解析，够用即可）。

- 任务 B：收敛 service 引用
  - 先从已存在的 `get_service(game, key)` 模式推进（`TileService/ChanceService` 已在用）。
  - 目标：删除“延迟 require 兜底”与循环依赖注释，让引用链可预测。

- 任务 C：补齐回归覆盖 `wait_choice`
  - 至少覆盖：落地可选行动（buy/upgrade）、偷窃（目标选择/二级选择）、导弹目标选择。
  - 验收：固定 seed 下回放一致；并且在无 UI（auto）与有 UI（dispatch action）下都不会卡死。

### 6.2 P1 任务

- 拆分 `ItemService`：
  - `item_handlers.lua`（注册表）
  - `item_auto_policy.lua`（自动前置策略）
  - `item_interactions.lua`（Choice 构建）
  - 保持对外 API 不变（M1 内不动玩法）。

---

## 7. 验收标准（建议作为 M1 的“架构验收”）

- 任意需要选择的效果：必须进入 `turn.phase == "wait_choice"`；没有 action 不推进下一阶段。
- 自动与手动共享 action 通道：同 seed + 同 action 序列，结果一致。
- 代码层约束：`src/gameplay/services/*` 之间无直接 `require("src.gameplay.services.*")`（允许从 `src/app.lua` 组装注入）。
- 回归脚本在固定 seed 下可重复运行，输出一致（允许日志时间戳等非确定字段不同）。
