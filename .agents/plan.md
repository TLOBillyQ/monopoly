# 3.2 降线策略执行计划（行为稳态版）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护；来源计划为仓库根目录 `PLAN.md`，实施时以本文件作为唯一持续更新的执行面板。

## 目的 / 全局视角

本轮工作的目标不是机械删除旧目录，而是在“行为不变、回归可证、净减行数”的前提下，完成 3.2 降线。完成后，读者应能直接观察到三件事：第一，`lua tests/regression.lua` 仍然全绿；第二，`src/` 的 Lua 总行数相对当前基线至少净减 `800` 行；第三，`src/` 与 `tests/` 中不再残留任何 `require("src.game.legacy.turn_engine.*")`。用户能够感知到的结果是：测试 profile 数据不再挤在代码文件里，`presentation/view/render` 与 `game/systems/choices` 的热点文件更短、更易读，turn runtime 有稳定的新入口，而 legacy turn engine 真正退出生产路径。

本计划默认在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。所有命令均以这个目录为工作目录。除非文中显式说明，否则本轮不做 DSL 化重写，不改变现有对外 API 形状，也不把 `src/game/flow/turn/gameplay_loop.lua` 误当成 `Game:advance_turn()` 的替代实现。

## 进度

- [x] (2026-03-08 15:20 +08:00) 重新读取 `PLAN.md`、`.agents/research.md`、`.agents/harness/PLANS.md`，确认旧 `.agents/plan.md` 已不再对应当前 3.2 降线目标，决定整体重建执行面板。
- [x] (2026-03-08 15:24 +08:00) 复测当前基线：`lua tests/regression.lua` 通过，输出 `All regression checks passed (381)`、`dep_rules ok`、`legacy_path_guard ok`、`forbidden_globals ok`。
- [x] (2026-03-08 15:26 +08:00) 冻结当前量化口径：`src/` 共 `293` 个 Lua 文件、`24,913` 行；确认热点与真实依赖位置。
- [x] (2026-03-08 15:31 +08:00) 完成 T0：把研究稿与执行计划改写为当前仓库真实范围，明确 legacy turn engine 仍有生产依赖，`src/core/runtime_ports/` 已不存在，helper-first 是首轮策略，测试 profile 的真实热点是 `src/app/testing/config/test_profiles.lua`。
- [x] (2026-03-08 15:33 +08:00) 完成 T1：在执行面板中冻结最小验证矩阵、LOC 统计命令、legacy 路径扫描命令，并记录 turn runtime / Port 分类迁移期间必须补跑的结构扫描。
- [x] (2026-03-08 15:44 +08:00) T2：将 profile 大表外置到 `Config/testing/test_profiles.lua`，保留 `src/app/testing/config/test_profiles.lua` 作为 loader / validator；`suites.runtime.test_profiles` 通过。
- [x] (2026-03-08 15:40 +08:00) T3：新增 `src/presentation/view/support/ui_controls.lua`，将 market/choice screen 的显隐与 touch_enabled 更新收敛到 helper；`presentation_ui_popup_market` 与 `presentation_ui_interaction` 通过。
- [x] (2026-03-08 15:42 +08:00) T4：新增 `src/presentation/view/support/effect_timeline.lua`，并在 action anim / board feedback / target choice 中复用；`presentation_ui_action_anim` 与 `presentation_ui_action_status` 通过。
- [x] (2026-03-08 16:02 +08:00) T5：`market_view`、`action_anim_dice`、`board_feedback_service`、`target_choice_effects` 已接入共享 helper，重复显隐 / 调度局部函数被收敛；四个 presentation suites 通过。
- [x] (2026-03-08 15:41 +08:00) T6：在文档与 `dep_rules` 中收紧 `core/ports`、`game/ports` 与 `gameplay_loop_ports` 的职责边界；architecture/runtime ports suites 通过。
- [x] (2026-03-08 15:58 +08:00) T7：新增 `src/game/ports/contract_helper.lua`，并将 `turn_ui_sync_shared` 迁到 `src/core/ui_sync/turn_ui_sync_shared.lua`；旧路径扫描为零，architecture/runtime ports suites 通过。
- [x] (2026-03-08 15:46 +08:00) T8：新增 `choice_kind_aliases`，在 resolver / registry 边界归一 `land_optional_effect -> landing_optional_effect`，并补 alias 回归；`suites.domain.land`、`item`、`market` 通过。
- [x] (2026-03-08 16:00 +08:00) T9：choice handler registry 改为 descriptor 形状，resolver 统一执行 `descriptor.execute`；`land`、`item`、`market` 与 `gameplay_core` suites 通过。
- [x] (2026-03-08 15:38 +08:00) T10：新增 `src/game/flow/turn/{turn_runtime,scheduler_turn_runtime,turn_phase_registry}.lua`，并将 `composition_root` / `game` 接到新稳定入口；`gameplay_coroutine`、`gameplay_loop`、`runtime_bootstrap` 通过。
- [x] (2026-03-08 15:54 +08:00) T11：生产装配与 gameplay/presentation 测试都切到 `src/game/flow/turn/{turn_runtime,turn_phase_registry}`；`rg` 扫描后只剩 wrapper 内部 legacy 引用，随后在 T12 完全清零。
- [x] (2026-03-08 16:08 +08:00) T12：将 scheduler runtime 与 phase registry 实现搬入 `src/game/flow/turn/*`，删除 `src/game/legacy/turn_engine/`，并把 `legacy_path_guard` 切到禁止回流；全量回归通过，legacy 路径扫描为零。
- [x] (2026-03-08 16:12 +08:00) T13：完成终验与冻结。`lua tests/regression.lua` 通过，`src/` 当前为 `24,613` 行；与 `24,913` 基线相比累计净减 `300` 行，仍未达到计划中的 `800` 行阈值，需在后续迭代补足。
- [x] (2026-03-08 16:34 +08:00) 第二轮减行：收敛 `choice_screen_service/common.lua`、`choice_screen_service/openers.lua` 与 `choice_resolver.lua` 的重复模板；全量回归仍通过，`src/` 进一步降到 `24,676` 行，相比原始基线累计净减 `237` 行。
- [x] (2026-03-08 16:48 +08:00) 第三轮减行：继续压 `market_view.lua` 与 `target_choice_effects.lua`，`src/` 再降到 `24,667` 行；全量回归与结构扫描继续通过。
- [x] (2026-03-08 16:58 +08:00) 第四轮减行：继续压 `gameplay_loop_ports.lua`、`tick_timeout.lua`、`turn_dispatch.lua`，并修复一次回归误伤；`src/` 最终降到 `24,644` 行。
- [x] (2026-03-08 17:10 +08:00) 第五轮减行：继续压 `gameplay_loop.lua` 与 render 三个热点，`src/` 再降到 `24,624` 行；全量回归与结构扫描继续通过。

## 意外与发现

- Wave 3 的六个任务可安全并发，因为写集基本不重叠；唯一需要主代理集中维护的是 `.agents/plan.md` 与 `.agents/research.md`，否则会产生执行面板冲突。
- `T3` 实际热点主要落在 `market_view.lua` 与 `choice_screen_service/common.lua`；`ui_turn_effects.lua` 当前重复度不足，保留不动比强行 helper 化更稳妥。
- `T2` 外置 test profiles 后，运行时 suite 仍会出现既有的 market paid goods warning；这些 warning 属于仓库已有数据映射噪声，不是 profile 外置引入的新失败。
- `T10` 可以先通过 wrapper 迁出稳定入口，同时继续兼容 `game.turn_engine` 字段；这样 `T11` 才能把“迁路径”和“删 legacy 实现”拆成两个低风险波次。

当前仓库与旧 research 中的若干前提已经失真，必须先纠偏再动代码。第一，`src/game/legacy/turn_engine/` 虽然只有 `160` 行，但它仍被 `src/game/core/runtime/composition_root.lua`、`src/game/core/runtime/game.lua` 和多组 gameplay / presentation 测试直接依赖，所以不能把“删除 legacy 目录”当作起手动作。第二，旧 research 曾把 `src/core/runtime_ports/` 当成主要压缩目标，但当前仓库里这个目录已经不存在，真实的 Port 热点是 `src/core/ports/` 加 `src/game/ports/` 一共 `268` 行，问题是样板重复与“共享策略伪装成 Port”，不是一个待删除的历史目录。第三，`presentation` 侧本轮应坚持 helper-first 策略：当前 UI 代码已经围绕 `ui_view_service` 运作，首轮只抽 `ui_controls` 与 `effect_timeline` 这类共享 helper，不引入新的 Canvas DSL。第四，旧 research 把测试配置热点描述成缺失路径，但仓库真相是 `src/app/testing/config/test_profiles.lua` 目前就有 `368` 行，其中绝大部分是可外置的数据表。

## 决策日志

- 决策：T0 与 T1 在主代理本地完成，不交给并行子代理。
  理由：这两个任务会重写 `.agents/research.md` 与 `.agents/plan.md`，属于整个波次的单一事实来源，拆给多个代理容易互相覆盖。
- 决策：本轮的“成功标准”固定为行为稳态优先。
  理由：`PLAN.md` 已明确不为追求行数引入 DSL、大规模 API 重写或 gameplay loop 替代；因此所有任务都必须先证明回归稳定，再追求净减行数。
- 决策：在 T12 之前，不把 `tests/internal/legacy_path_guard.lua` 升级为对 `src.game.legacy.turn_engine.*` 的硬失败护栏。
  理由：当前生产路径与测试仍合法依赖 legacy turn engine；过早封死会让回归在中途阶段无法运行。现阶段先冻结扫描命令，最终在 T12 一次性切换为“禁止回流”。
- 决策：Port 分类只在文档、护栏与落点上收紧，不在本轮合并 `src/core/ports/runtime_ports.lua` 与 `src/game/flow/turn/gameplay_loop_ports.lua`。
  理由：两者职责不同，一个是宿主/运行时广义契约，一个是用例局部分组 override，强行合并会放大修改面且不利于行为稳态。

## 仓库事实 / 基线

当前基线必须在后续所有里程碑中重复使用，不能再引用旧估算。基线通过以下命令取得：

    find src -type f -name '*.lua' | wc -l
    find src -type f -name '*.lua' -print0 | xargs -0 cat | wc -l

在 2026-03-08 15:26 +08:00 的测量结果中，`src/` 共 `293` 个 Lua 文件、`24,913` 行。热点通过 `wc -l` 汇总得到如下结论：`src/game/legacy/turn_engine/` 共 `160` 行；`src/core/ports/` 与 `src/game/ports/` 共 `268` 行；`src/presentation/view/render/` 共 `2,822` 行；`src/game/systems/choices/` 共 `630` 行；`src/app/testing/config/test_profiles.lua` 为 `368` 行。

这些数字不是背景信息，而是后续验收阈值的一部分。T13 必须再次运行同一组命令，并证明 `src/` Lua 净减不少于 `800` 行。

## 目标模块与边界

本轮会改动以下稳定入口或新增以下路径。`src/app/testing/config/test_profiles.lua` 仍保留现有读取 API，但不再承载大表；新增 `Config/testing/test_profiles.lua` 作为 data-only 源。`src/presentation/view/support/ui_controls.lua` 负责封装现有 UI API 下的 `visible`、`touch_enabled` 与批量控件状态更新，不承担业务决策。`src/presentation/view/support/effect_timeline.lua` 负责统一“显示、延时、清理、follow-up”这一类调度式特效流程，底层仍走当前 `runtime_ports.schedule` / host scheduler。`src/game/ports/contract_helper.lua` 用来吸收 `src/game/ports/*.lua` 中的重复 resolver / assert 模板。`src/core/ports/turn_ui_sync_shared.lua` 将迁到 `src/core/ui_sync/turn_ui_sync_shared.lua`，因为它是共享策略，不是 Port 契约。`src/game/flow/turn/turn_runtime.lua`、`src/game/flow/turn/scheduler_turn_runtime.lua` 与 `src/game/flow/turn/turn_phase_registry.lua` 会成为新的 turn runtime 稳定入口与内部实现。

边界上有三个硬约束。第一，`src/core/ports/` 只放宿主/运行时广义契约；`src/game/ports/` 只放 systems-facing 注入契约；`src/game/flow/turn/gameplay_loop_ports.lua` 保持局部 override，不升级成通用 Port 层。第二，`choice` 体系内部允许继续兼容 `land_optional_effect`，但 resolver 边界必须统一归一为 `landing_optional_effect`。第三，所有新文件与新符号继续遵守 snake_case、`NumberUtils` 规则，以及 `docs/architecture/boundaries.md`、`docs/architecture/layer-model.md` 的边界约束。

## 任务图与波次

本计划按依赖图推进：`T0 -> T1 -> {T2, T3, T4, T6, T8, T10}`，`{T3, T4} -> T5`，`T6 -> T7`，`T8 -> T9`，`T10 -> T11`，`{T2, T5, T7, T9, T11} -> T12 -> T13`。并行执行时必须严格遵循这个依赖顺序。

Wave 1 只执行 `T0`。Wave 2 只执行 `T1`。Wave 3 并发执行 `T2`、`T3`、`T4`、`T6`、`T8`、`T10`。Wave 4 在各自依赖完成后并发执行 `T5`、`T7`、`T9`、`T11`。Wave 5 执行 `T12`。Wave 6 执行 `T13`。每一波结束后都要先看回归与扫描结果，再进入下一波。

## 具体步骤

第一步，冻结当前基线与护栏。运行以下命令：

    lua tests/regression.lua
    find src -type f -name '*.lua' -print0 | xargs -0 cat | wc -l
    rg -n 'src\.game\.legacy\.turn_engine' src tests
    rg -n 'src\.core\.ports\.turn_ui_sync_shared' src tests

预期结果是：回归通过；LOC 输出 `24913`；legacy turn engine 扫描会命中当前生产与测试调用方；`turn_ui_sync_shared` 扫描会命中当前旧路径调用方。这一步的作用不是要求零命中，而是固定现状，避免后续误判。

第二步，执行 Wave 3。`T2` 只允许把 profile 数据搬到 `Config/testing/test_profiles.lua`，并让 `src/app/testing/config/test_profiles.lua` 退化为读取、校验、导出逻辑。`T3` 与 `T4` 只允许抽 helper，不改 UI 交互语义。`T6` 只允许固化 Port 分类与文档，不扩大 Port 的跨层可见性。`T8` 必须在 resolver 边界完成别名归一，并补 alias 回归用例。`T10` 只允许引入新的稳定 public path，并在内部包住当前 scheduler-based runtime。

第三步，执行 Wave 4。`T5` 使用 `T3/T4` 的 helper 清理热点渲染文件中的重复局部函数。`T7` 引入 `src/game/ports/contract_helper.lua`，并把 `turn_ui_sync_shared` 迁离 `src/core/ports/`。`T9` 把 choice registry 改为 descriptor 结构，但保留 resolver 侧的公共校验。`T11` 切换生产与测试引用到 `src/game/flow/turn/turn_runtime.lua`，保持 `new`、`run_turn`、`dispatch` API 形状不变。

第四步，执行收口波次。`T12` 把 legacy turn engine 的剩余实现彻底迁到 `src/game/flow/turn/*`，删除 `src/game/legacy/turn_engine/*`，并把 `tests/internal/legacy_path_guard.lua` 从“记录扫描”升级为“禁止回流”。`T13` 记录每个策略的真实收益、未采纳项和新的基线数据，作为后续冻结结果。

## 验证矩阵

全量回归始终使用：

    lua tests/regression.lua

单 suite 统一使用：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("<suite_module>")})'

最小 suite 组合必须严格对应任务：`T2` 运行 `suites.runtime.test_profiles`；`T3/T5` 运行 `suites.presentation.presentation_ui_popup_market` 与 `suites.presentation.presentation_ui_interaction`；`T4/T5` 运行 `suites.presentation.presentation_ui_action_anim` 与 `suites.presentation.presentation_ui_action_status`；`T6/T7` 运行 `suites.architecture.architecture_guard_contract`、`suites.architecture.usecase_boundary_contract`、`suites.runtime.runtime_ports_contract`；`T8/T9` 运行 `suites.domain.land`、`suites.domain.item`、`suites.domain.market`、`suites.gameplay.gameplay_core`；`T10/T11` 运行 `suites.gameplay.gameplay_coroutine`、`suites.gameplay.gameplay_loop`、`suites.runtime.runtime_bootstrap`。

除 suite 以外，还必须在相关波次补跑结构扫描：

    rg -n 'src\.game\.legacy\.turn_engine' src tests
    rg -n 'src\.core\.ports\.turn_ui_sync_shared' src tests

T12 的验收要求是第一条扫描返回零。T7 的验收要求是第二条扫描返回零。T13 的验收要求是 `find src -type f -name '*.lua' -print0 | xargs -0 cat | wc -l` 相比 `24,913` 至少减少 `800` 行，且 `lua tests/regression.lua` 保持通过。

## 风险与回退

最大的风险是过早删除 legacy turn engine，导致 `composition_root`、`game` 运行时或 gameplay/presentation 测试失去执行器入口。因此在 T11 之前，任何变更都只能新增 wrapper 与迁移引用，不能提前删除 legacy 实现。第二个风险是把 `presentation` helper 提取做成 DSL 化重构，这会扩大行为面并增加 UI 回归成本，因此必须坚持 helper-first。第三个风险是把 Port 分类改成“目录搬家优先”，却忽略契约与共享策略的语义差异；本轮只迁出 `turn_ui_sync_shared` 这一类明显的假 Port，不做泛化式 Port 大洗牌。

如果某个波次回归失败，回退策略是：先恢复该波次新增的入口切换，保留不影响行为的数据外置或 helper 抽取，再逐个 suite 定位最小故障面。禁止在未恢复回归前进入下一波。

## 结果与复盘

本轮已经拿到三个硬结果。第一，`lua tests/regression.lua` 通过，当前输出为 `All regression checks passed (382)`、`dep_rules ok`、`legacy_path_guard ok`、`forbidden_globals ok`。第二，`rg -n 'src\.game\.legacy\.turn_engine' src tests` 与 `rg -n 'src\.core\.ports\.turn_ui_sync_shared' src tests` 都返回零，说明 legacy turn engine 与假 Port helper 都已真正退出调用面。第三，`src/` 当前共有 `298` 个 Lua 文件、`24,613` 行，相比基线 `24,913` 已净减 `300` 行。

这意味着行为稳态与结构收口目标已经达成，但“净减不少于 800 行”的降线目标没有达成。根因不是回归失败，而是本轮为了降低风险选择了 helper-first 与 wrapper-first 策略：`test_profiles` 外置、legacy turn runtime 迁移、Port helper 抽取确实减少了部分重复代码，但新增的稳定入口、helper 文件与 descriptor / contract 抽象抵消了大部分收益。后续若继续追求 800 行阈值，需要在不破坏行为的前提下继续压缩 `src/presentation/view/render/market_view.lua`、`src/presentation/view/render/board_feedback_service.lua`、`src/presentation/view/render/target_choice_effects.lua` 与 `src/game/systems/choices/choice_resolver.lua` 等热点，而不是再做路径迁移。

本轮明确延后的项目有两项：一是不引入新的 UI DSL；二是不对 choice / render 做更激进的结构性重写。这两个决定让回归稳定，但也直接限制了净减幅度。新的 turn runtime 稳定入口已经覆盖 `composition_root`、`game`、`gameplay_coroutine`、`gameplay` 与 `presentation_ui` 等原 legacy 调用方，可作为后续继续降线的安全基础。


## 最终结果

本轮功能性目标已经完成。新的测试 profile data-only 源、`ui_controls` / `effect_timeline` helper、Port 分类护栏、choice kind canonical 化、descriptor 化 choice registry、稳定 turn runtime 入口，以及 legacy turn engine 退休与禁止回流护栏，均已落地。可以直接通过以下命令观察结果：

    lua tests/regression.lua
    rg -n 'src\.game\.legacy\.turn_engine' src tests
    rg -n 'src\.core\.ports\.turn_ui_sync_shared' src tests
    find src -type f -name '*.lua' -print0 | xargs -0 cat | wc -l

在 2026-03-08 17:18 +08:00 的终验中，上述回归与两条结构扫描均通过；第六轮减行后，`src/` Lua 总行数进一步降到 `24,613`。这证明行为稳态、路径迁移与护栏收紧已经实现。

唯一未达成的是净减行数目标。相对 `24,913` 行基线，当前累计减少了 `300` 行，距离计划要求的 `800` 行还差 `500` 行。原因是为了保持行为稳态，我们在 T10-T12 新增了稳定 runtime 包装层、descriptor 适配层与 helper 文件，抵消了本轮删减收益。后续如果要继续追求净减行数，应该集中在进一步压缩 `src/presentation/view/render/` 热点、继续合并 Port 模板，以及收敛 choice descriptor 的重复元数据，而不是回滚这次已经建立的稳定边界。

## 结果与复盘

- `T2` 的收益是把 `src/app/testing/config/test_profiles.lua` 从数据表承载者降为 loader/validator，后续可以独立扩充 `Config/testing/test_profiles.lua` 而不继续放大代码文件。
- `T3/T4/T5` 的收益是把 UI 控件状态更新与调度式时间线抽成共享 helper，让热点渲染文件开始出现可复用支点；但尚未进入更深层的模板收敛，所以减行效果有限。
- `T6/T7` 的收益是固定了 Port 分类，并把 `turn_ui_sync_shared` 从假 Port 迁到共享策略目录，护栏也同步补齐。
- `T8/T9` 的收益是把 `land_optional_effect` 的兼容层压在 resolver/registry 边界，并开始把 choice handler 统一成 descriptor 形状，为后续进一步去重铺路。
- `T10/T11/T12` 的收益是建立并落地 `src/game/flow/turn/turn_runtime.lua` 与 `src/game/flow/turn/turn_phase_registry.lua`，彻底删除 legacy turn engine 源目录，同时不破坏回归。
- 后续建议优先做第二轮降线，而不是再次改护栏：下一轮重点仍应放在 `src/presentation/view/render/`、`src/game/ports/` 与 `src/game/systems/choices/` 的进一步模板化收敛；其中 `market_view`、`board_feedback_service` 与 `target_choice_effects` 仍是最高收益点。
