# `src/` 命名压缩与包入口收口计划

## 摘要

本轮按“`src/` 全量扫描、一次性切断旧路径、最激进短名”的口径执行，但不破坏仓库已固定的 `*_port.lua`、`*_ports.lua`、`*_port_adapter.lua` 语义。重构只做三类事：

- 去掉父目录已表达的重复前缀。
- 把“公共入口文件 + 同名子目录”收成 `init.lua` 包入口。
- 同一轮内同步更新 `require`、测试、架构脚本、护栏和文档，不保留兼容壳文件。

实施前先把本计划写入 [`.agents/plan.md`](/C:/Users/Lzx_8/Desktop/dev/repo/monopoly/.agents/plan.md)，并严格按 [`.agents/harness/PLANS.md`](/C:/Users/Lzx_8/Desktop/dev/repo/monopoly/.agents/harness/PLANS.md) 维护活文档章节。

## 公共模块路径变更

以下模块 id 改为新的 canonical 路径，旧路径同轮退休：

- `src.presentation.model.model` -> `src.presentation.model`
- `src.presentation.model.model.{board_slice,item_slice,choice_slice,panel_slice}` -> `src.presentation.model.{board_slice,item_slice,choice_slice,panel_slice}`
- `src.presentation.runtime.view_service` -> `src.presentation.runtime.view`
- `src.presentation.runtime.view_service.{core,state,assets,item_slots,debug}` -> `src.presentation.runtime.view.{core,state,assets,item_slots,debug}`
- `src.presentation.view.render.board_runtime` -> `src.presentation.view.render.board`
- `src.presentation.view.render.board_runtime.{anchors,player_units,placement,events}` -> `src.presentation.view.render.board.{anchors,player_units,placement,events}`
- `src.presentation.runtime.presentation_ports` -> `src.presentation.runtime.ports`
- `src.presentation.runtime.runtime` -> `src.presentation.runtime.ui`
- `src.infrastructure.runtime.runtime_context` -> `src.infrastructure.runtime.context`
- `src.infrastructure.runtime.runtime_event_bridge` -> `src.infrastructure.runtime.event_bridge`
- `src.game.flow.turn.runtime` -> `src.game.flow.turn.engine`
- `src.game.flow.turn.turn_roll` -> `src.game.flow.turn.roll`
- `src.game.flow.turn.turn_move` -> `src.game.flow.turn.move`
- `src.game.systems.land.land_*` -> `src.game.systems.land.*`
- `src.game.systems.board.board` -> `src.game.systems.board`
- `src.game.systems.movement.movement` -> `src.game.systems.movement`
- `src.game.core.player.player` -> `src.game.core.player`
- `src.game.scheduler.scheduler` -> `src.game.scheduler`
- `src.game.systems.vehicle.vehicle_feature` -> `src.game.systems.vehicle`

只做包入口收口、不改变对外模块 id 的目录：

- `src/app/bootstrap/runtime.lua` -> `src/app/bootstrap/runtime/init.lua`
- `src/presentation/runtime/host.lua` -> `src/presentation/runtime/host/init.lua`
- `src/presentation/view/render/status3d.lua` -> `src/presentation/view/render/status3d/init.lua`

明确排除：

- 不改 `src/game/systems/market/market_service.lua -> service.lua`，因为 `src.game.systems.market.service` 已被 retired path 护栏占用。
- `market_service.lua` 改为 `src/game/systems/market/init.lua`，canonical 模块 id 为 `src.game.systems.market`。
- 不缩短 `src/presentation/runtime/ports/` 下的 `anim_ports.lua`、`modal_ports.lua`、`ui_sync_ports.lua` 等叶子名。
- `src.presentation.runtime.ports` 作为公开 bundle 根目录是唯一允许的 `ports/init.lua` 例外，文档必须同步改写说明。

## 任务与依赖

### T0
- **depends_on**: `[]`
- **description**: 写入 `.agents/plan.md`，冻结 rename manifest、排除项、验证命令、回滚说明。
- **location**: `.agents/plan.md`
- **validation**: 计划包含本页全部 canonical 路径、排除项与验收命令。

### T1
- **depends_on**: `[T0]`
- **description**: 先让 `arch_view` 正确识别 `init.lua` 包入口。`foo/init.lua` 必须映射为模块 `foo`，而不是 `foo.init`。同步补 `arch_view_contract`。
- **location**: `scripts/architecture/arch_view/*`, `tests/suites/architecture/arch_view_contract.lua`
- **validation**: `lua scripts/architecture/arch_view_cli.lua check` 不再把包入口误判为外部模块或未分类模块。

### T2
- **depends_on**: `[T1]`
- **description**: 完成 Presentation 侧改名与 require 切换：`model` 包入口、`view_service -> view`、`board_runtime -> board`、`runtime -> ui`、`presentation_ports -> ports`、`host` 包入口、`status3d` 包入口。
- **location**: `src/presentation/**`, `src/app/bootstrap/**`
- **validation**: `rg` 搜索旧 presentation 模块 id 在 `src/presentation` 与 `src/app/bootstrap` 中为 0。

### T3
- **depends_on**: `[T1]`
- **description**: 完成 Flow 与 Infrastructure 侧改名：`turn_{roll,move} -> {roll,move}`、`scheduler_turn_runtime -> engine` 并删除 `runtime.lua` 壳、`runtime_{context,event_bridge} -> {context,event_bridge}`。
- **location**: `src/game/flow/turn/**`, `src/infrastructure/runtime/**`, `src/game/core/runtime/**`
- **validation**: 仓库内不再存在 `src.game.flow.turn.runtime`、`turn_roll`、`turn_move`、`runtime_context`、`runtime_event_bridge` 的 require。

### T4
- **depends_on**: `[T1]`
- **description**: 完成 Systems 侧改名：`land_* -> *`，`board/movement/player/scheduler/market/vehicle` 包入口收口，并更新所有调用方。
- **location**: `src/game/systems/**`, `src/game/core/player/**`, `src/game/scheduler/**`
- **validation**: `rg` 不再命中 `src.game.systems.land.land_`；`market_service` 只迁到 `src.game.systems.market`，不出现 `src.game.systems.market.service`。

### T5
- **depends_on**: `[T2, T3, T4]`
- **description**: 全仓切换测试、脚本、调用点与白名单。重点更新 `TestSupport`、presentation/runtime/architecture suites、bootstrap、`composition_root`。
- **location**: `tests/**`, `scripts/**`, `src/app/**`, `src/game/core/runtime/composition_root.lua`
- **validation**: 旧模块 id 在 `src tests scripts docs` 中仅允许出现在新 retired-path 清单或计划文档说明中。

### T6
- **depends_on**: `[T5]`
- **description**: 回填架构真源与护栏。更新边界文档、`dep_rules`、`legacy_path_guard`、`monopoly_architecture.lua`，把新 canonical 路径和包入口规则写成真源。
- **location**: `docs/architecture/*.md`, `tests/internal/dep_rules.lua`, `tests/internal/legacy_path_guard.lua`, `scripts/architecture/monopoly_architecture.lua`
- **validation**: 文档不再把旧路径写成 canonical；`legacy_path_guard` 纳入本轮退休路径；`monopoly_architecture.lua` 接受 exact package id 与子模块两种形式。

### T7
- **depends_on**: `[T6]`
- **description**: 运行全量验证并把结果写回 `.agents/plan.md` 的“结果与复盘”。
- **location**: 仓库根目录
- **validation**: 下列命令全部通过，且 grep 清零旧模块 id。

## 并行波次

- **Wave 1**: `T0`, `T1`
- **Wave 2**: `T2`, `T3`, `T4`
- **Wave 3**: `T5`
- **Wave 4**: `T6`
- **Wave 5**: `T7`

## 关键实现约束

- `scripts/architecture/monopoly_architecture.lua` 中 `game.scheduler`、`game.core.player` 等规则改成接受 exact package id，例如 `^src%.game%.scheduler($|%..+)`、`^src%.game%.core%.player($|%..+)`。
- `tests/internal/dep_rules.lua` 中所有写死 `src.game.flow.turn.runtime` 的白名单、growth budget、snippet 规则同步改为 `engine`。
- `tests/internal/legacy_path_guard.lua` 需要同时做两件事：
  - 保留已有 retired path。
  - 增加本轮退休的旧 canonical 路径，如 `src.presentation.runtime.view_service`、`src.presentation.runtime.runtime`、`src.game.flow.turn.turn_roll` 等。
- `docs/architecture/boundaries.md` 和 `docs/architecture/layer-model.md` 必须补一句：公开 bundle 根模块可以采用目录包入口形式，例如 `src.presentation.runtime.ports`，但叶子 bundle 文件仍保留 `*_ports.lua`。
- 不改 `lua_env` 数值约束；如补测试或示例，继续使用 `NumberUtils`，不引入 `tonumber` / `type(x) == "number"`。

## 测试与验收

必须执行：

1. `lua -e "assert(require('src.presentation.model')); assert(require('src.presentation.runtime.view')); assert(require('src.presentation.runtime.ports')); assert(require('src.presentation.runtime.ui')); assert(require('src.game.flow.turn.engine')); assert(require('src.game.systems.market'))"`
2. `lua scripts/architecture/arch_view_cli.lua check`
3. `lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.architecture.arch_view_contract"), require("suites.architecture.architecture_guard_contract"), require("suites.architecture.usecase_boundary_contract")})'`
4. `lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui")})'`
5. `lua tests/regression.lua`
6. `rg -n 'src\.presentation\.model\.model|src\.presentation\.runtime\.view_service|src\.presentation\.view\.render\.board_runtime|src\.presentation\.runtime\.presentation_ports|src\.presentation\.runtime\.runtime|src\.infrastructure\.runtime\.runtime_context|src\.infrastructure\.runtime\.runtime_event_bridge|src\.game\.flow\.turn\.runtime|src\.game\.flow\.turn\.turn_(move|roll)|src\.game\.systems\.land\.land_' src tests docs scripts`

验收标准：

- 回归输出包含 `All regression checks passed`、`dep_rules ok`、`legacy_path_guard ok`。
- `arch_view_cli.lua check` 通过，且包入口模块未被误报。
- 第 6 条 grep 为 0，或仅命中 `.agents/plan.md` 中的历史说明。
- `src.game.systems.market.service` 在仓库中仍为 0。

## 默认假设

- 当前 Lua 5.1 `package.path` 已包含 `?\init.lua`，所以包入口方案可直接使用。
- 本轮不保留兼容壳文件；任何旧 `require` 命中都视为缺陷。
- `chance_*`、`effect_*`、`market_*` 等还存在命名冲突或语义不稳定的簇，本轮不继续压缩，后续单开计划。
