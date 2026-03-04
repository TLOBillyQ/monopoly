# 位置选择屏接入场景准星射线点选


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护；任何实施或讨论都要先对照该规范检查章节完整性与可验证性。

## 目的 / 全局视角


这项改动要让玩家在 `roadblock_target` / `demolish_target` 的位置选择阶段，先通过准星射线看到“预览目标”，再通过场景点击把目标“锁定”，最后点击 `位置_确认按钮` 才提交；若锁定后发现选错，可点击 `位置_取消按钮` 解锁并回到 hover 重选。用户可见收益是防误选：鼠标移动或镜头变化不会在确认瞬间篡改最终目标，同时允许安全重选。

改动完成后，玩家能看到每个候选地块上方生成 `可选择地块` 标记，`选择地块箭头` 跟随当前预览；点击候选后进入锁定态，确认与取消按钮变为可用；点击取消会解锁并恢复射线预览，点击确认会提交锁定值。是否生效通过自动化测试和实机场景日志共同验证。

## 进度


- [x] (2026-03-04 02:05Z) [M0 计划文档规范化] 读取 `.agents/harness/PLANS.md`，提取可执行计划硬性结构要求与写作约束。
- [x] (2026-03-04 02:10Z) [M0 计划文档规范化] 读取 `PLAN.md`，整理目标、接口变更、测试与验收信息。
- [x] (2026-03-04 02:20Z) [M0 计划文档规范化] 重写并写入 `.agents/plan.md`，补齐活文档必需章节与可执行步骤。
- [x] (2026-03-04 02:21Z) [M0 计划文档规范化] 删除旧文件 `PLAN.md`，避免双计划入口并存。
- [x] (2026-03-04 02:21Z) [M0 计划文档规范化] 读取 `Data/UIManagerNodes.lua`，确认 `位置_取消按钮` 已存在于 `位置选择屏`，后续计划改为用它执行 unlock。
- [ ] (2026-03-04 10:21+08:00) [M1 端口与契约铺设] 已完成：无。剩余：`step_target_selection` 端口定义、默认 no-op、tick 接线、`target` screen 的 `confirm/cancel` 节点映射、confirm/unlock intent 绑定、UI bootstrap 点击节点注册。
- [ ] (2026-03-04 10:10+08:00) [M2 射线封装与场景点选锁定] 已完成：无。剩余：`host_runtime/Raycast.lua`、`HostRuntimePort` 封装暴露、场景点选回调、`GameplayRules` 射线参数与 override hook。
- [ ] (2026-03-04 10:21+08:00) [M3 TargetChoiceEffects 运行时行为] 已完成：无。剩余：`enter/step/on_scene_pick/on_unlock/leave`、候选标记 `+1.6`、箭头跟随、锁定后暂停射线、取消解锁后恢复射线、离场清理。
- [ ] (2026-03-04 10:21+08:00) [M4 自动化测试与回归验收] 已完成：无。剩余：10 个 `presentation_ui` 用例（含 cancel-unlock）、日志断言补充、实机验收记录与失败场景回归证明。

## 意外与发现


- 观察：原 `PLAN.md` 信息充足，但不满足 `.agents/harness/PLANS.md` 对活文档章节的强制要求。
  证据：原文缺少“进度 / 意外与发现 / 决策日志 / 结果与复盘”四个维护型章节。

- 观察：原文中的路径大量使用绝对 Windows 路径，不适合作为当前仓库新手执行指引。
  证据：当前工作树位于 `/Users/gangan/.codex/worktrees/08ad/monopoly`，计划应统一为仓库相对路径。

- 观察：`Data/UIManagerNodes.lua` 已包含 `位置_取消按钮`（`EButton`），可直接作为 unlock 输入，不需要新增 UI 资源节点。
  证据：`Data/UIManagerNodes.lua` 中存在条目 `{"位置_取消按钮", "EButton"}`。

## 决策日志


- 决策：将原计划重构为单一可执行计划文档，文件位置固定在 `.agents/plan.md`。
  理由：仓库约束要求该文件始终符合规范，分散在多个计划文件会导致实施入口不唯一。
  日期/作者：2026-03-04 / Codex

- 决策：保留“射线仅预览、场景点选锁定、确认按钮提交锁定值”的交互主线，不改业务意图。
  理由：这是用户已确认的核心行为约束，也是防误选问题的关键。
  日期/作者：2026-03-04 / Codex

- 决策：数值解析规则写入执行细则，新增实现一律使用 `NumberUtils`，禁止 `tonumber` 与 `type(x)=="number"`。
  理由：仓库 AGENTS 约束已明确此规则，必须前置到计划里避免实施偏差。
  日期/作者：2026-03-04 / Codex

- 决策：将 `位置_取消按钮` 定义为“解锁重选”而非“关闭面板”，仅在已锁定时生效。
  理由：用户明确要求“用取消按钮 unlock”；把取消语义绑定到解锁可覆盖“选错重选”核心用例，同时保持面板停留在当前选择流程。
  日期/作者：2026-03-04 / Codex

## 结果与复盘


本次交付完成了“计划文档规范化”与“旧计划文件退役”，尚未执行代码实现。结果是下一位实施者可只读 `.agents/plan.md` 就理解目标、范围、接口、步骤和验证方式。

仍未完成的部分是代码改造与测试落地；进入实施阶段后必须持续更新本节，记录每个里程碑是否达成了可观察行为。

## 背景与导读


本任务涉及“回合流程层、UI 同步层、运行时 Host 封装层、场景渲染层、目标选择 UI 事件层、测试层”六个区域。它们关系如下：

回合流程每帧调用 `ui_sync` 端口；`ui_sync` 再驱动目标选择运行时逻辑；运行时逻辑通过 HostRuntimePort 获取射线命中与场景点击；渲染层负责候选标记和箭头显隐；UI 层负责确认/取消按钮与意图分发；测试层验证“预览、锁定、解锁、提交、清理”链路。

关键术语定义：

“预览（hover）”指准星射线命中候选地块后，仅更新视觉指示，不写最终提交值。

“锁定（lock）”指玩家在场景里点击候选地块后，记录 `locked_option_id`；此后暂停射线驱动，避免目标漂移。

“解锁（unlock）”指点击 `位置_取消按钮` 后清空 `locked_option_id`，恢复射线预览，允许重新 hover 与重新点选锁定。

“提交（confirm submit）”指点击 `位置_确认按钮` 后发送 `choice_select`，其 `option_id` 必须来自 `locked_option_id`。

候选数据来源是 `pending choice options`；数值转换统一使用 `NumberUtils`。

## 里程碑


### 里程碑 1：端口与契约铺设


范围是打通每帧调用入口和 UI 契约，不引入复杂渲染逻辑。完成后系统具备 `step_target_selection` 调用链，`target` screen 拥有 `confirm = "位置_确认按钮"` 与 `cancel = "位置_取消按钮"` 并能分别触发确认与解锁意图。

工作内容：

- 在 `src/game/flow/turn/GameplayLoopPorts.lua` 增加 `ui_sync.step_target_selection(game, state, dt)` 端口定义。
- 在 `src/game/flow/turn/GameplayLoopUISyncDefaults.lua` 增加同名 no-op 默认实现。
- 在 `src/game/flow/turn/GameplayLoopTickSteps.lua` 每 tick 调用该端口。
- 在 `src/presentation/api/presentation_ports/UISyncPorts.lua` 实现转发入口。
- 在 `src/presentation/canvas/target_choice/nodes.lua` 为 `target` screen 增加确认/取消按钮映射。
- 在 `src/presentation/canvas/target_choice/intents.lua` 绑定 `位置_确认按钮` 到确认 intent，并绑定 `位置_取消按钮` 到 unlock intent。
- 在 `src/presentation/api/ui_view_service/core.lua` 增加按钮状态同步：未锁定时禁用确认并禁用（或隐藏）取消，已锁定时启用确认与取消。
- 在 `src/app/bootstrap/UIBootstrap.lua` 补齐 `位置_确认按钮` 与 `位置_取消按钮` 的 required click nodes。

验收：运行相关 UI 测试后，确认/取消按钮都可触发对应意图、按钮状态与锁定状态一致、tick 链路无报错，且旧调用方不受影响。

### 里程碑 2：射线封装与场景点选锁定


范围是封装 HostRuntime 射线入口和场景点选输入，确保业务层不直连底层 `GameAPI`。完成后可通过统一接口取得命中单位并接收点选锁定事件。

工作内容：

- 新建 `src/presentation/api/host_runtime/Raycast.lua`，提供：
  - `build_camera_ray(role, cfg)`
  - `pick_first_hit_unit(start_pos, end_pos, cfg)`
  - `get_unit_id(unit)`
  - `resolve_hit_position(...)`
- 在 `src/presentation/api/HostRuntimePort.lua` 暴露上述能力与场景点选注册接口。
- 在配置 `src/core/config/GameplayRules.lua` 增加 target-pick 射线参数：`eye_offset_y`、`ray_distance`、`nearest_tile_max_distance` 及 override hook。

验收：模拟或实机调用时，业务层仅依赖 HostRuntimePort 即可获得命中信息；底层 API 缺失时不中断流程并打 warn_once 日志。

### 里程碑 3：TargetChoiceEffects 运行时行为落地


范围是实现“进入/逐帧/点选锁定/取消解锁/退出”全流程。完成后玩家可看到候选标记与箭头，点选后可确认提交且不被后续射线改写；若选错可取消解锁并重选。

工作内容：

- 新建 `src/presentation/render/TargetChoiceEffects.lua`，实现 `enter`、`step`、`on_scene_pick`、`on_unlock`、`leave`。
- `enter`：
  - 仅对 `roadblock_target` / `demolish_target` 生效。
  - 用 `NumberUtils` 解析候选 option，初始化 `hover_option_id` 与 `locked_option_id`。
  - 按候选数量生成 `可选择地块` 标记，位置为候选 tile 的 `y + 1.6`。
  - `选择地块箭头` 保持单实例并对准当前预览。
  - 未锁定前禁用 `位置_确认按钮`。
- `step`：
  - 未锁定时执行射线命中更新 hover；锁定后暂停射线，仅维持展示。
  - 命中优先按 `unit_id -> tile_index`，失败后按命中点最近候选匹配（阈值限制）。
- `on_scene_pick`：
  - 只接受 owner role。
  - 命中候选后写入 `locked_option_id`，同步 `pending_choice_selected_option_id`，启用确认按钮。
- `on_unlock`：
  - 由 `位置_取消按钮` 触发，仅在 `locked_option_id ~= nil` 时生效。
  - 清空 `locked_option_id`，禁用确认按钮，恢复射线更新；`pending_choice_selected_option_id` 保留最后一次锁定值，但未重新锁定前不得提交。
  - 同步 UI：取消按钮恢复未锁定态（禁用或隐藏）。
- `leave`：
  - 清理生成的候选标记，隐藏箭头，注销点选回调。

验收：实机场景中可观察预览变化、锁定后暂停射线、取消后恢复射线并允许重锁定、确认提交锁定值、退出后无残留单位。

### 里程碑 4：自动化测试与回归验证


范围是补齐最小完备测试矩阵，证明行为正确且可回归。完成后应有可重复执行的测试证据。

工作内容：在 `tests/suites/presentation_ui.lua` 新增或更新以下测试：

- `target_confirm_dispatches_selected_option`
- `target_pick_tick_updates_selection_on_hit_change`
- `target_pick_tick_ignores_non_candidate`
- `target_pick_scene_click_locks_target_and_pauses_raycast`
- `target_pick_confirm_requires_lock`
- `target_pick_cancel_unlocks_and_resumes_raycast`
- `target_pick_cancel_noop_when_unlocked`
- `target_pick_leave_hides_scene_units`
- `target_pick_enter_spawns_candidate_markers_at_height_1_6`
- `target_pick_degrades_without_raycast_api`

验收：测试稳定通过，且至少一个场景能在改动前失败、改动后通过，证明不是“只改结构不改行为”。

## 工作计划


实施顺序采用“先接口、后行为、再测试”的增量策略，避免一次性大改难以定位问题。

第一步先完成端口、节点、意图的最小联通，这一步保证每帧驱动入口存在且不破坏现有流程，并把 `位置_取消按钮` 纳入 unlock 输入。第二步封装射线与点选事件，让后续运行时逻辑依赖稳定接口而不是底层 API 细节。第三步实现 `TargetChoiceEffects` 并接入 UI 打开/关闭生命周期，确保场景单位管理、锁定/解锁状态切换规则完整。最后补齐测试与日志，形成可回归证据链。

涉及文件清单（仓库相对路径）：

- `src/game/flow/turn/GameplayLoopPorts.lua`
- `src/game/flow/turn/GameplayLoopUISyncDefaults.lua`
- `src/game/flow/turn/GameplayLoopTickSteps.lua`
- `src/presentation/api/presentation_ports/UISyncPorts.lua`
- `src/presentation/api/HostRuntimePort.lua`
- `src/presentation/api/host_runtime/Raycast.lua`（新增）
- `src/presentation/render/TargetChoiceEffects.lua`（新增）
- `src/presentation/render/BoardScene.lua`
- `src/presentation/ui/UIModalPresenter.lua`
- `src/presentation/canvas/target_choice/nodes.lua`
- `src/presentation/canvas/target_choice/intents.lua`
- `src/presentation/api/ui_view_service/core.lua`
- `src/app/bootstrap/UIBootstrap.lua`
- `src/core/config/GameplayRules.lua`
- `tests/suites/presentation_ui.lua`
- `Data/UIManagerNodes.lua`（已存在 `位置_取消按钮`，本任务用作节点来源校验）

## 具体步骤


所有命令都在仓库根目录执行：`/Users/gangan/.codex/worktrees/08ad/monopoly`。

1. 建立工作基线，确认仅有预期计划文件变动：

    git status --short

2. 先做端口与 tick 链路改造，再跑快速语法检查（若仓库已有脚本则用仓库脚本）：

    rg "step_target_selection" src

3. 实现 HostRuntime 射线封装后，用搜索确认业务层不直接调用底层 raycast：

    rg "raycast_unit|get_obstacle_by_raycast|get_first_customtriggerspace_in_raycast" src/presentation

4. 实现 `TargetChoiceEffects` 并接入 modal 生命周期后，检查关键函数与解锁状态字段已落位：

    rg "TargetChoiceEffects|locked_option_id|hover_option_id|on_unlock|位置_取消按钮" src

5. 更新测试并执行：

    lua tests/run.lua presentation_ui

   若仓库使用其他测试入口，改为等价命令并记录实际命令。

6. 实机验收时开启日志过滤观察：

    rg "\[TargetPick\]" <运行日志文件路径>

   日志文件路径按本地运行环境填写并回写到本节，保证下一位执行者可复现。

## 验证与验收


自动化验收标准：

运行 UI 测试套件后，新增测试全部通过；其中 `target_pick_confirm_requires_lock` 必须证明“未锁定不提交、锁定后才提交”，`target_pick_cancel_unlocks_and_resumes_raycast` 必须证明“取消后恢复 hover，且重新锁定后才能提交”。

行为验收标准（手工）：

1. 进入目标选择后，候选数量与 `可选择地块` 标记数量一致，且都在 `y + 1.6`。
2. 准星扫过候选时只改变预览箭头，不直接改最终提交值。
3. 场景点击候选后进入锁定态，确认按钮可点，射线暂停。
4. 锁定后点击 `位置_取消按钮` 会解锁并恢复射线预览；此时确认按钮不可提交。
5. 解锁后重新场景点选可再次锁定；点击确认提交的 `option_id` 等于最新锁定值。
6. 关闭选择界面后标记和箭头都清理，无残留与旧回调。
7. 射线接口异常时流程不崩溃，并输出一次告警日志。

## 可重复性与恢复


本计划步骤是可重复执行的：重复进入选择界面不会累积旧标记，重复执行“锁定 -> 取消解锁 -> 重锁定”不会残留旧锁定态，`leave` 必须保证清理。

若实施中出现回归，按以下顺序恢复：

1. 保留当前改动，先用测试定位是“端口链路、射线封装、运行时状态、UI 意图”哪一层失败。
2. 临时禁用 `TargetChoiceEffects.step` 调用验证是否为新增逻辑导致。
3. 若确认是射线 API 兼容问题，保留 wrapper 接口，回退 wrapper 内部实现到降级路径，不回退业务层调用点。

禁止使用破坏性命令清理工作树；所有回退通过可审计的提交或明确 patch 完成。

## 产物与备注


预期关键日志片段（示例）应包含：

    [TargetPick] enter choice_id=... owner_id=... options=...
    [TargetPick] spawn_candidate_markers count=3 height_offset=1.6
    [TargetPick] hover_changed old=101 new=103 source=raycast tile_index=103
    [TargetPick] lock_target option_id=103 role_id=1
    [TargetPick] raycast_paused_by_lock locked_option_id=103
    [TargetPick] unlock_by_cancel old_locked_option_id=103
    [TargetPick] raycast_resumed_by_unlock hover_option_id=102
    [TargetPick] confirm_submit choice_id=... option_id=103 locked=true
    [TargetPick] leave reason=modal_closed

如日志量过大，只保留状态变化与异常首次日志，避免每帧刷屏。

## 接口与依赖


必须使用并遵守以下接口与依赖约束：

- UI 同步端口：`ui_sync.step_target_selection(game, state, dt)`
- 运行时射线封装：`HostRuntimePort -> host_runtime/Raycast.lua`
- 目标选择运行时模块：`TargetChoiceEffects.enter/step/on_scene_pick/on_unlock/leave`
- 目标选择 UI 节点：`target.confirm = "位置_确认按钮"`，`target.cancel = "位置_取消按钮"`，取消事件语义固定为 unlock（不关闭选择屏）
- 数值转换工具：`NumberUtils`（禁止新增 `tonumber` 与 `type(x)=="number"`）

建议保留的核心数据字段：

- `hover_option_id`
- `locked_option_id`
- `pending_choice_selected_option_id`
- `target_pick_raycast_override`

这些字段在里程碑结束时必须可追踪、可测试，并在日志中可定位状态变化。

## 假设与默认值


- 地图中存在模板单位 `可选择地块` 与 `选择地块箭头`。
- `Data/UIManagerNodes.lua` 中存在 `位置_取消按钮`，并可在 `位置选择屏` 被 `nodes.lua` 正确映射。
- 候选地块索引可通过场景 tile 数据反查。
- 射线默认参数：
  - `eye_offset_y = 1.2`
  - `ray_distance = 120.0`
  - `nearest_tile_max_distance = 4.0`
- 仅 `roadblock_target` / `demolish_target` 启用该机制。

若任一假设不成立，先在“意外与发现”记录证据，再在“决策日志”记录替代策略。

## 文档更新记录


- 2026-03-04 / Codex：将 `PLAN.md` 重构并迁移为 `.agents/plan.md` 的可执行计划版本，原因是满足 `.agents/harness/PLANS.md` 的强制结构、活文档维护要求与新手可执行标准；随后删除旧 `PLAN.md` 以消除双计划入口。
- 2026-03-04 / Codex：根据用户新增的 `位置_取消按钮`，将流程更新为“lock 后可 cancel 解锁回到 hover”，并同步调整了里程碑、UI 契约、测试矩阵、验收标准与日志样例，原因是覆盖“选错后重新选择”用例且保持防误选语义。
