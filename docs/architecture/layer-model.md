# 分层模型

```
UI → Turn Management → (Player | Computer) → shared-mechanics → (state | config)
```

依赖方向严格单向向右。

## 组件映射

| 组件 | 目录 |
|------|------|
| UI | `src/presentation/` |
| Turn Management | `src/game/flow/` |
| Player | UI 发出 action → `flow/dispatch_action` |
| Computer | `src/game/core/ai/agent.lua` |
| shared-mechanics | `src/game/systems/` + `src/game/ports/` |
| state | `src/game/core/player/`, `src/game/core/runtime/game.lua` |
| config | `Config/generated/`, `src/core/config/` |

**辅助层**（不计入上表）：`src/game/runtime/`（Port Adapter）、`src/game/flow/turn/`（turn runtime 编排）、`src/game/scheduler/`（协程调度）、`src/app/bootstrap/`（装配）、`src/infrastructure/runtime/`（Eggy 宿主实现）、`src/core/`（跨层工具与广义契约）。

`src/game/flow/output_adapters/` 属于 Turn Management，不是独立层。其中 `intent_output_adapter.lua`、`output_state_adapter.lua` 只负责把 turn use case 输出接回 `intent_dispatcher` 或 `ui_runtime`，是流程内部桥接，不是宿主 adapter。

## 强制边界

| 边界 | dep_rules 规则 |
|------|----------------|
| UI ↛ game | interaction layer forbidden `src.game.*` |
| game ↛ presentation | (grep 维持为零) |
| core/player ↛ systems | player state forbidden `src.game.systems.*` |
| systems ↛ flow | systems forbidden `src.game.flow.*` |
| systems ↛ core.runtime | systems forbidden `src.game.core.runtime.*` |
| systems ↛ gameplay_loop_ports | systems forbidden direct gameplay loop runtime object fields |
| core/ports ↛ gameplay | core runtime contracts forbidden `src.game.systems.*` / `src.game.flow.*` |
| core ↛ flow | core forbidden `src.game.flow.*` |
| state/config ↛ 上层 | Player/Inventory 仅依赖 vendor |

## Port 注入模式

```
systems → src/game/ports/xxx_port.lua (systems-facing contract)
                  ↑
        src/game/runtime/xxx_port_adapter.lua (实现)
```

默认 adapter 在 `CompositionRoot.assemble()` 安装，flow 层可覆盖。

**三类 Port 目录：**

- `src/core/ports/` — 宿主/运行时广义契约，gameplay 无关
- `src/game/ports/` — systems-facing 注入契约，允许业务名词
- `src/game/flow/turn/loop_ports.lua` — turn use case 局部 override bundle，不是通用 Port 层

**命名规则：**

- `*_port.lua` — 单一契约，落在 `src/core/ports/` 或 `src/game/ports/`
- `*_ports.lua` — 同生命周期注入 bundle（如 `loop_ports.lua`、`runtime_ports.lua`）
- `*_port_adapter.lua` — 外层对某契约的实现

## 依赖图

```
src/presentation/ ──> src/core/
      │
      ▼ (dispatch_action)
src/game/flow/turn/ ──> src/game/systems/
      │                       │
      │ (installs adapters)   │ (requires Port contracts)
      ▼                       ▼
src/game/runtime/      src/game/ports/
  (Adapters)
      │
      ▼
src/game/core/runtime/     src/core/config/
  (Game, CompositionRoot)   Config/generated/
      │
      ▼
src/game/core/player/  (state)

src/game/core/ai/      src/game/systems/endgame/
src/core/ports/        (host/runtime-wide contracts)
src/game/flow/turn/loop_ports.lua  (turn use case local override bundle)
```
