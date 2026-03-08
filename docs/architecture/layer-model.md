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
| Computer | `src/game/core/ai/agent.lua` |
| shared-mechanics | `src/game/systems/` + `src/game/ports/`（systems-facing Port 契约） |
| state | `src/game/core/player/`, `src/game/core/runtime/game.lua` |
| config | `Config/generated/`, `src/core/config/` |

辅助层（不计入 7 组件）：`src/game/runtime/`（Port Adapter）、`src/game/flow/turn/`（稳定 turn runtime 与 use case 编排）、`src/game/scheduler/`（协程调度细节）、`src/app/bootstrap/`（装配）、`src/infrastructure/runtime/`（Eggy 宿主真实实现）、`src/core/`（跨层工具与宿主 / 运行时广义契约）。

## 已强制的边界

| 边界 | dep_rules 规则 |
|------|----------------|
| UI ↛ game | interaction layer forbidden `src.game.*` |
| game ↛ presentation | (grep 维持为零) |
| core/player ↛ systems | player state forbidden `src.game.systems.*` |
| systems ↛ flow | systems forbidden `src.game.flow.*` |
| systems ↛ core.runtime | systems forbidden `src.game.core.runtime.*` |
| systems ↛ game.gameplay_loop_ports | systems forbidden direct gameplay loop runtime object fields |
| core/ports ↛ gameplay modules | core runtime contracts forbidden `src.game.systems.*` / `src.game.flow.*` gameplay dependencies |
| core ↛ flow | core forbidden `src.game.flow.*` |
| state/config ↛ 上层 | Player/Inventory 仅依赖 vendor |

## Port 注入模式

systems 需要调用宿主或装配细节时，通过 Port 契约 + Adapter 解耦：

```
systems → src/game/ports/xxx_port.lua (systems-facing contract)
                    ↑
          src/game/runtime/xxx_port_adapter.lua (实现)
                    ↑
          src/game/core/* 或 src/game/systems/* (具体实现)
```

默认 adapter 在 `CompositionRoot.assemble()` 安装；flow 层可覆盖。

这里要固定三类不同的东西。`src/core/ports/` 只放宿主 / 运行时广义契约，面向多个内层复用。`src/game/ports/` 只放 systems-facing 注入契约，帮助玩法规则向外发出稳定语义。`src/game/flow/turn/gameplay_loop_ports.lua` 只服务于 turn use case 本身，把 gameplay loop 运行时需要的多组函数按用途打包成 override bundle；它不是通用 Port 层，不能被 systems 或别的目录当成新的契约中心。

`game.bankruptcy_feedback_port` 也是同一模式：systems 只依赖 `src/game/ports/bankruptcy_feedback_port.lua`，由 outer runtime 在装配时注入“清地块后如何做展示反馈”的实现。

## 依赖图

```
src/presentation/ ──> src/core/
      │
      ▼ (dispatch_action)
src/game/flow/turn/ ──> src/game/systems/
      │                       │
      │ (installs adapters)   │ (requires Port contracts)
      ▼                       ▼
src/game/runtime/      src/game/ports/  (systems-facing contracts)
  (Adapters)
      │
      ▼
src/game/core/runtime/     src/core/config/
  (Game, CompositionRoot)   Config/generated/
      │
      ▼
src/game/core/player/  (state)

src/game/core/ai/      src/game/systems/endgame/
  (Agent)               (Bankruptcy, GameVictory)

src/core/ports/  (host/runtime-wide contracts)

src/game/flow/turn/gameplay_loop_ports.lua
  (turn use case local override bundle)
```
