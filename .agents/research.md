# 项目架构分析与简化方案（执行结果更新）

本文基于已落地变更更新（分支：`copilot/execute-research-plan-20260301`，提交：`df73efa`），重点记录“计划执行后的实际状态”。

---

## 当前架构总览（执行后，src: 209 个 Lua 文件，约 17,962 行）

```
main.lua → src/app/init.lua（启动编排）
  ├─ bootstrap/（5 个启动文件: RuntimeInstall → GameStartup → EventBridge → UIBootstrap → GameRuntimeBootstrap）
  │
  ├─ src/core/                         （8 文件）— Logger, RuntimeContext, NumberUtils, ChoiceRoutePolicy 等
  │
  ├─ src/game/
  │   ├─ core/runtime/                 （19 文件）— Game, TurnEngine, CompositionRoot, Bankruptcy, Agent...
  │   ├─ core/player/                  （2 文件）— Player, Inventory
  │   ├─ runtime_coroutine/            （5 文件）— Scheduler, Session, TurnScript, ActionRouter, Await
  │   ├─ flow/turn/                    （18 文件）— GameplayLoop, AutoContext, GameplayLoopPorts...
  │   ├─ flow/intent/                  （1 文件）— IntentDispatcher
  │   └─ systems/                      （10 子目录 / 52 文件）
  │
  └─ src/presentation/
      ├─ api/                          （9 文件，含 PresentationPorts + ui_view_service/5）
      ├─ canvas_runtime/               （6 文件）
      ├─ interaction/                  （10 文件）
      ├─ state/                        （3 文件）
      ├─ ui/                           （9 文件）
      ├─ render/                       （20 文件）
      ├─ shared/                       （4 文件）
      └─ canvas/                       （12 子目录 / 36 文件）
```

---

## 执行结果快照（可复核）

- 回归结果：`lua tests/regression.lua` → `All regression checks passed (187)`，且 `dep_rules / tick / forbidden_globals` 全部通过。
- 语法校验：`lua -e "assert(loadfile(...))"` 关键入口文件通过（`main.lua`、`src/app/init.lua`、`Game.lua`、`GameplayLoop.lua`、`UIViewService.lua`）。
- 已删除模块引用清零（`rg` 校验）：  
  `GameplayLoopPortsAdapter`、`UIEventRouter`、`TurnActionPort`、`CompatBridge`、`Signals`、`AgentTargeting`、`GameStateOps`、`GameplayLoopPortTypes` 均无残留 `require`。
- `UIViewService` 对 `UIRuntimePort` 已改为顶层依赖：仅保留 1 处文件级 `require`。
- `GameplayLoop` 中 `_build_auto_context` / `_build_tick_auto_context` 已删除，改由 `AutoContext` 统一构建。

---

## 各阶段实际落地情况（对照 plan）

### 阶段 0：基线固化（已完成）

- 固化回归基线为 187，并记录关键引用与后续清零目标。

### 阶段 1：删除死代码与测试过渡层（已完成）

- 删除：`src/presentation/canvas_runtime/CanvasCoordinator.lua`
- 删除：`src/presentation/api/GameplayLoopPortsAdapter.lua`
- 测试迁移：`tests/suites/presentation_ui.lua` 改为 `PresentationPorts.build()` 构建 grouped ports。

### 阶段 2：内联低风险薄封装（已完成）

- 删除：`src/presentation/interaction/UIEventRouter.lua`
- 删除：`src/game/runtime_coroutine/Signals.lua`
- 调整接线：`UIBootstrap` 与测试直接使用 `CanvasEventRouter`；`Scheduler/ActionRouter` 内联信号常量与判定。

### 阶段 3：内联中风险薄封装 + Agent 合并（已完成）

- 删除：`src/presentation/api/TurnActionPort.lua`（默认 reject / 不阻塞语义保留在 `UIIntentDispatcher`）
- 删除：`src/game/runtime_coroutine/CompatBridge.lua`（快照同步逻辑内联到 `TurnEngine`）
- 合并并删除：`src/game/core/runtime/AgentTargeting.lua` → 逻辑并入 `Agent.lua`
- 更新：`RuntimeInstall.lua` 移除 `AgentTargeting` preload。

### 阶段 4：塌缩 GameStateOps（已完成）

- 删除：`src/game/core/runtime/GameStateOps.lua`
- `Game.lua` 改为直接 mixin：
  - `GameStatePlayers`
  - `GameStateTiles`
  - `GameStateTurn`
- `rebuild`、`mark_players_dirty`、`mark_board_dirty` 保留在 `Game.lua`，对外接口兼容。

### 阶段 5：Port 基础设施收敛（已完成）

- 新增：`src/presentation/api/PresentationPorts.lua`（聚合 modal/anim/ui_sync/debug/state）
- 保留并重构：`src/game/flow/turn/GameplayLoopPorts.lua`（接口 + fallback/no-op）
- 删除：`src/game/flow/turn/GameplayLoopPortTypes.lua`
- 删除：`src/presentation/api/ports/*.lua`（5 个分散端口实现）
- `GameRuntimeBootstrap` 切换为 `PresentationPorts.build()`。

### 阶段 6：去重与依赖收敛（已完成）

- 新增：`src/core/ChoiceRoutePolicy.lua`，统一 choice route 推断与 confirm 规则。
- `IntentDispatcher` 与 `UIChoiceRoutePolicy` 均复用 `ChoiceRoutePolicy`。
- 新增：`src/game/flow/turn/AutoContext.lua`，统一 auto context 构建。
- `UIViewService` 清理函数体内 `require("UIRuntimePort")`，改为顶层依赖。

---

## 问题闭环状态（执行后）

| 问题 | 执行前 | 执行后状态 |
|------|--------|------------|
| 薄封装泛滥 | 8 个重点薄封装待处理 | 关键薄封装/过渡层已清理，引用清零 |
| Port 基础设施碎片化 | 7 文件 / 543 行（不含 adapter/bootstrap） | 已收敛为 `GameplayLoopPorts + PresentationPorts` 双核心 |
| state bag 过大 | 35 顶层字段 + 3 回调 | **未拆分**（保持兼容，后续可独立推进） |
| route 与 auto context 重复 | 2 组核心重复逻辑 | 已合并为单一策略/单一构建入口 |
| UIViewService 延迟 require | 函数体内 5 处 | 已降为文件级 1 处 |

---

## 实际收益（执行前 vs 执行后）

| 指标 | 执行前 | 执行后 | 变化 |
|------|--------|--------|------|
| src Lua 文件数 | 220 | 209 | -11 |
| src Lua 行数 | ~18,293 | ~17,962 | -331 |
| runtime_coroutine 文件数 | 7 | 5 | -2 |
| presentation/api 文件数 | 15 | 9 | -6 |
| 关键中间层文件 | 多处分散 | 统一到核心模块 | 结构收敛完成 |
| 回归通过数 | 187 | 187 | 行为保持稳定 |

补充说明：  
Port 侧“文件数量收敛”目标已完成；“行数显著压缩”未完全兑现（当前两核心文件合计约 560 行），但已移除跨文件跳转与重复入口，后续可在不改接口前提下继续做语义级瘦身。

---

## 当前遗留与后续建议

1. **state bag 子对象化仍未落地**：`GameStartup.build_state()` 仍为 35 个顶层字段，建议后续按 `ui/anim/turn/board/timers/locks` 子对象分批迁移。
2. **Port 行数优化可继续**：`PresentationPorts.lua` 目前聚合后可读性提升，但仍可抽出内部私有 helper（不新增对外层级）进一步降复杂度。
3. **收益口径建议固定**：后续继续使用同一回归入口（187 基线）和同一 `rg` 清零口径，保持横向可比。

---

## 核心原则

**不加目录、不加层，只删、合并、内联；每步都以可验证回归为准绳。**
