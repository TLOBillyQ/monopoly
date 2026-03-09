# `src/` 命名压缩与包入口收口

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。它是 `.agents/swarm_plan.md` 的实施真源，执行期间只维护这一份计划文件。

## 目的 / 全局视角

本轮重构的目标是压缩 `src/` 下目录名和文件名中的重复语义，但不改变运行时行为、端口契约或分层边界。完成后，开发者将通过更短、更稳定的模块路径访问核心入口，例如 `src.presentation.model`、`src.presentation.runtime.view`、`src.game.flow.turn.engine`，而不是继续使用重复词堆叠的旧路径。

这轮工作必须同时完成四件事。第一，把可机械判定的冗余命名改为更短的 canonical 路径。第二，让 `arch_view` 能把 `foo/init.lua` 识别为模块 `foo`，否则包入口方案会被静态架构检查误报。第三，在同一轮内切换全部 `require`、测试、护栏和文档，不保留兼容壳文件。第四，用 `legacy_path_guard` 明确退休旧 canonical 路径，避免回流。

可观察的成功标准有三条。其一，`lua tests/regression.lua`、架构 suite 和 presentation suite 全部通过。其二，旧模块 id grep 归零。其三，`docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 中的 canonical 路径和包入口规则与代码一致。

## 进度

- [x] (2026-03-09 08:55+08:00) 已读取 `.agents/swarm_plan.md`、`parallel-task` 技能说明和当前工作树，确认按全量计划执行。
- [x] (2026-03-09 09:05+08:00) 已把本轮命名压缩计划写入 `.agents/plan.md`，替换旧的前三周计划。
- [x] (2026-03-09 09:28+08:00) T1 完成：`arch_view` 现在把 `foo/init.lua` 识别为 `foo`，并修复了 Windows 下“相对 root + 绝对文件路径”导致的空扫描问题；`arch_view_contract` 与 `arch_view_cli.lua check` 均通过。
- [x] (2026-03-09 10:02+08:00) T2 完成：Presentation 侧已切到新 canonical 路径，`model`、`view`、`board`、`ports`、`ui`、`host`、`status3d` 均改为短名或包入口，所有调用方同步切换。
- [x] (2026-03-09 10:14+08:00) T3 完成：Flow / Infrastructure 侧已切到 `engine`、`move`、`roll`、`context`、`event_bridge`，并删除旧 `runtime.lua` 壳文件。
- [x] (2026-03-09 10:27+08:00) T4 完成：Systems 侧已完成 `land_*` 去前缀，以及 `board`、`movement`、`player`、`scheduler`、`market`、`vehicle` 的包入口收口。
- [x] (2026-03-09 10:42+08:00) T5 完成：`src/app/**`、`tests/**`、`scripts/**` 与跨层调用点已切到新模块 id，`TestHarness` 同步补上本地包入口加载路径。
- [x] (2026-03-09 10:51+08:00) T6 完成：`dep_rules`、`legacy_path_guard`、`monopoly_architecture.lua`、`boundaries.md`、`layer-model.md` 已切到新 canonical 路径并写入包入口规则。
- [x] (2026-03-09 11:03+08:00) T7 完成：smoke require、`arch_view_cli.lua check`、架构 suite、presentation suite 与 `lua tests/regression.lua` 全部通过；旧模块 id grep 归零。

## 意外与发现

- 观察：`parallel-task` 技能要求每个任务完成后立刻把日志写回计划文件，因此本文件必须在每个波次结束后回填，而不是最后一次性总结。
  证据：`C:/Users/Lzx_8/.agents/skills/parallel-task/SKILL.md` 明确要求 “ALWAYS mark completed tasks IN THE *-plan.md file AS SOON AS YOU COMPLETE IT!”。

- 观察：仓库本地 Lua 5.1 默认只保证 `./?.lua`，不保证 `./?/init.lua`；如果直接在仓库根运行 `lua -e "require('src.presentation.model')"` 会失败，需要显式补 `;./?/init.lua` 或经由 `tests/TestHarness.lua` 运行。
  证据：本轮 smoke require 只有在 `package.path=package.path..";./?/init.lua"` 后才能解析新的包入口模块；因此 `tests/TestHarness.lua` 已追加该路径。

- 观察：`src.game.systems.market.service` 已被 `legacy_path_guard` 视为 retired path，因此 `market_service.lua` 不能改成 `service.lua`，只能改成 `market/init.lua`。
  证据：`tests/internal/legacy_path_guard.lua` 的 retired_path_parts 包含 `{ "src", "game", "systems", "market", "service" }`。

- 观察：`arch_view` 在 Windows 上原本把 `dir /s` 返回的绝对路径与相对 `source_root` 直接做前缀匹配，导致实际模块扫描可能为空；本轮已一并修复。
  证据：修复前 `source_scan.scan({ source_roots = { "src" } })` 无法产出 `src.game.core.runtime.game`，修复后 `arch_view_contract` 与 `arch_view_cli.lua check` 均通过。

## 决策日志

- 决策：本轮不保留兼容壳文件。
  理由：用户指定“一次性切断”；旧路径应立即退休并交给 `legacy_path_guard` 兜底。
  日期/作者：2026-03-09 / Codex

- 决策：继续保留 `*_port.lua`、`*_ports.lua`、`*_port_adapter.lua` 的叶子文件语义。
  理由：`docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 已把这些后缀写成命名契约，只允许 bundle 根模块改为目录包入口。
  日期/作者：2026-03-09 / Codex

- 决策：`market_service.lua` 改为 `market/init.lua`，canonical 模块 id 为 `src.game.systems.market`。
  理由：这样既能压掉 `market_` 前缀，又不会复活 retired 的 `src.game.systems.market.service`。
  日期/作者：2026-03-09 / Codex

- 决策：在 T1 提前修改 `scripts/architecture/monopoly_architecture.lua` 的 `app` 组件规则，使其接受 exact package id `src.app`。
  理由：一旦 `source_scan` 正确识别 `src/app/init.lua`，旧规则 `^src%.app%..+` 会把 `src.app` 误判为未分类模块，阻塞所有后续工作。
  日期/作者：2026-03-09 / Codex

## 结果与复盘

本轮目标已完成。`src/` 下可机械判定的冗余命名已经压缩为更短的 canonical 路径，`arch_view` 现在把 `foo/init.lua` 正确识别为模块 `foo`，测试、护栏、文档和调用方均已与新路径对齐。用户现在可以稳定使用 `src.presentation.model`、`src.presentation.runtime.view`、`src.presentation.runtime.ports`、`src.presentation.runtime.ui`、`src.game.flow.turn.engine`、`src.game.systems.market` 等短路径，而不再依赖 `model.model`、`view_service`、`turn_roll` 一类历史名称。

本轮还顺手修掉了一个会误导后续迁移的问题：Windows 下 `arch_view` 的源码扫描此前会把相对 `source_root` 与绝对文件路径直接比较，导致扫描结果可能为空；这也是为什么在迁包入口之前，必须先修 `source_scan.lua`。除此之外，仓库本地 Lua 运行环境对 `init.lua` 包入口的支持并不完整，必须补 `./?/init.lua`；为避免每个测试命令都手写该路径，本轮把它收进了 `tests/TestHarness.lua`。

最终验证结果如下。`lua -e "package.path=package.path..';./?/init.lua'; assert(require('src.presentation.model')); assert(require('src.presentation.runtime.view')); assert(require('src.presentation.runtime.ports')); assert(require('src.presentation.runtime.ui')); assert(require('src.game.flow.turn.engine')); assert(require('src.game.systems.market'))"` 通过。`lua scripts/architecture/arch_view_cli.lua check` 通过。架构 suite 通过并输出 `All regression checks passed (27)`。presentation suite 通过并输出 `All regression checks passed (135)`。`lua tests/regression.lua` 通过并输出 `All regression checks passed (394)`、`dep_rules ok`、`legacy_path_guard ok`、`arch_view_guard ok`。最后执行旧路径 grep 时返回码为 1，说明旧 canonical 模块 id 已从仓库内容中清零。

## 背景与导读

当前命名冗余集中在四类位置。第一类是“公共入口文件 + 同名子目录”，例如 `src/presentation/model/model.lua` 搭配 `src/presentation/model/model/*`，`src/presentation/runtime/view_service.lua` 搭配 `src/presentation/runtime/view_service/*`，`src/presentation/view/render/board_runtime.lua` 搭配 `src/presentation/view/render/board_runtime/*`。第二类是“父目录已表达语义，文件名继续重复前缀”，例如 `src/game/flow/turn/turn_roll.lua`、`src/game/flow/turn/turn_move.lua` 和 `src/game/systems/land/land_rules.lua` 等。第三类是“旧门面名偏长但职责清晰”，例如 `src/presentation/runtime/runtime.lua` 和 `src/infrastructure/runtime/runtime_context.lua`。第四类是“可收成包入口但 public module id 现状冗长”，例如 `src/game/systems/board/board.lua` 和 `src/game/scheduler/scheduler.lua`。

与本轮直接相关的关键文件有：

- `scripts/architecture/arch_view/*` 与 `tests/suites/architecture/arch_view_contract.lua`：决定静态模块扫描是否理解 `init.lua`。
- `src/presentation/**`：本轮最多的公共路径收口发生在这里。
- `src/game/flow/turn/**`、`src/infrastructure/runtime/**`、`src/game/systems/**`：Flow、Infrastructure 与 Systems 侧的命名压缩。
- `tests/internal/dep_rules.lua`、`tests/internal/legacy_path_guard.lua`、`scripts/architecture/monopoly_architecture.lua`：需要跟着新 canonical 路径一起改的护栏真源。
- `docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`：需要同步记录“包入口 bundle 根模块”的命名规则。

本轮固定的 canonical 路径如下：

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
- `src.game.systems.market.market_service` -> `src.game.systems.market`
- `src.game.systems.vehicle.vehicle_feature` -> `src.game.systems.vehicle`

只做包入口收口、不改变 public module id 的目录如下：

- `src/app/bootstrap/runtime.lua` -> `src/app/bootstrap/runtime/init.lua`
- `src/presentation/runtime/host.lua` -> `src/presentation/runtime/host/init.lua`
- `src/presentation/view/render/status3d.lua` -> `src/presentation/view/render/status3d/init.lua`

明确排除项如下：

- 不把 `market_service.lua` 改成 `service.lua`。
- 不缩短 `src/presentation/runtime/ports/` 下的 `*_ports.lua` 叶子文件名。
- 不对 `chance_*`、`effect_*`、`market_*` 等存在现成命名冲突的簇继续做激进压缩。

## 工作计划

先做 T1，再并行推进 T2、T3、T4。原因是只要 `arch_view` 还把 `init.lua` 看成 `foo.init`，后面所有包入口改名都会把架构检查打爆，导致无法区分真实错误和工具误报。T1 完成后，再分三路实施：Presentation、Flow/Infrastructure、Systems。三路都完成后，再统一切到测试、脚本、调用点与白名单，然后最后更新文档和护栏真源。

具体编辑顺序固定如下。先在 `scripts/architecture/arch_view` 的扫描与模块 id 推导逻辑里识别 `init.lua`，把 `.../foo/init.lua` 归一成 `...foo`；同步在 `tests/suites/architecture/arch_view_contract.lua` 新增一个包入口用例。然后改 `src/presentation/**`：把入口文件迁到 `init.lua` 或短名文件，更新内部 `require`、`src/app/bootstrap/*` 和 presentation suites。接着改 `src/game/flow/turn/**` 和 `src/infrastructure/runtime/**`：迁掉 `turn_`、`runtime_` 冗余，并删除 `src/game/flow/turn/runtime.lua` 壳。再改 `src/game/systems/**`、`src/game/core/player/**`、`src/game/scheduler/**`：完成 `land_*` 去前缀和各自的包入口收口。全部代码切完后，再集中改 `tests/internal/dep_rules.lua`、`tests/internal/legacy_path_guard.lua`、`scripts/architecture/monopoly_architecture.lua` 与架构文档。最后执行全量验证，失败时只修正路径切换遗漏或护栏规则，不回滚命名方案本身。

## 具体步骤

在仓库根目录执行并记录输出：

    lua -e "print(package.path)"

期望看到输出至少包含 `./?.lua`。如果需要直接 `require("src.presentation.model")` 这类包入口模块，必须显式补 `;./?/init.lua`，或者经由已补路径的 `tests/TestHarness.lua` 执行。

先完成 T1 后运行：

    lua scripts/architecture/arch_view_cli.lua check

期望 `arch_view` 不再把 `foo/init.lua` 识别成 `foo.init`。

三路重命名完成后，执行路径清扫：

    rg -n "src\.presentation\.model\.model|src\.presentation\.runtime\.view_service|src\.presentation\.view\.render\.board_runtime|src\.presentation\.runtime\.presentation_ports|src\.presentation\.runtime\.runtime|src\.infrastructure\.runtime\.runtime_context|src\.infrastructure\.runtime\.runtime_event_bridge|src\.game\.flow\.turn\.runtime|src\.game\.flow\.turn\.turn_(move|roll)|src\.game\.systems\.land\.land_" src tests docs scripts

期望只剩计划文档中的历史说明；如果 `src.game.systems.market.service` 出现，说明误用了被退休的短名。

终验按固定顺序执行：

    lua -e "package.path=package.path..';./?/init.lua'; assert(require('src.presentation.model')); assert(require('src.presentation.runtime.view')); assert(require('src.presentation.runtime.ports')); assert(require('src.presentation.runtime.ui')); assert(require('src.game.flow.turn.engine')); assert(require('src.game.systems.market'))"

    lua scripts/architecture/arch_view_cli.lua check

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.architecture.arch_view_contract"), require("suites.architecture.architecture_guard_contract"), require("suites.architecture.usecase_boundary_contract")})'

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui")})'

    lua tests/regression.lua

成功时应看到架构 suite 通过、presentation suite 通过、`All regression checks passed`、`dep_rules ok`、`legacy_path_guard ok`。

## 验证与验收

验收标准固定为：

第一，`arch_view` 正确识别包入口，且不会把 `foo/init.lua` 误当成 `foo.init`。

第二，所有新 canonical 路径都能被 `require(...)` 成功解析，旧 canonical 路径在代码、测试、脚本和文档里全部退休。

第三，`tests/internal/dep_rules.lua`、`tests/internal/legacy_path_guard.lua`、`scripts/architecture/monopoly_architecture.lua` 与架构文档都使用新 canonical 路径，不再夹带旧 module id。

第四，`market_service.lua` 只迁到 `src.game.systems.market`，仓库里仍不出现 `src.game.systems.market.service`。

## 可重复性与恢复

本轮步骤应保持可重复。`rg` 清扫、架构 suite、presentation suite 和 `lua tests/regression.lua` 可以重复执行，不应引入额外副作用。若某一步中途失败，先修正该步遗漏的 `require`、测试引用或护栏规则，再重复执行同一步的验证命令。不得通过恢复兼容壳文件来规避错误；如果必须回退，应只回退最近一批尚未通过验证的重命名补丁。

## 产物与备注

关键产物应包括：

    .agents/plan.md
    scripts/architecture/arch_view/*
    src/presentation/**
    src/game/flow/turn/**
    src/infrastructure/runtime/**
    src/game/systems/**
    tests/internal/dep_rules.lua
    tests/internal/legacy_path_guard.lua
    scripts/architecture/monopoly_architecture.lua
    docs/architecture/boundaries.md
    docs/architecture/layer-model.md

每个任务完成后，都要在本文件回填“进度”、必要的“意外与发现”、对应“决策日志”以及最终“结果与复盘”。

## 接口与依赖

`arch_view` 的模块解析逻辑必须支持两种 canonical 形式：普通文件 `foo/bar.lua` -> `foo.bar`，以及包入口文件 `foo/bar/init.lua` -> `foo.bar`。`monopoly_architecture.lua` 中对 `game.scheduler`、`game.core.player` 之类的规则必须接受 exact package id 和子模块两种形式，例如：

    ^src%.game%.scheduler($|%..+)
    ^src%.game%.core%.player($|%..+)

`dep_rules` 中所有写死旧路径的 snippet 白名单、growth budget 和 retired module 检查都必须同步改成新 canonical 名。`legacy_path_guard` 需要把本轮退休的旧 canonical 路径加入 retired 列表，例如 `src.presentation.runtime.view_service`、`src.presentation.runtime.runtime`、`src.game.flow.turn.turn_roll`、`src.game.flow.turn.turn_move`、`src.game.flow.turn.runtime`、`src.infrastructure.runtime.runtime_context`、`src.infrastructure.runtime.runtime_event_bridge`。

本文件于 2026-03-09 11:12+08:00 更新：回填 T2-T7 的实际完成状态、修正本地 `package.path` 前提、补充最终验证结果与复盘，原因是实施已完成且此前文档仍停留在 T1。
