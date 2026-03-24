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
- 测试补强：补“visible=false 时隐藏”“visible=nil 时默认显示”“存在 set_label/set_visible 时分别调用”三组测试。

## 建议执行顺序

1. 先补 `availability.lua`、`context.lua`、`anim_units.lua` 的 characterization tests，再做拆解，优先压掉最高 CRAP 且防止行为漂移。
2. 第二批处理 `validator.resolve_item_slot_action`、`_resolve_backward_next_id`、`_remote_priority`，这些函数已有明确职责边界，适合直接做小步提炼。
3. 最后处理 `_direction`、`_profile`、`trigger_timing_allowed`、`build_wait_choice_args`、`anonymous@42`，这批以“命名化 + 补覆盖”为主，避免过度设计。

## 横向重构原则

- 优先“提炼查询函数 / 提炼上下文对象 / 表驱动规则”，不要引入新的跨层依赖。
- UI 侧热点优先把“参数解析”“反馈播放”“宿主调用”拆开，便于 stub 和测试。
- 规则侧热点优先把“资格判断”和“动作构造”分离，避免布尔分支与副作用混写。
- 对于复杂度低但覆盖为 0% 的函数，以补测试降 CRAP 为主，不为了数字强行拆成更多碎函数。

# 全系统优化分析

分析时间：`2026-03-24`
覆盖范围：`src/` 下全部 12 个子系统，约 250+ `.lua` 文件

## 架构概览

项目为基于蛋仔派对（Eggy Party）引擎的大富翁游戏，采用七层清洁架构：

```
app → infrastructure → presentation → turn → (state | computer) → rules → (state | config)
```

- 回合系统：**协程驱动的 phase 状态机**，基于 tick 的游戏循环
- 设计模式：端口与适配器（六边形架构），通过 `ports` 表注入所有外部依赖
- 状态管理：集中式 `game_state` + mixin 组装，脏标记驱动增量同步

---

## A. 跨系统重复代码（高优先级）

重复代码是最高 ROI 的优化目标——每消除一处，维护成本永久降低。

### A1. 工具函数重复

| # | 函数 | 重复位置 | 建议 |
|---|------|----------|------|
| 1 | `_copy_table()` | `bootstrap/choice_optional_effect_handler.lua:8`、`items/choice_handlers.lua:17`、`items/phase.lua:70`、`market/choice_handlers.lua:10` | 提取到 `src/core/utils/tables.lua`，统一引用 |
| 2 | `_each_option()` | `core/choice/item_preconsume_policy.lua`、`core/choice/resolver.lua` | 合并到 `core/choice/` 内共享模块 |
| 3 | `_is_cancel` / `_is_cancel_action` | 同上两文件 | 同上 |
| 4 | `_normalize_integer_field()` | `bootstrap/choice_optional_effect_handler.lua:19`、`items/choice_handlers.lua:28` | 合并到 `core/utils/` |
| 5 | `_contains()` | `items/availability.lua:34`、`market/choice/builder.lua:10` | 提取到 `core/utils/tables.lua` |
| 6 | `opposite` 方向表 | `board/init.lua:6`、`items/post_effects.lua:285` | 提取到 `config/content/maps/` 或 `core/utils/direction.lua` |
| 7 | `cfg_by_id` 模块加载时构建 | `items/inventory.lua:8`、`items/phase.lua:11` | 抽成共享工厂函数 |
| 8 | `_normalize_currency` | `player.lua:4`、`common.lua:12` | 合并到 `player/` 或 `core/utils/` |
| 9 | `_apply_dice_multiplier` | `turn/phases/roll.lua`、`turn/phases/move.lua` | 提取到 `turn/phases/` 共享模块 |

### A2. UI/表现层重复

| # | 函数/模式 | 重复位置 | 建议 |
|---|-----------|----------|------|
| 10 | `_with_client_role` helper | 4+ 个 `ctl/` 文件 | 提取到 `ui/ctl/` 共享模块 |
| 11 | `_log_once` 模式 | `choice_timeout.lua`、`ui_sync.lua` | 提取到 `core/utils/logger_utils.lua` |
| 12 | `turn_left`/`turn_right` 表 | `default_map.lua`、`ring_map_builder.lua` | 提取到地图共享常量 |
| 13 | Role 解析 helpers | `context.lua`、`vehicle_runtime_legacy.lua`、`vehicle_runtime_source.lua` | 统一到 `host/eggy/role_utils.lua` |

### A3. 规则层结构性重复

| # | 模式 | 位置 | 建议 |
|---|------|------|------|
| 14 | `cash_handlers.lua` 中 `add_cash`/`pay_cash`/`percent_pay_cash` 的 `target=="all"` 分支 | `src/rules/land/effects/cash_handlers.lua` | 提取 `_apply_to_all_players(game, fn)` 统一处理 |
| 15 | 物品数据 `items.lua` / `market.lua` / `rules.lua:item_ids` 三处定义 | 分散在 `config/` 和 `rules/` | 统一为单一数据源，其余引用 |

---

## B. 死代码 / 残留功能（中高优先级）

移除死代码可减少认知负载、加速 require 和缩小包体。

| # | 范围 | 文件 | 行数估算 | 说明 |
|---|------|------|----------|------|
| 1 | 载具系统（已完全禁用） | `vehicles.lua`（空）、`vehicle_catalog.lua`（存根）、`feature_toggles.lua`（零消费者）、`vehicle_ops.lua`（全常量）、`vehicle.lua`（始终 false）、`runtime_constants.lua` 中死常量 | ~150 行 | 6+ 文件可整体删除或归档 |
| 2 | `skins.lua` | `src/config/content/skins.lua` | ~30 行 | 零消费者，数据已在 `market.lua` 中重复 |
| 3 | `set_player_seat` | `src/player/state_ops/status_ops.lua` | ~5 行 | 始终 assert nil，死代码 |
| 4 | `fill_output_defaults()` | `src/turn/output/state_adapter.lua` | ~3 行 | 空函数体 |
| 5 | `_fill_clock_defaults` | `src/turn/loop/ports.lua` | ~5 行 | 空操作，将值复制给自身 |
| 6 | 3 个全局别名 | `RegisterCustomEvent`、`UnitCustomEvent`、`UnitTriggerEvent` in `global_aliases.lua` | ~10 行 | `src/` 内零消费者 |
| 7 | 孤立资产引用 | `runtime_refs.lua` 中 keys 3014-3016, 3035-3037 | ~12 行 | 无对应内容 |
| 8 | 空 `if` body | `action_dispatcher.lua:55` | 1 行 | 应为日志或移除 |

**总计约 ~220 行可安全移除。**

---

## C. 架构与分层问题（中优先级）

### C1. God Object — `game_state.lua`

- **位置**：`src/state/game_state.lua`
- **问题**：通过 `pairs()` 从 4 个 mixin 模块复制所有字段，无冲突检测。`pairs()` 迭代顺序非确定性——如果两个 mixin 定义同名键，后写入的取决于运行时。
- **建议**：
  1. 添加 mixin 组装时的键冲突断言（`assert(target[k] == nil, "mixin collision: " .. k)`）
  2. 长期考虑将 mixin 改为组合（`state.board`, `state.turn`, `state.player`）

### C2. God Config — `gameplay/rules.lua`

- **位置**：`src/config/gameplay/rules.lua`
- **问题**：混合 5+ 关注点（调试标志、时序参数、棋盘几何、道具 ID、目标选择），被 50+ 文件消费。
- **建议**：按关注点拆分为 `timing.lua`、`board_geometry.lua`、`item_ids.lua`、`debug_flags.lua`，各文件独立导出。

### C3. 层级依赖违规

| 违规 | 位置 | 说明 | 建议 |
|------|------|------|------|
| App → Presentation | `src/app/bootstrap/init.lua:5-8` | app 层直接引用表现层模块 | 通过端口注入 |
| Presentation → Host | 2 个 presentation 文件直接 `require "src.host.eggy.context"` | 跨层直接依赖 | 通过 `presentation/ports` 注入 |
| Rules → Host | `src/rules/land/effects/chance.lua` 调用 `LuaAPI.rand()` | 规则层直接调用宿主 API | 改用 `runtime_ports.rng_next_int` |

### C4. require 时副作用

- **位置**：`src/app/bootstrap/init.lua`
- **问题**：`require` 时立即执行所有启动逻辑，无法在测试中隔离加载。
- **建议**：改为导出 `init()` 函数，由调用方显式调用。

### C5. 双状态同步

- **位置**：`src/state/state_access/landing_visual_hold.lua`（321 行）
- **问题**：同时维护 `game.turn.*` 和 `state.turn_runtime.*` 两套表示，必须手动保持同步。
- **建议**：将 visual hold 逻辑统一到单一状态源，另一侧通过派生（getter/computed）获取。

---

## D. 额外复杂度热点（CRAP 报告之外）

| # | 函数/文件 | 位置 | 行数 | 问题 | 建议 |
|---|-----------|------|------|------|------|
| 1 | `_resolve_wait_state` | `src/turn/phases/land.lua` | ~40 | 3 个布尔组合产生 6 个分支，组合爆炸 | 改为查表：`wait_state_table[has_x][has_y][has_z]` |
| 2 | `tick_clock.lua` | `src/turn/loop/tick_clock.lua` | 191 | 过度工程化的墙钟处理 | 简化为单一时钟源 + 漂移补偿 |
| 3 | `await.lua` | `src/turn/waits/await.lua` | 471 | turn/ 最大文件，处理 8 种等待类型，内部状态复杂 | 按等待类型拆分为子模块 |
| 4 | `move_anim.lua` | `src/ui/render/move_anim.lua` | 633 | ui/ 最大文件，复杂状态机 | 提取 `_move_step_anim`、`_teleport_anim`、`_path_anim` |
| 5 | `logger.lua` | `src/core/utils/logger.lua` | 420 | 重量级单例，12+ 可变状态字段，O(n) 环形缓冲区 | 见 E9 性能建议 |
| 6 | `auto_action_for_choice` | `src/computer/policies/core_agent.lua` | ~50 | 10 分支 elseif 链 | 改为表驱动分发 |
| 7 | `_build_initial_turn()` | `src/turn/` 相关 | ~60 | 返回 30 字段的巨型表 | 拆分为 `_build_turn_timing()`、`_build_turn_phase()`、`_build_turn_players()` |

---

## E. 性能问题（中低优先级）

以下问题在当前规模下可能不构成瓶颈，但随玩家/地块增加会恶化。

| # | 问题 | 位置 | 复杂度 | 建议 |
|---|------|------|--------|------|
| 1 | `runtime_state` getter 每次调用 `ensure_*` | `src/state/state_access/runtime_state.lua` | O(1) 但冗余 | 初始化后移除 ensure 检查，或用 metatables `__index` 惰性初始化 |
| 2 | `roadblock.is_ui_candidate` 全量重算 | `src/ui/` 相关 | O(n) 每次查询 | 缓存候选集，仅在状态变更时刷新 |
| 3 | `market_slots.lua` 线性扫描 | `src/ui/stores/market_slots.lua` | O(n) × 2 | 构建 `id → entry` 哈希表，查询 O(1) |
| 4 | `alive_players` 每次重建列表 | `src/state/` 相关 | O(n) 每次调用 | 缓存并在玩家状态变更时失效 |
| 5 | `find_player_by_id` 读时写缓存 | `src/state/` 相关 | — | 意外副作用；应在写入时更新缓存，而非读取时 |
| 6 | `_resolve_dispatch_context` 每次创建新表 | `src/turn/actions/action_dispatcher.lua` | O(1) 但 GC 压力 | 复用上下文表，调用后清零 |
| 7 | `default_policy()` 每次调用克隆 | `src/turn/policies/timeout.lua` | O(fields) | 实际从不修改返回值；改为返回冻结的共享实例 |
| 8 | `_resolve_trigger_available` 运行 `debug.getupvalue` 循环 | `src/presentation/runtime/event_bridge.lua` | O(128) 每次事件触发 | 在注册时缓存 upvalue 引用，而非每次触发时搜索 |
| 9 | `table.remove(entries, 1)` 在 logger 环形缓冲区 | `src/core/utils/logger.lua` | O(n) | 改用头尾指针实现 O(1) 环形缓冲区 |
| 10 | `_deep_copy` 在每次 `get`/`resolve` | `src/config/testing/test_profiles.lua` | O(fields) × 频繁 | 使用冻结表 + 写时复制，或标记 profile 为不可变 |

---

## F. 数据完整性风险（中优先级）

| # | 问题 | 位置 | 影响 | 建议 |
|---|------|------|------|------|
| 1 | `remove_by_index` 无边界检查 | `src/rules/items/inventory.lua` | 越界时静默 nil + 通知，下游可能崩溃 | 添加 `assert(index >= 1 and index <= #items)` |
| 2 | 无负余额守卫 | `src/player/state_ops/balance_ops.lua` | 扣款可能导致负余额 | 添加 `assert(new_balance >= 0)` 或返回失败 |
| 3 | 物品数据三处定义 | `items.lua` / `market.lua` / `rules.lua:item_ids` | 三份数据可能不一致 | 统一为单一数据源 |
| 4 | `dirty_tracker.mark()` 无域校验 | `src/state/dirty_tracker.lua` | 拼写错误静默成功，脏标记永远不被消费 | 添加已知域的白名单断言 |
| 5 | 可变单例配置 | `src/config/` 中 `constants.lua` 等 | 测试直接修改，导致跨测试污染 | 冻结配置表或在每个测试前重置 |
| 6 | `total_invested()` 双实现 | 使用不同字段名 `level_costs` vs `upgrade_costs` | 两个实现可能返回不同结果 | 统一字段名，删除冗余实现 |

---

## G. 测试覆盖空白（按模块）

| 模块 | 未测试关键文件 | 建议 |
|------|----------------|------|
| `state/` | `board_state.lua`、`turn_state.lua`、`dirty_tracker.lua`、`game_state.lua` mixin 组装 | 补 mixin 冲突断言测试、脏标记域校验测试 |
| `host/` | `vehicle_runtime_source.lua` | 已死代码，可跳过 |
| `ui/` | `ui_role_globals.lua` | 补全局状态初始化/清理测试 |
| CRAP Top 6 | 见上方 CRAP 报告 | 5 个函数 0% 覆盖，最高 ROI |

---

## H. 全局状态与注入风险

- **12 个全局名**由宿主层注入（`LuaAPI`、`GameAPI`、`RegisterCustomEvent` 等）
- 3 个全局别名（`RegisterCustomEvent`、`UnitCustomEvent`、`UnitTriggerEvent`）在 `src/` 内零消费者
- **建议**：
  1. 移除零消费者的全局别名
  2. 对必要全局进行 lazy-require 包装，避免模块加载顺序依赖
  3. 在测试 harness 中 mock 全局表，防止测试泄露

---

## 建议执行路线图

### 第一阶段：高 ROI 清理（低风险，立即可做）

1. **删除死代码**（~220 行）——载具系统、`skins.lua`、空函数、死别名
2. **消除工具函数重复**（A1 表中 9 项）——提取到 `core/utils/`
3. **补 CRAP Top 6 的 characterization tests**——0% → 基线覆盖

### 第二阶段：架构改善（中风险，需逐步推进）

4. **拆分 God Config** `rules.lua` → 4 个关注点文件
5. **修复层级违规**（3 处跨层直接依赖 → 端口注入）
6. **添加 mixin 冲突断言**到 `game_state.lua`
7. **消除 UI 层重复**（A2 表中 4 项）

### 第三阶段：复杂度与性能（需充分测试保护）

8. **拆解 CRAP 热点函数**（按上方修复方案执行）
9. **表驱动重构**：`_remote_priority`、`_resolve_wait_state`、`auto_action_for_choice`
10. **性能优化**：logger O(1) 环形缓冲区、`debug.getupvalue` 缓存、`runtime_state` ensure 移除
11. **拆解大文件**：`await.lua`（471 行）、`move_anim.lua`（633 行）

### 第四阶段：数据完整性加固

12. **添加边界断言**：`remove_by_index`、`balance_ops`、`dirty_tracker`
13. **统一数据源**：物品三处定义 → 单一来源
14. **冻结配置单例**：防止测试交叉污染
