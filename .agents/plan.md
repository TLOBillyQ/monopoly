# src 目录分层重命名执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 维护。后续任何人只拿到当前工作树与本文件，也必须能按这里的说明继续推进，不需要再回头查历史对话。

## 目的 / 全局视角

这项工作的目标不是“把目录名字改漂亮”，而是把 `src/` 的物理目录名收敛到仓库已经声明的 7 组件分层模型上，让新进入项目的人只看路径就能判断职责边界，知道代码应该放在哪里，也知道哪些依赖方向是不允许的。完成后，`src/game/core/runtime/` 不再继续混放 AI 与玩家状态操作，`src/game/runtime_coroutine/` 不再和 `src/game/runtime/` 在语义上撞名，`src/presentation/api/` 与 `src/presentation/ui/` 也会换成更贴近职责的名称，`src/core/` 顶层的平铺文件会按工具、choice、端口与 runtime façade 分组。

这项重构对用户可见的“生效证明”有三条。第一，回归命令 `lua tests/regression.lua` 必须在仓库根目录直接通过，说明 require 路径重写没有破坏玩法、展示层和边界守卫。第二，针对旧路径的搜索必须在 `src/`、`tests/` 与 `docs/architecture/` 中归零，说明历史命名确实被移除，而不是留下半迁移状态。第三，几个关键入口模块必须能直接被 `require` 成功，例如新的 `src.game.core.ai.Agent`、`src.game.flow.output_adapters.UseCaseOutputPort`、`src.game.scheduler.Scheduler`、`src.presentation.adapter.UIViewService` 与 `src.presentation.widgets.UIPanel`。只要这三类证据同时成立，这项工作就可以被认定为“真的完成了”。

## 进度

- [x] (2026-03-07 13:51:35 +0800) 已读取 `.agents/research.md`、`.agents/harness/PLANS.md`、`docs/architecture/layer-model.md`、`docs/architecture/boundaries.md`，确认这是纯仓库内路径与命名重构，不涉及外部库 API 选择。
- [x] (2026-03-07 13:51:35 +0800) 已核对当前目录与引用规模：`ChoiceHandlers` 2 处文件引用，`src.game.flow.ports` 10 处，`src.game.core.runtime.Agent` 8 处，`src.game.core.runtime.player_state` 6 处，`src.game.runtime_coroutine` 3 处，`src.presentation.api` 52 处，`src.presentation.ui` 14 处，`src.core` 顶层平铺模块 159 处引用。
- [x] (2026-03-07 13:51:35 +0800) 已确认统一回归入口为 `lua tests/regression.lua`，并抽样验证 `lua -e 'require("src.game.flow.turn.GameplayLoop")'`、`lua -e 'require("src.presentation.api.UIViewService")'`、`lua -e 'require("src.game.runtime.TurnEngine")'` 在仓库根目录可直接 smoke load。
- [x] (2026-03-07 14:03:44 +0800) 已完成一次子代理复审，并吸收反馈：补上 `T9` 显式依赖、文档与守卫文件的单点收口、`T1` 的大小写 rename 验证、`T7/T8` 的映射重检，以及“`T1` 到 `T8` 只跑 grep + smoke，不跑全量回归”的阶段策略。
- [ ] T0：建立重构前基线，并记录旧路径搜索结果与回归成功输出。
- [ ] T1：将 `src/game/systems/choices/ChoiceHandlers/` 改为 `src/game/systems/choices/choice_handlers/`。
- [ ] T2：将 `src/game/flow/ports/` 改为 `src/game/flow/output_adapters/`。
- [ ] T3：将 `src/game/core/runtime/player_state/` 移入 `src/game/core/player/state_ops/`。
- [ ] T4：将 `src/game/core/runtime/Agent.lua` 移入 `src/game/core/ai/Agent.lua`。
- [ ] T5：化解 runtime 命名冲突：保留 `src/game/runtime/` 作为 adapter 层，迁出 deprecated turn engine 文件，并将 `src/game/runtime_coroutine/` 改为 `src/game/scheduler/`。
- [ ] T6：将 `src/presentation/api/` 改为 `src/presentation/adapter/`，将 `src/presentation/ui/` 改为 `src/presentation/widgets/`。
- [ ] T7：先做 `src/core/` require 重写脚本原型，证明大规模路径替换可安全执行。
- [ ] T8：执行 `src/core/` 顶层平铺模块分组迁移，并重写全部 call site。
- [ ] T9：同步更新 `docs/architecture/`、`tests/internal/dep_rules.lua`、守护测试与最终验收证据。

## 意外与发现

- 观察：`docs/architecture/boundaries.md` 已把 `src/game/runtime/` 定义为贴近 gameplay 的 adapter 层，这与研究稿里“整个 `src/game/runtime/` 更名为 `src/game/turn_engine/`”的提案冲突。
  证据：文档明确写明 `src/game/runtime` 容纳 `AutoPlayPortAdapter`、`BankruptcyPortAdapter` 这类 adapter，因此最终计划保留该目录名，只迁出 `TurnEngine.lua` 与 `PhaseRegistry.lua` 这两个 deprecated 文件。
- 观察：CI 使用的回归入口就是 `lua tests/regression.lua`，并没有隐藏的二级测试脚本。
  证据：`.github/workflows/regression.yml` 的 `Run regression` 步骤直接运行该命令。
- 观察：`ChoiceHandlers` 只改大小写，在常见的 macOS 大小写不敏感文件系统上，直接一次性改名很容易失败或被 Git 忽略。
  证据：这个目录当前是仓库里少数 PascalCase 目录之一，必须使用两步 `git mv`，先改成临时名，再改成最终的 `choice_handlers`。
- 观察：`src/core/` 顶层平铺文件的引用面远大于其他任务，是唯一需要原型验证的阶段。
  证据：`rg -l 'src\.core\.(ActionAnimPort|ChoiceContract|ChoiceRoutePolicy|DirtyTracker|Logger|NumberUtils|RoleId|RuntimeContext|RuntimeEditorExports|RuntimeEventBridge|RuntimePorts|RuntimeState|TurnUISyncShared|UIRoleGlobals)' src tests | wc -l` 返回 `159`。

## 决策日志

- 决策：采用研究稿的总体阶段顺序，但将 M1 的 runtime rename 收敛为“保留 `src/game/runtime/`，仅迁出 deprecated turn engine，并把 `runtime_coroutine` 改成 `scheduler`”。
  理由：这样既保留 `docs/architecture/boundaries.md` 已经宣告的 adapter 目录语义，也达成“不要让两个 runtime 目录互相撞名”的目标。
  日期/作者：2026-03-07 / Codex
- 决策：`src/presentation/ui/` 的新名字定为 `src/presentation/widgets/`，而不是直接并入 `src/presentation/canvas/`。
  理由：`ui/` 里的 `UIPanel`、`PopupRenderer`、`MarketModalRenderer` 与 `choice_screen_service` 更像可复用展示组件，而不是某个具体 Canvas 页面；改成 `widgets/` 只收敛命名，不额外改变职责边界。
  日期/作者：2026-03-07 / Codex
- 决策：`src/core/` 分组迁移必须先做原型，再做全量迁移。
  理由：159 处引用不适合凭肉眼全局替换；先写一个只改 literal `require(...)` 的脚本并 dry-run，能显著降低误替换风险。
  日期/作者：2026-03-07 / Codex
- 决策：本计划不引入任何新的外部依赖，也不需要额外的框架文档检索。
  理由：任务只涉及仓库内 Lua 模块路径、现有测试脚本与架构文档，不存在需要 Context7 或联网确认的第三方 API 细节。
  日期/作者：2026-03-07 / Codex

## 结果与复盘

当前版本只完成了计划初始化与约束核对，还没有进入实际重构。最大的风险已经明确：`src/core/` 的全局 fanout 最广，`src/presentation/` 的路径改名会跨多个测试文件，而 `src/game/runtime/` 的命名改动必须服从现有架构文档，不能只照着研究稿生搬。好处是这些风险都已经被折算成独立任务与验证命令；后续真正实施时，不需要再重新设计阶段，只需要按波次执行并在每一步补写本节与前面的活文档章节即可。

## 背景与导读

本仓库已经有一套明确的架构边界，但目录名还没有完全对齐这套边界。`docs/architecture/layer-model.md` 把仓库划成 7 个组件：`src/presentation/` 是 UI 层，`src/game/flow/` 是回合管理与用例编排，`src/game/systems/` 是共享玩法规则，`src/game/core/player/` 与 `src/game/core/runtime/Game*.lua` 承载状态，`src/game/core/runtime/Agent.lua` 当前被当作 Computer 侧实现，`src/game/runtime/` 是 port adapter 辅助层，`src/app/bootstrap/` 负责装配。`docs/architecture/boundaries.md` 进一步规定：`src/game/flow` 可以协调系统层但不能碰 UI 细节，`src/game/systems` 可以产出稳定的 output model 但不能直接碰 UI 节点或宿主 API，`src/game/runtime` 与 `src/infrastructure/runtime` 是 runtime 适配层，所有“离开 Eggy 就不存在”的逻辑都应该留在外层。

这里的“Port”指的是稳定的输入输出契约，例如 `src/game/ports/` 或 `src/core/RuntimePorts.lua` 暴露的窄接口；“Adapter”指的是把这些契约接到具体运行时、UI 或宿主 API 的实现。目录重命名的目标不是改变业务逻辑，而是让 Port、Adapter、flow、systems、state 这些角色在路径上也一眼可见。只要 require 路径重写后，导出的 Lua table、函数与行为保持不变，这次重构就是安全的。

当前最需要处理的现状有五块。第一，`src/game/core/runtime/` 同时放着 `Game.lua`、`GameState*.lua`、`Bankruptcy.lua`、`GameVictory.lua`、`CompositionRoot.lua`、`Bootstrap.lua`、`Agent.lua` 和 `player_state/*.lua`，混合了状态、AI、领域逻辑与装配。第二，`src/game/runtime/` 与 `src/game/runtime_coroutine/` 两个目录都在表达“运行时”，但前者实际上是 adapter 与 deprecated engine 的混合，后者才是真正的调度器。第三，`src/game/flow/ports/` 名字容易让人误会它和 `src/game/ports/` 是同一方向的端口，实际前者更接近 flow 的 output adapter。第四，`src/presentation/api/` 与 `src/presentation/ui/` 的名字都太宽，无法直接反映“这是 adapter 还是 widget”。第五，`src/core/` 根下的 `Logger.lua`、`NumberUtils.lua`、`ChoiceContract.lua`、`RuntimeContext.lua` 等 14 个文件没有二级分类，导致新代码很容易继续平铺堆放。

边界守卫主要依赖 `tests/internal/dep_rules.lua` 与多组 contract suite。`tests/regression.lua` 会先跑所有 suites，再执行 `dep_rules.lua`、`gameplay_loop_no_ui.lua` 与 `forbidden_globals.lua`。因此路径迁移不仅要改 `src/` 里的 require，还要同步改测试、守卫脚本和架构文档，否则就算代码本身能 load，回归也会失败。

## 依赖图

    T0 ──┬── T1
         ├── T2
         ├── T3
         ├── T4
         ├── T5
         ├── T6
         └── T7

    T1, T2, T3, T4, T5, T6, T7 ──> T8 ──> T9

这个依赖图的含义是：先做一次统一基线采样，然后把低到中风险的目录改名拆给不同 agent 并行处理。`T7` 虽然和 `T8` 都属于 `src/core/`，但 `T7` 只负责原型与替换脚本，不应该提前改动正式路径。等 `T1` 到 `T7` 都完成并合并后，再启动 `T8` 做全量 `src/core/` 分组迁移，最后由 `T9` 统一修正文档、守护规则与整体验收。

## 里程碑

第一个里程碑是“低风险命名归一”。它覆盖 `T1` 与 `T2`，也就是把 PascalCase 目录改为 snake_case，并把 `flow/ports` 改成 `flow/output_adapters`。完成后，代码树里最明显的命名异类会先消失，新人一眼就能看懂 flow 输出端口与系统层 port 的方向差别。这个里程碑完成的证明是：旧路径搜索归零，`ChoiceRegistry`、`GameplayLoop`、`UseCaseOutputPort` 三个入口模块 smoke load 通过。

第二个里程碑是“core runtime 职责收窄”。它覆盖 `T3`、`T4` 与 `T5`。完成后，`player_state` 变成 `src/game/core/player/state_ops/`，`Agent.lua` 变成 `src/game/core/ai/Agent.lua`，协程调度器改名为 `src/game/scheduler/`，而 `src/game/runtime/` 被保留下来继续表达 adapter 层。这个阶段的验收重点不是目录名字本身，而是 `CompositionRoot`、`TurnEngine`、`Scheduler`、`runtime_bootstrap` 与 gameplay 相关测试仍能正常 load 和执行。

第三个里程碑是“presentation 命名收敛”。它覆盖 `T6`。完成后，`src/presentation/adapter/` 直接表达“这是展示侧适配层”，`src/presentation/widgets/` 直接表达“这是可复用视图组件”，`canvas/` 仍然保留页面级 presenter 与页面行为。这个里程碑的证明是 `UIViewService`、`UIPanel`、`PopupRenderer`、`MarketModalRenderer` 相关模块 smoke load 通过，并且 `tests/suites/presentation_*.lua` 与 `tests/suites/read_model_contract.lua` 在整体验收中保持通过。

第四个里程碑是“core 扁平目录分组完成并且文档闭环”。它覆盖 `T7`、`T8`、`T9`。完成后，`src/core/` 根目录只保留子目录入口，不再继续扩张平铺文件，`tests/internal/dep_rules.lua` 与 `docs/architecture/` 会同步反映最终路径，整套回归与 grep 验收会证明旧路径已经全部退出正式代码与架构文档。这个阶段是最后的集成关卡，必须在一个干净工作树里通过。

## 任务清单

### T0：建立基线

`depends_on`: `[]`。`location`: 仓库根目录、`tests/regression.lua`、`.github/workflows/regression.yml`。`description`: 在任何路径迁移前，先在仓库根目录运行一次完整回归，并把旧路径的 grep 结果记录到本计划“意外与发现”或后续日志中。这里的目的是确认当前工作树本来就是可工作的，避免把历史失败误判成重构引入的问题。`validation`: `lua tests/regression.lua` 退出码为 0；旧路径搜索命令能打印出当前待迁移引用，为后续归零做对照。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T1：将 `ChoiceHandlers` 目录改为 `choice_handlers`

`depends_on`: `[T0]`。`location`: `src/game/systems/choices/ChoiceHandlers/`、`src/game/systems/choices/ChoiceRegistry.lua`、`tests/suites/market.lua`。`description`: 使用两步 `git mv` 处理大小写改名，把目录先改到临时名，再改到最终的 `choice_handlers`。随后修改所有 `require("src.game.systems.choices.ChoiceHandlers...")` 为 `require("src.game.systems.choices.choice_handlers...")`。不要顺手改 handler 的导出结构，保持行为完全不变。`validation`: `rg -n 'ChoiceHandlers' src tests` 在 `src/` 与 `tests/` 中归零；`git diff --name-status | rg 'choice_handlers|ChoiceHandlers'` 能显示 Git 把这次变更识别为 rename 相关记录，而不是大小写混乱的 delete/add；`lua -e 'require("src.game.systems.choices.ChoiceRegistry"); print("T1 smoke ok")'` 打印 `T1 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T2：将 `src/game/flow/ports/` 改为 `src/game/flow/output_adapters/`

`depends_on`: `[T0]`。`location`: `src/game/flow/ports/`、`src/game/flow/turn/GameplayLoop.lua`、`src/game/flow/turn/GameplayLoopPorts.lua`、`src/game/flow/turn/TickTimeout.lua`、`src/game/ports/IntentOutputPort.lua`、`tests/suites/architecture_guard_contract.lua`、`tests/suites/intent_output_contract.lua`、`tests/suites/legacy_output_mirror_contract.lua`、`tests/suites/ui_runtime_state_contract.lua`、`tests/suites/usecase_boundary_contract.lua`。`description`: 迁移目录并重写所有 `src.game.flow.ports.*` require，让名字直接表达“这是 flow 对外发出的 output adapter”。`UseCaseOutputPort.lua`、`IntentOutputAdapter.lua` 与 `LegacyOutputMirror.lua` 的模块返回值必须保持不变。`validation`: `rg -n 'src\.game\.flow\.ports' src tests` 归零；`lua -e 'require("src.game.flow.output_adapters.UseCaseOutputPort"); require("src.game.flow.output_adapters.IntentOutputAdapter"); print("T2 smoke ok")'` 打印 `T2 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T3：把 `player_state` 移入 `src/game/core/player/state_ops/`

`depends_on`: `[T0]`。`location`: `src/game/core/runtime/player_state/`、`src/game/core/player/`、所有引用 `src.game.core.runtime.player_state.*` 的 `src/` 与 `tests/` 文件。`description`: 新建 `src/game/core/player/state_ops/`，把 `BalanceOps.lua`、`Common.lua`、`DeityOps.lua`、`LocationOps.lua`、`StatusOps.lua`、`VehicleOps.lua` 迁过去，然后把所有 require 改到新路径。这个任务只处理玩家状态操作模块，不要同时改 `Game.lua`、`GameState*.lua` 的职责。`validation`: `rg -n 'src\.game\.core\.runtime\.player_state' src tests` 归零；`lua -e 'require("src.game.core.player.state_ops.BalanceOps"); require("src.game.core.runtime.Game"); print("T3 smoke ok")'` 打印 `T3 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T4：把 `Agent.lua` 移入 `src/game/core/ai/`

`depends_on`: `[T0]`。`location`: `src/game/core/runtime/Agent.lua`、`src/game/core/ai/`、`src/game/core/runtime/CompositionRoot.lua`、所有引用 `src.game.core.runtime.Agent` 的 `src/` 与 `tests/` 文件。`description`: 新建 `src/game/core/ai/`，把 `Agent.lua` 移到 `src/game/core/ai/Agent.lua`，并把 CompositionRoot 与测试中的 require 路径全部改到新位置。这个任务的目标是把 Computer 侧实现从 Game aggregate root 目录里剥离出来，而不是修改 AI 算法。架构文档中的路径说明不要在这里提前修改，只在任务日志里记下“`Agent.lua` 已迁到 `src/game/core/ai/Agent.lua`，待 T9 统一同步文档”。`validation`: `rg -n 'src\.game\.core\.runtime\.Agent' src tests` 归零；`lua -e 'require("src.game.core.ai.Agent"); print("T4 smoke ok")'` 打印 `T4 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T5：保留 `src/game/runtime/` 为 adapter 层，并解决 scheduler 命名冲突

`depends_on`: `[T0]`。`location`: `src/game/runtime/`、`src/game/runtime_coroutine/`、新建的 `src/game/turn_engine/` 与 `src/game/scheduler/`、所有引用这些目录的 `src/` 与 `tests/` 文件。`description`: 把 `src/game/runtime_coroutine/ActionRouter.lua`、`Await.lua`、`Scheduler.lua`、`Session.lua`、`TurnScript.lua` 迁移到 `src/game/scheduler/`，同时把 `src/game/runtime/TurnEngine.lua` 与 `src/game/runtime/PhaseRegistry.lua` 迁到 `src/game/turn_engine/`。`src/game/runtime/AutoPlayPortAdapter.lua` 与 `src/game/runtime/BankruptcyPortAdapter.lua` 保持原位，继续表达 adapter 层。`TurnEngine.lua` 内部对 scheduler 的 require 也必须同步改成 `src.game.scheduler.*`。这里先不改架构文档，只在任务日志里明确记录：`src/game/turn_engine/` 是 deprecated/frozen 的历史执行器容器，不是新的常规分层目录，正式文档说明放到 `T9` 统一补写。`validation`: `rg -n 'src\.game\.runtime_coroutine' src tests` 归零；`lua -e 'require("src.game.turn_engine.TurnEngine"); require("src.game.scheduler.Scheduler"); require("src.game.runtime.AutoPlayPortAdapter"); print("T5 smoke ok")'` 打印 `T5 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T6：重命名 presentation 的 adapter 与 widget 目录

`depends_on`: `[T0]`。`location`: `src/presentation/api/`、`src/presentation/ui/`、`src/presentation/interaction/`、`src/presentation/canvas_runtime/`、`src/presentation/render/`、`src/presentation/state/ui_model/`、`src/app/bootstrap/`、所有 presentation 相关测试。`description`: 把 `src/presentation/api/` 改为 `src/presentation/adapter/`，把 `src/presentation/ui/` 改为 `src/presentation/widgets/`，然后一次性重写所有 `src.presentation.api.*` 与 `src.presentation.ui.*` require。为了避免交叉冲突，这个任务必须由同一个 agent 负责整个 presentation 路径改名，不能拆成两个独立分支。架构文档与 dep rule 的正式同步统一留到 `T9`，这里先专注于代码树与测试引用。`validation`: `rg -n 'src\.presentation\.(api|ui)' src tests` 归零；`rg -n 'src\.presentation\.(api|ui)' src/presentation src/app tests/suites/presentation_*` 也必须归零，以确认 presentation 内部交叉引用没有漏掉；`lua -e 'require("src.presentation.adapter.UIViewService"); require("src.presentation.widgets.UIPanel"); require("src.presentation.widgets.PopupRenderer"); print("T6 smoke ok")'` 打印 `T6 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T7：为 `src/core/` 迁移编写原型脚本

`depends_on`: `[T0]`。`location`: `scripts/tmp_rewrite_requires.py`、`src/core/`、少量抽样调用点。`description`: 编写一个一次性 Python 脚本，只重写字面量形式的 `require("...")` 与 `require('...')`，不碰拼接字符串、不碰注释、不碰普通文案。脚本必须支持 dry-run 模式，用来打印将要替换的文件与旧新路径对；支持 apply 模式，用来真正写回文件。除了 literal require 替换清单，脚本或配套扫描还必须产出第二类结果：把 `package.loaded[...]`、`dep_rules.lua` 里的 budget/root/path 字符串、文档中的路径文本等非 require 引用整理成人工处理清单，交给 `T9` 统一收尾。这个任务只做原型验证，不做 `src/core/` 的正式文件迁移。原型验证至少要覆盖一个 `choice` 类模块、一个 `ports` 类模块和一个 `runtime façade` 类模块的替换预演。`validation`: `python3 scripts/tmp_rewrite_requires.py --check` 能打印出两类结果——literal require 替换预览与人工处理清单——且退出码为 0；抽样对 `src.core.ChoiceContract`、`src.core.ActionAnimPort`、`src.core.RuntimeContext` 的 dry-run 输出符合预期。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T8：执行 `src/core/` 顶层平铺模块分组迁移

`depends_on`: `[T1, T2, T3, T4, T5, T6, T7]`。`location`: `src/core/`、所有引用 `src.core.*` 顶层平铺模块的 `src/` 与 `tests/` 文件。`description`: 依据本计划“接口与依赖”一节的映射执行正式迁移：`Logger.lua`、`NumberUtils.lua`、`DirtyTracker.lua`、`RoleId.lua` 进入 `src/core/utils/`；`ChoiceContract.lua` 与 `ChoiceRoutePolicy.lua` 进入 `src/core/choice/`；`ActionAnimPort.lua`、`RuntimePorts.lua`、`TurnUISyncShared.lua` 进入 `src/core/ports/`；`RuntimeContext.lua`、`RuntimeEditorExports.lua`、`RuntimeEventBridge.lua`、`RuntimeState.lua`、`UIRoleGlobals.lua` 进入 `src/core/runtime_facade/`。现有的 `src/core/config/`、`src/core/events/` 与 `src/core/runtime_ports/` 保持原位。迁移时先基于合并后的工作树重新运行一次 `python3 scripts/tmp_rewrite_requires.py --check`，确认映射仍然覆盖完整，再 `git mv` 文件并执行 `scripts/tmp_rewrite_requires.py --apply` 重写引用，最后人工检查 `RuntimePorts` 与 `runtime_ports/DefaultPorts.lua` 的配套关系没有断开。`validation`: `rg -n 'src\.core\.(ActionAnimPort|ChoiceContract|ChoiceRoutePolicy|DirtyTracker|Logger|NumberUtils|RoleId|RuntimeContext|RuntimeEditorExports|RuntimeEventBridge|RuntimePorts|RuntimeState|TurnUISyncShared|UIRoleGlobals)' src tests` 归零；`lua -e 'require("src.core.choice.ChoiceContract"); require("src.core.ports.ActionAnimPort"); require("src.core.runtime_facade.RuntimeContext"); print("T8 smoke ok")'` 打印 `T8 smoke ok`。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

### T9：更新守卫、文档并做最终验收

`depends_on`: `[T1, T2, T3, T4, T5, T6, T8]`。`location`: `tests/internal/dep_rules.lua`、`tests/suites/architecture_guard_contract.lua`、`tests/suites/usecase_boundary_contract.lua`、其他受路径变更影响的 contract suite、`docs/architecture/layer-model.md`、`docs/architecture/boundaries.md`、如仍保留则删除 `scripts/tmp_rewrite_requires.py`。`description`: 这一步只做最后的统一收尾，而且只能在前面所有 rename 与 `src/core/` regroup 任务已经合并完成后启动。需要把 dep rule 里的 root、budget、forbidden file 与显式路径全部替换成新目录；把两份架构文档更新到最终路径；为 `src/game/turn_engine/` 增补“deprecated/frozen 的历史执行器容器，不是新的常规层”的明确说明；检查并清理 `tests/internal/dep_rules.lua` 中像 `src/core/RuntimeEnvBindings.lua` 这类历史 budget 路径；确认 `src/core` 的临时迁移脚本如果不再需要就删除；然后运行完整回归与最终 grep 验收，确保仓库里不存在半迁移路径。`validation`: `lua tests/regression.lua` 通过；所有旧路径 grep 归零；`git diff --name-status` 只显示计划内的目录重命名与守卫更新。`status`: `Not Completed`。`log`: 。`files edited/created`: 。

## 并行执行说明

`T1`、`T2`、`T3`、`T4`、`T5`、`T6` 与 `T7` 在 `T0` 完成后可以并行启动，但要严格按目录所有权分工。`T1` 只拥有 `src/game/systems/choices/` 及相关测试；`T2` 只拥有 `src/game/flow/` 与 `src/game/ports/IntentOutputPort.lua` 及相关测试；`T3` 只拥有 `src/game/core/player/` 与 `src/game/core/runtime/player_state/`；`T4` 只拥有 `src/game/core/ai/`、`CompositionRoot.lua` 与 AI 相关测试；`T5` 只拥有 `src/game/runtime/`、`src/game/runtime_coroutine/`、`src/game/turn_engine/`、`src/game/scheduler/`；`T6` 拥有整个 `src/presentation/` 树与 presentation 相关测试；`T7` 只拥有临时脚本与 mapping 原型，不改正式路径。这样做是为了把多 agent 合并时的冲突面压到最低。

`T8` 必须串行执行，因为它会批量重写几乎全仓的 `src.core.*` require；如果在其他路径重命名尚未落定时就提前做，会让后续每个任务都额外背负两次 require 改写。`T9` 也必须串行，因为 `tests/internal/dep_rules.lua` 与两份架构文档都属于仓库级约束入口，只适合在最终路径确定后统一收口。

## 工作计划

实际实施时，从最外层风险控制开始。先做 `T0`，确认当前仓库本身能通过回归，并把旧路径命中的搜索结果记下来。接着并行处理 `T1` 到 `T6`，因为这些任务虽然都在改 require 路径，但目录所有权基本互不重叠，最适合多个 agent 同时推进。`T7` 与它们并行进行，但仅限于写脚本、做 dry-run 和整理 `src/core` 的映射表，不能提前把 `src/core` 真正迁走。`T1` 到 `T8` 期间不要跑全量 `lua tests/regression.lua` 作为任务完成标准，因为 `tests/internal/dep_rules.lua` 与架构文档要到 `T9` 才会统一收口；这些阶段性任务只用 grep 与 smoke 验证。

等前一波任务合并后，再一次性做 `T8`。这个阶段只关心一件事：让 `src/core/` 顶层不再继续平铺扩散，同时保证所有旧的 `require("src.core.Xxx")` 都被系统性替换为新目录。这里不应该顺手改变模块导出格式，也不应该借机合并函数或改业务逻辑，因为那会让“路径重构失败”与“逻辑回归失败”混在一起，难以定位。

最后做 `T9`，把守卫规则、架构文档和最终验收证据补齐。只有当 `lua tests/regression.lua` 通过、旧路径在 `src/`、`tests/`、`docs/architecture/` 中全部归零，并且新的关键入口模块能 smoke load 成功时，才算这份计划交付完成。

## 具体步骤

所有命令都在仓库根目录 `/Users/gangan/Dev/repo/monopoly` 执行。如果机器上没有 `lua` 但有 `lua5.4`，把下文里的 `lua` 全部替换为 `lua5.4`；其他命令保持不变。

第一步先建立基线。这是整个计划里第一次运行全量回归。

    cd /Users/gangan/Dev/repo/monopoly
    git status --short
    lua tests/regression.lua
    rg -n 'ChoiceHandlers|src\.game\.flow\.ports|src\.game\.core\.runtime\.Agent|src\.game\.core\.runtime\.player_state|src\.game\.runtime_coroutine|src\.presentation\.api|src\.presentation\.ui' src tests docs/architecture

第二步处理 `T1`。由于这是大小写改名，必须用临时目录过渡。

    git mv src/game/systems/choices/ChoiceHandlers src/game/systems/choices/ChoiceHandlers_tmp
    git mv src/game/systems/choices/ChoiceHandlers_tmp src/game/systems/choices/choice_handlers
    rg -l 'src\.game\.systems\.choices\.ChoiceHandlers' src tests
    lua -e 'require("src.game.systems.choices.ChoiceRegistry"); print("T1 smoke ok")'

第三步处理 `T2` 到 `T6`。这些步骤可以分给不同 agent，但每个 agent 结束时都要执行本任务自己的 grep 与 smoke 命令，不要在这个阶段运行全量 `lua tests/regression.lua`，因为 dep rule 与架构文档的硬编码路径要等 `T9` 才会统一改完。

    git mv src/game/flow/ports src/game/flow/output_adapters
    lua -e 'require("src.game.flow.output_adapters.UseCaseOutputPort"); print("T2 smoke ok")'

    mkdir -p src/game/core/player/state_ops
    git mv src/game/core/runtime/player_state/*.lua src/game/core/player/state_ops/
    lua -e 'require("src.game.core.player.state_ops.BalanceOps"); print("T3 smoke ok")'

    mkdir -p src/game/core/ai
    git mv src/game/core/runtime/Agent.lua src/game/core/ai/Agent.lua
    lua -e 'require("src.game.core.ai.Agent"); print("T4 smoke ok")'

    mkdir -p src/game/turn_engine src/game/scheduler
    git mv src/game/runtime/TurnEngine.lua src/game/turn_engine/TurnEngine.lua
    git mv src/game/runtime/PhaseRegistry.lua src/game/turn_engine/PhaseRegistry.lua
    git mv src/game/runtime_coroutine/*.lua src/game/scheduler/
    lua -e 'require("src.game.turn_engine.TurnEngine"); require("src.game.scheduler.Scheduler"); print("T5 smoke ok")'

    git mv src/presentation/api src/presentation/adapter
    git mv src/presentation/ui src/presentation/widgets
    lua -e 'require("src.presentation.adapter.UIViewService"); require("src.presentation.widgets.UIPanel"); print("T6 smoke ok")'

第四步处理 `T7`。先写脚本，再 dry-run。脚本只允许替换字面量 require，不允许替换注释和普通字符串文本，同时还要输出一份人工处理清单，列出非 require 的路径字符串引用。

    python3 scripts/tmp_rewrite_requires.py --check

第五步处理 `T8`。按“接口与依赖”一节的映射逐个 `git mv` `src/core/` 顶层文件，但在真正 apply 前，先基于合并后的工作树再跑一次 `--check`，确认映射仍完整，再执行 apply 模式重写 require，最后跑 smoke。

    python3 scripts/tmp_rewrite_requires.py --check
    python3 scripts/tmp_rewrite_requires.py --apply
    lua -e 'require("src.core.choice.ChoiceContract"); require("src.core.ports.ActionAnimPort"); require("src.core.runtime_facade.RuntimeContext"); print("T8 smoke ok")'

第六步处理 `T9`，统一修改守卫和文档，再跑最终验收。

    lua tests/regression.lua
    rg -n 'ChoiceHandlers|src\.game\.flow\.ports|src\.game\.core\.runtime\.Agent|src\.game\.core\.runtime\.player_state|src\.game\.runtime_coroutine|src\.presentation\.api|src\.presentation\.ui' src tests docs/architecture
    rg -n 'src\.core\.(ActionAnimPort|ChoiceContract|ChoiceRoutePolicy|DirtyTracker|Logger|NumberUtils|RoleId|RuntimeContext|RuntimeEditorExports|RuntimeEventBridge|RuntimePorts|RuntimeState|TurnUISyncShared|UIRoleGlobals)' src tests
    lua -e 'require("src.game.core.ai.Agent"); require("src.game.flow.output_adapters.UseCaseOutputPort"); require("src.game.scheduler.Scheduler"); require("src.presentation.adapter.UIViewService"); require("src.presentation.widgets.UIPanel"); require("src.core.choice.ChoiceContract"); print("final smoke ok")'
    git diff --name-status

## 验证与验收

最终验收以行为证据为准，而不是以“目录已经改了”自我感觉良好。`T1` 到 `T8` 的阶段性任务只要求 grep 与 smoke 通过，不要求全量回归；这是刻意设计，因为 `tests/internal/dep_rules.lua`、growth budget 和架构文档中的硬编码路径会集中在 `T9` 改完。真正的全量回归只在 `T0` 建基线时跑一次，在 `T9` 最终收尾时再跑一次。第一条硬标准是回归通过：在仓库根目录运行 `lua tests/regression.lua`，预期输出里能看到 `[regression] mode=` 开头的行，并在最后出现 `dep_rules ok`，整个命令退出码为 0。第二条硬标准是旧路径归零：对 `ChoiceHandlers`、`src.game.flow.ports`、`src.game.core.runtime.Agent`、`src.game.core.runtime.player_state`、`src.game.runtime_coroutine`、`src.presentation.api`、`src.presentation.ui` 和旧的 `src.core.*` 顶层平铺模块执行 grep 时，`src/`、`tests/` 和 `docs/architecture/` 中都不再出现匹配。第三条硬标准是关键入口 smoke：运行 `lua -e 'require("src.game.core.ai.Agent"); require("src.game.flow.output_adapters.UseCaseOutputPort"); require("src.game.scheduler.Scheduler"); require("src.presentation.adapter.UIViewService"); require("src.presentation.widgets.UIPanel"); require("src.core.choice.ChoiceContract"); print("final smoke ok")'`，预期打印 `final smoke ok`。

如果上面三条里任何一条失败，都不要继续往下叠改动。先用 grep 找出残留旧路径，再用 `git diff` 锁定最近一次 rename 或批量替换是否遗漏。只有在三个证据同时成立时，才可以在“结果与复盘”里写明该计划已完成。

## 可重复性与恢复

这份计划设计成可分任务重跑。所有 grep、smoke 与回归命令都可以重复执行，不会破坏工作树。真正不可重复的是 `git mv`，因此每次移动前都先确认旧路径仍存在；如果某一步已经成功，不要重复执行同一条 rename 命令。大小写改名必须保留临时目录那一步，否则在大小写不敏感文件系统上会留下脏状态。

如果某个任务中途失败，优先只回滚当前任务拥有的路径，而不是把整个仓库恢复到最初状态。例如 `T6` 失败时，只回滚 `src/presentation/`、相关测试和文档；`T8` 失败时，只回滚 `src/core/` 与被批量改写 require 的文件。推荐的恢复命令是：

    git restore --source=HEAD -- <本任务涉及的路径>
    git clean -fd <本任务新建的目录>

如果 `scripts/tmp_rewrite_requires.py` 在 `T8` 之后不再需要，应该在 `T9` 删除，避免仓库长期保留一次性迁移工具。整个重构完成后，`git status --short` 应该只显示计划内的文件改动，不应残留临时目录、备份文件或未跟踪的中间产物。

## 产物与备注

最终工作树应该呈现出一组清晰的 rename 结果，而不是夹杂逻辑改动。理想状态下，`git diff --name-status` 会以 `R` 或 `M` 为主，显示目录重命名、文档更新和守卫脚本调整。关键的成功输出应当接近下面这样：

    [regression] mode=...
    dep_rules ok
    final smoke ok

如果在 `T7` 或 `T8` 阶段需要记录批量替换摘要，保留脚本打印的“旧 require -> 新 require -> 文件数”统计即可，不要把大段自动生成内容塞进计划正文。计划正文只保留能帮助下一位执行者判断成功与失败的最小证据。

## 接口与依赖

这次重构不计划改变任何模块导出的接口形状。所有模块仍然返回与改名前相同的 table、函数或构造器；变更点只在文件路径和 `require(...)` 字符串。`scripts/tmp_rewrite_requires.py` 必须只处理字面量 `require`，因为仓库里的守卫与回归依赖路径字符串精确匹配，任何额外的文本改写都可能引入隐蔽错误。

`src/core/` 的目标映射如下，实施 `T8` 时必须按这份映射执行，不要临场再发明新目录名：

    src/core/Logger.lua -> src/core/utils/Logger.lua
    src/core/NumberUtils.lua -> src/core/utils/NumberUtils.lua
    src/core/DirtyTracker.lua -> src/core/utils/DirtyTracker.lua
    src/core/RoleId.lua -> src/core/utils/RoleId.lua

    src/core/ChoiceContract.lua -> src/core/choice/ChoiceContract.lua
    src/core/ChoiceRoutePolicy.lua -> src/core/choice/ChoiceRoutePolicy.lua

    src/core/ActionAnimPort.lua -> src/core/ports/ActionAnimPort.lua
    src/core/RuntimePorts.lua -> src/core/ports/RuntimePorts.lua
    src/core/TurnUISyncShared.lua -> src/core/ports/TurnUISyncShared.lua

    src/core/RuntimeContext.lua -> src/core/runtime_facade/RuntimeContext.lua
    src/core/RuntimeEditorExports.lua -> src/core/runtime_facade/RuntimeEditorExports.lua
    src/core/RuntimeEventBridge.lua -> src/core/runtime_facade/RuntimeEventBridge.lua
    src/core/RuntimeState.lua -> src/core/runtime_facade/RuntimeState.lua
    src/core/UIRoleGlobals.lua -> src/core/runtime_facade/UIRoleGlobals.lua

现有的 `src/core/config/`、`src/core/events/` 与 `src/core/runtime_ports/DefaultPorts.lua` 保持原位；`DefaultPorts.lua` 如果引用 `RuntimePorts.lua`，则在 `T8` 中把它的 require 同步改到 `src.core.ports.RuntimePorts`。对应地，最终路径迁移矩阵还包括：

    src/game/systems/choices/ChoiceHandlers/* -> src/game/systems/choices/choice_handlers/*
    src/game/flow/ports/* -> src/game/flow/output_adapters/*
    src/game/core/runtime/player_state/* -> src/game/core/player/state_ops/*
    src/game/core/runtime/Agent.lua -> src/game/core/ai/Agent.lua
    src/game/runtime/TurnEngine.lua -> src/game/turn_engine/TurnEngine.lua
    src/game/runtime/PhaseRegistry.lua -> src/game/turn_engine/PhaseRegistry.lua
    src/game/runtime_coroutine/* -> src/game/scheduler/*
    src/presentation/api/* -> src/presentation/adapter/*
    src/presentation/ui/* -> src/presentation/widgets/*

本次更新说明：从空白的 `.agents/plan.md` 初始化为一份可执行的重构计划；补入了任务依赖、并行波次、验证命令、恢复策略，以及研究稿与架构文档之间的 runtime 命名冲突处理方案。这样做的原因是，用户明确要求把 `.agents/research.md` 转成基于 `swarm-planner` 的执行计划，而仓库同时要求 `.agents/plan.md` 完整遵循 `.agents/harness/PLANS.md`。
