# Turn 流程依赖倒置与策略统一重构


本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.github/PLANS.md` 的维护要求。

## 目的 / 全局视角


当前 `src/game/flow/turn` 可以运行，但回合策略层仍直接依赖平台全局（例如 `GameAPI` 和 UI 状态细节），并且自动决策与超时策略分散在多个模块。结果是：同一条规则需要多处改动，行为容易漂移，且在无 UI 或测试桩不完整时容易触发断言。

本次重构完成后，用户可见行为不改变，但“稳定性与一致性”会提升：倒计时展示与真实超时一致，自动选择在所有入口遵循同一策略，回合核心可在 headless 场景稳定推进。验收方式是新增/更新回归测试，并运行统一回归命令，确认所有旧行为保留且新增约束成立。

## 进度


- [x] (2026-02-23 02:31Z) 完成审查结论整理，并将重构方向落入本可执行计划。
- [x] (2026-02-23 02:40Z) 拆出时钟端口：`GameplayLoopPortTypes/GameplayLoopPorts` 新增 `clock`，`TurnDispatch` 改为读端口时间源。
- [x] (2026-02-23 02:43Z) 合并自动选择策略：新增 `TurnChoiceAutoPolicy`，`TurnDecision` 与 `TickTimeout` 统一接入。
- [x] (2026-02-23 02:45Z) 统一动作门禁入口：`TurnDispatch` 通过 `TurnDispatchValidator.resolve_gate_state/should_block_action` 做单点判定。
- [x] (2026-02-23 02:46Z) 统一弹窗倒计时来源：`TickUISync` 改为读取 `TickTimeout.resolve_modal_timeout_seconds`。
- [x] (2026-02-23 02:48Z) 增补 4 条回归测试并执行 `lua .github/tests/regression.lua`，结果 `154/154` 通过。

## 意外与发现


- 观察：`TurnDispatch` 直接读取 `GameAPI.get_timestamp/get_timestamp_diff`，策略层依赖平台全局，测试环境必须打补丁。
  证据：`src/game/flow/turn/TurnDispatch.lua:12`，`src/game/flow/turn/TurnDispatch.lua:19`。

- 观察：自动选择逻辑同时存在于 `TurnDecision.decide_choice_action` 与 `TickTimeout.step_choice_timeout`，最小展示时长与触发时机靠两处协作。
  证据：`src/game/flow/turn/TurnDecision.lua:79`，`src/game/flow/turn/TickTimeout.lua:105`。

- 观察：弹窗倒计时展示使用 `constants.action_timeout_seconds`，但实际关闭可走 `popup_payload.auto_close_seconds` 或 `gameplay_rules.popup_auto_close_seconds`。
  证据：`src/game/flow/turn/TickUISync.lua:46`，`src/game/flow/turn/TickTimeout.lua:92`。

- 观察：测试桩最初把 `clock.now()` 固定为 `0`，导致 `next` 冷却永远不满足，`autorunner` 用例卡死。
  证据：回归失败日志 `autorunner did not finish within max_steps=5000`，修复后回归恢复全绿。

## 决策日志


- 决策：先做“依赖倒置 + 策略统一”，不改玩家可见交互语义。
  理由：当前主要风险是可维护性和一致性，不是功能缺失；先保证行为等价可降低重构风险。
  日期/作者：2026-02-23 / Codex

- 决策：以“端口 + 纯函数策略”方式重构，不引入复杂对象层级。
  理由：Lua 项目当前以模块函数为主，保持同风格可减少迁移成本。
  日期/作者：2026-02-23 / Codex

- 决策：测试优先覆盖行为不变与一致性约束，不追求一次性重写所有历史测试结构。
  理由：回归面已较大，增量补测比全面重构测试框架更稳妥。
  日期/作者：2026-02-23 / Codex

- 决策：门禁增强只对 `ui_button:next` 增加 choice/market/popup/detained 语义阻塞，不扩大到 `choice_select`。
  理由：保持现有“选择态可提交”的行为，避免无关交互回归。
  日期/作者：2026-02-23 / Codex

- 决策：测试端口 `clock` 默认实现改为优先读 `GameAPI`，而不是固定常量。
  理由：保证旧测试补丁语义不变，避免把基础设施差异误判为业务回归。
  日期/作者：2026-02-23 / Codex

## 结果与复盘


已完成三项里程碑并通过回归验收。交付结果如下：一是 `TurnDispatch` 不再硬依赖全局 `GameAPI`；二是自动选择规则收敛到 `TurnChoiceAutoPolicy` 单入口；三是弹窗倒计时展示与真实超时来源一致，动作门禁进入 `TurnDispatchValidator` 单点判定。回归命令 `lua .github/tests/regression.lua` 输出 `All regression checks passed (154)`，满足“行为等价 + 一致性提升”的初始目标。

## 背景与导读


`turn` 流程的运行入口在 `src/game/flow/turn/GameplayLoop.lua`。它每帧调用超时、动画、UI 同步和自动执行器。状态机本体在 `src/game/flow/turn/TurnFlow.lua`，具体阶段由 `src/game/core/runtime/PhaseRegistry.lua` 组装，包含 `start/roll/move/landing/post_action/end_turn`。

动作分发在 `src/game/flow/turn/TurnDispatch.lua`，输入合法性在 `src/game/flow/turn/TurnDispatchValidator.lua`。选择态处理在 `src/game/flow/turn/TurnChoiceHandler.lua`，选择解析落到 `src/game/systems/choices/ChoiceResolver.lua`。超时逻辑在 `src/game/flow/turn/TickTimeout.lua`，倒计时展示在 `src/game/flow/turn/TickUISync.lua`。

所谓“端口”，是把外部能力（时间、UI、调试、动画）封装成一组函数接口，让核心规则只依赖接口而不是直接调用全局。项目已有端口骨架：`src/game/flow/turn/GameplayLoopPorts.lua` 和 `src/game/flow/turn/GameplayLoopPortTypes.lua`。本次重构会沿用这一路径扩展，而不是新建第二套机制。

测试主入口是 `/.github/tests/regression.lua`。`gameplay` 相关用例集中在 `/.github/tests/suites/gameplay.lua`，切片映射在 `/.github/tests/suites/gameplay_registry.lua`。headless 验证脚本在 `/.github/tests/internal/gameplay_loop_no_ui.lua`。

## 里程碑一：时钟依赖倒置（先消除硬依赖）


本里程碑目标是让回合核心不再直接读取 `GameAPI`。完成后，`TurnDispatch` 的“下一回合冷却”依赖可由端口注入，headless 测试不需要再依赖全局补丁。用户可见行为保持不变，但测试和维护成本显著下降。

实施上，在 `GameplayLoopPortTypes` 新增 `clock` 分组（例如 `now()`、`diff_seconds(a,b)`），在 `GameplayLoopPorts` 提供默认实现。默认实现优先走 `GameAPI`，若环境缺失则安全降级（返回可预测值并让逻辑走保守分支，不崩溃）。随后改 `TurnDispatch`：删除 `_get_timestamp/_get_timestamp_diff_seconds` 对全局的直接断言，改为从 dispatch context 读 `clock` 端口。

验收证据是：旧测试仍通过，且新增一条测试验证“未注入 GameAPI 但注入 clock 端口时 next 冷却逻辑仍生效”。

## 里程碑二：统一自动选择策略（收敛重复逻辑）


本里程碑目标是把自动选择规则集中到一个策略模块，避免 `TurnDecision` 和 `TickTimeout` 分别维护。完成后，最小可见时长、AI 自动选择、超时兜底在所有路径上由同一套规则产出动作。

实施上，新增 `src/game/flow/turn/TurnChoiceAutoPolicy.lua`（命名可在实施时微调，但必须单一职责），提供一个统一入口，例如 `decide(game, state, choice, ctx)`。`TurnDecision.decide_choice_action` 改为调用该入口；`TickTimeout.step_choice_timeout` 也调用同入口，传入 `reason = "min_visible" | "timeout"` 之类上下文，避免重复拼动作。

验收证据是：新增测试覆盖“同一个 choice 在 wait_choice 路径与 tick_timeout 路径生成相同动作”；并验证 `auto_choice_min_visible_seconds` 生效时不会提前动作。

## 里程碑三：统一动作门禁与超时展示（保证一致性）


本里程碑目标是收敛“动作是否允许”和“UI 倒计时显示”两类一致性问题。完成后，阻塞规则可以在单点说明并测试，倒计时显示数值与真实触发时机一致。

实施上，抽出门禁策略函数（可放在 `TurnDispatchValidator` 内部或新模块，但最终必须只有一个判断入口），把 `input_blocked`、`wait_choice`、`popup_active`、`detained_wait` 等判定整合为显式规则。与此同时，在 `TickUISync.update_countdown` 侧引入与 `TickTimeout` 共享的“有效超时解析”函数，弹窗倒计时要读取与 `step_modal_timeout` 相同的超时来源。

验收证据是：新增测试验证“popup_payload.auto_close_seconds=3 时，倒计时从 3 递减并在约 3 秒触发关闭”；并验证阻塞矩阵下 `ui_button next`、`choice_select` 的放行/拦截符合策略。

## 工作计划


先做端口扩展，再做策略收敛，最后处理一致性显示。这个顺序的原因是：时钟依赖倒置能先把核心逻辑从环境细节里抽离，后续策略重构就能在更稳定的测试条件下进行；若反过来做，容易把行为差异和环境问题混在一起，调试成本高。

具体编辑顺序如下。第一步修改 `src/game/flow/turn/GameplayLoopPortTypes.lua` 与 `src/game/flow/turn/GameplayLoopPorts.lua` 增加 `clock` 分组及默认实现，同时保证旧调用者不传 `clock` 也不会崩。第二步修改 `src/game/flow/turn/TurnDispatch.lua` 改为读取 context 中的 `clock` 端口，并保持对 `next_turn_cooldown` 的行为等价。第三步新增统一自动策略模块，并改造 `TurnDecision.lua` 与 `TickTimeout.lua` 调用。第四步统一门禁判定与超时展示来源，涉及 `TurnDispatchValidator.lua`、`GameplayLoopRuntime.lua`、`TickUISync.lua`。第五步补测试，必要时调整 `/.github/tests/suites/gameplay_registry.lua` 的命名与切片索引，让新增测试被回归入口覆盖。

## 具体步骤


在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 按以下顺序执行。

    1) 编辑端口与分发：
       - src/game/flow/turn/GameplayLoopPortTypes.lua
       - src/game/flow/turn/GameplayLoopPorts.lua
       - src/game/flow/turn/TurnDispatch.lua

    2) 新增并接入自动策略：
       - 新建 src/game/flow/turn/TurnChoiceAutoPolicy.lua
       - 修改 src/game/flow/turn/TurnDecision.lua
       - 修改 src/game/flow/turn/TickTimeout.lua

    3) 统一门禁与倒计时来源：
       - 修改 src/game/flow/turn/TurnDispatchValidator.lua
       - 修改 src/game/flow/turn/TickUISync.lua

    4) 增补测试并接入回归：
       - 修改 .github/tests/suites/gameplay.lua
       - 如有新增索引，修改 .github/tests/suites/gameplay_registry.lua

    5) 运行回归：
       cd /Users/billyq/Dev/Github/Lua/monopoly && lua .github/tests/regression.lua

预期关键输出包含：

    All regression checks passed (...)
    dep_rules ok
    tick ok

## 验证与验收


验收分三层。第一层是行为等价：不改玩法语义，原有关键流程（投骰、移动、落地、选择、动画等待）全部按旧规则推进。第二层是一致性：自动选择路径统一，弹窗倒计时显示与实际关闭一致。第三层是可测试性：在 headless 条件下，回合流程不因平台全局缺失而崩溃。

执行回归命令：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

如果失败，按“新增测试失败优先于旧测试波动”的原则排查：先确认新策略是否破坏既有语义，再决定是修代码还是修错误断言。最终验收标准是回归全绿，且新增测试能够在改造前失败、改造后通过。

## 可重复性与恢复


本计划步骤可重复执行，不涉及数据迁移。若中途失败，允许按文件粒度回退当次改动后重跑回归，不需要重建环境。建议每完成一个里程碑就运行一次 `lua .github/tests/regression.lua`，避免累计偏差导致定位困难。

如果需要完整回退本任务，可按提交边界撤销以下路径：`src/game/flow/turn/*` 中本次新增/修改文件、`.github/tests/suites/gameplay.lua`、`.github/tests/suites/gameplay_registry.lua`、`.github/tests/internal/gameplay_loop_no_ui.lua`、`.github/PLAN_CURRENT.md`。回退后再次运行回归确认恢复。

## 产物与备注


本任务实施完成时应有三类产物。第一类是代码产物：端口扩展、策略模块、门禁与倒计时一致性改造。第二类是测试产物：覆盖时钟端口注入、自动策略统一、弹窗倒计时一致性的新增用例。第三类是文档产物：本计划中的“进度”“决策日志”“结果与复盘”必须与真实实现状态同步。

建议在本节追加简短证据片段，例如：

    [PASS] _test_turn_dispatch_uses_clock_ports_without_game_api
    [PASS] _test_choice_auto_policy_consistent_between_wait_and_timeout
    [PASS] _test_popup_countdown_uses_effective_modal_timeout
    [PASS] _test_dispatch_gate_blocks_next_when_choice_active
    All regression checks passed (154)

## 接口与依赖


本次改造不新增第三方依赖，继续使用现有 Lua 模块体系。

里程碑完成时必须稳定存在以下接口（命名可微调，但语义必须一致）：

    -- in src/game/flow/turn/GameplayLoopPortTypes.lua
    groups.clock = { "now", "diff_seconds" }

    -- in src/game/flow/turn/GameplayLoopPorts.lua
    clock.now() -> number
    clock.diff_seconds(ts1, ts2) -> number

    -- in src/game/flow/turn/TurnChoiceAutoPolicy.lua
    decide(game, state, choice, ctx) -> action|nil

    -- in src/game/flow/turn/TickTimeout.lua (共享超时来源)
    resolve_modal_timeout_seconds(game, state) -> number

动作门禁应通过单一入口调用（保留在 `TurnDispatchValidator` 或独立模块均可），禁止出现多份分叉规则。

## 变更记录（本次）


- 已清空旧 `PLAN_CURRENT.md` 并写入本计划，原因是当前任务已切换为“turn 流程重构方案”，旧计划主题与目标不再匹配。
- 本次版本补全了可执行计划的必需章节与里程碑验收标准，原因是要保证新手在无历史上下文下也能直接落地实施。
- 本次版本将计划状态更新为“已实施完成”，同步补充了真实回归结果与实施中发现，原因是活文档必须与当前代码状态一致。
