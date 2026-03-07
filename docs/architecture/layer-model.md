# 7 组件分层模型

```
UI → Turn Management → (Player | Computer) → shared-mechanics → (state | config)
```

依赖方向严格单向向右。

## 组件映射

| 组件 | 目录 |
|------|------|
| UI | `src/presentation/` |
| Turn Management | `src/game/flow/` |
| Player | 人类玩家路径：UI 发出 action → Turn Management `dispatch_action` |
| Computer | `src/game/core/ai/Agent.lua` |
| shared-mechanics | `src/game/systems/` + `src/game/ports/`（Port 契约） |
| state | `src/game/core/player/`, `src/game/core/runtime/Game*.lua` |
| config | `Config/Generated/`, `src/core/config/` |

辅助层（不计入 7 组件）：`src/game/runtime/`（Port Adapter）、`src/game/turn_engine/`（deprecated/frozen 的历史执行器容器）、`src/game/scheduler/`（协程调度细节）、`src/app/bootstrap/`（装配）、`src/infrastructure/runtime/`（Eggy 宿主）、`src/core/`（跨层工具）。

## 已强制的边界

| 边界 | dep_rules 规则 |
|------|----------------|
| UI ↛ game | interaction layer forbidden `src.game.*` |
| game ↛ presentation | (grep 维持为零) |
| systems ↛ flow | systems forbidden `src.game.flow.*` |
| systems ↛ core.runtime | systems forbidden `src.game.core.runtime.*` |
| core ↛ flow | core forbidden `src.game.flow.*` |
| state/config ↛ 上层 | Player/Inventory 仅依赖 vendor |

## Port 注入模式

systems 需要调用 runtime 细节时，通过 Port 契约 + Adapter 解耦：

```
systems → src/game/ports/XxxPort.lua (assert-only)
                    ↑
          src/game/runtime/XxxPortAdapter.lua (实现)
                    ↑
          src/game/core/runtime/Xxx.lua (具体逻辑)
```

默认 adapter 在 `CompositionRoot.assemble()` 安装；flow 层可覆盖。

## 依赖图

```
src/presentation/ ──> src/core/
      │
      ▼ (dispatch_action)
src/game/flow/turn/ ──> src/game/systems/
      │                       │
      │ (installs adapters)   │ (requires Port contracts)
      ▼                       ▼
src/game/runtime/      src/game/ports/  (pure assert contracts)
  (Adapters)
      │
      ▼
src/game/core/runtime/     src/core/config/
  (Agent, Bankruptcy,       Config/Generated/
   Game, CompositionRoot)
      │
      ▼
src/game/core/player/  (state)
```
