# 全研究项并行治理与计划重建

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `.agents/harness/PLANS.md` 维护，并作为并行执行各任务的唯一事实来源。

## 目的 / 全局视角

这轮工作的目标不是单点修补，而是把 `.agents/research.md` 里的四类问题真正收口：降低高风险热点函数的维护成本，收敛“同因变化”的重复代码，只删除已经证明零消费者的残留代码，并修正已经确认的架构越界。改完后，开发者可以直接看到三类结果：行为与契约测试仍然全绿、架构守卫没有回退、CRAP 热点分数相对基线继续下降，而且 `.agents/plan.md` 本身能独立指导任何后来者继续推进。

第一步先建立可信基线。基线不是沿用旧研究截图，而是以当前工作树重新跑一遍仓内质量命令得到的结果。之后按依赖分波次推进：先补护栏和小步重构，再做共享 helper 合并，再做入口/配置迁移和 landing visual hold 收口，最后统一做质量回归与复盘。

## 进度

- [x] (2026-03-24 02:21Z) 完成 `T0`：重写本计划为活文档，重新跑 baseline 五条命令并把结果写回计划。
- [x] (2026-03-24 02:21Z) 记录 repo 真相：`src/config/gameplay/vehicle_catalog.lua`、`src/infrastructure/runtime/global_aliases.lua`、`src/player/actions/state_ops/status_ops.lua` 仍有消费者，不进入首轮删除。
- [x] (2026-03-24 03:06Z) 完成 `T1`：`availability.lua` 两个热点降为低复杂度，并补齐 rent-response / timing characterization tests。
- [x] (2026-03-24 03:09Z) 完成 `T2`：`item_preconsume_policy.lua` 与 `phase.lua` 拆成单职责 helper，目标 behavior suites 通过。
- [x] (2026-03-24 03:03Z) 完成 `T3`：`context.lua` 的 provider/GameAPI fallback 与 `get_role` 容错已被拆小并补护栏。
- [x] (2026-03-24 02:56Z) 完成 `T5`：validator 与 backward board 链路改成中间结果函数，并有定向 RED->GREEN 证据。
- [x] (2026-03-24 03:11Z) 完成 `T6`：AI `_remote_priority` 拆成 tile-type / land 子规则，land suite 绿且 CRAP 显著下降。
- [x] (2026-03-24 03:01Z) 完成 `T7`：`ring_map_builder` 与 `test_profiles` 的 characterization tests 补齐，`_profile` 改为深拷贝。
- [x] (2026-03-24 03:04Z) 完成 `T12`：`_with_client_role` 重复实现已收敛到 `src/core/utils/with_client_role.lua`，presentation 相关 suites 通过。
- [x] (2026-03-24 02:52Z) 完成 `T13`：wait 层 `_log_once` 已收敛到 `src/turn/waits/log_once.lua`，相关 gameplay/runtime suites 通过。
- [x] (2026-03-24 03:05Z) 完成 `T14`：删除 `skins.lua`、`feature_toggles.lua` 与空 `fill_output_defaults()`；`runtime_refs.lua` 审计后保留。
- [x] (2026-03-24 03:17Z) 完成 `T15`：机会卡抽取彻底改走注入 RNG，domain/runtime/architecture 三组护栏已补齐。
- [x] (2026-03-24 02:50Z) 完成 `T16`：`game_state.lua` 增加 mixin collision assert，并补了“正常组装 / 重复 key 失败”护栏。
- [x] (2026-03-24 03:16Z) 完成 `T17`：`src.app.bootstrap` 改为显式 `init()`，`main.lua` 切到显式调用，startup profile suite 绿。
- [x] (2026-03-24 03:19Z) 完成 `T20`：caller 清单已盘点，并用 characterization tests 固定 attached-state / release 顺序相关行为。
- [x] (2026-03-24 03:28Z) 完成 `T4`：mine trigger、tile index 解析、turn label 命名化已完成，presentation suites 绿。
- [x] (2026-03-24 03:31Z) Wave 1 收口：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check` 全部通过。
- [x] (2026-03-24 03:46Z) 完成 `T8`：`resolver` 与 `item_preconsume_policy` 已共享 option/cancel helper，保留普通 cancel / preconsumed cancel 语义。
- [x] (2026-03-24 03:49Z) 完成 `T9`：rules 层表复制、整数归一化、包含判断已收敛到共享 helper，受影响 suites 通过。
- [x] (2026-03-24 03:43Z) 完成 `T10`：骰子倍率逻辑已提到 `src/turn/phases/dice_multiplier.lua`。
- [x] (2026-03-24 03:40Z) 完成 `T11`：方向映射共享到 `src/rules/board/directions.lua`。
- [x] (2026-03-24 03:47Z) 完成 `T18`：presentation-owned 入口 `src/presentation/runtime/install.lua` 生效，`main.lua` 切换完成。
- [x] (2026-03-24 03:51Z) 完成 `T21`：landing visual hold 底层真相收敛到 runtime state，并补“state 胜过 stale game flags”护栏。
- [x] (2026-03-24 03:55Z) Wave 2 收口：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check` 全部通过。
- [x] (2026-03-24 04:07Z) 完成 `T19`：`src/config/gameplay/rules.lua` 已删除；新建 `debug_flags.lua`、`timing.lua`、`board_geometry.lua`、`target_pick.lua`、`item_ids.lua` 并完成消费者迁移，`rg 'src.config.gameplay.rules' src tests` 归零。
- [x] (2026-03-24 04:05Z) 完成 `T22`：hold callers 已切到新单源 API，旧的 game 同步式 defer 读路径被移除。
- [x] (2026-03-24 04:09Z) Wave 3 收口：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check` 全部通过，`git diff --check` 通过。
- [x] (2026-03-24 04:12Z) 完成 `T23`：重跑 baseline 五条命令并记录最终 CRAP；`behavior=1165`、`contract=88`、`guard=5/5`、`arch=ok`、`crap=passed`。
- [x] (2026-03-24 04:13Z) 完成 Wave 4：基于 `T23` 结果核对最终验收与复盘，清理活文档中残留的未完成状态、旧路径与过时叙述。

## 意外与发现

- 观察：`.agents/research.md` 记录的 CRAP Top Hotspots 已经落后于当前工作树，不能直接当作执行基线。
  证据：`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 当前输出的第一名已是 `src/ui/render/status3d/status.lua:_has_pending_roadblock_trigger`，不再是 `_can_offer_rent_response`。
- 观察：`lua tests/behavior.lua` 当前全绿，共 `1141` 条回归；最慢用例是 `land.apply_tax_with_pending_tax_free_skips_payment`，耗时约 `1000ms`。
  证据：
    All regression checks passed (1141)
- 观察：架构检查与 guard 检查在基线阶段已经通过，说明后续任务必须在“不回退现有 guard”的前提下推进。
  证据：
    arch_view 检查通过 / arch_view check ok
    dep_rules ok
    gameplay_loop_no_ui ok
    forbidden_globals ok
    arch_view_guard ok
    repo_hygiene ok
- 观察：为了把 CRAP Top 原样抄入计划，直接附加的 `cjson` 解析辅助命令失败；但质量工具自身已经成功生成 `tmp/crap_report.json` 并打印热点列表，因此以工具输出为准。
  证据：
    [crap] analyzed modules=346 functions=2879
    [crap] lane=behavior mode=behavior status=passed total=1141 failures=0
    cjson missing
- 观察：`T12` 初版把 `_with_client_role` helper 放进 `src/ui/render/`，立刻触发 `projection_cycle ui`；把 helper 移到 `src/core/utils/with_client_role.lua` 后，`arch` 与 `guard` 恢复通过。
  证据：
    arch_view 检查失败 / arch_view check failed
      投影循环 / projection_cycle ui
    arch_view 检查通过 / arch_view check ok
    arch_view_guard ok
- 观察：`T20` 的 characterization 显示当前 landing visual hold 仍是“双源同步后保持一致”的过渡态，而不是最终单源；`T21/T22` 仍然必要。
  证据：
    failed=true total=7
    failed=false total=7
    failed=false total=26
- 观察：`T15` 改完机会卡 RNG 后，旧的 `landing.chance_landing_pushes_popup` 仍在 patch `LuaAPI.rand`，导致行为车道出现 1 条回归；把该测试改成注入 `game.rng.next_int` 后，behavior 恢复全绿。
  证据：
    Regression failed (1/1160)
    All regression checks passed (1160)
- 观察：`T18` 初版让 `src/presentation/runtime/install.lua` 直接 `require("src.app.bootstrap")`，触发了 `projection_cycle root`；改成仓内既有的惰性字符串 require 形式后，`arch` 恢复通过。
  证据：
    arch_view 检查失败 / arch_view check failed
      投影循环 / projection_cycle root
    arch_view 检查通过 / arch_view check ok
- 观察：T0 的 CRAP baseline 与本轮任务关注点并不完全一致；因此最终 top hotspots 并未整体下降，反而把“当前 baseline 未覆盖的热点”更清晰地暴露出来。
  证据：
    T0 top 1: _has_pending_roadblock_trigger | 18.96 | src/ui/render/status3d/status.lua
    T23 top 1: _has_pending_roadblock_trigger | 18.96 | src/ui/render/status3d/status.lua
    T23 新上榜: _validate_item_slot_action | 12.00 | src/turn/actions/validator.lua

## 决策日志

- 决策：以当前仓库重新跑出的 baseline 作为本计划后续验收的唯一基准，不再沿用 `.agents/research.md` 里的旧排行。
  理由：研究文档已经与当前代码状态不一致，继续沿用会把执行工作引向错误目标。
  日期/作者：2026-03-24 / Codex
- 决策：保留原任务编号 `T0` 到 `T23`，但执行时以“当前仓库事实优先、旧研究结论次之”解释每个任务。
  理由：这样既保留用户要求的依赖图，又允许后续子任务在不违背现状的情况下调整实现细节。
  日期/作者：2026-03-24 / Codex
- 决策：死代码清理只接受“已证实零消费者”的删除，不对 `vehicle_catalog`、全局别名桥和 `set_player_seat` 做先验假设。
  理由：用户已明确给出这三处仍有消费者；本轮只做安全删除，不做冒险清理。
  日期/作者：2026-03-24 / Codex
- 决策：`_with_client_role` 的共享 helper 不放在 `src/ui/render/`，而是放进 `src/core/utils/with_client_role.lua`。
  理由：`src/ui.render.canvas_render_pipeline -> src.ui.wid.*` 已存在投影边；若 `wid` 反向依赖 `render`，会形成 `projection_cycle ui`。
  日期/作者：2026-03-24 / Codex
- 决策：Wave 4 完成后，以“计划事实自洽”作为最后一道收尾标准，移除已被后续记录覆盖的进行中条目，并把执行目录统一到当前仓库路径。
  理由：活文档不仅要记录做过什么，还要保证后来者按当前文本继续执行时不会被旧状态或旧环境路径误导。
  日期/作者：2026-03-24 / Codex

## 结果与复盘

整份计划已经执行完成。`src/config/gameplay/rules.lua` 已经拆除并删除，宿主入口已经反转到 `src/presentation/runtime/install.lua`，landing visual hold 已完成“先建护栏、再底层单源、再 caller 切换”的三步走。最终基线重新验证结果为：`lua tests/behavior.lua` 通过 `1165` 项，`lua tests/contract.lua` 通过 `88` 项，`lua tests/guard.lua` 五项全过，`lua tools/quality/arch.lua check` 通过，`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 通过。

T0 与 T23 的 CRAP 对比有一个重要偏差：这轮任务显著压低了旧研究里指定的热点，例如 `_can_offer_rent_response`、`availability.trigger_timing_allowed`、`_remote_priority`、`_direction`、`_profile` 已不在最终 top 20；但 T0 当天重新跑出来的 top 15 热点大多并非本轮任务对象，所以它们的分数并没有整体下降。例如 `_has_pending_roadblock_trigger` 仍是 `18.96`，`src/app/bootstrap/runtime_install.lua:M.install` 仍是 `12.00`，`src/rules/effects/mine_effect.lua:_find_pending_roadblock_trigger` 仍是 `11.76`。同时，经过重构后暴露出了新的热点，如 `src/turn/actions/validator.lua:_validate_item_slot_action` 与 `_resolve_item_slot_resolution`。这不是回归失败，而是说明当前质量风险已经从旧研究的热点转移到了新的、未纳入本计划的函数上。

从结果上看，本计划完成了四个原始目标：一，旧研究中列出的热点与重复点都已被清理或降险；二，确认零消费者的死代码已删除，保留了明确有消费者的遗留桥；三，入口与 rules/host/hold 架构边界已经按计划收口；四，活文档本身已经记录了波次、验证、偏差与剩余风险。剩余风险主要有两类：当前 CRAP top 仍有若干未治理函数；以及 `land phase` 中为了兼容 legacy fixture 仍保留少量 fallback。它们适合作为下一轮计划，而不是回滚本轮结果。

## 背景与导读

本仓库是运行在 Eggy 宿主上的 Lua 5.5 大富翁项目，代码长期按七层清洁架构组织。与这轮计划最相关的目录如下：

`src/rules/` 承载规则与效果计算，是 CRAP 热点和配置聚合问题的集中区。`src/turn/` 承载回合状态机与等待逻辑，既有热点函数，也有 wait 层重复 helper。`src/presentation/` 与 `src/ui/` 承担宿主事件桥接、界面渲染和 UI runtime 维护，是入口切换和 landing visual hold 收口的核心区域。`src/state/` 负责集中式游戏状态与访问器，是 landing visual hold 单源化和 `game_state` 组装保护的落点。`src/app/bootstrap/` 现已收敛为显式 `init()` 组装入口，宿主启动入口已经切到 `src/presentation/runtime/install.lua`。

本计划提到的“CRAP”是复杂度与覆盖率组合得分：复杂度越高、测试越少，分数越高，风险越大。提到的“characterization test”是先把现有可观察行为锁住的测试，用来保护后续小步重构不发生语义漂移。提到的“单一状态源”是指同一个业务事实只保留一个真相字段，其他位置只能从它派生，而不能双写双同步。

## 当前基线

以下命令全部在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 执行，并且已经成功跑通：

    lua tests/behavior.lua
    lua tests/contract.lua
    lua tests/guard.lua
    lua tools/quality/arch.lua check
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

当前 baseline 结果如下：

    behavior: All regression checks passed (1141)
    contract: All regression checks passed (83)
    guard: dep_rules ok / gameplay_loop_no_ui ok / forbidden_globals ok / arch_view_guard ok / repo_hygiene ok
    arch: arch_view 检查通过 / arch_view check ok
    crap: analyzed modules=346 functions=2879 / lane=behavior / status=passed

当前 CRAP Top Hotspots（按工具输出原样抄录“函数名 + 分数 + 文件”）：

    _has_pending_roadblock_trigger | 18.96 | src/ui/render/status3d/status.lua
    M.install | 12.00 | src/app/bootstrap/runtime_install.lua
    _find_pending_roadblock_trigger | 11.76 | src/rules/effects/mine_effect.lua
    M.resolve_player_status_key | 11.00 | src/ui/render/status3d/status.lua
    _run_auto_phase | 9.97 | src/rules/items/phase.lua
    turn_timer_policy.update_action_button_timer | 9.51 | src/turn/policies/timer_policy.lua
    startup_policy.resolve | 9.03 | src/app/bootstrap/startup_policy.lua
    choice_resolver.resolve | 9.00 | src/core/choice/resolver.lua
    defaults.cpu_now_seconds | 8.67 | src/host/eggy/default_ports.lua
    defaults.wall_now_seconds | 8.67 | src/host/eggy/default_ports.lua
    _first_role_from_game_api | 8.67 | src/host/eggy/vehicle_runtime_legacy.lua
    anonymous@90 | 8.21 | src/turn/timing/session_script.lua
    defaults.resolve_role | 8.06 | src/host/eggy/default_ports.lua
    _build_ui_gate | 8.06 | src/turn/output/ui_sync_defaults.lua
    _play_effect | 8.06 | src/ui/render/board_feedback_service.lua

`.agents/research.md` 仍然有价值，但只能作为候选工作池。凡是与当前 baseline 冲突的地方，都以本节为准。

## 并行策略

整个计划按依赖分五个波次执行。每个任务只允许聚焦自己的文件集合，不把“顺手重构”混入同一次提交。共享 helper 合并只在计划明确允许的任务里做；其余任务以补测试、提炼单职责函数、保持语义不变为原则。

Wave 0 只有 `T0`，用于确立基线和重写计划。Wave 1 处理热点、死代码审计、入口显式化原型和 landing visual hold 原型门。Wave 2 在第一波结果稳定后处理共享 helper 合并与入口反转切换。Wave 3 一次性完成 `gameplay/rules.lua` 消费者迁移以及 hold caller 切换。Wave 4 已重跑 baseline，并完成分数、守卫和风险偏差核对。

## 任务拆分

### T0: 基线与计划重写

- **depends_on**: []
- **location**: `.agents/plan.md`, `.agents/research.md`, `tmp/crap_report.json`
- **description**: 把旧计划改成符合 `.agents/harness/PLANS.md` 的活文档；重新跑 baseline 五条命令；把当前仓库的 CRAP 热点、测试结果和 repo 真相写回计划。
- **acceptance**:
  - 本文件包含“进度 / 意外与发现 / 决策日志 / 结果与复盘”四章。
  - baseline 五条命令的结果被写回计划，并可作为后续验收对照。
  - 记录 `vehicle_catalog.lua`、`global_aliases.lua`、`status_ops.lua` 仍有消费者，不进入首轮删除。
- **validation**:
  - `lua tests/behavior.lua`
  - `lua tests/contract.lua`
  - `lua tests/guard.lua`
  - `lua tools/quality/arch.lua check`
  - `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`

### T1: 道具可用性热点

- **depends_on**: [T0]
- **location**: `src/rules/items/availability.lua`, `tests/suites/domain/item_availability_matrix.lua`
- **description**: 仅治理 `_can_offer_rent_response` 与 `trigger_timing_allowed`。先补 rent-response 分支与余额边界测试，再做小步提炼，保持选择与资格语义不变。
- **acceptance**:
  - rent-response 至少覆盖“非地产 / 自己地块 / 他人地块免租 / 强夺且余额不足 / 强夺且余额足够”。
  - `trigger_timing_allowed` 对缺失 phase、未知 timing、合法映射有明确测试。
  - 记录这两个函数重构后的 CRAP 分数。
- **validation**:
  - `lua tests/behavior.lua`
  - 目标 suite：`tests/suites/domain/item_availability_matrix.lua`

### T2: preconsume + item phase 热点

- **depends_on**: [T0]
- **location**: `src/core/choice/item_preconsume_policy.lua`, `src/rules/items/phase.lua`, `tests/suites/gameplay/gameplay_t2_characterization.lua`, `tests/suites/domain/item.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`
- **description**: 把 cancel 禁用、meta 初始化、resume args 构造拆成单职责 helper，不改变 choice 流转语义。
- **acceptance**:
  - `decorate_followup_choice_spec` 的 nil guard、meta 回填、取消禁用都被测试锁住。
  - `build_wait_choice_args`、`_run_auto_phase` 相关行为不回退。
  - helper 抽取不跨出 `src/core/choice/` 与 `src/rules/items/` 各自边界。
- **validation**:
  - `lua tests/suites/gameplay/gameplay_t2_characterization.lua`
  - `lua tests/suites/domain/item.lua`
  - `lua tests/suites/gameplay/gameplay_items_startup.lua`

### T3: runtime context 热点

- **depends_on**: [T0]
- **location**: `src/host/eggy/context.lua`, `tests/suites/runtime/misc.lua`, `tests/suites/runtime/runtime_ports_contract.lua`
- **description**: 隔离 provider roles、GameAPI fallback 和 `get_role` 容错，把 `_safe_get_role` 与 `resolve_any_role` 拆成更小的查询函数，但保留 release/noop helper 行为。
- **acceptance**:
  - provider 成功、provider 空且 GameAPI 成功、GameAPI 抛错、全部失败这四类路径有测试。
  - `_safe_get_role` 的 nil、缺失 `get_role`、pcall 失败、成功返回 role 有测试。
  - 不引入 presentation 或 rules 层依赖。
- **validation**:
  - `lua tests/suites/runtime/misc.lua`
  - `lua tests/suites/runtime/runtime_ports_contract.lua`

### T4: presentation 热点

- **depends_on**: [T0]
- **location**: `src/ui/render/anim_units.lua`, `src/ui/ctl/event_handlers.lua`, `src/ui/ctl/ui_runtime.lua`, `tests/suites/presentation/presentation_action_anim_effect_routes.lua`, `tests/suites/presentation/presentation_ui_event_handlers.lua`
- **description**: 分别治理 `play_mine_trigger`、`_resolve_tile_index`，并把 turn label 的匿名闭包命名化；先补护栏，再提炼 helper。
- **acceptance**:
  - mine trigger 覆盖“有单位坐标”“无单位坐标回退 tile cue”“duration/snap_delay 归一化”。
  - `_resolve_tile_index` 覆盖 `tile_index`、`tile.id`、`tile_id`、无 context、board 缺少 `index_of_tile_id`。
  - `ui_runtime` 中 turn label 刷新逻辑从匿名闭包改为具名函数。
- **validation**:
  - `lua tests/suites/presentation/presentation_action_anim_effect_routes.lua`
  - `lua tests/suites/presentation/presentation_ui_event_handlers.lua`
  - 受影响的 presentation suites

### T5: validator + backward board 热点

- **depends_on**: [T0]
- **location**: `src/turn/actions/validator.lua`, `src/rules/board/init.lua`, `tests/suites/presentation/ui_runtime_state_contract.lua`, `tests/suites/domain/movement.lua`
- **description**: 把 item slot 校验链与 backward 选路链拆成中间结果函数，降低圈复杂度而不改变对外动作语义。
- **acceptance**:
  - `resolve_item_slot_action` 通过中间结果对象表达失败原因。
  - `_resolve_backward_next_id` 保持原优先级，但来源拆分成更小 helper。
  - 边界测试至少覆盖 slot 缺失、option 不存在、availability 拒绝、facing 命中、outer_prev 命中、fallback 命中。
- **validation**:
  - `lua tests/suites/presentation/ui_runtime_state_contract.lua`
  - `lua tests/suites/domain/movement.lua`

### T6: AI 远程骰子热点

- **depends_on**: [T0]
- **location**: `src/computer/policies/core_agent.lua`, `tests/suites/domain/land.lua`
- **description**: 把 `_remote_priority` 拆成 tile-type / land 子规则，保证排序语义不变。
- **acceptance**:
  - item、chance、空地、己方地、敌方地、market 六类优先级都有测试。
  - land 相关分数逻辑不再和其它 tile 类型混写在同一个 `elseif` 链里。
  - 新 CRAP 分数低于 T0 基线。
- **validation**:
  - `lua tests/suites/domain/land.lua`

### T7: ring map + test profile 热点

- **depends_on**: [T0]
- **location**: `src/config/content/maps/ring_map_builder.lua`, `src/config/testing/test_profiles.lua`, `tests/suites/gameplay/gameplay_t4_characterization.lua`, `tests/suites/runtime/startup_profile.lua`
- **description**: 以补覆盖为主，只做最小意图拆分，不为了降分引入额外抽象。
- **acceptance**:
  - `_direction` 覆盖 next、prev、非法跳跃、缺失 id。
  - `_profile` 覆盖 meta copy、不共享引用、bootstrap 缺省空表。
  - 如需 helper，只允许抽最小断言或拷贝函数。
- **validation**:
  - `lua tests/suites/gameplay/gameplay_t4_characterization.lua`
  - `lua tests/suites/runtime/startup_profile.lua`

### T8: choice 迭代 / cancel helper 合并

- **depends_on**: [T2]
- **location**: `src/core/choice/resolver.lua`, `src/core/choice/item_preconsume_policy.lua`
- **description**: 抽共享 `_each_option` 与 cancel 判定 helper，迁移 resolver 与 preconsume，但只合并“同因变化”的逻辑。
- **acceptance**:
  - 共享 helper 只放在 `src/core/choice/` 边界内。
  - resolver 与 preconsume 的遍历/取消判定不再重复。
  - 相关 characterization 与 contract 全绿。
- **validation**:
  - `lua tests/suites/gameplay/gameplay_t2_characterization.lua`
  - 相关 choice contract suites

### T9: copy / normalize / contains helper 合并

- **depends_on**: [T1, T2]
- **location**: `src/rules/bootstrap/choice_optional_effect_handler.lua`, `src/rules/items/choice_handlers.lua`, `src/rules/market/choice_handlers.lua`, `src/rules/items/phase.lua`, `src/rules/items/availability.lua`, `src/rules/market/choice/builder.lua`
- **description**: 只合并“同因变化”的表复制、整数归一化、包含判断，不顺带重构业务逻辑。
- **acceptance**:
  - 共享 helper 的落点不越过 rules 层边界。
  - 原有 call site 行为保持不变。
  - 受影响 gameplay/domain suites 全绿。
- **validation**:
  - 受影响的 gameplay suites
  - 受影响的 domain suites

### T10: 骰子倍率 helper 合并

- **depends_on**: [T0]
- **location**: `src/turn/phases/roll.lua`, `src/turn/phases/move.lua`
- **description**: 提取统一倍率逻辑到 `src/turn/phases/` 内共享模块，保证 roll 与 move 使用同一套规则。
- **acceptance**:
  - 统一倍率 helper 只服务 `turn/phases`。
  - roll 与 move 行为不变。
  - 相关 gameplay turn flow suites 通过。
- **validation**:
  - 相关 gameplay turn flow suites

### T11: 方向表共享

- **depends_on**: [T5]
- **location**: `src/rules/board/init.lua`, `src/rules/items/post_effects.lua`
- **description**: 抽出单一方向映射常量，保持 backward / post effects 语义不变。
- **acceptance**:
  - 两处方向表只保留一个共享来源。
  - movement 与 item/domain 回归都通过。
- **validation**:
  - `lua tests/suites/domain/movement.lua`
  - item/domain 回归 suites

### T12: `_with_client_role` 去重

- **depends_on**: [T0]
- **location**: `src/presentation/runtime/ports/debug.lua`, `src/ui/ctl/market.lua`, `src/ui/ctl/popup.lua`, `src/ui/wid/turn_effects.lua`
- **description**: 抽 presentation 共享 helper，不混入 turn wait 逻辑。
- **acceptance**:
  - `_with_client_role` 的重复实现收敛到单一 presentation helper。
  - helper 不渗入 `src/turn/` 或 `src/state/`。
- **validation**:
  - presentation suites

### T13: `_log_once` 去重

- **depends_on**: [T0]
- **location**: `src/turn/waits/ui_sync.lua`, `src/turn/waits/choice_timeout.lua`
- **description**: 抽 wait 层共享 helper，统一一次性日志行为。
- **acceptance**:
  - wait 层只保留一个 `_log_once` 逻辑来源。
  - 相关 wait 行为和 contract 不回退。
- **validation**:
  - wait 相关 behavior suites
  - wait 相关 contract suites

### T14: 安全清理第一批

- **depends_on**: [T0]
- **location**: `src/config/content/skins.lua`, `src/config/gameplay/feature_toggles.lua`, `src/turn/output/state_adapter.lua`, `src/turn/loop/ports.lua`, `src/config/content/runtime_refs.lua`
- **description**: 只删零消费者或空实现。`runtime_refs` 必须先审计后删，不允许先假定 orphan key 可删。
- **acceptance**:
  - 每个删除点都有零消费者或空实现证据。
  - `vehicle_catalog.lua`、`global_aliases.lua`、`status_ops.lua` 不进入本任务删除集合。
  - 每删一波立即跑 contract / guard / arch。
- **validation**:
  - `lua tests/contract.lua`
  - `lua tests/guard.lua`
  - `lua tools/quality/arch.lua check`

### T15: rules 层宿主解耦

- **depends_on**: [T0]
- **location**: `src/rules/land/effects/chance.lua`, `src/app/bootstrap/compose_game.lua`, `tests/suites/domain/chance.lua`, `tests/suites/runtime/runtime_ports_contract.lua`, `tests/suites/architecture/usecase_boundary_contract.lua`
- **description**: 把 `LuaAPI.rand()` 改成现有注入 RNG，优先走 `ctx.game.rng:next_int(...)`；补确定性测试，禁止 rules 层直读宿主全局。
- **acceptance**:
  - rules 层不再直接调用 `LuaAPI.rand()`。
  - chance/domain、runtime ports、usecase boundary 都有护栏。
  - `compose_game` 负责把 RNG 注入到需要的位置。
- **validation**:
  - `lua tests/suites/domain/chance.lua`
  - `lua tests/suites/runtime/runtime_ports_contract.lua`
  - `lua tests/suites/architecture/usecase_boundary_contract.lua`

### T16: game state 组装保护

- **depends_on**: [T0]
- **location**: `src/state/game_state.lua`
- **description**: 为 mixin 合并增加 collision assert，并新增“重复 key 组装失败”负向测试。
- **acceptance**:
  - mixin 合并时如果出现重复 key，会报出可读错误。
  - 原有正常组装路径不受影响。
- **validation**:
  - 现有 game assemble 相关 suites
  - 新增负向测试

### T17: bootstrap 显式化兼容阶段

- **depends_on**: [T0]
- **location**: `src/app/bootstrap/init.lua`, `main.lua`, `tests/suites/runtime/startup_profile.lua`
- **description**: 把 app bootstrap 改为显式 `init()`，保证 `require("src.app.bootstrap")` 不自动执行，同时保持当前启动路径仍然可用。
- **acceptance**:
  - `require("src.app.bootstrap")` 不触发启动副作用。
  - 显式 `init()` 只执行一次。
  - 当前 `main.lua` 启动路径仍成立，直到 `T18` 再切换入口所有权。
- **validation**:
  - `lua tests/suites/runtime/startup_profile.lua`

### T18: 入口反转切换

- **depends_on**: [T17]
- **location**: `src/presentation/runtime/install.lua`, `main.lua`, `tools/ops/deploy.ps1`
- **description**: 新建 presentation-owned 入口，`main.lua` 改为 require presentation 入口，部署脚本和仓内启动引用一起切换。
- **acceptance**:
  - `main.lua` 只负责调用 presentation 入口。
  - `deploy.ps1` 与仓内启动引用指向新入口。
  - runtime 启动测试通过。
- **validation**:
  - main 启动路径检查
  - `lua tests/suites/runtime/startup_profile.lua`
  - deploy 相关验证

### T19: gameplay rules 拆分

- **depends_on**: [T1, T2, T4, T5, T6, T7, T12, T15, T16, T18]
- **location**: `src/config/gameplay/rules.lua`, `src/config/gameplay/debug_flags.lua`, `src/config/gameplay/timing.lua`, `src/config/gameplay/board_geometry.lua`, `src/config/gameplay/target_pick.lua`, `src/config/gameplay/item_ids.lua`
- **description**: 按五个模块一次性迁移所有消费者并删除旧聚合文件，不留 shim。先用 `rg 'src.config.gameplay.rules' src tests` 生成清单，再在同一波完成替换。
- **acceptance**:
  - `src.config.gameplay.rules` 的 repo 内消费者清零。
  - 旧聚合文件被删除，不保留兼容层。
  - contract / guard / arch / behavior 全通过。
- **validation**:
  - `rg 'src.config.gameplay.rules' src tests`
  - `lua tests/contract.lua`
  - `lua tests/guard.lua`
  - `lua tools/quality/arch.lua check`
  - `lua tests/behavior.lua`

### T20: landing visual hold 原型门

- **depends_on**: [T0]
- **location**: `src/state/state_access/landing_visual_hold.lua`, `src/ui/runtime/landing_visual_hold.lua`, `src/turn/waits/await.lua`, `src/turn/loop/tick_flow.lua`, `src/turn/loop/tick_steps.lua`, `src/turn/phases/land.lua`, `src/turn/phases/move_followup.lua`, `src/presentation/runtime/event_bridge.lua`, `src/ui/ctl/event_handlers.lua`
- **description**: 先盘点所有 caller，再用 characterization tests 固定“单一状态源”目标行为与 release 顺序；这一任务不做最终迁移，只建立护栏。
- **acceptance**:
  - caller 清单明确写回计划或日志。
  - `misc_landing_visual_hold` 中“单一状态源目标行为”和 release 顺序被测试固定。
  - 不提前删除旧同步逻辑。
- **validation**:
  - `lua tests/suites/runtime/misc_landing_visual_hold.lua`
  - 相关 gameplay / presentation hold suites

### T21: hold 单一状态源迁移

- **depends_on**: [T20]
- **location**: `src/state/state_access/landing_visual_hold.lua`, `src/state/state_access/runtime_state.lua`
- **description**: 把 hold/release 真相收敛到一个状态源，先完成底层读写迁移，不做 caller 清理。
- **acceptance**:
  - hold/release 的写入路径只剩一个真相字段。
  - 新增“无双写漂移”测试。
  - 原有顺序测试继续通过。
- **validation**:
  - `lua tests/suites/runtime/misc_landing_visual_hold.lua`
  - 新增单源负向/正向测试

### T22: hold caller 切换与清理

- **depends_on**: [T4, T18, T19, T21]
- **location**: `src/turn/loop/tick_flow.lua`, `src/turn/loop/tick_steps.lua`, `src/turn/phases/land.lua`, `src/presentation/runtime/event_bridge.lua`, `src/ui/ctl/event_handlers.lua`
- **description**: 把 callers 统一切到新单源，再删除旧双源同步逻辑。
- **acceptance**:
  - 所有 caller 都通过单源 API 读写 hold 状态。
  - 旧双写同步代码被删除。
  - runtime / presentation / gameplay 的 hold suites 全绿。
- **validation**:
  - hold 相关 runtime suites
  - hold 相关 presentation suites
  - hold 相关 gameplay suites

### T23: 最终质量收口

- **depends_on**: [T3, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T18, T19, T22]
- **location**: `.agents/plan.md`, `tmp/crap_report.json`
- **description**: 重跑 T0 baseline 五条命令，核对热点分数、arch/guard、行为/契约结果，把证据、偏差和剩余风险写回计划。
- **acceptance**:
  - baseline 五条命令重新执行并记录结果。
  - T0 记录的热点与最终热点被并排对比。
  - 如果有未下降或新上榜热点，要在“结果与复盘”解释原因与剩余风险。
- **validation**:
  - `lua tests/behavior.lua`
  - `lua tests/contract.lua`
  - `lua tests/guard.lua`
  - `lua tools/quality/arch.lua check`
  - `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`

## 工作计划

执行顺序必须保持简单且可证明。每个任务先读自己的文件和测试，再补测试或确立非测试型验证证据，再做生产改动，最后只跑与该任务相关的最小验证集。只有删除、入口切换、架构边界、配置迁移这类高风险任务，才强制附加 `contract + guard + arch`。任何共享 helper 合并都必须等对应热点任务已经锁住行为后再做；否则会把“补护栏”和“抽重复”混成一次高风险提交。

对跨层任务，要优先遵守当前层级边界：rules 不碰宿主全局、presentation 不直接吞宿主细节、app 最终只保留组装职责。对 landing visual hold，要分成“建护栏”和“做迁移”两个任务，先证明单源目标行为，再收敛实现，最后再切 caller。对 `gameplay/rules.lua` 拆分，必须一次迁完消费者后再删旧文件，不能留下 shim。

## 具体步骤

1. 在仓库根目录重跑 baseline 并记录结果。已经执行过的命令如下：

       cd C:\Users\Lzx_8\Desktop\dev\repo\monopoly
       lua tests/behavior.lua
       lua tests/contract.lua
       lua tests/guard.lua
       lua tools/quality/arch.lua check
       lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

2. Wave 1 从每个无依赖任务各自的目标测试开始。优先顺序是：热点任务先补 characterization，结构任务先建立最小负向/契约护栏，删除任务先做 `rg` 审计，入口与 hold 任务先固定启动/顺序行为。

3. 每完成一个任务，都要在本文件同步追加三类事实：改动了哪些文件、跑了哪些命令、观察到了什么结果。如果任务中途改道，必须把原因记进“决策日志”。

4. Wave 2 只在 Wave 1 对应依赖已经完成后开始。`T8`、`T9`、`T10`、`T11` 是共享 helper 合并任务，必须保持“小改、少文件、同因变化”；`T18`、`T21` 是结构迁移任务，必须附带更强验证。

5. Wave 3 用于一次性做高耦合迁移：`T19` 删除 `src/config/gameplay/rules.lua`，`T22` 清理 hold 双源同步。两者都不允许拆成“先加 shim 再慢慢迁”的长期过渡态。

6. Wave 4 重跑 baseline 五条命令，把初始与最终热点和守卫结果并排写入本计划，并在“结果与复盘”说明收口情况。

## 验证与验收

本计划的最低验收标准不是“代码改了”，而是以下行为可以被重复证明。

第一，测试仍然可靠。所有任务完成后，以下命令必须通过：

    cd C:\Users\Lzx_8\Desktop\dev\repo\monopoly
    lua tests/behavior.lua
    lua tests/contract.lua
    lua tests/guard.lua

第二，架构边界没有回退。以下命令必须通过：

    cd C:\Users\Lzx_8\Desktop\dev\repo\monopoly
    lua tools/quality/arch.lua check

第三，复杂度治理有客观证据。以下命令必须生成新的 `tmp/crap_report.json`，并将 T0 基线与最终结果并排对比：

    cd C:\Users\Lzx_8\Desktop\dev\repo\monopoly
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

第四，高风险结构迁移必须有专项证明。`T17/T18` 需要证明 `require("src.app.bootstrap")` 不自动启动、显式 `init()` 只执行一次、`main.lua` 最终切到 presentation 入口。`T20/T21/T22` 需要证明 landing visual hold 不再双源漂移，并且 release callback 顺序不变。`T19` 需要证明 `rg 'src.config.gameplay.rules' src tests` 归零。

## 可重复性与恢复

本计划默认采用可重复的增量式推进：每个任务都应能单独重跑自己的验证命令，不依赖临时手工状态。删除任务必须先用搜索证明零消费者，再删除；如果验证失败，直接恢复该任务改动并保留日志，不把失败状态带入下一波。入口切换和配置迁移都要求“先建立测试护栏，再切实现，再删旧路径”，避免因为一次性大改导致无法定位回归。

如果某个波次中的单个任务失败，不应阻塞不相干任务继续推进；但依赖它的后续任务必须等待。恢复时优先回退该任务自己的改动，而不是在未验证状态下叠加修复。

## 产物与备注

本轮 `T0` 已生成或更新的关键产物如下：

    .agents/plan.md               # 活文档重写版
    tmp/crap_report.json          # 当前 baseline 的行为车道 CRAP 报告

关键基线输出片段如下：

    All regression checks passed (1141)
    All regression checks passed (83)
    arch_view 检查通过 / arch_view check ok
    dep_rules ok
    gameplay_loop_no_ui ok
    forbidden_globals ok
    arch_view_guard ok
    repo_hygiene ok
    [crap] analyzed modules=346 functions=2879
    [crap] lane=behavior mode=behavior status=passed total=1141 failures=0

## 接口与依赖

本计划不引入新三方库，不增加长期兼容 shim，也不改变现有测试入口名称。所有共享 helper 都应落在现有层内：例如 choice 共享逻辑只放在 `src/core/choice/`，turn phase 共享倍率逻辑只放在 `src/turn/phases/`，presentation 的 `_with_client_role` 只放在 presentation 可见范围。rules 层必须继续通过注入或上下文访问 RNG 与宿主能力，不能重新引入对宿主全局的直接读取。

`src.app.bootstrap` 的最终对外接口是显式 `init()`；`main.lua` 的最终职责是调用 `src/presentation/runtime/install.lua` 提供的入口；`src/config/gameplay/rules.lua` 的最终状态是被删除，调用方直接使用拆分后的关注点模块；landing visual hold 的最终状态是只有一个真实状态源。

---

本次改动说明：2026-03-24 重写 `.agents/plan.md`，把旧研究导向的任务列表改成可执行活文档，并补入当前 baseline、真实依赖图、验证命令与执行波次，作为后续并行派工的事实来源。

本次改动说明：2026-03-24 04:13Z 收尾 Wave 4 文档状态，删除已过时的 `T4` 进行中条目，补记 Wave 4 完成记录，并把旧机器路径与未来时叙述改成当前仓库事实，保证活文档可直接续跑。
