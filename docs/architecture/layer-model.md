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

`src/game/flow/output_adapters/` 仍视为 Turn Management 的一部分，而不是独立第 8 层。它内部的 `intent_output_adapter.lua`、`output_state_adapter.lua` 只负责把 turn use case 产生的输出接回 `intent_dispatcher` 或 `ui_runtime`，因此属于流程编排内部桥接，不是宿主 adapter。

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

这里要固定三类不同的东西。`src/core/ports/` 只放宿主 / 运行时广义契约，面向多个内层复用。`src/game/ports/` 只放 systems-facing 注入契约，帮助玩法规则向外发出稳定语义。`src/game/flow/turn/loop_ports.lua` 只服务于 turn use case 本身，把 gameplay loop 运行时需要的多组函数按用途打包成 override bundle；它不是通用 Port 层，不能被 systems 或别的目录当成新的契约中心。

命名时直接看文件后缀。`*_port.lua` 是单一契约，应该落在 `src/core/ports/` 或 `src/game/ports/`，例如 `action_anim_port.lua`、`bankruptcy_feedback_port.lua`。`*_ports.lua` 是按 use case 或展示面打包的一组 override bundle，当前典型例子是 `src/core/ports/runtime_ports.lua` 与 `src/game/flow/turn/loop_ports.lua`；它们可以汇总多项能力，但不替代单一 Port 契约。如果 bundle 根模块已经收口为目录包入口，也允许像 `src/presentation/runtime/ports/init.lua` 这样把目录本身作为 canonical 入口，但目录里的叶子 bundle 文件仍应保持 `*_ports.lua`。`*_port_adapter.lua` 是 outer layer 的实现文件，负责把宿主能力接入前面的契约，例如 `src/game/runtime/auto_play_port_adapter.lua`。新增文件时，如果后缀和职责对不上，先改名字或拆文件，不要让 `_ports.lua` 和 `_port_adapter.lua` 退化成“随手起名”。

`src/game/flow/output_adapters/*.lua` 则是另一种更窄的“用例内部 adapter”语义：它们不定义 Port 契约，也不实现宿主 Port，而是把 flow 内部输出桥到 `intent_dispatcher` 或 `ui_runtime`。所以第三周先固定它们的目录语义，不把它们误并到 `src/game/runtime/`。

`game.bankruptcy_feedback_port` 也是同一模式：systems 只依赖 `src/game/ports/bankruptcy_feedback_port.lua`，由 outer runtime 在装配时注入“清地块后如何做展示反馈”的实现。

`scripts/architecture/monopoly_architecture.lua` 是这套分层模型的可执行投影。它把 `app`、`core`、`presentation`、`game_flow`、`game_systems`、`game_runtime`、`game_ai`、`state`、`infrastructure` 这些组件映射成 `arch_view` 的分类规则，再由 `lua scripts/architecture/arch_view_cli.lua check` 对 `src/**/*.lua` 的静态 `require` 图做校验。这个工具只检查模块依赖图与循环基线；`lua scripts/architecture/arch_view_cli.lua viewer --out-dir <dir>` 则把同一份投影导出为静态 viewer，支持层级 drill-down、dependency triangles、聚合 edge tooltip 与返回状态恢复。像旧路径禁用、宿主全局 API、runtime 对象字段直读这类文本护栏，仍留在 `tests/guards/dep_rules.lua`、`tests/guards/legacy_path_guard.lua`、`tests/guards/forbidden_globals.lua`；其中 `dep_rules.lua` 只保留硬边界，`legacy_path_guard.lua` 只保留 exact/prefix 退休路径回流检查。默认入口是 `lua tests/guard.lua`。

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

src/game/flow/turn/loop_ports.lua
  (turn use case local override bundle)
```
