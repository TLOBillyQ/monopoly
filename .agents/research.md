# 项目架构分析与简化方案

下面是对整个项目的架构分析和简化方案。

---

## 当前架构总览（219 文件, ~15,800 行）

```
main.lua → src/app/init.lua (启动编排)
  ├─ bootstrap/ (5 个启动文件: RuntimeInstall → GameStartup → EventBridge → UIBootstrap → GameRuntimeBootstrap)
  │
  ├─ src/core/          (6 文件) — Logger, RuntimeContext, 工具函数
  │
  ├─ src/game/
  │   ├─ core/runtime/  (15 文件) — Game, TurnEngine, CompositionRoot, GameStateOps, Bankruptcy, Agent...
  │   ├─ core/player/   (2 文件)  — Player, Inventory
  │   ├─ runtime_coroutine/ (7 文件) — Scheduler, Session, TurnScript, ActionRouter, Await...
  │   ├─ flow/turn/     (17 文件) — GameplayLoop, TurnDispatch, TurnMove, TurnLand, TurnRoll...
  │   ├─ flow/intent/   (1 文件)  — IntentDispatcher
  │   └─ systems/       (10 子目录) — board, land, movement, market, items, effects, chance, choices...
  │
  └─ src/presentation/
      ├─ api/           (6 文件 + ports/ 5 文件 + ui_view_service/ 5 文件)
      ├─ canvas_runtime/(7 文件) — CanvasStore, CanvasEventRouter, CanvasRenderPipeline...
      ├─ interaction/   (11 文件) — UICanvasCoordinator, UIIntentDispatcher, UIEventBindings...
      ├─ state/         (3 文件) — UIModel, UIRoleContext, UIRoleAvatar
      ├─ ui/            (7 文件) — UIPanel, UIChoice, UIModalPresenter, PopupRenderer...
      ├─ render/        (12 文件) — BoardScene, MoveAnim, ActionAnim, Status3D...
      ├─ shared/        (4 文件) — UIEvents, UIAliases, PlayerColors, MarketLayout
      └─ canvas/        (12 子目录) — 每个屏一个目录 (base, always_show, popup, market...)
```

---

## 核心问题（按严重度排序）

> **审查意见**：整体按"问题 → 方案 → 收益"组织清晰；建议每个关键结论补上证据来源（文件:行号或检索命令），便于复核。

### 1. 过度间接 — 薄封装泛滥（~8 个纯转发文件, ~400 行）

| 薄封装 | 行数 | 消费者 | 做了什么 |
|--------|------|--------|----------|
| GameStateOps | 141 | Game (mixin) | 30+ 函数逐行转发 GameStatePlayers/Tiles/Turn |
| GameStatePlayers | 19 | GameStateOps | 再转发 5 个 player_state/*Ops |
| UIEventRouter | 16 | UIBootstrap（1 处） | 包装 CanvasEventRouter |
| TurnActionPort | 19 | UIIntentDispatcher（1 处） | 规范化 port 表 |
| CompatBridge | 17 | TurnEngine（1 处） | 同步 phase 到 legacy turn |
| Signals | 11 | Scheduler+ActionRouter | 2 个字符串常量 |
| CanvasCoordinator | 25 | 零消费者 | 克隆 UICanvasCoordinator |
| GameplayLoopPortsAdapter | 16 | 零消费者 | 复制 GameRuntimeBootstrap |

> **审查意见**：`GameplayLoopPortsAdapter` 目前并非"零消费者"，测试中仍有引用（`tests/suites/presentation_ui.lua` 多处 `require`）；该项应标注为"仅测试依赖"并给出迁移步骤。

### 2. Port 基础设施过重（~540 行 / 7 文件）

GameplayLoop ← GameplayLoopPorts(208 行 fallback 构建) ← ports/(5 个文件) ← 各自 require(UIViewService)。多数 port 函数仅 1-2 行 `require("UIViewService").xxx(state)`。这实际上只是为了解耦 game/flow 和 presentation，但代价太高。

> **审查意见**：判断方向正确，建议补一张"7 文件明细表"（每文件行数、调用点、是否可合并）来支撑 540 行结论。

### 3. 上帝对象 state（40+ 字段）

GameStartup.build_state() 创建一个巨型 table，同时承载：UI 状态、动画序列、待决选择、棋盘位置、锁标志、计时器、game 引用、factory 闭包。整个 presentation 和 flow 层都传递这个 bag。

### 4. 逻辑重复

- 选择路由：IntentDispatcher._resolve_choice_route() 和 UIChoiceRoutePolicy.resolve() 相同 if-chain
- 自动上下文：GameplayLoop 里 _build_auto_context() 和 _build_tick_auto_context() 近似重复
- Agent ↔ AgentTargeting：4 个函数纯转发

### 5. 循环依赖导致延迟 require

UIViewService 在 5 个函数体内 require("UIRuntimePort") 而非文件顶部——说明依赖图有环。

---

## 简化方案（收敛路线，不新建目录）

### 阶段 0：删除死代码

- 删 CanvasCoordinator.lua（0 消费者）
- 删 GameplayLoopPortsAdapter.lua（0 消费者）
- 预计减少 ~40 行

> **审查意见**：该阶段需修正事实：`GameplayLoopPortsAdapter.lua` 当前被测试依赖，不能直接按死代码删除；建议先替换测试入口再删除。

### 阶段 1：内联单消费者薄封装

| 操作 | 方式 |
|------|------|
| UIEventRouter → 内联到 UIBootstrap | 3 行替换 |
| TurnActionPort → 内联到 UIIntentDispatcher | nil 检查直接写 |
| CompatBridge → 内联到 TurnEngine | 10 行逻辑搬入 |
| Signals → 内联到 Scheduler | 常量搬入 |
| 合并 Agent + AgentTargeting 为单文件 | 消除 4 个透传 |
| 预计减少 ~100 行，减少 5 个文件 | |

> **审查意见**：建议按风险拆批执行：先 `UIEventRouter`/`Signals`（低风险），再 `TurnActionPort`/`CompatBridge`（行为风险更高）。

### 阶段 2：塌缩 GameStateOps 链

当前:
```
Game ──mixin──> GameStateOps ──> GameStatePlayers ──> 5个*Ops
```

目标:
```
Game ──mixin──> GameStatePlayers (直接聚合 5 个 *Ops)
      ──mixin──> GameStateTiles
      ──mixin──> GameStateTurn
```

删除 GameStateOps.lua（141 行纯透传）。Game.lua 直接 mixin 三个子模块。

> **审查意见**：这里应增加"mixin 顺序不变性"验收项，重点验证同名方法覆盖顺序与初始化副作用。

### 阶段 3：简化 Port 基础设施

当前 7 文件 ~540 行:
- GameplayLoopPortTypes + GameplayLoopPorts + 5 个 ports/*.lua

目标 2 文件 ~200 行:
- GameplayLoopPorts.lua — 声明接口 + no-op fallback
- PresentationPorts.lua — 一个文件聚合全部 concrete 实现

把 ModalPorts/AnimPorts/UISyncPorts/DebugPorts/StatePorts 各自的 .build() 合并到 PresentationPorts.build()。消除中间 resolve 层。

> **审查意见**：建议保留最小契约测试（尤其 fallback/no-op 行为），否则 Port 收敛后失败定位成本会升高。

### 阶段 4：拆分 state bag

从 40+ 平铺字段 → 子对象

```lua
state = {
  ui      = { ... },      -- UI 显示状态（已存在）
  anim    = { ... },      -- 动画序列 + wait 标志
  turn    = { ... },      -- pending_choice, elapsed, id
  board   = { ... },      -- positions, sync_pending, scene
  timers  = { ... },      -- countdown, action_button
  locks   = { ... },      -- next_turn, role_control, input
}
```

渐进迁移：先加子对象，旧字段保留为 alias，逐步删除。

> **审查意见**：建议补充 alias 退出机制（旧字段访问告警 + 明确清理条件），避免长期双轨。

### 阶段 5：统一重复逻辑

- 选择路由：UIChoiceRoutePolicy.resolve() 为唯一入口，IntentDispatcher 调用它
- auto context：提取 AutoContext.build(game) 工具函数
- 解决循环 require：UIRuntimePort 移到 presentation/shared/ 或拆分接口

> **审查意见**：循环依赖改造建议先给出最小依赖环和拆环顺序（先抽哪层接口），否则执行风险偏高。

---

## 预期收益

| 指标 | 当前 | 目标 |
|------|------|------|
| 纯透传/死代码文件 | 8+ | 0 |
| Port 基础设施 | 7 文件 540 行 | 2 文件 ~200 行 |
| state bag 字段 | 40+ 平铺 | 6 个子对象 |
| 重复逻辑 | 2 处 | 0 |
| 总文件数 | 219 | ~207 |
| 总行数 | ~15,800 | ~14,800（-1000） |

> **审查意见**：收益表建议拆分"确定值/估算值"，并补充统一验收口径（回归通过数、启动耗时、关键路径性能）。

---

## 核心原则

**不加目录、不加层。只删、合并、内联。每个阶段独立可验证，回归跑通即合。**

> **总评**：方向正确且可执行性高；补齐证据链与每阶段验收标准后，可以直接作为实施清单。
