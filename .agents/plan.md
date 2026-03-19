# Context

这次 `/simplify` 不适合做 `src/` 全量重构；当前更稳妥的做法，是围绕最近收敛出来的 6 个核心模块做低风险简化：去掉重复逻辑、统一已有契约入口、保持行为与质量门不变。目标是减少重复 dirty 处理、choice owner / route 解析分叉、以及事件派发样板代码，同时不改事件名、payload、route 语义和外部调用方式。

# Recommended Approach

1. 先统一 dirty bucket 的内部实现，只做同源化，不改外部结构
   - 修改 `src/core/utils/dirty_tracker.lua`
   - 修改 `src/state/state_access/landing_visual_hold.lua`
   - 修改 `src/turn/output/intent_dispatcher.lua`
   - 做法：把 dirty bucket 的初始化 / merge / reset 逻辑收敛到 `dirty_tracker`，让 `landing_visual_hold` 复用它，`intent_dispatcher` 也改用统一打标入口，避免继续手写 `game.dirty.any = true` / `game.dirty.turn = true`
   - 复用现有模式：保留 `dirty_tracker.new()`、`dirty_tracker.consume()` 的 snapshot 结构与 `inventory_ids` 语义

2. 简化 `number_utils` 的重复转换路径，但保持边界行为完全一致
   - 修改 `src/core/utils/number_utils.lua`
   - 做法：合并 `is_numeric()`、`to_integer()`、`format_integer_part()` 内部重复的安全整型转换逻辑，减少重复探测与重复解析
   - 复用现有模式：继续通过 `number_utils` 作为统一数字归一化入口，不在业务层新增 helper
   - 注意：字符串解析、`tostring` fallback、`math.tointeger` / `math.floor` 回退都保持原行为

3. 收敛 choice owner / target owner 的重复解析
   - 修改 `src/core/choice/contract.lua`
   - 修改 `src/ui/ctl/target_choice_effects.lua`
   - 修改 `src/presentation/runtime/ports/ui_sync/choice_state.lua`
   - 必要时检查 `src/turn/actions/validator.lua`
   - 做法：以 `choice_contract` 为唯一字段归一化入口，抽出共用 owner 解析逻辑；UI 层和表现层复用它，不再各自手写 `owner_role_id` / `target_picker_owner_role_id` 解析
   - 复用现有函数：`choice_contract.resolve_owner_role_id()`、`choice_contract.resolve_target_picker_owner_role_id()`、`src/core/utils/role_id.lua`
   - 注意：各处现有 fallback 顺序保持不变；仅收敛“从 choice 中取值并归一化”的重复部分

4. 收敛 route policy 的重复字段读取，保留现有 route 语义
   - 修改 `src/core/choice/route_policy.lua`
   - 检查 `src/ui/input/choice_route_policy.lua`
   - 做法：把 `choice -> route -> meta` 的 layered lookup 收敛成共享内部 helper；把 `base_inline`、`secondary_confirm` 这类核心 route 字面量集中在 policy 模块内部管理
   - 复用现有模式：UI wrapper 继续只是薄代理，不新增 UI 逻辑
   - 注意：`resolve()` fallback 到 `base_inline`、`requires_confirm()` 的判断结果与 warning 行为都不能变

5. 简化 intent 事件派发样板代码，但不改事件契约
   - 修改 `src/core/events/monopoly_events.lua`
   - 修改 `src/turn/output/intent_dispatcher.lua`
   - 做法：在 `monopoly_events` 内提供更直接的 intent 事件派发入口，内部仍走 `resolve_intent()` + `emit()`；`intent_dispatcher` 只负责构建 payload，不再重复拼事件名逻辑
   - 复用现有函数：`monopoly_events.resolve_intent()`、`monopoly_events.emit()`、`runtime_ports.emit_event()`
   - 注意：事件名、payload 字段、`feature_key = "event." .. kind` 语义全部保持不变

6. 最后只对 action anim port 做微清理
   - 修改 `src/core/ports/action_anim_port.lua`
   - 做法：删掉局部重复 guard / 布尔冗余，让 `is_enabled()` / `queue()` 更直接
   - 注意：assert 契约、返回值、`queue_action_anim(payload)` 的调用时机不变

# Critical Files

- `src/core/utils/dirty_tracker.lua`
- `src/state/state_access/landing_visual_hold.lua`
- `src/turn/output/intent_dispatcher.lua`
- `src/core/utils/number_utils.lua`
- `src/core/choice/contract.lua`
- `src/ui/ctl/target_choice_effects.lua`
- `src/presentation/runtime/ports/ui_sync/choice_state.lua`
- `src/core/choice/route_policy.lua`
- `src/ui/input/choice_route_policy.lua`
- `src/core/events/monopoly_events.lua`
- `src/core/ports/action_anim_port.lua`

# Existing Utilities / Patterns To Reuse

- `src/core/utils/dirty_tracker.lua`：dirty bucket 的唯一语义源
- `src/core/choice/contract.lua`：choice 显式字段复制与 owner 解析入口
- `src/core/utils/role_id.lua`：role id 归一化 / 比较
- `src/core/choice/route_policy.lua`：route / requires_confirm 的中心策略
- `src/core/events/monopoly_events.lua`：事件常量表与统一 emit 入口
- `src/ui/input/choice_route_policy.lua`：UI 对 core route policy 的薄包装边界

# Verification

1. 先跑与 dirty / runtime 相关的定向测试
   - `lua tests/suites/runtime/misc.lua`
   - 重点确认 `dirty_tracker.consume()` snapshot shape、`landing_visual_hold` defer/release 行为不变

2. 跑 choice / route / target pick / intent 相关定向测试
   - `lua tests/suites/presentation/presentation_ui_model_dispatch.lua`
   - `lua tests/suites/presentation/presentation_choice_routes.lua`
   - `lua tests/suites/presentation/presentation_target_pick.lua`
   - `lua tests/suites/gameplay/gameplay_intent_dispatch_and_event_feed.lua`

3. 跑完整质量门
   - `lua tests/guard.lua`
   - `lua tests/contract.lua`
   - `lua tests/behavior.lua`

4. 人工核对重点
   - choice 打开后 UI 路由是否仍按原规则展示
   - target picker 的 owner 限制与锁定逻辑是否不变
   - landing visual hold 释放后 dirty / UI 刷新是否仍准确
   - action animation queue 与 wait phase 是否仍保持原时序
