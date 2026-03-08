# 3.2 降线策略开发计划（行为稳态版）

**摘要**
- 目标不是机械照抄 `.agents/research.md:1` 的旧估算，而是基于当前仓库真相做“行为不变、回归可证、净减行数”的降线。
- 已确认的当前基线：`src/` 共 `293` 个 Lua 文件、`24,913` 行；热点分别为 `src/game/legacy/turn_engine:1` `160` 行、`src/core/ports:1` + `src/game/ports:1` `268` 行、`src/presentation/view/render:1` `2,822` 行、`src/game/systems/choices:1` `630` 行、`src/app/testing/config/test_profiles.lua:1` `368` 行。
- 关键纠偏：A 不能直接做删除，因为 `src/game/core/runtime/composition_root.lua:1`、`src/game/core/runtime/game.lua:1` 和多组测试仍直接依赖 `src/game/legacy/turn_engine/*`；B 里的 `src/core/runtime_ports/` 已不存在；C 首轮只抽 helper，不上 DSL；E 的真实配置热点是 `src/app/testing/config/test_profiles.lua:1`，不是旧 research 里的缺失路径。
- 成功标准：`lua tests/regression.lua` 全绿，且 `src/` Lua 净减不少于 `800` 行；最终禁止任何 `require("src.game.legacy.turn_engine.*")` 残留。

**接口与边界变更**
- `src/app/testing/config/test_profiles.lua:1` 保持现有读取 API，不再承载大表；新增 `Config/testing/test_profiles.lua:1` 作为 data-only 源。
- 新增 `src/presentation/view/support/ui_controls.lua:1`，统一当前 UI API 下的 `visible` / `touch_enabled` / 批量控件状态更新。
- 新增 `src/presentation/view/support/effect_timeline.lua:1`，统一基于调度器的显隐、延时清理、follow-up 回调。
- 新增 `src/game/ports/contract_helper.lua:1`，吸收 `src/game/ports/*.lua` 的重复断言/解析模板。
- `src/core/ports/turn_ui_sync_shared.lua:1` 迁到 `src/core/ui_sync/turn_ui_sync_shared.lua:1`，因为它是共享策略，不是 Port。
- 新增稳定入口 `src/game/flow/turn/turn_runtime.lua:1`，并引入 `src/game/flow/turn/scheduler_turn_runtime.lua:1`、`src/game/flow/turn/turn_phase_registry.lua:1`；`src/game/legacy/turn_engine/*` 最终退休。
- `src/game/systems/choices/choice_resolver.lua:1` 统一 canonical kind；`land_optional_effect` 继续兼容，但内部一律归一到 `landing_optional_effect`。

**依赖图**
- `T0 -> T1 -> {T2, T3, T4, T6, T8, T10}`
- `{T3, T4} -> T5`
- `T6 -> T7`
- `T8 -> T9`
- `T10 -> T11`
- `{T2, T5, T7, T9, T11} -> T12 -> T13`

**任务**
### T0 重新基线化 3.2
- `depends_on`: `[]`
- `location`: `.agents/research.md:1`, `.agents/plan.md:1`
- `description`: 把 research 3.2 改写成当前仓库真实范围：明确 A 仍有生产依赖、B 的旧路径已清零、C 基于 `ui_view_service` 而非 Canvas DSL、E 的真实目标是 `src/app/testing/config/test_profiles.lua:1`。同时固定量化口径与验收阈值。
- `validation`: 用 `find src -type f -name '*.lua' -print0 | xargs -0 cat | wc -l` 记录 `24,913` 行；并把各热点行数写入计划。

### T1 先补护栏与量化命令
- `depends_on`: `[T0]`
- `location`: `tests/internal/legacy_path_guard.lua:1`, `tests/internal/dep_rules.lua:1`, `.agents/plan.md:1`
- `description`: 在任何重构前先固定 guard rail：记录单 suite 运行命令、LOC 统计命令、legacy path 扫描命令，并为新的 Port 分类与 turn runtime 迁移预留架构护栏。
- `validation`: `lua tests/regression.lua` 当前全绿；计划里明确写出最小验证矩阵与 `rg` 扫描命令。

### T2 外置测试 profile 数据
- `depends_on`: `[T1]`
- `location`: `src/app/testing/config/test_profiles.lua:1`, `src/app/testing/test_profile_resolver.lua:1`, `src/app/testing/test_profile_bootstrap.lua:1`, `Config/testing/test_profiles.lua:1`, `tests/suites/runtime/test_profiles.lua:1`
- `description`: 把 `profiles` 大表搬到 `Config/testing/test_profiles.lua:1`，保留 `src/app/testing/config/test_profiles.lua:1` 作为薄 loader/validator，现有 resolver/bootstrap 调用点不改接口。
- `validation`: 运行单 suite 命令加载 `suites.runtime.test_profiles`；`src/app/testing/config/test_profiles.lua:1` 只剩读取、校验、导出逻辑。

### T3 提取 UI 控件状态 helper
- `depends_on`: `[T1]`
- `location`: `src/presentation/view/support/ui_controls.lua:1`, `src/presentation/view/render/market_view.lua:1`, `src/presentation/view/widgets/ui_turn_effects.lua:1`, `src/presentation/view/widgets/choice_screen_service/common.lua:1`
- `description`: 面向当前 `ui_view_service` 风格，提取“显隐 + 可触摸 + 批量控件组更新 + 选择框 reset”共用 helper，不引入新的 View DSL。
- `validation`: 运行单 suite 命令加载 `suites.presentation.presentation_ui_popup_market` 和 `suites.presentation.presentation_ui_interaction`。

### T4 提取调度式特效时间线 helper
- `depends_on`: `[T1]`
- `location`: `src/presentation/view/support/effect_timeline.lua:1`, `src/presentation/view/render/action_anim_dice.lua:1`, `src/presentation/view/render/board_feedback_service.lua:1`, `src/presentation/view/render/target_choice_effects.lua:1`
- `description`: 把“显示 -> 延时 -> 清理 -> follow-up”模式抽成统一时间线 helper，统一当前 `runtime_ports.schedule` / host scheduler 用法，不碰领域逻辑。
- `validation`: 运行单 suite 命令加载 `suites.presentation.presentation_ui_action_anim` 和 `suites.presentation.presentation_ui_action_status`。

### T5 渲染热点迁移并删重复局部函数
- `depends_on`: `[T3, T4]`
- `location`: `src/presentation/view/render/market_view.lua:1`, `src/presentation/view/render/action_anim_dice.lua:1`, `src/presentation/view/render/board_feedback_service.lua:1`, `src/presentation/view/render/target_choice_effects.lua:1`
- `description`: 把首批热点文件迁到共享 helper，删除重复本地函数；首轮只做 helper 化，不上声明式 DSL。
- `validation`: 运行 `suites.presentation.presentation_ui_popup_market`、`suites.presentation.presentation_ui_action_anim`、`suites.presentation.presentation_ui_action_status`、`suites.presentation.presentation_ui_interaction`。

### T6 固化 Port 分类
- `depends_on`: `[T1]`
- `location`: `docs/architecture/boundaries.md:1`, `docs/architecture/layer-model.md:1`, `tests/internal/dep_rules.lua:1`, `src/game/flow/turn/gameplay_loop_ports.lua:1`
- `description`: 明确三类东西的边界：`src/core/ports:1` 只放宿主/运行时广义契约，`src/game/ports:1` 只放 systems-facing 注入契约，`src/game/flow/turn/gameplay_loop_ports.lua:1` 保持用例局部分组 override，不把它升级成通用 Port 层。
- `validation`: 运行单 suite 命令加载 `suites.architecture.architecture_guard_contract`、`suites.architecture.usecase_boundary_contract`、`suites.runtime.runtime_ports_contract`。

### T7 合并 Port 样板代码并迁出假 Port helper
- `depends_on`: `[T6]`
- `location`: `src/game/ports/contract_helper.lua:1`, `src/game/ports/auto_play_port.lua:1`, `src/game/ports/bankruptcy_port.lua:1`, `src/game/ports/bankruptcy_feedback_port.lua:1`, `src/game/ports/intent_output_port.lua:1`, `src/core/ports/turn_ui_sync_shared.lua:1`, `src/core/ui_sync/turn_ui_sync_shared.lua:1`, `src/game/flow/turn/tick_ui_sync.lua:1`, `src/presentation/runtime/presentation_ports/ui_sync/ui_model_sync.lua:1`
- `description`: 抽出通用 resolver/assert helper，消除 `game/ports` 重复模板；同时把 `turn_ui_sync_shared` 从 `src/core/ports:1` 迁出，避免“共享策略伪装成 Port”。
- `validation`: `rg -n 'src\\.core\\.ports\\.turn_ui_sync_shared' src tests` 结果为零；对应 architecture/runtime suites 继续通过。

### T8 统一 choice kind 别名
- `depends_on`: `[T1]`
- `location`: `src/game/systems/choices/choice_resolver.lua:1`, `src/game/systems/choices/choice_registry.lua:1`, `src/game/systems/choices/choice_handlers/optional_effect_handler.lua:1`, `src/game/systems/choices/choice_kind_aliases.lua:1`
- `description`: 在 resolver 边界先做 canonical 化；对外继续兼容 `land_optional_effect`，内部统一映射为 `landing_optional_effect`，并补契约测试。
- `validation`: 运行单 suite 命令加载 `suites.domain.land`、`suites.domain.item`、`suites.domain.market`，并新增 alias 回归用例。

### T9 把 choice registry 从函数组改成 descriptor
- `depends_on`: `[T8]`
- `location`: `src/game/systems/choices/choice_registry.lua:1`, `src/game/systems/choices/choice_resolver.lua:1`, `src/game/systems/choices/choice_handlers/item_choice_handler.lua:1`, `src/game/systems/choices/choice_handlers/land_choice_handler.lua:1`, `src/game/systems/choices/choice_handlers/market_choice_handler.lua:1`, `src/game/systems/choices/choice_handlers/optional_effect_handler.lua:1`
- `description`: handler 模块改为注册 descriptor 表，公共的 cancel/option 校验/meta 前置校验继续留在 resolver 或 descriptor helper，handler 只保留业务执行分支。
- `validation`: 运行单 suite 命令加载 `suites.domain.land`、`suites.domain.item`、`suites.domain.market`、`suites.gameplay.gameplay_core`。

### T10 引入非 legacy 的 turn runtime 稳定入口
- `depends_on`: `[T1]`
- `location`: `src/game/flow/turn/turn_runtime.lua:1`, `src/game/flow/turn/scheduler_turn_runtime.lua:1`, `src/game/flow/turn/turn_phase_registry.lua:1`, `src/game/core/runtime/composition_root.lua:1`, `src/game/core/runtime/game.lua:1`
- `description`: 新建稳定 public path，但首版只包装当前 scheduler-based turn runtime；明确不直接拿 `src/game/flow/turn/gameplay_loop.lua:1` 替代，因为它是 UI tick/autorunner 入口，不是 `Game:advance_turn()` 执行器。
- `validation`: 运行单 suite 命令加载 `suites.gameplay.gameplay_coroutine`、`suites.gameplay.gameplay_loop`、`suites.runtime.runtime_bootstrap`。

### T11 迁移生产调用方与测试到新 turn runtime 路径
- `depends_on`: `[T10]`
- `location`: `src/game/core/runtime/composition_root.lua:1`, `src/game/core/runtime/game.lua:1`, `tests/suites/gameplay/gameplay_coroutine.lua:1`, `tests/suites/gameplay/gameplay.lua:1`, `tests/suites/presentation/presentation_ui.lua:1`
- `description`: 替换所有直接依赖 `src.game.legacy.turn_engine.*` 的调用方，保持 `new` / `run_turn` / `dispatch` API 形状不变，先迁路径再删旧实现。
- `validation`: `rg -n 'src\\.game\\.legacy\\.turn_engine' src tests` 只剩 legacy 源文件本身；gameplay/presentation 相关 suite 通过。

### T12 删除 legacy 目录并拉紧护栏
- `depends_on`: `[T2, T5, T7, T9, T11]`
- `location`: `src/game/legacy/turn_engine/phase_registry.lua:1`, `src/game/legacy/turn_engine/turn_engine.lua:1`, `tests/internal/legacy_path_guard.lua:1`, `docs/architecture/boundaries.md:1`, `docs/architecture/layer-model.md:1`
- `description`: 将剩余 scheduler runtime 实现完全迁到新的 `src/game/flow/turn/*` 路径，删除 `src/game/legacy/turn_engine/*`，并把 guard/doc 一并更新成“禁止回流”状态。
- `validation`: `rg -n 'src\\.game\\.legacy\\.turn_engine' src tests` 返回零；`lua tests/regression.lua` 全绿。

### T13 最终验收与冻结指标
- `depends_on`: `[T12]`
- `location`: `.agents/research.md:1`, `.agents/plan.md:1`
- `description`: 记录每个策略的真实产出、净减行数、未采纳项（例如 DSL 延后），并冻结新的基线与后续禁止项。
- `validation`: `find src -type f -name '*.lua' -print0 | xargs -0 cat | wc -l` 显示净减不少于 `800` 行；`lua tests/regression.lua` 保持通过。

**并行波次**
- Wave 1：`T0`
- Wave 2：`T1`
- Wave 3：`T2`, `T3`, `T4`, `T6`, `T8`, `T10`
- Wave 4：`T5`, `T7`, `T9`, `T11`
- Wave 5：`T12`
- Wave 6：`T13`

**测试计划**
- 全量回归始终使用：`lua tests/regression.lua`
- 单 suite 统一使用：`lua -e 'package.path=package.path..\";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua\"; require(\"TestHarness\").run_all({require(\"<suite_module>\")})'`
- 最小 suite 组合：
  - `T2`：`suites.runtime.test_profiles`
  - `T3/T5`：`suites.presentation.presentation_ui_popup_market`、`suites.presentation.presentation_ui_interaction`
  - `T4/T5`：`suites.presentation.presentation_ui_action_anim`、`suites.presentation.presentation_ui_action_status`
  - `T6/T7`：`suites.architecture.architecture_guard_contract`、`suites.architecture.usecase_boundary_contract`、`suites.runtime.runtime_ports_contract`
  - `T8/T9`：`suites.domain.land`、`suites.domain.item`、`suites.domain.market`、`suites.gameplay.gameplay_core`
  - `T10/T11`：`suites.gameplay.gameplay_coroutine`、`suites.gameplay.gameplay_loop`、`suites.runtime.runtime_bootstrap`
- 结构扫描始终补跑：
  - `rg -n 'src\\.game\\.legacy\\.turn_engine' src tests`
  - `rg -n 'src\\.core\\.ports\\.turn_ui_sync_shared' src tests`

**假设与默认决策**
- 以“行为稳态降线”为最高优先级；不为追求行数引入 DSL、大规模 API 重写或 gameplay loop 替代。
- `src/core/ports/runtime_ports.lua:1` 继续保留在 `core/ports`，本轮不与 `src/game/flow/turn/gameplay_loop_ports.lua:1` 合并。
- `src/game/flow/turn/gameplay_loop.lua:1` 不承担 legacy turn runtime 替换职责；真正替换路径是新的 `src/game/flow/turn/turn_runtime.lua:1`。
- 所有新文件与新符号继续遵守 snake_case、`NumberUtils` 规则，以及现有边界文档约束。
- 当前处于 Plan Mode，本轮交付的是 decision-complete 计划文本；后续如需落盘，应写入 `.agents/plan.md:1` 并按 `.agents/harness/PLANS.md:1` 展开成单一 `md` 可执行计划。
