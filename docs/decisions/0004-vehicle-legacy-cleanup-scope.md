# 0004 — 载具遗留清理范围

> 状态：草稿 | 日期：2026-05-07

## 背景

载具（Vehicle）功能最初设计为玩家可以购买/装备座驾，座驾影响骰子数量、移动动画表现、地雷免疫等。功能通过 `src/rules/vehicle.lua` 的特征开关控制（`_enabled = false`），release 模式下 `src/host/context.lua` 直接返回 noop helper。**特征开关已永久关闭**，但载具代码仍在约 28 个源码文件 + 30 个测试文件中作为布线存在。

本文档明确清理范围、依赖顺序和风险点。

---

## 第 1 层：config 数据 + catalog

| 文件 | 行数 | 内容 | 清理方式 |
|---|---|---|---|
| `src/config/content/vehicles.lua` | 15 | 12 辆载具定义（id 4001-4012，含 dice_count / indestructible） | **删除** |
| `src/config/gameplay/vehicle_catalog.lua` | 36 | find / has / name_of / list 查询 | **删除** |
| `src/config/gameplay/runtime_constants.lua` (line 35-38) | 4 | `vehicle_speed` / `vehicle_accel` / `vehicle_move_api_enabled` / `vehicle_enter_delay` 常量 | **删除** 4 行，保留文件其余内容 |
| `src/config/gameplay/config_sanity.lua` (line 12-20, 30, 111) | ~10 | `_validate_data_has_no_vehicle_content()`：检查 `set_vehicle` 卡牌和 `vehicle` 市场条目 | **删除** 函数 + 第 111 行调用点（Phase 1 后检查永远通过，成为死代码） |

**风险**：`dice_count` 被 `src/player/actions/state_ops/vehicle.lua:player_dice_count()` 消费。删除载具概念后，dice_count 的 fallback 来源是 `src/config/content/constants.lua:3`（`default_dice_count = 1`）。确认逻辑层不再写入 `player.seat_id` 后，`catalog.find(seat_id)` 总是返回 nil → dice_count 总是 1，不需要额外迁移。

---

## 第 2 层：feature flag + player state seat 管理

| 文件 | 行数 | 内容 | 清理方式 |
|---|---|---|---|
| `src/rules/vehicle.lua` | 26 | `set_enabled` / `is_enabled` / `resolve_seat_id` | **删除** |
| `src/player/actions/state_ops/vehicle.lua` | 47 | `player_vehicle_cfg` / `dice_count` / `indestructible` | **删除**，dice_count fallback 改为硬编码常量 |
| `src/player/actions/state_ops/status.lua` (line 10-13) | 4 | `set_player_seat` — 写入 `player.seat_id` | **删除** 函数 |
| `src/player/actions/state_ops/location.lua` (line 89-91) | 3 | `clear_seat` 分支 — 调用 `set_player_seat(player, nil)` | **删除** 分支 |
| `src/app/compose_game.lua` (line 17, 32, 88) | 3 | `require vehicle_ops` / op 注册 / `vehicle_resync_seq = 0` 初始状态字段 | **删除** 3 处 |

**关于 `src/state/player_state.lua`**：第 2 行只含注释中的"vehicle"一词，无 seat_id 字段定义（seat_id 是玩家对象的动态字段，由 `set_player_seat` 写入）。删除 `set_player_seat` 后无新写入来源，可保留注释不改，也可顺手更新。

**引用方需同步修改**（删除对上述函数的调用）：

- `src/rules/effects/mine.lua`：删 `clear_seat = true`（line 121）、删 `had_vehicle` 分支（line 105）、删 `player_is_vehicle_indestructible`（line 98）
- `src/rules/items/demolish.lua`：删 `clear_seat = true`（line 67）
- `src/turn/phases/move.lua`（line 63）：删 `vehicle_id = vehicle_feature.resolve_seat_id(player.seat_id)`
- `src/rules/chance/handlers/common.lua`（line 103）：删 `vehicle_id = ...`

---

## 第 3 层：host bridge（GameAPI 代理 + runtime context）

| 文件 | 行数 | 内容 | 清理方式 |
|---|---|---|---|
| `src/host/vehicle.lua` | 227 | create / copy / destroy / enter / exit / move / stop / reset / get_driving_vehicle | **删除**（仅供测试通过 `runtime_ports.resolve_vehicle_helper()` 间接引用，无业务调用方） |
| `src/state/vehicle_runtime_source.lua` | 126 | `VEHICLE_RUNTIME_MODE` 解析 + `_build_none_helper` | **删除** |
| `src/host/context.lua` (line 84-106) | 23 | `_build_noop_vehicle_helper` | **简化**：原地展开 noop 字面量 |
| `src/host/context.lua` (line 108-125) | 18 | `_resolve_vehicle_helper_builder` — release 分支 vs vehicle_runtime_source 分支 | **删除**，固定返回 noop builder |
| `src/host/context.lua` (line 126, 175-179, 194, 206) | ~15 | ctx 初始化 / helpers 注入 / 全局写入 | **简化**：去掉 vehicle_helper 相关的条件分支和全局写入 |
| `src/host/default_ports.lua` (line 126-131) | 6 | `resolve_vehicle_helper()` 默认实现 | **删除** 函数（保留 runtime_ports 的端口定义不变，由上层 configure 注入 noop） |

**注意**：`runtime_ports.resolve_vehicle_helper()` 被 UI 层 4 处调用。如果端口无 configure，default_ports 中返回 nil → UI 层所有 `vehicle and vehicle.emit_...` 都是 nil 短路，天然安全。所以 default_ports 中的实现可以安全删除。

---

## 第 4 层：UI render 动画

### 4a. view 层

| 文件 | 行数 | 内容 | 清理方式 |
|---|---|---|---|
| `src/ui/view/gameplay_read_port.lua` (line 2, 25-33) | 10 | `vehicle_catalog` 引用 + `resolve_vehicle_seat_id` | **删除** 函数和 import |
| `src/ui/view/board_slice.lua` (line 90, 110) | 2 | `vehicle_resync_seq` 字段 | 写死 `0` 或删字段 |

### 4b. board render

| 文件 | 行数 | 内容 | 清理方式 |
|---|---|---|---|
| `src/ui/render/board/init.lua` (line 42, 45, 60, 68, 77) | 8 | `vehicle_resync_seq` 变量 + `board_last_vehicle_resync_seq` 持久化 | **删除**：去掉 resync_seq 相关逻辑，`compute_need_sync` 不再需要 vehicle_resync_seq 参数 |
| `src/ui/render/board/placement.lua` (line 22-25, 54, 66, 143-145, 156-157, 166-168, 181-195) | ~40 | 全部 stop_player_motion / emit_set_position / place_player_unit / sync 分支 | **删除**：所有 vehicle 参数和分支。`_place_player_unit` 退化回纯 `scene:set_unit_position` |
| `src/state/runtime.lua` (line 171) | 1 | `_ensure_field(board_runtime, "board_last_vehicle_resync_seq", ...)` | **删除** 字段同步行 |

### 4c. move_anim

| 文件 | 行数 | 内容 | 清理方式 |
|---|---|---|---|
| `src/ui/render/move_anim/sequence_builder.lua` (line 40-186) | ~55 | `is_vehicle_anim` / `is_vehicle_move_mode` / `is_vehicle_jump_mode` / `resolve_vehicle_seat_id` / `vehicle_helper_method` / `_calc_vehicle_step_time` / `consume_enter_delay` | **删除**：所有 vehicle 函数。`calc_step_time` 只剩 `_calc_walk_step_time` 调用 |
| `src/ui/render/move_anim/stop.lua` (line 88-92, 103-106, 113, 160-161, 174-176) | ~20 | `_set_player_position` vehicle 分支 / `stop_player_presentation` opts / `_on_anim_early_stop` | **删除** vehicle 分支，退化回纯 character 动画停止 |
| `src/ui/render/move_anim/playback.lua` (line 42-51, 68-69, 78, 107, 166) | ~15 | `is_vehicle_jump_mode` / `is_vehicle_move_mode` 分支 / `stop_vehicle` opts | **删除** vehicle 分支，退化回纯 walk 播放 |

---

## 第 5 层：events + runtime constants

| 文件 | 内容 | 清理方式 |
|---|---|---|
| `src/foundation/events/init.lua` | `market.bought_vehicle`（line 24）+ `vehicle` 事件组（line 39-48）共 8 个 | **删除** 事件定义 |
| `src/foundation/ports/runtime_ports.lua` (line 57-62) | `resolve_vehicle_helper()` 端口 | 保留端口定义（UI 层调用），删 default_ports 中的实现即可 |

**注意**：`vehicle` 事件组被 `src/host/vehicle.lua` 的 `_emit_event` 消费。host/vehicle.lua 删除后，事件组无生产方。

---

## 第 6 层：spec 测试

### 全量删除（4 个文件）

| 文件 | 行数 | 理由 |
|---|---|---|
| `spec/behavior/domain/vehicle_helper_spec.lua` | 353 | 专属 host/vehicle.lua 的 coverage spec，随源码同删 |
| `spec/behavior/domain/vehicle_runtime_source_coverage_spec.lua` | 155 | 专属 vehicle_runtime_source.lua，随源码同删 |
| `spec/behavior/runtime/misc_vehicle_runtime_source_spec.lua` | 28 | 同上，小型附属 spec |
| `spec/behavior/presentation/presentation_move_anim_teleport_and_vehicle_spec.lua` | — | 整个文件测试 vehicle 动画路径；sequence_builder 清理后无法运行 |

### 局部修改 — 业务 domain 层（10 个文件）

| 文件 | 修改点 |
|---|---|
| `spec/behavior/gameplay/choices/market_spec.lua` | 删 `_test_market_context_entry_name_vehicle_cfg` 测试（若文件仅剩此测试则整文件删） |
| `spec/behavior/domain/config_sanity_spec.lua` | 删 4 条 `rejects_vehicle` 测试（验证函数本身已删除） |
| `spec/behavior/domain/landing_spec.lua` | 删 `mine_landing_log_mentions_vehicle_when_present` 测试 |
| `spec/behavior/domain/chance_spec.lua` | 删 `set_vehicle == nil` 断言 |
| `spec/behavior/domain/paid_currency_spec.lua` | 删 `"vehicle_disabled"` 匹配分支 |
| `spec/behavior/domain/item_spec.lua` (line 1490-1492) | 删 `set_player_seat` seat_id 测试片段 |
| `spec/behavior/domain/move_phase_extended_coverage_spec.lua` | 删 vehicle 桩/resolve_seat_id 断言（约 22 处引用） |
| `spec/behavior/domain/runtime_ports_coverage_spec.lua` | 删 `resolve_vehicle_helper` 3 条测试（或改为 noop 断言） |
| `spec/behavior/domain/host_context_crap_coverage_spec.lua` | 删 vehicle_helper 断言 |
| `spec/behavior/domain/runtime_state_coverage_spec.lua` | 删 `board_last_vehicle_resync_seq` 字段断言 |

### 局部修改 — 表现层（4 个文件）

| 文件 | 修改点 |
|---|---|
| `spec/behavior/presentation/presentation_board_sync_spec.lua` | 删 `vehicle_resync_seq` / `seat_id` fixture 字段；删 `_test_board_refresh_stops_vehicle_before_vehicle_set_position` 测试块 |
| `spec/behavior/presentation/_presentation_action_status_status3d_spec.lua` | 删 fixture 中 `seat_id = nil` / `vehicle_resync_seq = 0` 字段（保留其它断言） |
| `spec/behavior/presentation/presentation_ui_event_bindings_spec.lua` (line 184) | 更新 market controls 数量断言（vehicle 条目移除后计数 -1） |
| `spec/behavior/runtime/misc_spec.lua` | 删 6 处 `ctx.vehicle_helper` 引用 |

### 局部修改 — gameplay（1 个文件）

| 文件 | 修改点 |
|---|---|
| `spec/behavior/gameplay/movement/obstacles_spec.lua` | 删 `same_tile_obstacle_chain_keeps_vehicle_log_text` 测试 |

### 局部修改 — guards（2 个文件）

| 文件 | 修改点 |
|---|---|
| `spec/guards/dep_rules_spec.lua` (line 79-80, 204, 266, 276) | 删 vehicle eggy-support 路径模式测试、`vehicle_helper` forbidden 模式测试、stale 路径条目测试 |
| `spec/guards/lib/dep_rules.lua` (line 127-128, 269, 335) | 同步删对应禁用规则条目 |

### 局部修改 — 测试支撑基础设施（8 个文件）

| 文件 | 修改点 |
|---|---|
| `spec/support/gameplay_suites/runtime/cases.lua` | 删 `seat_id = 4001` 测试用例、`vehicle_resync_seq` 检查块、`vehicle_helper` 桩注入 |
| `spec/support/gameplay_suites/shared/helpers.lua` (line 102, 284, 336-337) | 删 `vehicle_helper = nil` 默认值、`seat_id = 3` fixture 字段、`vehicle_id` 断言 |
| `spec/support/gameplay_suites/shared/misc_cases.lua` (line 49) | 更新 mine 测试描述字符串（不含 vehicle 词） |
| `spec/support/gameplay_suites/bankruptcy/cases.lua` (line 376) | 检查 `active_tab = "vehicle"` 测试用例：vehicle 市场条目删除后确认对应 tab 是否仍保留（若 tab 移除则改断言） |
| `spec/support/shared_support.lua` (line 141, 153) | 删 `vehicle_helper` 传递字段 |
| `spec/support/test_env.lua` (line 127-130) | 删 `vehicle_helper` 注入逻辑分支 |
| `spec/support/test_profile_support.lua` (line 119, 132) | 删 `vehicle_resync_seq = 0` 初始值、`board_last_vehicle_resync_seq` 同步行 |
| `spec/env_runtime.lua` (line 23) | 删 `vehicle_helper = vehicle_helper` 字段 |

### 局部修改 — tooling（1 个文件）

| 文件 | 修改点 |
|---|---|
| `spec/support/tooling_suites/architecture/script_tools_contract.lua` (line 692-693) | 删 `"vehicle-runtime"` 旗标合约测试 |

---

## 第 7 层：架构守卫规则同步

| 文件 | 位置 | 操作 |
|---|---|---|
| `tools/quality/arch/config.json` | line 39，`infrastructure_runtime_bridges` 组的 `match` 数组 | **删除** `"^src%.rules%.vehicle$"` 条目 |

`infrastructure_runtime_bridges` 的另外两个条目（`^src%.config%.content%.runtime_refs$` 和 `^src%.config%.gameplay%.runtime_constants$`）不受影响：`runtime_constants.lua` 仅删除 4 行 vehicle 常量，文件本身保留。

**必须与 Phase 2 同步执行**：删除 `src/rules/vehicle.lua` 后若不同步删此条目，`lua tools/quality/lint.lua` 的 arch 守卫会报"规则有白名单条目但无匹配文件"错误（或等价的 unmatched pattern 错误），导致 CI 失败。

---

## 清理顺序

按依赖从底层到上层排列，同层可并行：

```
Phase 1  (config 数据 + sanity guard)
  └── 删 src/config/content/vehicles.lua
  └── 删 src/config/gameplay/vehicle_catalog.lua
  └── 改 src/config/gameplay/runtime_constants.lua（删 4 行 vehicle 常量）
  └── 改 src/config/gameplay/config_sanity.lua（删 _validate_data_has_no_vehicle_content）

Phase 2  (fsm / state ops + arch config 同步)
  └── 删 src/rules/vehicle.lua
  └── 改 tools/quality/arch/config.json（同步删除白名单条目，必须与上行同步）
  └── 删 src/player/actions/state_ops/vehicle.lua
  └── 改 src/player/actions/state_ops/status.lua（删 set_player_seat）
  └── 改 src/player/actions/state_ops/location.lua（删 clear_seat 分支）
  └── 改 src/app/compose_game.lua（删 vehicle_ops require/注册/初始状态字段）

Phase 3  (effects / turn / chance — 依赖 state ops)
  └── 改 src/rules/effects/mine.lua
  └── 改 src/rules/items/demolish.lua
  └── 改 src/turn/phases/move.lua
  └── 改 src/rules/chance/handlers/common.lua

  ⚑ 里程碑：busted --run smoke（core 回归确认）

Phase 4  (host bridge)
  ⚑ 覆盖率 dry-run：执行前先跑 lua tools/quality/coverage.lua，记录当前 host_bridge 基线
  └── 删 src/host/vehicle.lua
  └── 删 src/state/vehicle_runtime_source.lua
  └── 改 src/host/context.lua
  └── 改 src/host/default_ports.lua

Phase 5  (events)
  └── 改 src/foundation/events/init.lua

Phase 6  (UI + runtime state 同步)
  └── 改 src/ui/view/gameplay_read_port.lua
  └── 改 src/ui/view/board_slice.lua
  └── 改 src/ui/render/board/init.lua
  └── 改 src/ui/render/board/placement.lua
  └── 改 src/ui/render/move_anim/sequence_builder.lua
  └── 改 src/ui/render/move_anim/stop.lua
  └── 改 src/ui/render/move_anim/playback.lua
  └── 改 src/state/runtime.lua（删 board_last_vehicle_resync_seq 同步行）

Phase 7  (spec + guards + tooling)
  └── 删 4 个 vehicle 专属 spec（见 §第 6 层）
  └── 改 26 个关联 spec（见 §第 6 层，含 guards / support / env 文件）
```

---

## 存档兼容性

旧档中残留的 `player.seat_id` 字段在清理后的行为：

- 所有 `catalog.find(seat_id)` 调用在 Phase 1 后总是返回 nil（catalog 已删除）
- `set_player_seat` 在 Phase 2 后不再写入新的 seat_id
- 既有存档载入后，seat_id 成为玩家对象上的孤儿字段，不影响任何逻辑路径（所有消费方已清理）

**风险**：目前**无回归测试**覆盖"载入含 seat_id 的旧档后跑 turn 流程不崩溃"的场景。

**建议**：在 Phase 7 完成后，补充一条回归测试（测试设计如下）：

```lua
-- 注入含 seat_id 的玩家状态，模拟旧存档载入
it("old_save_with_seat_id_survives_full_turn", function()
  local state = build_default_state()
  state.players[1].seat_id = 4001  -- 旧存档残留
  -- 跑完整回合流程（roll → move → land）
  -- 断言：不崩溃，seat_id 字段被忽略
end)
```

---

## 覆盖率核算

相关配置：
- 总体门槛：`tools/quality/coverage.lua:11` → `threshold = 90`
- host_bridge tier：`tools/quality/crap/coverage_tiers.lua:18-19` → `threshold = 0.60`

Phase 4 删除文件体积：
- `src/host/vehicle.lua`：234 行（占 `src/host/` 目录总行数 2062 的 ~11%）
- `spec/behavior/domain/vehicle_helper_spec.lua`：353 行（专属 coverage spec）

预估影响：vehicle.lua 被其专属 spec 充分覆盖，同时删除源码和 spec 后分子/分母同步下降，host_bridge tier 覆盖率百分比变化接近零或略有提升（若 vehicle.lua 存在部分未覆盖行）。

**必做检查点**（Phase 4 开始前）：

```bash
lua tools/quality/coverage.lua --threshold=60  # 记录 host_bridge 当前基线
```

删除 Phase 4 文件后再次运行，确认 host_bridge tier 仍 ≥ 60%，整体仍 ≥ 90%，再继续 Phase 5。

---

## 不清理的范围

- `dice_count` 业务语义：当前 `player_dice_count` 回退到 `default_dice_count = 1`（`src/config/content/constants.lua:3`）。如果后续需要可变骰子数，应重新设计成独立于"载具"概念的渠道
- `indestructible` 语义：当前只有 3 辆载具用了这个标记。删除后 mine effect 的 `player_is_vehicle_indestructible` 必然返回 false，行为等同于无免疫
- 旧存档中的 `player.seat_id`：残留字段不影响行为（所有消费路径已短路），见 §存档兼容性 的处理说明
