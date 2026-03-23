# CRAP 热点函数

来源：`C:/Users/Lzx_8/AppData/Local/Temp/monopoly_crap/crap_report.json`
生成时间：`2026-03-23T08:37:25Z`

## Top Hotspots

| Rank | Function | Location | CRAP | Complexity | Coverage | Risk |
|---|---|---|---:|---:|---:|---|
| 1 | `_can_offer_rent_response` | `src/rules/items/availability.lua:103` | 56.00 | 7 | 0.00% | critical |
| 2 | `units.play_mine_trigger` | `src/ui/render/anim_units.lua:66` | 42.00 | 6 | 0.00% | critical |
| 3 | `item_preconsume_policy.decorate_followup_choice_spec` | `src/core/choice/item_preconsume_policy.lua:51` | 30.00 | 5 | 0.00% | warning |
| 4 | `resolve_any_role` | `src/host/eggy/context.lua:51` | 30.00 | 5 | 0.00% | warning |
| 5 | `_resolve_tile_index` | `src/ui/ctl/event_handlers.lua:126` | 25.02 | 5 | 7.00% | warning |
| 6 | `_safe_get_role` | `src/host/eggy/context.lua:15` | 20.00 | 4 | 0.00% | warning |
| 7 | `validator.resolve_item_slot_action` | `src/turn/actions/validator.lua:137` | 16.04 | 13 | 74.00% | warning |
| 8 | `_resolve_backward_next_id` | `src/rules/board/init.lua:155` | 16.00 | 8 | 50.00% | warning |
| 9 | `_remote_priority` | `src/computer/policies/core_agent.lua:54` | 13.05 | 6 | 42.00% | warning |
| 10 | `_direction` | `src/config/content/maps/ring_map_builder.lua:48` | 12.00 | 3 | 0.00% | warning |
| 11 | `_profile` | `src/config/testing/test_profiles.lua:1` | 12.00 | 3 | 0.00% | warning |
| 12 | `availability.trigger_timing_allowed` | `src/rules/items/availability.lua:70` | 12.00 | 3 | 0.00% | warning |
| 13 | `phase_module.build_wait_choice_args` | `src/rules/items/phase.lua:121` | 12.00 | 3 | 0.00% | warning |
| 14 | `anonymous@42` | `src/ui/ctl/ui_runtime.lua:42` | 12.00 | 3 | 0.00% | warning |
| 15 | `_run_auto_phase` | `src/rules/items/phase.lua:211` | 9.97 | 7 | 61.00% | low |
| 16 | `turn_timer_policy.update_action_button_timer` | `src/turn/policies/timer_policy.lua:111` | 9.51 | 9 | 81.00% | low |
| 17 | `startup_policy.resolve` | `src/app/bootstrap/startup_policy.lua:7` | 9.03 | 9 | 93.00% | low |
| 18 | `choice_resolver.resolve` | `src/core/choice/resolver.lua:134` | 9.00 | 9 | 97.00% | low |
| 19 | `defaults.cpu_now_seconds` | `src/host/eggy/default_ports.lua:175` | 8.67 | 3 | 14.00% | low |
| 20 | `defaults.wall_now_seconds` | `src/host/eggy/default_ports.lua:147` | 8.67 | 3 | 14.00% | low |

## 观察

- 当前最高风险集中在 `src/rules/items/availability.lua`、`src/host/eggy/context.lua`、`src/rules/items/phase.lua`。
- 前 6 个热点里有 5 个覆盖率为 `0%`，优先补 characterization tests 收益最高。
- `src/turn/actions/validator.lua:137` 的 `validator.resolve_item_slot_action` 复杂度高，但覆盖率已到 `74%`，更偏向局部降复杂度而不是先补覆盖。

## 修复方案（仅方案，不动手）

### 1. `_can_offer_rent_response` - `src/rules/items/availability.lua:103`

- 问题：同时处理落点校验、房租拥有者解析、强夺卡分支、余额比较，决策路径耦合在一个函数里。
- 拆解方向：拆成 `_resolve_rent_response_context(game, player)`、`_is_rent_response_available(ctx)`、`_can_afford_strong_card(game, player, ctx)` 三段。
- 实施要点：先把 `tile_ref`、`owner`、`st`、`total_value` 收敛成上下文表，再让主函数只做“普通免租直接可用 / 强夺卡需余额校验”的调度。
- 测试补强：补 4 组 characterization tests：非地产、自己地块、他人地块免租、他人地块强夺但余额不足/足够。

### 2. `units.play_mine_trigger` - `src/ui/render/anim_units.lua:66`

- 问题：混合了参数断言、命中坐标解析、音效/提示播放、overlay 清理、角色 snap 时序。
- 拆解方向：拆成 `_resolve_mine_hit_position(board_scene, player_id, tile_index)`、`_play_mine_feedback(state, anim, player_id, tile_index, hit_pos)`、`_clear_mine_overlay(opts, state, tile_index)`。
- 实施要点：主函数保留“取参数 -> prepare snap -> 播放反馈 -> 清 overlay -> snap -> 归一化 delay”的线性编排；反馈分支只负责 player cue / tile cue 二选一。
- 测试补强：补“有单位坐标”和“无单位坐标回退 tile cue”两组测试，再补 `duration`/`snap_delay` 最小值归一化测试。

### 3. `item_preconsume_policy.decorate_followup_choice_spec` - `src/core/choice/item_preconsume_policy.lua:51`

- 问题：在一个函数里同时做输入兜底、取消行为禁用、meta 初始化、上下文字段灌入。
- 拆解方向：拆成 `_disable_cancel(choice_spec)`、`_ensure_preconsume_meta(choice_spec)`、`_merge_preconsume_context(meta, ctx)`。
- 实施要点：主函数只做 nil guard 与顺序编排；上下文字段写入独立函数里处理“仅在 meta 未设置时回填”。
- 测试补强：补空 `choice_spec`、已有 `meta.item_id/player_id` 不覆盖、无上下文只标记 `item_preconsumed` 三组测试。

### 4. `resolve_any_role` - `src/host/eggy/context.lua:51`

- 问题：同时处理 provider roles、GameAPI fallback、pcall 容错和 first-role 选择，职责过宽。
- 拆解方向：抽 `_resolve_provider_roles(get_roles)`、`_resolve_valid_roles_from_game_api(get_game_api)`、`_first_available_role(primary, fallback)`。
- 实施要点：把“数据源解析”和“取首个可用 role”分离，`resolve_any_role` 只保留优先级编排。
- 测试补强：补 provider 成功、provider 空且 GameAPI 成功、GameAPI 抛错、两边都空四组测试。

### 5. `_resolve_tile_index` - `src/ui/ctl/event_handlers.lua:126`

- 问题：混合 payload 结构判断、tile_id 提取、state/board 访问与索引查询。
- 拆解方向：拆成 `_resolve_tile_index_from_payload(payload)`、`_resolve_tile_id(payload)`、`_index_of_tile_id_from_context(tile_id)`。
- 实施要点：优先返回显式 `payload.tile_index`；否则统一走 `tile.id` / `tile_id` 提取，再调用 board 查询函数。
- 测试补强：补显式 `tile_index`、`tile.id`、`tile_id`、无 `context.state`、board 无 `index_of_tile_id` 五组测试。

### 6. `_safe_get_role` - `src/host/eggy/context.lua:15`

- 问题：nil 检查、GameAPI 可用性校验、`pcall(game_api.get_role, role_id)` 容错写在一起，可读性差。
- 拆解方向：抽 `_resolve_game_api_instance(get_game_api)`、`_can_get_role(game_api)`、`_pcall_get_role(game_api, role_id)`。
- 实施要点：让 `_safe_get_role` 只保留卫语句；异常隔离到 `_pcall_get_role`，避免每次阅读都跨越多层条件。
- 测试补强：补 nil `role_id`、缺失 `get_role`、`pcall` 失败、成功返回 role 四组测试。

### 7. `validator.resolve_item_slot_action` - `src/turn/actions/validator.lua:137`

- 问题：单函数串联了 action 识别、choice 解析、slot 映射、option 校验、availability 二次校验、最终 action 构造。
- 拆解方向：拆成 `_resolve_item_phase_choice(state, game)`、`_validate_item_option(choice, item_id)`、`_validate_item_phase_availability(game, choice, actor_role_id, item_id)`、`_build_choice_select_action(choice, action, item_id)`。
- 实施要点：每一步都返回明确的 `ok=false, reason=...` 中间结果，主函数只串联；这样能降低圈复杂度，也便于日志统一。
- 测试补强：虽然覆盖较高，但应补“slot 映射缺失”“option 不在 choice 内”“phase 可见但 availability 拒绝”三条边界断言。

### 8. `_resolve_backward_next_id` - `src/rules/board/init.lua:155`

- 问题：向后寻路把 facing 反向、outer_prev、fallback 映射、邻居唯一选择、任意方向回退全部塞在一个函数中。
- 拆解方向：拆成 `_resolve_backward_by_facing(neigh, facing)`、`_resolve_backward_from_map(map, current_id)`、`_resolve_backward_from_neighbors(neigh, facing)`。
- 实施要点：优先级保持不变，但每一层来源独立；主函数只负责“按优先级挑第一命中值”。
- 测试补强：补 facing 命中、outer_prev 命中、backward_fallback 命中、unique_dir 回退、any_dir 最终回退五组测试。

### 9. `_remote_priority` - `src/computer/policies/core_agent.lua:54`

- 问题：大段 `elseif` 将 tile 类型分类、地块状态判断和分值计算耦合在一起。
- 拆解方向：改成规则表驱动，抽 `_remote_priority_for_tile_type(tile_ref, st, player, sim)` 或一组 `_priority_for_item/chance/land/start/...` 小函数。
- 实施要点：把“敌方地产负租金 score”单独作为 land 子规则；land 类型先解析 `st`，再委派到 `owned/unowned/self_owned/enemy_owned` 分支。
- 测试补强：至少覆盖 item、chance、空地、己方地、敌方地、market 六类决策，保证排序语义不变。

### 10. `_direction` - `src/config/content/maps/ring_map_builder.lua:48`

- 问题：虽然代码短，但同时承担索引断言、前后邻接判断和异常报错；0% 覆盖导致 CRAP 偏高。
- 拆解方向：抽 `_assert_ring_endpoint(index_by_id, from_id, to_id)` 和 `_is_adjacent_in_ring(from_index, to_index, total)`，主函数只返回 `left/right`。
- 实施要点：如果不想继续拆函数，最低成本方案是保留实现，仅补覆盖把 CRAP 直接压下去。
- 测试补强：补 next、prev、非法跳跃、缺失 id 四组测试即可明显降风险。

### 11. `_profile` - `src/config/testing/test_profiles.lua:1`

- 问题：逻辑不复杂，CRAP 主要来自 0% 覆盖；当前函数承担 meta copy 和 bootstrap 默认化。
- 拆解方向：无需过度重构，可抽 `_copy_meta(meta)` 以明确意图，但优先级低于补测试。
- 实施要点：保持 `_profile` 作为轻量 factory，避免为了降 CRAP 反而引入更多样板代码。
- 测试补强：补 meta copy、不共享引用、bootstrap 缺省为空表三组测试即可。

### 12. `availability.trigger_timing_allowed` - `src/rules/items/availability.lua:70`

- 问题：函数短，但把 phase 缺失兜底、`phase_timing` 查表、timing nil 判定合在一起；主要风险仍是未覆盖。
- 拆解方向：抽 `_resolve_phase_timing(phase)` 或 `_is_known_timing(allowed, timing)`，但更推荐只补测试。
- 实施要点：保持现有查表设计，不要把简单逻辑过度抽象成多层 helper。
- 测试补强：补 phase 缺失且允许/不允许、未知 phase、未知 timing、合法映射四组测试。

### 13. `phase_module.build_wait_choice_args` - `src/rules/items/phase.lua:121`

- 问题：函数非常短，CRAP 偏高同样主要由 0% 覆盖触发；职责是把 meta 恢复为 wait args。
- 拆解方向：无需拆分；若要增强可读性，可抽 `_assert_resume_next_state(meta)`，但不建议为降分而重构。
- 实施要点：这里应以测试保底为主，保证 `resume_next_state` 缺失时断言、`resume_next_args` 允许为 nil。
- 测试补强：补正常构建、缺少 `resume_next_state` 触发 assert、`resume_next_args=nil` 三组测试。

### 14. `anonymous@42` - `src/ui/ctl/ui_runtime.lua:42`

- 问题：匿名闭包内同时处理 countdown 显隐和 label 更新，导致报告中函数名不可识别，也不利于单测定位。
- 拆解方向：把闭包提名为 `_refresh_turn_label_for_runtime_role(ui, base_nodes, label_text, countdown_visible)`。
- 实施要点：`service.refresh_turn_label` 仅负责准备参数并调用 `runtime.for_each_role_or_global(named_fn)`，最后统一 `runtime.set_client_role(nil)`。
- 测试补强：补“visible=false 时隐藏”“visible=nil 时默认显示”“存在 `set_label/set_visible` 时分别调用”三组测试。

## 建议执行顺序

1. 先补 `availability.lua`、`context.lua`、`anim_units.lua` 的 characterization tests，再做拆解，优先压掉最高 CRAP 且防止行为漂移。
2. 第二批处理 `validator.resolve_item_slot_action`、`_resolve_backward_next_id`、`_remote_priority`，这些函数已有明确职责边界，适合直接做小步提炼。
3. 最后处理 `_direction`、`_profile`、`trigger_timing_allowed`、`build_wait_choice_args`、`anonymous@42`，这批以“命名化 + 补覆盖”为主，避免过度设计。

## 横向重构原则

- 优先“提炼查询函数 / 提炼上下文对象 / 表驱动规则”，不要引入新的跨层依赖。
- UI 侧热点优先把“参数解析”“反馈播放”“宿主调用”拆开，便于 stub 和测试。
- 规则侧热点优先把“资格判断”和“动作构造”分离，避免布尔分支与副作用混写。
- 对于复杂度低但覆盖为 0% 的函数，以补测试降 CRAP 为主，不为了数字强行拆成更多碎函数。
