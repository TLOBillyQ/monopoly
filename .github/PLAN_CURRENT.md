# 统一收敛 Gameplay 入口职责与 Landing/Ports 结构拆分

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.github/PLANS.md` 维护。

## 目的 / 全局视角

上一轮已经修复两类高风险问题：破产回调端口不兼容、`pay_others` 在破产后继续结算。本计划处理剩余结构性债务，目标是把当前“能跑但难改”的状态，改成“职责清晰、接口稳定、回归成本低”的状态。完成后，用户可见行为不变，但开发者将能在不触碰无关模块的前提下新增地块效果、替换 UI 端口实现、或调整初始化流程。

可见生效方式有三点。第一，`src/app/init.lua` 体量显著下降，只保留装配入口。第二，`GameplayLoopPortsAdapter` 拆分为分组子适配器，端口职责可独立测试。第三，`LandingEffectExecutors` 拆成按场景组织的子模块后，新增或修改一个效果不再需要改 300+ 行单文件。最终通过回归测试和一次无 UI headless 驱动证明改动有效。

## 进度

- [x] (2026-02-18 00:00Z) 已完成前置修复提交：`937a086`（破产端口兼容、`pay_others` 破产短路、端口契约收紧、回归补测）。
- [x] (2026-02-18 00:00Z) 清空并重写 `PLAN_CURRENT.md`，将剩余工作细化为可执行计划。
- [x] (2026-02-18) 里程碑 A：拆分 `src/app/init.lua`，init.lua 从 262 行精简为 13 行装配入口。
- [x] (2026-02-18) 里程碑 A-1/A-2/A-3/A-4/A-5：RuntimeInstall/GameStartup/UIBootstrap 三模块建立，职责分离完成。
- [x] (2026-02-18) 里程碑 A-6/A-7：回归 136 项全通过，dep_rules ok，tick ok。
- [x] (2026-02-18) 里程碑 B：拆分 `GameplayLoopPortsAdapter.lua`，顶层文件从 293 行精简为 19 行组装层。
- [x] (2026-02-18) 里程碑 B-1 至 B-6：ModalPorts/AnimPorts/UISyncPorts/DebugPorts/StatePorts 五模块建立。
- [x] (2026-02-18) 里程碑 B-7/B-8：回归 136 项全通过。
- [x] (2026-02-18) 里程碑 C：拆分 `LandingEffectExecutors.lua`，聚合入口从 399 行精简为 24 行。
- [x] (2026-02-18) 里程碑 C-1 至 C-6：BaseLandEffects/ChanceEffects/MarketEffects/TransitEffects/SpecialTileEffects 五模块建立。
- [x] (2026-02-18) 里程碑 C-7/C-8：回归 136 项全通过。
- [x] (2026-02-18) 里程碑 D：全量回归 136 项通过，计划收口。提交 feecf08。
## 意外与发现

- 观察：当前回归入口历史上依赖 `.agents` 路径，导致直接运行 `.github/tests/regression.lua` 失败。
  证据：上轮已修复入口路径并在本地跑通 136 个回归用例。
- 观察：`GameplayLoopPorts` 的旧平铺端口在部分内部脚本仍有遗留样例。
  证据：`.github/tests/internal/gameplay_loop_no_ui.lua` 需要同步到分组端口结构后才符合新契约。
- 观察：`LandingEffectExecutors` 同时承载概率抽卡、地块规则、动画意图、市场交互，存在多个变化原因。
  证据：单文件 399 行，包含 chance/tax/rent/mine/market 多域逻辑。

## 决策日志

- 决策：剩余重构拆成四个里程碑，先入口，再端口，再地块执行器，最后统一回归。
  理由：按依赖方向推进，避免在单次改动中同时重排入口与业务规则。
  日期/作者：2026-02-18 / Codex

- 决策：本轮重构不改变任何对外玩法语义，只做结构迁移与边界清晰化。
  理由：将风险控制在“可验证的等价重构”，避免功能变更与重构混杂。
  日期/作者：2026-02-18 / Codex

- 决策：端口契约继续使用已落地的分组模型（`modal/anim/ui_sync/debug/state`），不再提供平铺写法。
  理由：平铺模型已被证明会引入静默退化，继续兼容会持续增加隐患。
  日期/作者：2026-02-18 / Codex

## 结果与复盘

本计划全部里程碑已完成（2026-02-18，提交 feecf08）。

**结构产物（新增 13 个文件）：**
- 入口：`src/app/bootstrap/RuntimeInstall.lua`、`GameStartup.lua`、`UIBootstrap.lua`
- 端口：`src/presentation/api/ports/` 下 5 个子模块
- 落点：`src/game/systems/land/landing_effects/` 下 5 个子模块

**验证结果：** `lua .github/tests/regression.lua` → All regression checks passed (136)，dep_rules ok，tick ok。

**复盘要点：**
1. 三个顶层文件从合计 954 行压缩为 56 行，主要实现已迁移到子模块。
2. 拆分过程中无行为变更，所有接口签名保持不变。
3. `init.lua` 中 `current_game` 从模块局部变量改为通过 `current_game_ref[1]` 闭包传递，是唯一有别于原逻辑的结构调整（等价语义）。
4. 没有出现循环依赖，子模块按职责单向依赖领域层。

## 背景与导读

本仓库是 Lua Monopoly 项目，核心运行路径是 `src/app/init.lua` 初始化运行时并启动 `GameplayLoop`。`GameplayLoop` 通过 `GameplayLoopPorts` 抽象连接到 UI、动画、输入锁、调试输出等表现层能力。地块落点规则通过 `LandingEffectExecutors` 提供执行器，再由效果流水线调用。

本计划涉及三个核心区域。第一是入口编排层（`src/app/init.lua`），目前包含太多职责。第二是端口适配层（`src/presentation/api/GameplayLoopPortsAdapter.lua`），目前把五组端口默认实现集中在一个文件。第三是落点执行器层（`src/game/systems/land/LandingEffectExecutors.lua`），目前将多类规则堆叠在同一表内。

“端口”在本仓库里是一个约定的函数集合，用来让 Gameplay 不直接依赖具体 UI 库。所谓“拆分”不是改玩法，而是把同一类变化原因收拢到同一模块，避免一次改动牵动整条链路。

## 工作计划

里程碑 A 先重构入口。将 `src/app/init.lua` 按职责拆分到同目录或 `src/app/bootstrap/` 子目录。建议新增 `RuntimeInstall.lua`（安装环境与导出）、`GameStartup.lua`（构建 state 与 game_factory）、`UIBootstrap.lua`（注册 GAME_INIT、校验节点、显示加载屏）。`init.lua` 仅保留顺序装配与启动调用。拆分过程中保留原函数名语义，避免行为变化。

里程碑 B 处理端口适配器。把 `src/presentation/api/GameplayLoopPortsAdapter.lua` 拆成五个子模块：`ports/ModalPorts.lua`、`ports/AnimPorts.lua`、`ports/UISyncPorts.lua`、`ports/DebugPorts.lua`、`ports/StatePorts.lua`。顶层 `GameplayLoopPortsAdapter.build()` 仅负责组装并返回分组端口。每个子模块只导出本组默认函数集合，禁止跨组直接 require，跨组协作通过传入参数完成。

里程碑 C 处理落点执行器。将 `LandingEffectExecutors` 迁移为“分组构建 + 聚合注册”模式。建议新增 `landing_effects/` 目录，并按职责拆分为 `BaseLandEffects.lua`、`ChanceEffects.lua`、`MarketEffects.lua`、`TransitEffects.lua`、`SpecialTileEffects.lua`。原文件保留为聚合入口（兼容 require 路径），内部只做 `register_many` 所需的执行器合并。

里程碑 D 补测试和回归。新增针对拆分边界的单元用例，至少覆盖三类风险：入口组装是否漏注册事件、端口默认实现是否与拆分前等价、落点执行器聚合后可枚举且可执行。最后运行全量回归并确认全部通过。

## 具体步骤

在仓库根目录执行以下步骤。命令按顺序执行，不要跳步。

    cd /Users/billyq/Dev/Github/Lua/monopoly

步骤 1：建立入口拆分骨架并迁移 `init.lua` 职责。

    rg -n "local function _build_state|_install_game_init|_start_tick_loop" src/app/init.lua
    # 新增/迁移模块后，确保 src/app/init.lua 仅保留装配调用

步骤 2：拆分端口适配器。

    rg -n "_default_" src/presentation/api/GameplayLoopPortsAdapter.lua
    # 将同组默认函数迁移到 ports 子模块，顶层 build 仅组装

步骤 3：拆分 landing 执行器并保持聚合导出不变。

    rg -n "executors = \{|register_effect_executors|chance_draw_and_resolve|market =" src/game/systems/land/LandingEffectExecutors.lua
    # 新增 landing_effects 子模块并在聚合入口合并

步骤 4：补测试。

    rg -n "_test_.*ports|_test_.*landing|_test_.*init" .github/tests/suites/gameplay.lua .github/tests/suites/presentation_ui.lua
    # 新增针对拆分边界的用例并在 registry 中注册

步骤 5：执行验证。

    lua -e "package.path=package.path..';./.github/tests/?.lua;./.github/tests/suites/?.lua;./.github/tests/fixtures/?.lua'; local h=require('TestHarness'); h.run_all({require('gameplay')})"
    lua .github/tests/internal/gameplay_loop_no_ui.lua
    lua .github/tests/regression.lua

预期输出关键片段如下。

    All regression checks passed (...)
    dep_rules ok
    tick ok

## 验证与验收

验收以“行为未变 + 边界清晰”为准，不以“文件数量变化”为准。

第一，运行 `lua .github/tests/regression.lua`，预期所有回归通过，不出现新增失败。第二，运行 headless 驱动脚本，预期输出 `tick ok`。第三，人工快速检查以下结构性条件：

- `src/app/init.lua` 不再包含大段 UI 节点校验和事件处理细节。
- `src/presentation/api/GameplayLoopPortsAdapter.lua` 不再包含大段 `_default_*` 实现体，仅做组装。
- `src/game/systems/land/LandingEffectExecutors.lua` 成为聚合层，主要实现已迁移到 `landing_effects/` 子模块。

## 可重复性与恢复

本计划中的迁移步骤可重复执行。若中途失败，优先使用增量提交回退到上一个通过回归的提交点，而不是手工反向修改多文件。每完成一个里程碑都应执行一次最小回归（至少 `gameplay` + `gameplay_loop_no_ui`），避免错误跨里程碑扩散。

若发现拆分后出现循环依赖，先恢复到该里程碑起点提交，再通过“提取纯函数 + 延迟 require”方式重做，不要在同一提交中混入额外功能改动。

## 产物与备注

本计划完成后，仓库应新增三个结构产物。

- 入口拆分模块（`src/app/bootstrap/*` 或等价目录）。
- 端口分组默认实现模块（`src/presentation/api/ports/*`）。
- 落点执行器分组模块（`src/game/systems/land/landing_effects/*`）。

并保留兼容入口文件，使原有 require 路径不变，防止调用方批量改动。

## 接口与依赖

必须保持以下接口稳定，不得改函数签名与调用约定。

- `src/presentation/api/GameplayLoopPortsAdapter.lua`：
    - `adapter.build(state) -> { modal, anim, ui_sync, debug, state }`
- `src/game/systems/land/LandingEffectExecutors.lua`：
    - `landing_effect_executors.executors`（table）
    - `landing_effect_executors.register_effect_executors(effect_registry)`
- `src/game/flow/turn/GameplayLoop.lua`：
    - `new_game(state)`
    - `set_game(state, game)`
    - `tick(game, state, dt)`

依赖约束：Gameplay 层不直接 require UI 细节模块；UI 细节通过端口默认实现承载。Landing 执行器子模块只依赖领域规则和 presenter，不得直接操作入口状态机。

## 里程碑

### 里程碑 A：入口职责拆分

目标是把 `init.lua` 从“全能文件”变为“装配入口”。完成后，阅读入口时应在几十行内看懂启动顺序。验收通过条件是：`init.lua` 行数显著下降，`GAME_INIT` 注册和 state 构建逻辑分别位于独立模块，回归通过。

里程碑 A 的完成定义（DoD）如下。第一，`src/app/init.lua` 不再定义 `_build_state`、`_start_tick_loop`、`_install_game_init` 这类长函数。第二，三个新模块都能被独立 require，且每个模块只负责一个变化原因。第三，入口初始化顺序与拆分前一致：先 Runtime 安装，再构建 state/game，再绑定 GAME_INIT，再启动 tick。第四，相关回归全部通过且无新增 flaky。

里程碑 A 的分步验收顺序固定为：先做 A-1/A-2 并跑 `gameplay_loop_no_ui`，再做 A-3/A-4 并跑 `gameplay`，最后做 A-5/A-6/A-7 并跑 `regression`。每完成一步都要在“进度”勾选并附时间戳，若中断则在“结果与复盘”记录停点与下一步命令。

### 里程碑 B：端口适配器分组拆分

目标是把端口默认实现按组归位，避免一个文件承载 UI/动画/调试全部细节。完成后，修改某一组端口不会触碰其他组代码。验收通过条件是：`GameplayLoopPortsAdapter.lua` 主要由组装代码构成，端口行为保持不变，`gameplay_loop_no_ui` 通过。

里程碑 B 的完成定义（DoD）如下。第一，`src/presentation/api/GameplayLoopPortsAdapter.lua` 仅保留 `build()` 组装逻辑，不再包含大量 `_default_*` 函数体。第二，`src/presentation/api/ports/` 下 5 个子模块都存在，并且每个模块只导出本组端口函数集合。第三，`GameplayLoopPorts.resolve` 所需的分组键（`modal/anim/ui_sync/debug/state`）全部可用且函数签名保持兼容。第四，`presentation_ui` 与 `gameplay` 相关回归全部通过。

里程碑 B 的分步验收顺序固定为：先做 B-1/B-2 并跑 `gameplay_loop_no_ui`，再做 B-3/B-4/B-5 并跑 `presentation_ui` 相关子集，最后做 B-6/B-7/B-8 并跑全量 `regression`。每完成一步都要在“进度”勾选并附时间戳；若中断，需要在“结果与复盘”补充中断点、未完成项与下一条执行命令。

### 里程碑 C：Landing 执行器拆分

目标是降低落点规则文件复杂度，建立可扩展结构。完成后，新增一种 tile/effect 只需改对应子模块和聚合声明。验收通过条件是：拆分后 `register_effect_executors` 仍能注册完整执行器集，现有 landing/chance/market 相关回归全通过。

里程碑 C 的完成定义（DoD）如下。第一，`src/game/systems/land/landing_effects/` 下 5 个子模块都存在，并按职责导出执行器片段。第二，`src/game/systems/land/LandingEffectExecutors.lua` 仅作为聚合层，不再承载多域细节实现。第三，`landing_effect_executors.executors` 的 key 集合与拆分前一致，`register_effect_executors(effect_registry)` 的行为与签名保持兼容。第四，`landing/chance/market/gameplay` 相关回归全部通过。

里程碑 C 的分步验收顺序固定为：先做 C-1/C-2 并跑 `landing` 子集，再做 C-3/C-4/C-5 并跑 `chance+market` 子集，最后做 C-6/C-7/C-8 并跑 `gameplay` 与全量 `regression`。每完成一步都要在“进度”勾选并附时间戳；若出现行为偏差，必须先补回归用例复现再继续迁移。

### 里程碑 D：收口验证与文档更新

目标是保证拆分结果可交接。完成后，应更新必要注释或简短导读，明确新目录分工。验收通过条件是：全量回归通过，`PLAN_CURRENT.md` 的进度、发现、决策、复盘均更新到最终状态。

里程碑 D 的完成定义（DoD）如下。第一，所有新增拆分模块都有对应验证用例或被现有回归覆盖。第二，`lua .github/tests/regression.lua` 全量通过，且包含 `dep_rules ok` 与 `tick ok`。第三，`PLAN_CURRENT.md` 的“进度”“意外与发现”“决策日志”“结果与复盘”都更新为最终状态，并可支持新接手者直接继续。第四，交付清单明确列出新增文件、兼容保留点和后续可选优化，不留未解释的隐式决策。

里程碑 D 的分步验收顺序固定为：先做 D-1/D-2 建立覆盖，再做 D-3 层级回归，随后做 D-4 全量回归，最后做 D-5/D-6 文档收口。若任一回归失败，先回到对应里程碑修复并补充“意外与发现”，不得跳过失败直接收口。

## 更新记录

- 2026-02-18：基于已完成修复提交 `937a086`，将“剩余结构重构”整理为可执行计划并重写本文件。这样做的原因是把功能修复与结构改造分阶段推进，降低实施风险并提升可追踪性。
