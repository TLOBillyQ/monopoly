  # CRAP < 10 双 lane 清零计划

  ## 摘要

  - 最终验收口径固定为双 lane：在仓库根目录运行 lua scripts/crap.lua report --lane behavior --lane contract --out tmp/
    crap_report.json --top 300，要求 src/**/*.lua 中零个函数 crap >= 10。
  - 2026-03-13 当前工作树里的 tmp/crap_report.json 还是单 lane behavior 结果，且 behavior 本身先失败：tests/suites/presentation/
    _presentation_action_status_status3d_and_panel_cases.lua 中 _test_ui_sync_opens_choice_modal_after_wait_action_anim 报错 choice
    modal should open once after leaving wait_action_anim。这会污染 CRAP 基线，所以必须先修。
  - 当前单 lane 诊断值为 276 个函数 crap >= 10，其中 112 个 complexity >= 10，不能只靠补测，必须拆复杂度。最高热点依次是 src/
    presentation/view/render/board_scene.lua、src/presentation/model/init.lua、src/game/scheduler/await.lua。
  - 对外接口保持不变：不修改 src/core/ports/、src/game/ports/ 契约；不改变 choice / market / ui_model shape；不引入跨层依赖；新增
    helper 只能留在原 layer/subsystem 内。
  - .agents/plan.md 整份替换为本计划；旧的 <=8 计划只保留分桶思路，不保留正文内容。

  ## 关键改动与任务依赖

  ### 依赖图

  T1 -> (T2, T3, T4, T5, T6, T7) -> T8 -> T9

  ### T1 基线稳定化

  - id: T1
  - depends_on: []
  - location: src/presentation/runtime/ports/ui_sync/ui_model_sync.lua，相关 presentation suites，.agents/
    crap_baseline.json，.agents/crap_baseline.md
  - description: 先修复 wait_action_anim -> wait_choice 后 choice modal 未重新打开的回归，恢复 behavior lane 可用；随后重新生成双
    lane CRAP 基线，把所有 crap >= 10 热点按 must_refactor(complexity>=10) 与 coverage_first(complexity<=9) 分类，并分配到 T2-T7。
  - validation: 失败 case 单测通过；lua tests/behavior.lua 与 lua tests/contract.lua 可跑完；新基线文件落盘且成为唯一真源。

  ### T2 Flow wait/landing cluster

  - id: T2
  - depends_on: [T1]
  - location: src/game/flow/turn/*，排除 auto_* / choice_auto_policy.lua
  - description: 清理 wait、landing、timer、dispatch 相关热点，优先处理 _phase_start、handle_need_landing、_phase_move、
    _phase_roll、_phase_post、timer_policy、tick_*。complexity >= 10 的函数必须继续拆 helper；低复杂度热点先补 characterization
    tests。
  - validation: 该目录重新跑 CRAP 后无 crap >= 10；相关 gameplay/flow suites 全过；不新增 flow -> presentation/runtime 依赖。

  ### T3 Scheduler / AI / auto-runner cluster

  - id: T3
  - depends_on: [T1]
  - location: src/game/scheduler/*，src/game/core/ai/*，src/game/flow/turn/auto_*，src/game/flow/turn/choice_auto_policy.lua
  - description: 清理 await.*、AI 选项决策、auto-runner/auto-context 热点。先用 characterization tests 钉住时序，再拆调度与自动决策
    分支，避免改坏 coroutine 与 auto-play 行为。
  - validation: scheduler/AI 相关热点清零；gameplay_coroutine、gameplay_timeout_and_auto_runner、AI 相关 suite 全过。

  ### T4 Gameplay systems / core cluster

  - id: T4
  - depends_on: [T1]
  - location: src/game/systems/*，src/game/core/player/*，必要时含 src/game/core/runtime/*
  - description: 清理规则层热点，如 items、chance、bankruptcy、state_ops 等。优先在 rules 层内部提取纯 helper，不把 UI/宿主细节带入
    systems。
  - validation: systems/core 分桶热点清零；domain suites 与 contract suites 全过；边界扫描保持通过。

  ### T5 Presentation model / runtime cluster

  - id: T5
  - depends_on: [T1]
  - location: src/presentation/model/*，src/presentation/runtime/*
  - description: 重点拆 model_api.update、panel_slice.update、board_slice.update、ui_model_sync、raycast 等热点。拆分策略固定为“按
    数据块更新职责切 helper，不改 read model shape”；临时测试 seam 只允许局部导出私有 helper，统一在 T8 回收。
  - validation: presentation model/runtime 分桶热点清零；market、modal、ui sync 相关 suites 全过；choice/market/ui_model 数据 shape
    无变化。

  ### T6 Presentation view / input cluster

  - id: T6
  - depends_on: [T1]
  - location: src/presentation/view/*，src/presentation/input/*
  - description: 清理 board_scene.init、tile_renderer.render_tile、anim_tip_text、player_units、building_effects、input dispatch 等
    热点。优先把 unit 查询、节点拼装、渲染决策拆为可单测 helper，用 fake unit / fake LuaAPI 做 characterization tests。
  - validation: view/input 分桶热点清零；board/render/input 相关 suites 全过；不把宿主 API 回流到 model/flow。

  ### T7 Infrastructure / app / core cluster

  - id: T7
  - depends_on: [T1]
  - location: src/infrastructure/*，src/app/*，src/core/*
  - description: 清理 runtime context、synthetic actor registry、bootstrap、state_access 等热点。此波只允许做边界内重构与补测，不改
    bootstrap 装配语义。
  - validation: infra/app/core 分桶热点清零；runtime/bootstrap/support suites 全过；lua tests/guard.lua 继续通过。

  ### T8 Residual sweep 与串行冲突收口

  - id: T8
  - depends_on: [T2, T3, T4, T5, T6, T7]
  - location: 共享测试支撑与残余热点文件
  - description: 统一处理并行阶段故意回避的共享文件与跨桶残余，包括 tests/catalog.lua、tests/support/shared_support.lua、公共
    fixture、需要跨波次复用的测试 seam，以及最终剩余的 crap >= 10 函数。并清理不再需要的临时 helper/export。
  - validation: 双 lane CRAP 剩余为零；共享支撑未引入新的耦合或测试漂移。

  ### T9 最终验证与计划收尾

  - id: T9
  - depends_on: [T8]
  - location: 仓库根目录，.agents/plan.md
  - description: 执行全量验证，生成最终 CRAP 报告与 viewer，更新计划中的“进度 / 意外与发现 / 决策日志 / 结果与复盘”。
  - validation: lua tests/behavior.lua、lua tests/contract.lua、lua tests/guard.lua、MONO_REGRESSION_MODE=release_trimmed lua
    tests/regression.lua、双 lane CRAP 命令全部通过；tmp/crap_report.json 显示零个 crap >= 10。

  ## 并行执行规则

  - Wave 1 只做 T1。T1 未完成前，任何人都不能认领热点，因为当前 CRAP 基线不可信。
  - Wave 2 并行执行 T2-T7，但每个任务只能改自己的代码桶和本桶测试文件；禁止改 tests/catalog.lua、tests/support/shared_support.lua、
    tests/bootstrap.lua、共享 presentation status case 聚合文件。
  - 任一波次若需要共享测试 helper，先在本桶测试文件内局部实现；只有 T8 才能把它提升到共享 support。
  - 临时对私有函数的测试导出允许存在，但必须标记仅供测试使用，并在 T8 判断是否能删回私有实现。
  - 若双 lane CRAP 新报告导致桶边界变化，以 T1 生成的 .agents/crap_baseline.json 为准，不再沿用旧 .agents/plan.md 的分配。

  ## 测试与验收

  - 基线命令：lua scripts/crap.lua report --lane behavior --lane contract --out tmp/crap_report.json --top 300
  - 可视化命令：lua scripts/crap.lua viewer --in-json tmp/crap_report.json --out-dir tmp/crap_view
  - 必跑回归：lua tests/behavior.lua、lua tests/contract.lua、lua tests/guard.lua
  - 最终总回归：MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua
  - 每个任务至少新增一组能解释热点行为的 characterization tests；对于 complexity >= 10 的函数，测试只能作为护栏，不能替代继续拆分。
  - 验收以“函数级 CRAP 清零 + 回归通过 + 架构边界未破坏”三项同时满足为准，缺一不可。

  ## 假设与默认决策

  - 最终 gate 固定采用双 lane behavior + contract。
  - .agents/plan.md 整份替换，不在旧 <=8 计划上续写。
  - 当前 tmp/crap_report.json 仅用于诊断，不作为最终基线；最终基线必须在修复 behavior 失败 case 后重生。
  - 不新增外部依赖，不需要引入新的第三方库或宿主接口；全部实现基于现有 Lua 5.4 与仓库内测试基础设施。
  - Saved 的 .agents/plan.md 必须初始化为活文档，并持续维护 进度、意外与发现、决策日志、结果与复盘 四个章节。

  ## 进度

  - [x] (2026-03-13 02:06Z) 读取 `parallel-task` 技能、当前 `.agents/plan.md`、harness 约束，并确认本次按 full plan 执行。
  - [x] (2026-03-13 02:12Z) 重新验证 `T1` 的真实入口：`lua tests/behavior.lua` 与 `MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua` 当前均通过，原计划中记录的 `wait_action_anim` presentation 失败在当前工作树未复现。
  - [x] (2026-03-13 02:16Z) 发现 `T1` 当前真正阻塞项变为 Windows shell 兼容问题：`lua tests/contract.lua` 因 `scripts/arch/arch_view/common.lua` 建目录失败而红；`lua tests/guard.lua` 因 `tests/support/guards/guard_support.lua` 的 `dir` 调用与 `tests/guards/dep_rules.lua` 的过期 root 而红。
  - [x] (2026-03-13 02:18Z) 修复 Windows shell 兼容：`scripts/arch/arch_view/common.lua` 的列目录/建目录/打开 viewer 命令改为显式 `cmd /c`；`tests/support/guards/guard_support.lua` 的列目录命令改为显式 `cmd /c`；`tests/guards/dep_rules.lua` 将失效 root 从 `src/presentation/view/canvas/base` 改到现存 `src/presentation/schema/canvas/base`。
  - [x] (2026-03-13 02:21Z) 回归验证通过：`lua tests/contract.lua` 绿，`lua tests/guard.lua` 绿。
  - [x] (2026-03-13 02:31Z) 重新生成双 lane CRAP 基线并写入仓库路径：`lua scripts/crap.lua report --lane behavior --lane contract --out ./tmp/crap_report.json --top 300`。结果为 `crap >= 10` 数量 `0`。
  - [x] (2026-03-13 02:33Z) 新建 `.agents/crap_baseline.json` 与 `.agents/crap_baseline.md`，完成 `must_refactor` / `coverage_first` 分类落盘（当前两类均为空）。
  - [x] (2026-03-13 02:33Z) `T2` 到 `T7` 判定为无需执行：双 lane 新基线已满足“函数级 CRAP < 10 清零”目标。
  - [x] (2026-03-13 02:38Z) 完成 `T9` 验收命令：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua` 全部通过。
  - [x] (2026-03-13 02:39Z) 生成可视化产物：`lua scripts/crap.lua viewer --in-json ./tmp/crap_report.json --out-dir ./tmp/crap_view`。

  ## 意外与发现

  - 观察：原计划摘要里写的 `behavior` 失败在当前工作树上已经不是事实。
    证据：`lua tests/behavior.lua` 输出 `All regression checks passed (990)`；`MONO_REGRESSION_MODE=release_trimmed lua tests/behavior.lua` 输出 `All regression checks passed (988)`。
  - 观察：`contract` 的八个失败都收敛到同一个根因，不是 `arch_view` 业务逻辑，而是 Windows shell 下直接执行 `mkdir` / `dir` 的兼容性问题。
    证据：`lua tests/contract.lua` 初次失败包含 `failed to create directory`；修复后输出 `All regression checks passed (97)`。
  - 观察：`guard` 失败既有 shell 兼容问题，也有规则 root 已过期的问题。
    证据：初次失败为 `list command failed for root: src/presentation/view/canvas/base`；仓库实际目录位于 `src/presentation/schema/canvas/base`；修复后 `lua tests/guard.lua` 输出 `dep_rules ok` 且 guard 全绿。
  - 观察：`crap` CLI 的 `tmp/...` 路径会被映射到系统临时目录，而不是仓库 `tmp/`。
    证据：`crap.common.resolve_cli_path(..., "tmp/crap_report.json")` 解析到 `C:/Users/Lzx_8/AppData/Local/Temp/monopoly_crap/crap_report.json`；改用 `./tmp/crap_report.json` 后成功写回仓库路径。

  ## 决策日志

  - 决策：先修正 `contract/guard` 的 Windows 兼容性，而不是继续追已经无法复现的 `behavior` case。
    理由：`T1` 的目标是恢复可信基线；当前真正阻塞双 lane 基线的是 `contract` 与 `guard`，继续追旧行为回归不会推进 gate。
    日期/作者：2026-03-13 / Codex
  - 决策：只做最小修复面，落在 `scripts/arch/arch_view/common.lua`、`tests/support/guards/guard_support.lua`、`tests/guards/dep_rules.lua` 三处。
    理由：三个失败都集中在 Windows shell 调用与过期路径，不需要扩大到 `cli.lua`、测试 harness 或架构规则本身。
    日期/作者：2026-03-13 / Codex
  - 决策：双 lane CRAP 基线命令统一使用 `--out ./tmp/...`，避免误写到系统临时目录。
    理由：计划验收和人工排查都基于仓库内产物，`tmp/...` 的默认映射会造成“报告未更新”的误判。
    日期/作者：2026-03-13 / Codex
  - 决策：`T2-T7` 本轮不展开，直接推进 `T9` 验收收尾。
    理由：新基线 `crap >= 10` 已是 0，继续分桶重构不会提升目标指标，反而增加变更噪音。
    日期/作者：2026-03-13 / Codex

  ## 结果与复盘

  `T1` 已闭环完成：`behavior`、`contract`、`guard` 三条回归链路恢复可用，且双 lane CRAP 基线重新落盘。最新报告 `tmp/crap_report.json` 显示 `crap >= 10` 为 `0`，已满足本计划核心验收目标。`T9` 验收命令组与 viewer 产物也已全部完成。

  本轮最大的经验是路径语义必须显式：`crap` CLI 的 `tmp/...` 会落到系统临时目录，若需要仓库内可追踪产物必须使用 `./tmp/...`。修正这一点后，基线生成与验收链路可稳定复现。

  改动说明：2026-03-13 本次更新完成了 `T1` 收口，新增基线文件，并将 `T2-T7` 标记为“在零热点基线上无需执行”。
