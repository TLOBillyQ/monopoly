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

### 近期变更（已落地）

- **wait_choice / pending_choice**：`TurnManager` 增加 `wait_choice`，`Choice` + `choice_resolver` 将 UI 选择（含取消）转回 gameplay，自动模式走同一 action 通道。
- **状态一致性**：`turn/end_turn.lua` 统一 `commit_state`；`sync_all` 对齐 `pending_choice/choice_seq/phase/current_player` 等运行态。
- **随机源一致**：机会卡抽取等统一走 `game.rng`，回放可重现。
- **UI 依赖收敛**：`game.ui_enabled` 控制是否发起选择；无 UI 时流程返回 `{waiting=true}` 由上层驱动。
- **规则单源化**：Land 规则从 `TileService` 收敛到 `land_effects` + `LandResolver`，避免租金/税务双份实现；`ChanceService` 移动后复用同一套结算。
- **注册表化**：道具与机会卡效果已切换为 handler registry（`item_handlers/post_consume_handlers/effect_handlers`），新增效果按表扩展即可。
- **UI 端口统一**：`gameplay/ui.lua` 统一 `push_popup/request_choice` payload，services 不再直接组装异构参数。

---

## 1. 好莱坞原则（Hollywood Principle）

> 核心：上层 orchestrator “调用”下层，**不要让领域逻辑主动驱动 UI**；同时当出现“等待输入”的流程时，系统应自然进入 `wait` 状态，而不是继续推进。

### 更新后的现状

- **已改进**：`wait_choice` / `pending_choice` 已成为一等状态；`Choice.open` 写入 store，`choice_resolver` 通过 action 推进 flow，自动/手动共享同一入口。
- **仍需注意**：少量即时弹窗（如提示类 `push_popup`）仍在 service 内直接触发，但不再驱动流程；后续可统一走 UI 端口。

---

## 2. 依赖倒置（Dependency Inversion Principle）

> 核心：高层模块不应该依赖低层模块的具体实现；二者都应依赖抽象（接口/端口/协议）。

### 发现

1) `game.ui_hooks` 是正向实践，但目前是“半抽象”

- 优点：gameplay 不依赖 Love2D。
- 问题：hook 的调用发生在 services 内部，且参数形态不统一（`push_popup` vs `request_choice` 的 payload 结构各异）。

2) services 之间存在硬依赖 + 循环依赖迹象

- `src/gameplay/services/chance_service.lua` 用延迟 `require` 避免循环（`TileService = nil -- 延迟加载以避免循环`）。
- `TileService` 又依赖 `ChanceService/ItemService/MarketService/StatusService` 等，耦合度较高。

3) 随机源注入不一致（影响可重放与测试）

- `Dice.roll(..., rng)` 支持注入 RNG。
- **已修正**：机会卡抽取改为使用 `game.rng`，回放一致性恢复。

### 建议（P0/P1）

- **统一端口层**：定义 gameplay 可调用的端口（例如 `ports.ui`, `ports.random`, `ports.log`），由 `App.new` 组装注入；services 只依赖端口，不 `require` 其它 service。
- **把 RNG 作为强制依赖**：所有抽卡/随机都走 `game.rng`（包括 chance、market 策略等），新增功能沿用此约束。
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

## 4. 一致性/正确性风险清单（P0 状态刷新）

- **已解决**
  - 回合结束路径统一：`turn/end_turn.lua` 负责 `commit_state`，避免双份实现。
  - phase 单一真相源：phase 写入 store，并通过 `sync_all` 对齐 runtime。
  - Chance 抽卡走 `game.rng`，回放一致性恢复。
  - Land 规则单源：TileService 不再重复租金/税务逻辑，由 LandResolver + land_effects 负责。
  - 机会卡/道具分支移除：注册表驱动，新增效果无需改主干。

- **仍需跟踪**
  - services 间仍有硬引用（Item/Status 等），可进一步用接口/端口注入减耦。
  - UI hook 的 no-op/CLI 适配器可补齐，便于无 UI 运行。

---

## 5. 推荐的落地路线（与 backlog 对齐）

### P0（已完成，保持）

- `wait_choice` + `pending_choice` + `choice_resolver`，自动/手动统一 action 通道。
- `end_turn` 统一 `commit_state`，phase 由 store 管理并可 `sync_all`。
- 随机源统一注入 `game.rng`，回放可重放。

### P1（结构拆分与可扩展）

- 道具/机会卡注册表化 + 拆分 SRP。**（已完成注册表化，后续可拆策略/交互）**
- TileService 与 land_effects 完成迁移，避免双份规则。**（已落地：LandResolver 统一租金/税务/可选行动）**
- 用 services 注入消除循环依赖与延迟 require。**（已建立 `game.services`，仍可逐步替换硬引用）**
- UI payload 规范化。**（已提供统一 UI 端口，建议继续补 CLI/no-op 实现）**

### P2（工程化）

- 更新 README 中的目录指引（当前仍提及旧 `src/ui`、`src/services`）。
- 扩充回归脚本覆盖“等待选择”的路径（确保自动/手动一致）。

---

## 6. 验收标准（建议）

- 任意需要选择的效果：回合流程必须进入 `wait_choice`，没有选择不会推进到下一阶段/下一玩家。
- 自动运行与手动输入共享同一 action 通道。
- `lua scripts/regression.lua` 在固定 seed 下可 100% 重放，且不会出现偶发差异。
