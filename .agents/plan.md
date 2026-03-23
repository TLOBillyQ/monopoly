# 路障地雷同格渲染链修复计划

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。本文件遵循 `.agents/harness/PLANS.md` 维护，面向第一次接触本仓库的新手。

## 目的 / 全局视角

当前用户可见问题是：同一地块同时触发路障和地雷时，路障“无法移动”3D HUD 看不到，地雷爆炸也看不到或几乎看不到，视觉上像被“送医院状态”直接覆盖。修复后，玩家应先看到路障状态，再进入送医状态；地雷爆炸应先可见，再执行送医院位移。可观察证明是：相关行为测试通过，且新增测试能稳定复现“先路障后医院、先爆炸后送医”的顺序。

## 进度

- [x] (2026-03-23 22:34 CST) 完成根因定位，确认是 status3d 优先级覆盖 + mine_trigger 同帧 snap 两个独立问题。
- [x] (2026-03-23 22:43 CST) 按 PLANS 标准重写 `.agents/plan.md`，替换掉与本任务无关的旧计划。
- [x] (2026-03-23 22:52 CST) 实现 status3d 在路障触发动画进行中优先显示路障状态，并新增 `_test_status3d_roadblock_anim_pending_overrides_hospital_pending`。
- [x] (2026-03-23 22:56 CST) 实现 mine_trigger 延迟 snap（默认 0.6s，可配置）并新增 `_test_play_mine_trigger_delays_snap_when_schedule_available`。
- [x] (2026-03-23 23:00 CST) 完成目标测试与回归：2 个目标 presentation suite、`gameplay_obstacle_chain_order`、`behavior`、`contract` 全绿。
- [x] (2026-03-23 23:02 CST) 回写计划文档“结果与复盘”“产物与备注”并完成收尾。
- [x] (2026-03-23 23:10 CST) 代码审查修复：将 play_mine_trigger fallback 路径的调用顺序恢复为 prepare→feedback→clear→snap，与原始代码一致。scheduled 路径保持 feedback→clear→schedule(prepare+snap)。全量回归通过。

## 意外与发现

- 观察：`status3d` 不是队列模型，而是单槽优先级替换模型，`hospital` 优先级高于 `roadblock`。
  证据：`src/ui/render/status3d/specs.lua` 中 `status_priority = { "hospital", "mountain", "roadblock", ... }`。
- 观察：`mine_effect.apply()` 在地雷动作动画前就写入 `pending_location_effect = "hospital"`，导致 status3d 很早就能解析到 hospital。
  证据：`src/rules/effects/mine_effect.lua:116`。
- 观察：`units.play_mine_trigger()` 先播爆炸 cue，随后同次调用内立即 `snap_player_to_index()`，没有给“先看爆炸”预留位移延迟。
  证据：`src/ui/render/anim_units.lua:79-93`。
- 观察：`presentation_action_anim_effect_routes` 新增延迟 snap 用例初次失败，不是实现错误，而是测试把 `scheduled_fn()` 放到 patch 作用域外，导致真实 `move_anim.snap_player_to_index` 被调用并触发 `missing tile: 2`。
  证据：失败栈 `src/ui/render/move_anim.lua:382: missing tile: 2`；将 `scheduled_fn()` 移入 `_with_patches` 作用域后通过。

- 观察：代码审查发现 fallback 路径（无 scheduler）中 `prepare_player_for_snap` 调用顺序被意外改变，从原始的 prepare→feedback→clear→snap 变成了 feedback→clear→prepare→snap。
  证据：git diff 显示原始代码第一行是 `prepare_player_for_snap`，而新代码把它放入了 `run_snap()` 函数中，在 feedback 和 clear 之后才调用。已通过拆分两条路径修复。

## 决策日志

- 决策：不改动 obstacle chain 的核心状态机顺序（roadblock -> mine -> move_followup），只修复展示层时序。
  理由：现有 `tests/suites/gameplay/gameplay_obstacle_chain_order.lua` 已锁定业务顺序，改状态机会引入更大回归面。
  日期/作者：2026-03-23 / Codex。
- 决策：status3d 通过“检测路障触发动画是否仍在 action_anim 槽/队列”来临时提升 roadblock 显示优先，不删除 hospital pending 语义。
  理由：最小改动可覆盖用户问题，同时保留已有“pending hospital 可见”能力。
  日期/作者：2026-03-23 / Codex。
- 决策：mine_trigger 增加可配置的延迟 snap（默认 0.6s），通过 `opts.schedule` 调度位移。
  理由：保持现有动作动画框架不变，最小侵入实现“先爆炸后送医”的视觉节奏。
  日期/作者：2026-03-23 / Codex。
- 决策：保留 `play_mine_trigger` 无 `schedule` 时的即时 snap 回退，并保持返回值兼容（回退路径仍按实际 snap delay 与 minimum duration 归一化）。
  理由：避免影响没有 runtime scheduler 注入的现有测试与运行路径，降低兼容风险。
  日期/作者：2026-03-23 / Codex。

## 结果与复盘

本任务已完成并通过回归。改动后，status3d 在“同玩家本回合路障触发且 roadblock_trigger 动画仍在槽/队列中”时会优先显示 `roadblock`，不会被 `pending_location_effect = hospital` 抢占。与此同时，`mine_trigger` 渲染改为“立即爆炸反馈 + 清除地雷 overlay，延迟执行 snap 送医”，默认延迟 0.6 秒，可由规则配置覆盖。

用户可见层面对应到两个效果：

第一，路障“无法移动”3D HUD 在链式触发窗口中可见，不再被医院状态立刻覆盖。证明来自新增 status3d 用例 `_test_status3d_roadblock_anim_pending_overrides_hospital_pending` 与原有 status3d 组回归全绿。

第二，地雷爆炸与送医不再同帧发生，爆炸有独立展示窗口。证明来自新增渲染用例 `_test_play_mine_trigger_delays_snap_when_schedule_available`，并且 `gameplay_obstacle_chain_order` 继续全绿，说明业务链顺序未被破坏。

最终回归结果：目标 presentation suites 34/34 通过，`gameplay_obstacle_chain_order` 4/4 通过，`behavior` 1141 通过 0 失败，`contract` 83 通过 0 失败。当前无已知回归缺口。

## 背景与导读

本任务涉及三个直接模块和两个测试簇。`src/ui/render/status3d/status.lua` 负责为每个玩家解析当前应显示的 3D 状态层（例如 hospital、roadblock）。`src/rules/effects/mine_effect.lua` 负责地雷触发后的状态写入与动作动画入队。`src/ui/render/anim_units.lua` 负责动作动画真实渲染，包括地雷爆炸 cue、障碍物 overlay 清理、角色 snap 位移。测试侧，`tests/suites/presentation/_presentation_action_status_status3d_and_panel_cases.lua` 负责 status3d 行为验证，`tests/suites/presentation/presentation_action_anim_effect_routes.lua` 负责动作动画路由与 mine_trigger 细节验证。

“pending_location_effect”在本仓库中的含义是“位置效果已决定，但尚未在 move_followup 中落地到 stay_turns/费用结算”。“snap”是瞬移式位置同步，不走逐步移动动画。

## 工作计划

先修 status3d：在 `resolve_player_status_key()` 内新增一个局部 helper，识别“该玩家是否仍有 roadblock_trigger 动画待播或正在播”。若为真，优先返回 `roadblock`，避免 hospital pending 抢占显示。该改动只影响显示决策，不改 turn state。

再修 mine_trigger 渲染：在 `anim_units.play_mine_trigger()` 中引入延迟位移窗口。爆炸 cue 与地雷 overlay 清理保持立即执行，角色 snap 改为在 delay 后通过调度器执行。若没有调度器（单元测试或极简运行态），回退到即时 snap，保证兼容。

最后补测试并回归：新增 status3d 用例覆盖“hospital pending + roadblock anim pending 时必须显示 roadblock”；新增 mine_trigger 用例覆盖“存在 schedule 时 snap 被延迟执行且返回时长不低于延迟阈值”。完成后跑目标套件和 behavior 车道。

## 具体步骤

所有命令在工作目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。

先实现并验证 status3d：

    lua tests/behavior.lua

再实现并验证 mine_trigger 延迟 snap：

    lua tests/behavior.lua

在最终验收时至少执行：

    lua tests/behavior.lua

如果全量 behavior 耗时过长且需要快速定位，可先运行目标套件（通过 Lua 直接加载 suite + TestHarness），确认局部通过后再跑全量。

## 验证与验收

验收以“可观察行为”定义，而不是代码形态。status3d 的验收标准是：当玩家处于 hospital pending 且同一玩家还有 roadblock_trigger 动画待播/在播时，显示层应为 `roadblock`，不是 `hospital`。mine_trigger 的验收标准是：爆炸 cue 先触发，snap 通过调度器在延迟后执行；函数返回值不早于该延迟。最后以 `lua tests/behavior.lua` 绿灯作为回归证明。

## 可重复性与恢复

本计划步骤可重复执行。若某次修改导致失败，优先保留新增测试，仅回退本任务涉及文件中的实现改动，不删除测试护栏。若调度器缺失导致兼容问题，`play_mine_trigger` 保留“无 schedule 时即时 snap”的兜底路径，确保旧运行路径可恢复。

## 产物与备注

关键证据如下：

    targeted suites: All regression checks passed (34)
    obstacle chain: All regression checks passed (4)
    behavior lane: All regression checks passed (1141)
    contract lane: All regression checks passed (83)

## 接口与依赖

不新增第三方依赖，不新增测试车道，不改公开导出模块名。需保持签名不变：`status.resolve_player_status_key(game, player)` 与 `units.play_mine_trigger(state, anim, duration, opts)`。允许新增同文件 `local function`。`opts.schedule` 继续沿用 action_anim 现有传参约定，不引入新的跨层依赖。

2026-03-23 22:43 CST：本次更新将旧的 CRAP 治理计划整体替换为“路障地雷同格渲染链修复计划”，原因是用户任务已切换，且 PLANS 要求计划必须与当前实施目标一致并可独立执行。
2026-03-23 23:02 CST：本次更新回写了实现完成态（status3d 路障动画优先 + mine_trigger 延迟 snap）、新增测试与回归证据，并记录一次测试作用域导致的误报修复，原因是让计划保持可重启、可审计、可验证。
