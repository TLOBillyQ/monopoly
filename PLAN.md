# 位置选择屏接入“场景准星射线点选”执行计划

## 摘要

目标：把 `roadblock_target / demolish_target` 的“位置选择屏”改成场景内准星持续射线预览 + 场景点选锁定，玩家最后点 `位置_确认按钮` 才提交。  
同时按你的要求接入并复用场景单位 `可选择地块`、`选择地块箭头`，其中 `可选择地块` 必须根据目标选择给出的每个候选地块生成，生成位置为目标地块上方 `+1.6`，并把射线 API 封在开放位置（后续可替换实现），全链路加可追踪日志。

你已确认的关键决策（本计划按此落地）：
- 射线主链路：`Lua主动射线`
- 选点节奏：`该阶段持续 tick`
- 命中规则：`准星命中只预览，场景点选后才锁定选中`
- 防误选规则：`锁定后暂停射线；确认提交使用锁定值，不使用实时命中值`
- 提交规则：`点选后点确认`
- 场景单位结构：`可选择地块按候选批量生成 + 选择地块箭头单实例`

## 公开接口 / 契约变更

1. `ui_sync` 端口新增能力  
- 新增 `step_target_selection(game, state, dt)`  
- 变更位置：
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopPorts.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopPorts.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopUISyncDefaults.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopUISyncDefaults.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/presentation_ports/UISyncPorts.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/presentation_ports/UISyncPorts.lua)
- 约束：默认 no-op，兼容旧调用方。

2. HostRuntime 射线封装对外新增  
- 新增（或扩展）HostRuntimePort 的射线能力入口，禁止业务层直接 `GameAPI.*raycast*`。
- 变更位置：
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/HostRuntimePort.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/HostRuntimePort.lua)
  - 新文件：[C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/host_runtime/Raycast.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/host_runtime/Raycast.lua)

3. 位置选择屏节点契约补全  
- `target` screen 增加 `confirm = "位置_确认按钮"`，并接入 intent 路由。
- `target` screen 的确认按钮改为“未锁定前不可点”，只在收到场景点选锁定后可点。
- 变更位置：
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/target_choice/nodes.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/target_choice/nodes.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/ui_view_service/core.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/ui_view_service/core.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/target_choice/intents.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/target_choice/intents.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/app/bootstrap/UIBootstrap.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/app/bootstrap/UIBootstrap.lua)

4. 游戏参数新增（开放射线位置）  
- 在规则配置增加 target-pick 射线参数（距离、眼高偏移、近点阈值等），并允许 runtime override hook。
- 变更位置：
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/core/config/GameplayRules.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/core/config/GameplayRules.lua)

5. 场景点选事件接入（锁定输入）  
- 位置选择阶段新增“场景点选锁定”输入通道：玩家点击某个候选地块标记时，写入 `locked_option_id` 并暂停射线更新。
- 变更位置：
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/HostRuntimePort.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/HostRuntimePort.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/host_runtime/Raycast.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/host_runtime/Raycast.lua)
  - [C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/render/TargetChoiceEffects.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/render/TargetChoiceEffects.lua)

## 实施方案（决策完成版）

### 1) 场景单位与地图索引准备

在 [BoardScene.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/render/BoardScene.lua) 增加：

- 查询并缓存基准单位：
  - `"可选择地块"`（作为克隆/生成模板）
  - `"选择地块箭头"`（单实例）
- 初始化时先隐藏（`set_model_visible(false)`，若接口不存在则记录 warn）。
- 为地块单位建立 `unit_id -> tile_index` 映射（供射线命中反查），映射来源 `scene.tiles`。
- 全部失败路径仅降级日志，不中断游戏主流程。

### 2) 射线 API 开放层

新增 [host_runtime/Raycast.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/host_runtime/Raycast.lua) 并由 [HostRuntimePort.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/HostRuntimePort.lua) 暴露：

- `build_camera_ray(role, cfg)`  
  - `start = ctrl_unit_pos + (0, eye_offset_y, 0)`  
  - `end = start + camera_dir * ray_distance`
- `pick_first_hit_unit(start_pos, end_pos, cfg)`  
  - 统一封装底层调用（优先 `raycast_unit`，可回退 `get_obstacle_by_raycast` / `get_first_customtriggerspace_in_raycast`）。
- `get_unit_id(unit)` 封装 `LuaAPI.get_unit_id`。
- `resolve_hit_position(...)`（若底层提供 hit_pos，则返回；否则 nil）。

开放原则：
- 业务层只调用 HostRuntimePort，不直连 `GameAPI`。
- 提供 `state.target_pick_raycast_override`（函数）优先入口，后续改 API 只改这一层。

### 3) 位置选择运行时（持续 tick + 准星选中）

新增模块（建议）：  
[TargetChoiceEffects.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/render/TargetChoiceEffects.lua)

职责：

- `enter(state, choice)`  
  - 仅当 `choice.kind` 属于 `roadblock_target / demolish_target`。
  - 解析候选 `option_id`（用 `NumberUtils.to_integer`）构建候选集合。
  - 初始化 `hover_option_id`（默认首个可用 option）和 `locked_option_id=nil`。
  - 根据候选集合逐个生成 `可选择地块` 标记，位置为候选地块中心上方 `+1.6`（`y + 1.6`）。
  - `选择地块箭头` 保持单实例，仅重定位到当前选中格上方（同样使用统一高度偏移）。
  - 注册场景点选回调（marker touch begin / click），用于锁定目标。
  - 进入时禁用 `位置_确认按钮`（未锁定不可提交）。
  - 记录日志 `[TargetPick] enter ...`。

- `step(game, state, dt)`（每 tick 调用）  
  - 读取当前 pending choice 与 owner role。
  - 若 `locked_option_id ~= nil`：跳过射线更新（暂停态），仅维持箭头位置与按钮可用性。
  - 若未锁定：构建相机射线并命中，更新 `hover_option_id`。
  - 命中解析优先级：
    1. 命中单位 `unit_id -> tile_index` 反查成功，且在候选集合内；
    2. 否则用命中点与候选地块中心最近匹配（阈值内）。
  - 命中变化时只更新预览（`hover_option_id` + 箭头），不更新最终选项。
  - 仅在“命中变化/异常首次”打日志，避免刷屏。

- `on_scene_pick(option_id, role_id)`（场景点选回调）  
  - 仅接受当前 choice owner 的输入。
  - 若 `option_id` 在候选集合中：写入 `locked_option_id=option_id`，并同步 `pending_choice_selected_option_id`（通过 `UIViewService.select_choice_option`）。
  - 启用 `位置_确认按钮`，暂停后续射线更新，记录 `lock_target` 日志。
  - 若点到非候选：忽略并记一次 `pick_not_candidate`。

- `leave(state, reason)`  
  - 销毁/隐藏本次生成的全部 `可选择地块` 标记，并隐藏 `选择地块箭头`，清理 runtime 上下文。
  - 清空/失效场景点选回调 token，防止旧回调污染新 choice。
  - 日志 `[TargetPick] leave reason=...`。

### 4) UI 打开/关闭与确认提交

1. 在 [UIModalPresenter.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/ui/UIModalPresenter.lua)：
- 打开 target screen 时调用 `TargetChoiceEffects.enter`。
- 关闭 choice 或切换到非 target screen 时调用 `TargetChoiceEffects.leave`，防止残留。

2. 在 [nodes.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/target_choice/nodes.lua) + [core.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/ui_view_service/core.lua)：
- 把 `位置_确认按钮` 纳入 `screen.confirm`。

3. 在 [target_choice/intents.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/target_choice/intents.lua)：
- 绑定 `位置_确认按钮 -> choice_confirm_intent(...)`。
- 提交时必须使用 `locked_option_id`（已锁定目标），禁止直接使用实时 `hover_option_id`。
- 若未锁定：不发 `choice_select`，保留屏幕并提示“请先在场景中点选地块”。

4. 在 [UIBootstrap.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/app/bootstrap/UIBootstrap.lua)：
- 将 `位置_确认按钮` 加入 required click nodes，确保事件绑定完整。

### 5) tick 链路接入

- 在 [UISyncPorts.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/api/presentation_ports/UISyncPorts.lua) 新增 `step_target_selection` 实现（转发到 UIModelSync/TargetChoiceEffects）。
- 在 [GameplayLoopPorts.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopPorts.lua) 与 [GameplayLoopUISyncDefaults.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopUISyncDefaults.lua) 增加同名端口与默认 no-op。
- 在 [GameplayLoopTickSteps.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/game/flow/turn/GameplayLoopTickSteps.lua) 的每 tick 刷新流程中调用 `ui_sync_ports.step_target_selection(game, state, dt)`，保证“阶段内持续 tick”。

## 日志设计（保留）

统一前缀：`[TargetPick]`

必打日志点：
- 进入选择：`enter choice_id owner_id options...`
- 生成候选标记：`spawn_candidate_markers count=... height_offset=1.6`
- 射线预览变化：`hover_changed old->new source=... tile_index=...`
- 场景点选锁定：`lock_target option_id=... role_id=...`
- 暂停射线：`raycast_paused_by_lock locked_option_id=...`
- 射线不可用/命中无效（warn_once）：`ray_api_unavailable` / `hit_not_candidate`
- 场景单位缺失（warn_once）：`marker_unit_missing`
- 确认提交：`confirm_submit choice_id option_id locked=true`
- 退出选择：`leave reason=...`

## 测试用例与验收

### 自动化（必做）

更新 [tests/suites/presentation_ui.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/tests/suites/presentation_ui.lua)：

1. `target_confirm_dispatches_selected_option`
- 给定 `roadblock_target`，预设 `pending_choice_selected_option_id=102`；
- 触发 `位置_确认按钮`；
- 断言发出 `choice_select(choice_id, option_id=102)`。

2. `target_pick_tick_updates_selection_on_hit_change`
- mock 射线命中 tile_index=103 且是候选；
- tick 一次；
- 断言 `hover_option_id` 更新为 103；
- 断言 `pending_choice_selected_option_id` 仍未锁定（不应自动提交最终选项）；
- 断言 `选择地块箭头` 跟随预览重定位（候选标记不应重复生成）。

3. `target_pick_tick_ignores_non_candidate`
- mock 命中非候选 tile；
- 断言选中不变、不提交 action。

4. `target_pick_scene_click_locks_target_and_pauses_raycast`
- 先通过 tick 预览到 option=103；
- 触发场景点选 option=103；
- 再 mock 射线命中 option=102 并 tick；
- 断言 `locked_option_id` 仍为 103；
- 断言 `pending_choice_selected_option_id` 仍为 103（未被后续射线改写）。

5. `target_pick_confirm_requires_lock`
- 未锁定时点击 `位置_确认按钮`；
- 断言不发 `choice_select`；
- 锁定后再次点击确认；
- 断言发 `choice_select(option_id=locked_option_id)`。

6. `target_pick_leave_hides_scene_units`
- 打开 target 后关闭 modal；
- 断言候选生成的全部 `可选择地块` 被清理，`选择地块箭头` 被隐藏。

7. `target_pick_enter_spawns_candidate_markers_at_height_1_6`
- 给定 `choice.options = {101, 102, 103}`；
- 进入 target 选择；
- 断言创建了 3 个 `可选择地块` 标记；
- 断言每个标记位置为对应 tile `position.y + 1.6`。

8. `target_pick_degrades_without_raycast_api`
- raycast wrapper 返回不可用；
- 断言不崩溃，且 confirm 仍可按当前选中提交。

### 手工验收（实机）

场景：使用 `roadblock` 或 `demolish` 进入位置选择屏。

验收点：
1. 进入位置选择屏时，会根据候选地块数量生成等量 `可选择地块`，每个都在对应地块上方 `1.6`；`选择地块箭头` 指向默认预览候选。
2. 转动视角准星扫过候选地块时，只改变预览（hover），不改变最终锁定目标（有日志）。
3. 玩家在场景中点击某个候选地块后，该目标被锁定，确认按钮变为可点，同时射线更新暂停。
4. 玩家把鼠标移动到确认按钮并点击时，不会再被中途射线误改；提交的是锁定目标。
5. 关闭位置选择/进入其他选择后，候选标记全部清理，箭头隐藏且不残留。
6. 射线异常时流程不崩溃，日志能定位原因。

## 假设与默认值

- 地图中至少存在两个模板单位：`可选择地块`、`选择地块箭头`；其中 `可选择地块` 允许运行时按候选批量生成实例。
- 准星命中来源为“当前 choice owner 的相机方向射线”。
- 目标确认采用“两段式”：射线只预览，必须场景点选锁定后才能确认提交。
- 候选标记高度偏移固定为 `1.6`（相对 tile 锚点位置）。
- 射线参数默认：
  - `eye_offset_y = 1.2`
  - `ray_distance = 120.0`
  - `nearest_tile_max_distance = 4.0`
- 非 `roadblock_target/demolish_target` 不启用该机制。
- 数值解析统一 `NumberUtils`，禁止 `tonumber` 与 `type(...) == "number"` 新增用法。
