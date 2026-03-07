# 架构审查：7 组件分层模型（v2 — 2026-03-07 更新）

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

## 审查结果 v2

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

### ⚠️ 残余观察项

#### OBS-1: BankruptcyPort fallback 仍硬编码 Bankruptcy

`src/game/ports/BankruptcyPort.lua` L3-8:
```lua
local function _fallback_port()
  local runtime_bankruptcy = require("src.game.core.runtime.Bankruptcy")
  ...
end
```

**风险**: `src/game/ports/` 不在 `src/game/systems/` 下，因此不被 dep_rules 拦截。但 Port 契约文件携带具体实现引用，削弱了 Port 的"纯契约"语义。

**建议**: fallback 移到 Adapter 或 bootstrap 层；Port 文件应无 fallback，port 缺失时直接报错。

#### OBS-2: AutoPlayPort fallback 同理

`src/game/ports/AutoPlayPort.lua` L3-5 同样有 fallback 到 `src.game.runtime.AutoPlayPortAdapter`。

**建议**: 与 OBS-1 同处理。长期目标：Port 文件只声明接口，不含 require 链。

#### OBS-3: Adapter 层位置

当前 Adapter 位于 `src/game/runtime/`（2 个新文件 + PhaseRegistry deprecated）。该目录语义模糊——既有 deprecated 模块又有新 adapter。

**建议**: 考虑迁至 `src/game/adapters/` 或保留在 `src/game/runtime/` 但在 boundaries.md 补充说明。

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
```

## 当前架构依赖图

```
src/presentation/  ──(ports)──>  src/core/
       │
       │ (UI events → dispatch_action)
       ▼
src/game/flow/turn/  ──>  src/game/systems/
       │                        │
       │ (injects ports)        │ (requires Port contracts)
       ▼                        ▼
src/game/runtime/   src/game/ports/  ←──  (pure contracts)
  (Adapters)              │
       │                  │ (fallback - 待移除)
       ▼                  ▼
src/game/core/runtime/   src/core/config/
  (Agent, Bankruptcy,     Config/Generated/
   Game, GameState*)
       │
       ▼
src/game/core/player/  (state)
```
