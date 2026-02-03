标题：Store 驱动倒计时 + 脏标记 UI 增量刷新

摘要

在现有“Store 快照 + UIModel 构建”基础上，增加倒计时字段并由 Store 驱动更新。
UI 刷新从“每帧全量重建”改为“脏标记触发 + 倒计时 1Hz 更新”，减少 CPU/GC 压力。
倒计时始终显示，格式为 回合: X | 倒计时: Y，无有效倒计时时显示 0。
对外接口/类型变更

Store：
新增 store.version, store.dirty。
新增 store:consume_dirty()（返回并清空脏标记）。
在 Store:set 中按路径写入脏标记。
store.state.turn：
新增字段 countdown_seconds（number）。
UIModel：
新增 ui_model.update(prev, store_state, env, dirty) 用于增量构建。
UIPanel.build_turn_label：
修改签名为 build_turn_label(turn_count, countdown_seconds)。
实施步骤

Store 脏标记体系

在 Store:init 初始化：
version = 0
dirty = { any=false, players=false, board_tiles=false, turn=false, market=false, turn_countdown=false, inventory_ids={} }
在 Store:set(path, value)：
dirty.any = true, version += 1
path[1]=="players" → dirty.players=true（若 path[3]=="inventory" 记录 dirty.inventory_ids[pid]=true）
path[1]=="board" → dirty.board_tiles=true
path[1]=="market" → dirty.market=true
path[1]=="turn"：
如果 path[2]=="countdown_seconds" → 仅 dirty.turn_countdown=true
否则 dirty.turn=true
实现 consume_dirty()：返回当前 dirty 并重置为初始结构。
Store 中引入倒计时字段

CompositionRoot._build_initial_state：turn.countdown_seconds = 0。
UI 文案展示始终包含倒计时。
倒计时逻辑（Store 驱动，1Hz 更新）

在 GameplayLoop.tick 新增 update_countdown(game, state)：
取 timeout = constants.action_timeout_seconds。
优先级：pending_choice > popup > 无。
remaining = max(0, timeout - elapsed)，seconds = math.ceil(remaining)。
当无有效倒计时：seconds = 0。
仅当 seconds 与 state.countdown_last 不同才 store:set({"turn","countdown_seconds"}, seconds)。
记录 state.countdown_last（初始化为 nil）。
UIModel 增量更新

新增 ui_model.update(prev, store_state, env, dirty)：
dirty.players/board_tiles/turn/market → 更新对应块。
仅 dirty.turn_countdown → 只更新 panel.turn_label（不重建 board/choice）。
UIPanel.build_turn_label 拼接为："回合: " .. turn_count .. " | 倒计时: " .. countdown_seconds。
UI 刷新触发规则

GameplayLoop.tick：
dirty = store:consume_dirty()
need_refresh = dirty.any or state.ui_dirty
若 dirty.turn_countdown 且其他 dirty 都为 false，可只刷新倒计时标签（新增 ui_view.refresh_turn_label），避免全量刷新。
在 dispatch_action 和弹窗/选择框开关处设置 state.ui_dirty = true，保证 UI 状态变化被刷新。
测试与验收

倒计时显示：
无 choice/popup 时显示 回合: X | 倒计时: 0。
choice 激活后，从 action_timeout_seconds 递减，每秒更新一次。
计时结束：
倒计时到 0 时，自动触发选择超时逻辑，与现有行为一致。
UI 刷新：
非倒计时变化时，UI 不应每帧重建。
倒计时更新时，仅刷新倒计时标签（或最小面板刷新），不会重绘棋盘。
假设与默认值

倒计时显示始终存在，无有效倒计时时显示 0。
倒计时整数取 math.ceil，避免提前显示 0。
Choice 与 popup 同时存在时，倒计时以 choice 为准。