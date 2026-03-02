# Monopoly Turn Tick 编排细化执行计划（步骤4 / R15）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。任何执行者只依赖当前工作树与本文件即可从零开始推进。

## 目的 / 全局视角

本计划只处理研究文档中的“步骤4：继续细化 turn 用例编排职责”。目标是在不改变玩法语义与时序契约的前提下，降低 `GameplayLoopTickFlow` 的单文件复杂度，让 phase 驱动、timeout 驱动和 dirty 刷新驱动各自成为窄职责模块。用户可见结果是回归保持全绿，并且后续定位 tick 行为问题时能更快定位到单一职责函数。是否生效以全量回归和关键时序测试为准。

## 进度

- [x] (2026-03-02 17:12 +08:00) 已重写计划为“仅步骤4”范围，移除已完成历史里程碑展示。
- [x] (2026-03-02 17:14 +08:00) 建立实施基线：`lua tests/internal/dep_rules.lua` 与 `lua tests/regression.lua` 通过（N=209）。
- [x] (2026-03-02 17:20 +08:00) M59.1：完成 tick 职责地图并确认驱动边界（phase/timeout/dirty/auto runner）。
- [x] (2026-03-02 17:24 +08:00) M59.2：抽离 timeout 驱动到 `GameplayLoopTickSteps.step_tick_timeouts`。
- [x] (2026-03-02 17:24 +08:00) M59.3：抽离 dirty 刷新与 phase 同步到 `GameplayLoopTickSteps.refresh_tick_from_dirty/sync_tick_phase`。
- [x] (2026-03-02 17:24 +08:00) M59.4：`GameplayLoopTickFlow` 收口为轻量编排壳层，仅保留顺序调度。
- [x] (2026-03-02 17:31 +08:00) M60.1：在 `tests/suites/gameplay.lua`（`_test_tick_headless_ports_cover_anim_phases`）补强 tick 时序断言。
- [x] (2026-03-02 17:31 +08:00) M60.2：通过现有 loop slice 保持覆盖面稳定，无需新增 suite 切片范围。
- [x] (2026-03-02 17:33 +08:00) M61：完成收口验证并回填证据，步骤4交付完成。

## 意外与发现

实施中发现一个用例装配脆弱点：若直接扩展 `gameplay.loop` slice 上限，`gameplay_registry` 的名称索引会与 `gameplay.lua` 返回顺序出现错位，导致失败名称与真实失败函数不一致。修复策略是把新时序断言并入既有 loop 用例（`_test_tick_headless_ports_cover_anim_phases`），避免破坏既有切片边界与命名映射。

## 决策日志

决策：本计划只覆盖未完成的步骤4，不再在进度清单重复展示步骤1/3/5历史完成项。
理由：本次目标是推进未完成工作，避免执行者在进度章节被历史噪音干扰。
日期/作者：2026-03-02 / Codex GPT-5。

决策：步骤4采用四段拆分（职责建模 -> timeout 抽离 -> dirty/phase 抽离 -> 壳层收口）并以每段回归绿灯作为闸门。
理由：tick 时序高度敏感，分段推进可最小化定位半径，减少一次性重构风险。
日期/作者：2026-03-02 / Codex GPT-5。

## 结果与复盘

当前仅完成计划重写，尚未完成步骤4代码实施。验收结论待 M59-M61 完成后回填。完成时必须总结三项内容：拆分前后职责边界变化、时序契约是否保持、剩余技术债与下一步建议。
步骤4已完成。`GameplayLoopTickFlow` 从“细节实现 + 编排混合”收敛为“编排壳层”，具体驱动逻辑迁移到 `GameplayLoopTickSteps`。时序契约通过增强后的 loop 测试验证保持稳定，全量回归与依赖守护继续全绿。剩余技术债主要是 `gameplay_registry` 与 `gameplay.lua` 的切片索引耦合仍偏脆弱，后续可考虑改为显式按测试名组装 suite。

## 背景与导读

本仓库的 turn 主循环由 `src/game/flow/turn/GameplayLoop.lua` 对外暴露入口，`GameplayLoopTickFlow.lua` 承担 tick 内部编排，`GameplayLoopRuntime.lua` 和若干 policy 模块承载具体行为。步骤4关注点不是新增功能，而是把已有编排逻辑进一步细化，使每类驱动逻辑都有明确责任边界。

本计划中的“phase 驱动”指按当前 turn phase 触发的流程推进；“timeout 驱动”指 choice/modal 等超时自动行为；“dirty 刷新驱动”指 UI/状态脏标记触发的刷新同步；“auto runner 驱动”指自动托管路径对 action 的推进。步骤4验收要求这些驱动的触发条件与先后关系保持不变。

## 工作计划

先在 `GameplayLoopTickFlow.lua` 内标注当前执行顺序，把语义相关分支按驱动类型归档。然后先抽 timeout 驱动，因为其输入输出边界通常最清晰，容易保持语义不变并快速验证。随后抽离 dirty 刷新与 phase 同步，将 `tick` 函数收敛为编排壳层。抽离过程中尽量复用现有 port 接口与 policy 模块，避免引入新的跨层耦合。

测试侧先加顺序断言，再补组合场景。顺序断言优先放在 `tests/suites/gameplay_loop.lua`，组合场景按需要补到 `gameplay.lua` 或 `gameplay_runtime.lua`。若拆分导致旧断言依赖内部实现细节，优先把断言改为行为导向，而不是回退结构优化。

## 具体步骤

所有命令在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行。

先运行基线命令：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua

预期输出至少包含：

    dep_rules ok
    All regression checks passed (N)

进入 M59.1 时执行：

    rg "tick|timeout|dirty|phase|auto_runner" src/game/flow/turn -n

并据此编辑 `src/game/flow/turn/GameplayLoopTickFlow.lua`。每完成一个子拆分（M59.2/M59.3/M59.4）都运行：

    lua tests/regression.lua

进入 M60 时更新测试文件后运行：

    lua tests/regression.lua

进入 M61 收口时运行：

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua
    rg "GameplayLoopTickFlow" tests/suites -n

并将关键输出写入“产物与备注”。

## 验证与验收

验收必须证明“行为不变且职责更清晰”。行为不变的判据是：全量回归持续通过，且新增/增强的时序断言稳定通过。职责清晰的判据是：`GameplayLoopTickFlow` 主体可读为顺序编排壳层，phase/timeout/dirty/auto runner 的实现细节进入窄职责函数或策略模块。

最终验收描述应包含：`lua tests/regression.lua` 的通过数，新增时序断言名称，以及拆分后关键函数入口列表。

## 可重复性与恢复

本计划按 M59.1 -> M59.2 -> M59.3 -> M59.4 -> M60.1 -> M60.2 -> M61 顺序推进。每个子里程碑完成后立即跑回归。若某一步失败，只回退该步骤触及文件并重新验证，禁止跨步骤打包回退。

若发现拆分会改变时序语义，应优先保语义并缩小拆分粒度，而不是强行完成结构目标。必要时可拆分为更小函数并延后文件级迁移，但必须在“决策日志”记录原因。

## 产物与备注

实施时在此节追加短证据片段，至少包含：

    [evidence] lua tests/internal/dep_rules.lua -> dep_rules ok
    [evidence] lua tests/regression.lua -> All regression checks passed (209)
    [evidence] gameplay_loop timing assertions -> pass (_test_tick_headless_ports_cover_anim_phases)
    [evidence] tick flow split summary -> GameplayLoopTickFlow.tick => sync_input_blocked -> role_control -> auto_runner -> timeouts -> phase_sync -> dirty_refresh

## 接口与依赖

步骤4不改变外部入口 `gameplay_loop.tick(game, state, dt)` 和 `gameplay_loop.step_auto_runner(game, state, dt, context)` 的函数签名。若新增内部策略文件，必须位于 `src/game/flow/turn/` 并通过现有 ports 访问外部能力，避免直接引入宿主全局依赖。

测试依赖继续使用仓库现有入口 `tests/regression.lua` 作为唯一验收口径，避免局部 suite 装配差异造成误判。

本次修订说明（2026-03-02）：按“重写 plan.md，删去已完成部分，将未完成里程碑细化拆分”的要求，重写为仅覆盖步骤4的执行计划，移除历史已完成里程碑，新增 M59.1-M61 细粒度拆分与闸门验证路径。

本次修订说明（2026-03-02，执行回填）：已完成 M59-M61。新增 `src/game/flow/turn/GameplayLoopTickSteps.lua`，收口 `GameplayLoopTickFlow.lua` 为壳层编排；增强 loop 时序断言并通过全量回归（N=209）与 `dep_rules` 验证。
