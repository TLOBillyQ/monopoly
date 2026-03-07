# 目录层级优化执行计划（保守收敛版）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护；来源计划为仓库根目录 `PLAN.md`，实施时以本文件作为唯一持续更新的执行面板。

## 目的 / 全局视角

本次工作在**不改变既有 7 组件分层与 5 个顶层命名空间**的前提下，收敛 `src/` 与 `tests/` 的目录语义，消除 `runtime / adapter / service / ports / shared` 多主轴混排带来的认知成本。完成后，读者应能看到以下可见结果：

- `src.app`、`src.core`、`src.game`、`src.infrastructure`、`src.presentation` 五个顶层命名空间保持不变，但各自子目录的命名主轴更稳定。
- `src.core.runtime_facade.*`、`src.game.turn_engine.*`、`src.game.systems.market.service.*`、`src.presentation.adapter.*`、`src.presentation.canvas_runtime.*`、`src.app.bootstrap.runtime_install*` 等旧路径在 `src/` 与 `tests/` 中被清零。
- `tests/regression.lua` 能加载 namespaced suite，并对退役路径提供护栏。
- `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 中的目录示例与实际树结构一致。

## 进度

- [x] (2026-03-07 09:00 +08:00) 从 `PLAN.md` 提炼任务图、依赖与验收口径。
- [x] (2026-03-07 09:10 +08:00) 重建 `.agents/plan.md`，补齐可执行计划必需章节、映射表与迁移日志模板。
- [x] (2026-03-07 23:57 +08:00) T1：建立回归护栏与旧路径残留检查；`tests/regression.lua` 改为从 `tests/suites/manifest.lua` 加载 suites，并接入 `tests/internal/legacy_path_guard.lua`。
- [x] (2026-03-08 00:02 +08:00) T2：完成低爆点目录重命名并清零旧 require。
- [x] (2026-03-08 00:03 +08:00) T3：统一 `src.app.bootstrap.runtime.*` 命名空间。
- [x] (2026-03-08 00:06 +08:00) T4：重组 `src.presentation` 为 `input / model / view / runtime`。
- [x] (2026-03-08 00:08 +08:00) T5：按 namespaced 目录重组 `tests/suites` 并接入 manifest。
- [x] (2026-03-08 00:11 +08:00) T6：全量回归、清场 stale require，并同步架构文档。

## 意外与发现

- 观察：现有 `.agents/plan.md` 是“清理兼容层与遗留债务”的旧计划，与本次目录迁移工作不一致，因此必须整体重建，不能在旧计划上增量修改。
  证据：旧文件标题与里程碑聚焦兼容壳删除、UI runtime state 迁移，与 `PLAN.md` 的目录重组目标完全不同。
- 观察：当前仓库仍有大量旧目录引用，尤其 `src.presentation.adapter` 与 `src.core.runtime_facade`；意味着 `presentation` 波次必须在低爆点迁移后执行，避免一次性爆炸式回归。
  证据：`rg -n "runtime_facade|presentation\.adapter|presentation\.canvas_runtime|turn_engine|systems\.market\.service|runtime_install" src tests` 命中大量生产模块。
- 观察：`tests/regression.lua` 的 `package.path` 其实已经允许 `require("suites.foo.bar")` 这类子目录模块；缺的是 suite manifest 和统一加载入口，而不是额外的 Lua 搜索路径技巧。
  证据：本次把回归入口改为 `require("suites.manifest")` + `require(module_name)` 后，现有 suites 可正常加载；失败点转为预期的旧路径护栏报警。
- 观察：`T1` 完成后，`lua tests/regression.lua` 会在业务 suite 全部跑完后被 `legacy_path_guard` 明确打红，并列出命中的旧路径与文件行号；这正是后续目录迁移所需的护栏形态。
  证据：回归输出包含 `legacy_path_guard: tests/suites/presentation_ui.lua:42 contains src.core.runtime_facade`、`legacy_path_guard: tests/suites/market.lua:47 contains src.game.systems.market.service` 等定位信息。
- 观察：`tests/suites` 的物理 namespacing 完成后，suite 组内 helper 也必须跟着改成 `suites.<group>.*` 路径；否则 `manifest` 已切换成功，但组内 registry require 会在总回归时失败。
  证据：总回归首次切到 namespaced manifest 时，`tests/suites/gameplay/gameplay_core.lua` 报 `module 'suites.gameplay.gameplay_registry' not found`；将组内 require 与 `manifest` 一并对齐后恢复通过。
- 观察：`presentation_ui` 中少量测试夹具仍手写 root 级 `ui_model` / `pending_choice_selected_option_id`；迁移到 `runtime_state` 真源后，这类夹具要显式改写到 `state.ui_runtime.*`。
  证据：`_test_ui_event_router_market_cancel_button_dispatches_choice_cancel` 初次运行返回 `got=nil`，把夹具切到 `ui_runtime.ui_model` 与 `ui_runtime.pending_choice_selected_option_id` 后通过。
- 观察：`presentation` 的最终落地形态采用“职责面 + 次级子树”折中：顶层收敛为 `input / model / view / runtime`，但在 `view/` 下保留 `canvas / widgets / render / support` 子树，在 `runtime/` 下保留 `presentation_ports / ui_view_service / host_runtime` 子树，以减少同名文件冲突并保留局部可读性。
  证据：当前树结构为 `src/presentation/view/{canvas,widgets,render,support}` 与 `src/presentation/runtime/{presentation_ports,ui_view_service,host_runtime,...}`。
- 观察：`tests/suites` 物理归组后，`tests/regression.lua` 无需额外改 Lua 搜索路径，只需把 manifest 切到 namespaced 模块名即可；`tests/?.lua` 已能解析 `require("suites.domain.market")` 这类路径。
  证据：最终 manifest 使用 `suites.domain.*`、`suites.gameplay.*`、`suites.presentation.*`、`suites.runtime.*` 模块名，`lua tests/regression.lua` 仍稳定通过。

## 决策日志

- 决策：先执行 T0/T1，再按 `T2 + T3 -> T4 -> T5 -> T6` 的依赖顺序推进，不跳过护栏阶段。
  理由：`presentation` 与 `tests` 的爆点最高，先建立 suite manifest 与旧路径扫描，能在后续路径迁移中尽早暴露遗漏。
  日期/作者：2026-03-07 / Codex
- 决策：不保留长期兼容 shim，迁移批次内同步改完内部 `require`。
  理由：根计划已明确“实施时一次性更新内部 require，不保留长期兼容 shim”；继续保留转发壳会让目录语义再次退化。
  日期/作者：2026-03-07 / Codex
- 决策：执行过程中不创建 git commit。
  理由：本会话的上位执行约束要求“除非用户明确要求，否则不要 git commit”；因此仅完成工作区修改、验证与计划更新。
  日期/作者：2026-03-07 / Codex
- 决策：旧路径残留检查单独放在 `tests/internal/legacy_path_guard.lua`，并直接接入 `tests/regression.lua` 尾部，而不是把它折叠进 `dep_rules.lua`。
  理由：该护栏是阶段性迁移门禁，和常驻层边界规则分开更容易在 T2-T6 中观察命中面，也避免把 `dep_rules` 的职责继续做大。
  日期/作者：2026-03-07 / Codex
- 决策：suite manifest 在 T1 先保持“逻辑 namespaced、物理目录未搬迁”的过渡状态。
  理由：这样可以先让 `tests/regression.lua` 摆脱硬编码列表，同时把真正的测试目录重组留到依赖更晚的 T5，降低一次性改动面。
  日期/作者：2026-03-07 / Codex

## 结果与复盘

- 当前状态：T0-T6 已全部完成。目录迁移、测试树归组、文档示例同步和总回归验证均已收口。
- 已获得结果：`src.core.state_access`、`src.game.legacy.turn_engine`、`src.game.systems.market.application`、`src.app.bootstrap.runtime.*`、`src.presentation.{input,model,view,runtime}` 与 `tests/suites/{architecture,domain,gameplay,presentation,runtime}` 均已落地。
- 最终验证：`lua tests/regression.lua` 通过，输出 `All regression checks passed (384)`、`dep_rules ok`、`legacy_path_guard ok`、`forbidden_globals ok`。
- 经验复盘：对高爆点目录重排，先用 `legacy_path_guard` 把旧路径“打红”，再分波迁移并以 manifest 控制 suite 入口，明显降低了排错成本。

## 背景与导读

本节面向首次接手该仓库的读者，说明本次目录优化涉及的关键现状与边界。

### 顶层边界

- `src/app`：启动期装配与 bootstrap。
- `src/core`：跨场景稳定内核、状态访问与通用接口。
- `src/game`：玩法领域、用例编排、系统规则与 legacy 容器。
- `src/infrastructure`：宿主运行时、外部 API、具体设施实现。
- `src/presentation`：输入、读模型、视图、UI 运行时桥接。

### 当前迁移热点

- `src.presentation.adapter`：约 107 处引用，必须最后迁移。
- `src.game.systems.market.service`：约 47 处引用，属于低爆点重命名范围。
- `src.core.runtime_facade`：约 38 处引用，属于低爆点重命名范围。
- `src.presentation.canvas_runtime`：约 14 处引用，纳入 `presentation.runtime` 收敛。
- `src.game.turn_engine`：约 5 处引用，适合先迁入 `src.game.legacy.turn_engine`。

### 相关规范与背景文档

- `docs/architecture/boundaries.md`：目录语义与边界约定；最终需同步示例。
- `docs/architecture/layer-model.md`：7 组件分层模型、Port 注入模式与已强制边界；最终需同步示例。
- `docs/eggy/lua_env.md`：Lua 环境约束；若涉及数值处理，统一走 `NumberUtils`，避免 `tonumber` 与 `type(x) == "number"`。
- `docs/eggy/ui_manager_lib.md`：`UIManagerLib` 负责 UI 组件注册、查询与事件分发；`presentation.runtime` 重组时不得绕开其边界语义。
- `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 已定义层边界；目录重构只允许修 require 方向，不允许引入新的跨层依赖。

## 当前→目标模块映射表

| 当前路径前缀 | 目标路径前缀 | 说明 |
|---|---|---|
| `src.core.runtime_facade.*` | `src.core.state_access.*` | 澄清其职责是状态访问层，而非宿主 runtime façade |
| `src.game.turn_engine.*` | `src.game.legacy.turn_engine.*` | 标记为冻结历史容器，禁止新增调用方 |
| `src.game.systems.market.service.*` | `src.game.systems.market.application.*` | 表达“用例编排”语义 |
| `src.game.systems.land.config.*` | `src.game.systems.land.specs.*` | 用规格（specs）替代配置（config）语义 |
| `src.game.systems.commerce.config.runtime_paid_goods` | `src.game.systems.commerce.specs.paid_goods` | 仅做目录语义收敛 |
| `src.app.bootstrap.runtime_install` + `src.app.bootstrap.runtime_install.*` | `src.app.bootstrap.runtime.*` | 安装入口与细节统一到单一命名空间 |
| `src.presentation.interaction.*` | `src.presentation.input.*` | 输入职责面 |
| `src.presentation.state.*` + `src.presentation.read_model.*` | `src.presentation.model.*` | 读模型职责面 |
| `src.presentation.canvas.*` + `src.presentation.widgets.*` + `src.presentation.render.*` | `src.presentation.view.*` | 视图职责面 |
| `src.presentation.adapter.*` + `src.presentation.canvas_runtime.*` + `src.presentation.shared.ui_events` | `src.presentation.runtime.*` | UI 运行时桥接职责面 |
| `src.presentation.shared.market_layout` | `src.presentation.view.support.market_layout` | 视图支持模块 |
| `src.presentation.shared.player_colors` | `src.presentation.view.support.player_colors` | 视图支持模块 |
| `src.presentation.shared.ui_aliases` | `src.presentation.view.support.ui_aliases` | 视图支持模块 |
| `tests/suites/*`（扁平） | `tests/suites/{architecture,domain,gameplay,presentation,runtime}/*` | namespaced suites |

## 工作计划

先用 T1 在 `tests/regression.lua` 建立 namespaced suite 加载能力，并增加旧路径残留扫描，让后续迁移失败能第一时间从回归护栏暴露。然后执行低爆点目录迁移：优先处理 `src/core/runtime_facade`、`src/game/turn_engine`、`src/game/systems/market/service`、`src/game/systems/land/config`、`src/game/systems/commerce/config/runtime_paid_goods.lua`，同步替换 `src/` 与 `tests/` 中的 require 前缀，并补跑架构边界相关 suite。

低爆点完成后，单独处理 `src/app/bootstrap/runtime_install.lua` 与其子目录，把安装入口和细节统一收敛到 `src.app.bootstrap.runtime.*`，同时保持 `src.app.init` 的外部职责不变。随后再执行 `presentation` 大波次，把 `interaction`、`state/read_model`、`canvas/widgets/render`、`adapter/canvas_runtime/shared.ui_events` 按职责面搬迁到 `input`、`model`、`view`、`runtime`，只修路径和边界，不顺手改变业务逻辑。

`presentation` 波次稳定后，再重组 `tests/suites` 的物理目录，使 suite manifest 与目录结构一致，并将旧路径扫描接入回归尾部。最后在 T6 跑完整回归、清理剩余 stale require 与 manifest 漏项，更新 `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 的目录示例文本，并在本文件补齐结果与复盘。

## 具体步骤

1. 在仓库根目录 `/Users/gangan/Dev/repo/monopoly` 执行计划初始化与现状扫描：

       rg -n "runtime_facade|turn_engine|systems\.market\.service|systems\.land\.config|runtime_paid_goods|runtime_install|presentation\.adapter|presentation\.canvas_runtime" src tests

   预期：命中当前旧目录引用，为后续清零提供基线。

2. 执行 T1 时，修改 `tests/regression.lua` 与必要的 suite/guard 文件，随后在仓库根目录运行：

       lua tests/regression.lua

   预期：在旧路径仍存在的阶段，新增“旧路径残留”护栏能够明确指出命中的旧前缀，且不会扫描 `vendor/`、`Config/`、`Data/`。

3. 执行 T2/T3/T4/T5 每个波次后，在仓库根目录增量运行相关 suite 或总回归：

       lua tests/regression.lua

   预期：相关 suite 通过；若失败，错误信息使用新 namespaced suite 名称或新路径定位遗漏。

4. 执行 T6 时，完成文档同步与终验，再次在仓库根目录运行：

       lua tests/regression.lua

   预期：377 项回归通过，输出包含 `dep_rules ok` 与 `forbidden_globals ok`，且文档中不再出现退役目录名。

## 验证与验收

总验收以 `lua tests/regression.lua` 为准，并辅以以下显式检查：

- 旧路径清零：`src.core.runtime_facade`、`src.game.turn_engine`、`src.presentation.adapter`、`src.presentation.canvas_runtime`、`src.game.systems.market.service`、`src.app.bootstrap.runtime_install` 在 `src/` 与 `tests/` 中不再出现。
- 边界不退化：`architecture_guard_contract`、`usecase_boundary_contract`、`cross_module_contract`、`runtime_ports_contract`、`ui_runtime_state_contract` 通过。
- 关键业务场景未坏：黑市选择与分页、选择弹窗 / 远端选择 / 二次确认、turn dispatch 与 gameplay loop 的 UI dirty 流、bankruptcy / land event / action anim 桥接。
- 文档一致性：`docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 中不再使用退役目录名作为示例。

变更前后的差异验证口径为：“新增护栏在旧路径存在时应报错；目录迁移完成后护栏回归为绿；相关 suite 在变更前可能失败或未覆盖，变更后进入稳定护栏。”

## 可重复性与恢复

本计划中的扫描与回归命令可重复执行。目录迁移属于高风险批量改名，建议按 T2/T3/T4/T5 波次逐步落地并在每波结束后立即回归。若某一波失败，应优先恢复该波次内的 require 一致性，再次运行 `lua tests/regression.lua`，避免跨波次叠加排错。

本次工作明确**不保留长期兼容 shim**；因此如需回滚，应按单个波次撤回对应目录与 require 变更，而不是临时增加转发壳。执行完成后，应保持 `src/`、`tests/`、文档与本计划中的命名一致，避免计划与实现再次漂移。

## 产物与备注

关键产物包括：

- `.agents/plan.md`：本执行计划与进度面板。
- `tests/regression.lua` 与相关护栏文件：suite manifest 与旧路径扫描。
- 目录迁移后的 `src/`、`tests/`、文档更新。

迁移日志模板（每完成一个任务后追加到本文件对应章节或提交说明中）：

    - 任务：T?
      时间：2026-03-07 HH:MM +08:00
      变更：<一句话说明>
      文件：<修改/新增/删除路径列表>
      验证：<运行的命令与结果>
      备注：<风险、遗漏或后续依赖>

    - 任务：T1
      时间：2026-03-07 23:57 +08:00
      变更：回归入口改为通过 manifest 加载 suites，并新增旧路径残留护栏脚本。
      文件：tests/regression.lua；tests/suites/manifest.lua；tests/internal/legacy_path_guard.lua
      验证：`lua tests/regression.lua`（预期失败）；失败尾部由 `legacy_path_guard` 列出旧路径命中与行号。
      备注：suite 物理目录仍保持原状，待 T5 再做真正的 namespaced 目录重组。

    - 任务：T2/T3
      时间：2026-03-08 00:20 +08:00
      变更：完成低爆点目录迁移，并把 bootstrap runtime 安装入口统一到 `src.app.bootstrap.runtime*`。
      文件：`src/core/state_access/*`；`src/game/legacy/turn_engine/*`；`src/game/systems/market/application/*`；`src/game/systems/land/specs/*`；`src/game/systems/commerce/specs/paid_goods.lua`；`src/app/bootstrap/runtime.lua`；`src/app/bootstrap/runtime/*`；相关 `src/` 与 `tests/` require。
      验证：逐个运行 `runtime_ports_contract`、`ui_runtime_state_contract`、`gameplay_coroutine`、`market`、`paid_currency`、`intent_output_contract`，均通过。
      备注：共享收口文件（如 `tests/internal/dep_rules.lua`、`tests/suites/gameplay.lua`）由主代理统一整合。

    - 任务：T4
      时间：2026-03-08 00:31 +08:00
      变更：将 `src.presentation` 收敛为 `input / model / view / runtime` 四个职责面，并修正相关测试夹具。
      文件：`src/presentation/input/*`；`src/presentation/model/*`；`src/presentation/view/*`；`src/presentation/runtime/*`；相关 `tests/suites/presentation/*` 与 `tests/TestSupport.lua`。
      验证：逐个运行 `read_model_contract`、`ui_gate_contract`、`presentation_ui_action_anim`、`presentation_ui_event_handlers`、`presentation_ui_event_bindings`、`presentation_player_colors`、`runtime_bootstrap`、`presentation_ui`，均通过。
      备注：有一个 `market_cancel` 用例需要把测试夹具从 root UI 字段迁到 `ui_runtime` 真源。

    - 任务：T5/T6
      时间：2026-03-08 00:40 +08:00
      变更：对齐 `tests/suites` namespaced manifest、修正 suite 组内 registry require，并同步 `docs/architecture` 示例。
      文件：`tests/suites/manifest.lua`；`tests/suites/gameplay/*`；`tests/suites/presentation/*`；`docs/architecture/boundaries.md`；`docs/architecture/layer-model.md`。
      验证：`lua tests/regression.lua` 通过；输出 `All regression checks passed (384)`、`dep_rules ok`、`legacy_path_guard ok`、`forbidden_globals ok`。
      备注：最终 manifest 保持原回归口径，不把额外 exploratory suite 纳入默认总回归。

    - 任务：T2/T3
      时间：2026-03-08 00:03 +08:00
      变更：完成 `core/game/app.bootstrap` 的低爆点路径迁移，统一到 `state_access`、`legacy.turn_engine`、`market.application`、`land.specs`、`commerce.specs` 与 `app.bootstrap.runtime.*`。
      文件：`src/core/`、`src/game/`、`src/app/bootstrap/`、`tests/` 对应引用与 `tests/internal/dep_rules.lua`。
      验证：`lua tests/regression.lua`（中途先由 `legacy_path_guard` 报 `presentation` 旧路径，低爆点旧前缀已清零）。
      备注：`gameplay.lua` 中的 `runtime.global_aliases` 共享引用需主代理额外收口一次。

    - 任务：T4
      时间：2026-03-08 00:06 +08:00
      变更：将 `src/presentation` 收敛到 `input / model / view / runtime` 顶层职责面，并同步全量 require。
      文件：`src/presentation/`、`src/app/bootstrap/`、`tests/suites/presentation/*` 等。
      验证：`lua tests/regression.lua` 通过，`legacy_path_guard ok`。
      备注：`view/` 与 `runtime/` 下保留次级子树以避免同名文件冲突。

    - 任务：T5/T6
      时间：2026-03-08 00:11 +08:00
      变更：将 `tests/suites` 物理归组为 `architecture / domain / gameplay / presentation / runtime`，同步 manifest 与少量 suite 间引用，并更新 `docs/architecture/boundaries.md`、`docs/architecture/layer-model.md` 的路径示例。
      文件：`tests/suites/`、`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`。
      验证：`lua tests/regression.lua` → `All regression checks passed (384)`、`dep_rules ok`、`legacy_path_guard ok`、`forbidden_globals ok`。
      备注：保留与 T1 一致的 suite 覆盖范围，仅把入口改成 namespaced manifest，避免意外扩大回归面。

## 接口与依赖

本次工作必须遵循现有架构边界与接口约束：

- `src/app/init.lua` 继续作为应用入口，不改变其对外职责，只调整内部 require。
- `tests/regression.lua` 必须支持 namespaced suite 加载；suite manifest 若新增，应作为唯一真实入口，避免继续依赖扁平短名。
- `presentation` 迁移只允许修导入方向与目录归位；不得新增 `src.presentation -> src.game.systems` 直接依赖。
- 涉及 UI 运行时桥接的模块，应保持通过 `UIManagerLib`、runtime port 或既有桥接接口交互，而非绕过边界直接读写宿主对象。
- 若代码涉及数值判断或转换，统一使用仓库的 `NumberUtils` 约定，避免 `tonumber` 与 `type(x) == "number"`。

## 里程碑

### 里程碑 1：护栏先行，冻结命名漂移

范围是 T1。完成后，仓库第一次具备“旧路径残留自动报警”的能力；这在迁移前是没有的。工作内容包括：给 `tests/regression.lua` 接入 namespaced suite 加载能力，新增旧路径残留检查，并保证它不会误扫 `vendor/`、`Config/`、`Data/`。验收方式是运行 `lua tests/regression.lua`，预期在旧路径仍存在的情况下出现清晰、可定位的报警，证明护栏生效。

### 里程碑 2：低爆点目录先收敛

范围是 T2 与 T3。完成后，`core`、`game`、`app.bootstrap` 的旧目录名将被新语义目录替代，且 `src.app.init` 的外部职责不变。工作内容包括：完成低爆点目录迁移、替换 `src/` 与 `tests/` require、补齐 `app.bootstrap.runtime.*` 命名空间。验收方式是运行与架构边界相关的 suite，并确认旧前缀在代码中清零。

### 里程碑 3：高爆点 `presentation` 收口

范围是 T4。完成后，`presentation` 将按 `input / model / view / runtime` 四个稳定职责面组织，目录语义明显改善。工作内容包括：按职责面搬迁 `interaction`、`state/read_model`、`canvas/widgets/render`、`adapter/canvas_runtime/shared.ui_events` 及若干 `shared` 支撑模块，只修目录与 require，不改业务逻辑。验收方式是运行 `presentation_ui_*`、`read_model_contract`、`ui_gate_contract`、`ui_runtime_state_contract` 并确保 `dep_rules` 无新增豁免。

### 里程碑 4：测试树与文档最终对齐

范围是 T5 与 T6。完成后，`tests/suites` 目录与 suite manifest 的 namespaced 结构一致，架构文档中的目录示例与新树同步。工作内容包括：重组 `tests/suites`、将旧路径扫描接入回归尾部、跑完整 `lua tests/regression.lua`、更新 `docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md`。验收方式是总回归通过，suite 数量不减少，文档中不再出现退役目录名。

---

更新说明（2026-03-07 / Codex）：用 `PLAN.md` 重建 `.agents/plan.md`，因为原文件对应的是另一轮“兼容层清理”工作，无法作为当前目录重组的执行面板；本次新增了任务依赖、当前→目标映射表、迁移日志模板和按 PLANS 规范要求的活文档章节。
更新说明（2026-03-08 / Codex）：完成 T2-T6，补记低爆点迁移、`presentation` 四职责面重组、suite namespaced 清单对齐与文档同步，并把最终回归结果写回本计划。

更新说明（2026-03-08 / Codex）：补记 T2-T6 的实际落地结果，更新完成态进度、迁移日志与复盘，并记录 `presentation` 与 `tests/suites` 的最终目录形态。
