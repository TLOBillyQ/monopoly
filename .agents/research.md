# 架构审查：7 组件分层模型（v3 — 2026-03-07 更新）

## 目标模型

```
UI → Turn Management → (Player | Computer) → shared-mechanics → (state | config)
```

7 个组件，依赖方向严格单向向右。

## 当前映射

| # | 组件 | 实际目录 |
|---|------|----------|
| 1 | **UI** | `src/presentation/` |
| 2 | **Turn Management** | `src/game/flow/` (turn/, intent/, ports/) |
| 3 | **Player** | 人类玩家路径: UI → Turn Management → dispatch_action |
| 4 | **Computer** | `src/game/core/runtime/Agent.lua` |
| 5 | **shared-mechanics** | `src/game/systems/` + `src/game/ports/`（Port 契约） |
| 6 | **state** | `src/game/core/player/`, `src/game/core/runtime/Game*.lua`, `src/core/RuntimeState.lua` |
| 7 | **config** | `Config/Generated/`, `src/core/config/` |

辅助层（不在 7 组件内）：
- `src/game/runtime/` — Port Adapter 实现（AutoPlayPortAdapter, BankruptcyPortAdapter）
- `src/app/bootstrap/` — 装配区
- `src/infrastructure/runtime/` — Eggy 宿主适配
- `src/core/` — 跨层共享工具（Logger, NumberUtils, ActionAnimPort, events）

## 审查结果 v3

### ✅ 全部主边界合规 (6/6)

| 边界 | 状态 | 证据 |
|------|------|------|
| UI ↛ game | ✅ 隔离 | grep 验证 0 结果 |
| game ↛ presentation | ✅ 隔离 | grep 验证 0 结果 |
| systems ↛ flow | ✅ 隔离 | dep_rules L136-140 强制，grep 验证 0 结果 |
| systems ↛ core.runtime | ✅ **新增隔离** | dep_rules L142-149 新规则，grep 验证 0 结果 |
| core ↛ flow | ✅ 隔离 | dep_rules L76-80 强制，grep 验证 0 结果 |
| state/config ↛ 上层 | ✅ 无上向依赖 | Player.lua / Inventory.lua 仅依赖 vendor |

### v1 违规修复确认

#### ✅ 已修复 — systems → Agent 依赖（原违规 1）

**方案**: 引入 `src/game/ports/AutoPlayPort.lua`（Port 契约）+ `src/game/runtime/AutoPlayPortAdapter.lua`（Adapter）

**变更**:
- 5 个 systems 文件全部改为 `require("src.game.ports.AutoPlayPort")` — ✅
- `GameplayLoop` 在运行时通过 `game.auto_play_port = adapter.build()` 注入 — ✅
- Agent.lua 本身不变，仅被 Adapter 引用 — ✅
- dep_rules 新增 `systems ↛ game.core.runtime` 规则 — ✅

**依赖流向**: `systems → Port 契约 ← Adapter ← Agent` — 符合依赖倒置

#### ✅ 已修复 — systems → Bankruptcy 依赖（原违规 2）

**方案**: 引入 `src/game/ports/BankruptcyPort.lua`（Port 契约）+ `src/game/runtime/BankruptcyPortAdapter.lua`（Adapter）

**变更**:
- 3 个 systems 文件全部改为 `require("src.game.ports.BankruptcyPort")` — ✅
- `GameplayLoop` 在运行时通过 `game.bankruptcy_port = adapter.build()` 注入 — ✅
- dep_rules 同一条新规则覆盖 — ✅

### ✅ 残余观察项全部收口（v3 确认）

#### OBS-1 / OBS-2 ✅ — Port 契约已为纯接口

`AutoPlayPort.lua` 和 `BankruptcyPort.lua` 已去除所有 `_fallback_port()` 和具体实现 `require` 链。现在只做：
1. 从 `game.auto_play_port` / `game.bankruptcy_port` 读取已注入的端口
2. `assert` 端口存在和方法存在
3. 转调

默认 adapter 安装点前移至 `CompositionRoot.assemble()`（L137-138），确保 game 实例创建即可用。`GameplayLoop` 仍可按需覆盖。

#### OBS-3 ✅ — `src/game/runtime/` 目录语义已文档化

`docs/architecture/boundaries.md` 已更新，明确该目录同时承载：
- 回合执行与状态机编排（TurnEngine/PhaseRegistry，deprecated）
- gameplay adapter（AutoPlayPortAdapter, BankruptcyPortAdapter）——实现 `src/game/ports/*` 契约到 runtime 细节的边界穿越

## 定量快照

```
回归测试: 376 通过
dep_rules: ok（含新规则 systems ↛ game.core.runtime）
tick: ok
forbidden_globals: ok
growth_budget: 全部 within budget
forbidden_files (3): 均已删除
presentation→game.systems whitelist: 空（完全隔离）
legacy_policy 引用: 0
Port fallback require: 0（纯 assert 契约）
```

## 当前架构依赖图

```
src/presentation/  ──(ports)──>  src/core/
       │
       │ (UI events → dispatch_action)
       ▼
src/game/flow/turn/  ──>  src/game/systems/
       │                        │
       │ (can override ports)   │ (requires Port contracts)
       ▼                        ▼
src/game/runtime/   src/game/ports/  ←──  (pure contracts, assert-only)
  (Adapters)
       │
       ▼
src/game/core/runtime/   src/core/config/
  (Agent, Bankruptcy,     Config/Generated/
   Game, GameState*,
   CompositionRoot
     └─ installs default adapters)
       │
       ▼
src/game/core/player/  (state)
```
