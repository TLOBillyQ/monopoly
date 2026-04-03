# src/ 综合优化设计

日期：2026-04-03

## 背景

### 现状指标

- `src/`：359 个 Lua 文件，约 30,912 行
- 架构边界：`arch.lua check` 通过，七层清洁架构
- CRAP 热点：最高 16.22（post_effects:_walk_and_clear_obstacles），无 critical 级别（>30）
- LOC 趋势：近期稳中微增（+477 行 / +1.6%）

### 用户痛点

landing 连续触发时，部分特效被吃掉或播放时序不对。根因：

1. `board_feedback_service` 的特效完全绕过 `landing_visual_hold`，hold 期间特效直接播放但 UI 被冻结
2. `action_anim` handler 是 fire-and-forget，返回估计时长但不追踪完成
3. `action_anim_done` 信号无超时保护
4. 无队列感知加速：3 人收租 = 6 个动画 x 2.0s = 12 秒纯等待
5. `timing.lua` 中 `event_tip_fast_seconds` / `event_tip_fast_backlog_threshold` 已定义但从未使用

### 大文件集中区

| 文件 | 行数 | 函数数 | 平均行/函数 |
|------|------|--------|------------|
| choice_handler_factory.lua | 622 | 51 | 12.2 |
| board/init.lua | 464 | 35 | 13.3 |
| post_effects.lua | 447 | 18 | 24.8 |
| logger.lua | 420 | 45 | 9.3 |
| landing_visual_hold.lua | 400 | 42 | 9.5 |

---

## 方案概览

分三个批次，每批独立可交付：

| 批次 | 主题 | 新增文件 | 修改文件 |
|------|------|---------|---------|
| P1 | 特效时序 + 队列加速 | 3 | 8 |
| P2 | 大文件精简 | 6 | 5 |
| P3 | CRAP 收尾 | 0 | ~12 |

---

## P1：特效时序修复 + 队列加速

### 问题根因

三条独立通路互不协调：

- 通路 A：`action_anim` -> handler fire-and-forget -> `board_feedback.play_*()` — 不走 landing_visual_hold
- 通路 B：`landing_visual_hold.register_release_callback()` -> 延迟到 release 时执行 — 正确路径，但 board_feedback 不走这里
- 通路 C：`effect_timeline.play()` -> schedule 各 step — 轻量调度，无完成追踪

### 方案：引入 EffectTrack

在 `src/ui/render/support/` 新增 `effect_track.lua`，三个职责：

#### 职责一：Token 生命周期追踪

```
effect_track
  spawn(id, kind, duration, on_complete?) -> token
  complete(token)
  cancel(token)
  await_all(callback)
  is_idle()
```

特效播放时产生 token，可被显式 complete 或超时自动 complete。外部可 `await_all()` 等待所有活跃 token 完成。

#### 职责二：队列感知加速

```
effect_track
  pressure()            -> 0~1，当前队列压力值
  scaled_duration(base) -> 根据 pressure 缩放后的时长
```

加速策略：

| 队列深度 | pressure | 时长缩放 | 行为 |
|----------|----------|----------|------|
| 0-1 | 0 | 1.0x (2.0s) | 正常播放 |
| 2-3 | 0.3 | 0.5x (1.0s) | 加速播放 |
| 4-6 | 0.6 | 0.25x (0.5s) | 快速闪过 |
| 7+ | 0.9 | 0.15x (0.3s) | 极速 + 合并同类 |

#### 职责三：同类特效合并

```
effect_track
  coalesce_policy = { cash_receive = "sum" }
```

当 pressure >= 0.6 时，队列中连续的同类 `cash_receive` 合并为一个：

- amount 求和
- 只播一次 cash_burst 特效，显示总金额
- 例：3 笔收租 +100, +150, +200 -> 合并为 1 笔 +450

#### 不做的事

- 不做 Unity Timeline 级别的完整轨道/编辑器系统
- 不改 Eggy 底层调度，继续用 `host_runtime.schedule()`
- 不改 landing_visual_hold 的 priority 机制，只在 release 流程中接入 effect_track

### 改动清单

| 文件 | 改动 |
|------|------|
| **新增** `src/ui/render/support/effect_track.lua` | token + pressure + coalesce |
| `src/ui/render/board_feedback_service.lua` | `_play_effect` / `_play_cue` 走 `run_or_defer` + 产生 track token |
| `src/ui/render/action_anim.lua` | 播放前查 `scaled_duration()`；handler 返回 token |
| `src/core/utils/tip_queue.lua` | 激活已有的 `fast_backlog_threshold` 逻辑，用 `pressure()` 驱动 |
| `src/player/actions/state_ops/balance_ops.lua` | `_queue_cash_anim` 写入 amount 到 payload，供合并用 |
| `src/turn/waits/await/action_anim_wait.lua` | 出队前调 coalesce 合并同类；加超时兜底 |
| `src/state/state_access/landing_visual_hold.lua` | release 后接入 `effect_track.await_all()` |
| `src/turn/phases/land/resolve.lua` | wait chain 接入 effect_track |

### 拆分 post_effects.lua

- `post_effects.lua` 保留入口 dispatch 逻辑（~250 行）
- 提取 `obstacle_clear.lua`：`_walk_and_clear_obstacles` 及相关 tree-walk 逻辑
- 递归回调改为迭代 + token 追踪（与 EffectTrack 集成）

### 拆分 landing_visual_hold.lua

- `landing_visual_hold.lua` 保留 start/release/should_defer 核心流程（~200 行）
- 提取 `deferred_dirty.lua`：dirty 累积与合并逻辑
- 提取 `release_scheduler.lua`：回调排序与 flush 逻辑

---

## P2：大文件精简

### choice_handler_factory.lua（622 行 -> ~80 行）

按 choice 领域分组提取：

| 提取目标 | 内容 | 估计行数 |
|----------|------|----------|
| `choice_handlers/market.lua` | 购买、升级、市场分页 handler | ~150 |
| `choice_handlers/item.lua` | 道具使用、目标选择、slot handler | ~180 |
| `choice_handlers/land.lua` | 地块效果选择、过路费 handler | ~120 |
| `choice_handler_factory.lua` | 保留入口：加载子模块 + register 调用 | ~80 |

原则：

- 每个子模块导出 `register(registry)` 函数
- factory 只负责调用各子模块的 register
- handler 函数签名不变，不影响调用方

### board/init.lua（464 行 -> ~280 行）

| 提取目标 | 内容 | 估计行数 |
|----------|------|----------|
| `board/direction.lua` | `_pick_unique_dir`, `_resolve_backward_from_neighbors`, `_resolve_fallback_next` 等方向解析 | ~130 |
| `board/init.lua` | 保留 Board 类核心：拓扑初始化、tile 查询、路径接口 | ~280 |

收益：方向解析是 CRAP 热点集中区（3 个 crap=12 函数），拆出后可独立补测试。

### logger.lua（420 行 -> ~150 行）

| 提取目标 | 内容 | 估计行数 |
|----------|------|----------|
| `utils/log_queue.lua` | 缓冲队列、flush 策略、容量管理 | ~120 |
| `utils/log_formatter.lua` | 格式化、分类、级别过滤 | ~100 |
| `utils/logger.lua` | 保留公共 API 入口 | ~150 |

### P2 汇总

| 文件 | 原始行数 | 拆分后主文件 | 提取模块数 |
|------|----------|------------|-----------|
| choice_handler_factory | 622 | ~80 | 3 |
| board/init | 464 | ~280 | 1 |
| post_effects | 447 | ~250 | 1 (P1) |
| logger | 420 | ~150 | 2 |
| landing_visual_hold | 400 | ~200 | 2 (P1) |

---

## P3：CRAP 收尾

### 降复杂度

| 函数 | crap | complexity | coverage | 手段 |
|------|------|-----------|----------|------|
| `post_effects:_walk_and_clear_obstacles` | 16.22 | 16 | 0.90 | P1 已拆分 + 递归改迭代，预计降至 complexity <= 8 |
| `visual_sync:sync_tile_visual` | 11.18 | 11 | 0.89 | 提取条件分支为子函数（`_sync_owner_visual`, `_sync_overlay_visual`） |
| `status:resolve_player_status_key` | 11.00 | 11 | 0.97 | 状态映射表替代 if-else 链 |
| `timer_policy:update_action_button_timer` | 9.51 | 9 | 0.81 | 提取定时器状态判断为 guard 函数 |

### 补覆盖率

| 函数 | crap | complexity | coverage | 手段 |
|------|------|-----------|----------|------|
| `host_install:M.install` | 12.00 | 3 | 0.00 | 宿主装配函数，加 contract 级集成测试 |
| `resolver:_contains` | 12.00 | 3 | 0.00 | 纯工具函数，加单元测试 |
| `board:_pick_unique_dir` | 12.00 | 3 | 0.00 | P2 拆到 direction.lua 后补测试 |
| `board:_resolve_backward_from_neighbors` | 12.00 | 3 | 0.00 | 同上 |
| `board:_resolve_fallback_next` | 12.00 | 3 | 0.00 | 同上 |
| `vehicle_runtime_source:_resolve_module` | 12.00 | 3 | 0.00 | 动态模块解析，加 behavior 测试 |
| `validator:_validate_item_slot_action` | 12.00 | 3 | 0.00 | 校验逻辑，加 behavior 测试 |
| `mine_effect:_find_pending_roadblock_trigger` | 11.76 | 8 | 0.61 | 补 2-3 个边界用例 |
| `validator:_resolve_item_slot_resolution` | 10.92 | 6 | 0.48 | 同 validator，一并补测试 |
| `anchors:_find_owner_name` | 10.75 | 4 | 0.25 | 新增函数，补 behavior 测试 |
| `sequence_builder:resolve_direction` | 10.75 | 4 | 0.25 | P1 修改后一并补测试 |

### 预期效果

| 指标 | 当前 | P3 后目标 |
|------|------|----------|
| CRAP >= 12 的函数数 | 8 | 0 |
| CRAP >= 10 的函数数 | 15 | <= 3 |
| coverage=0 的 src 函数 | 6 | <= 1（host_install 可能仍难覆盖） |

---

## 批次依赖与执行顺序

```
P1（特效时序）──┐
               ├──> P3（CRAP 收尾）
P2（文件精简）──┘
```

- P1 和 P2 可并行执行，部分共享文件（post_effects, landing_visual_hold）但改动不冲突
- P3 依赖 P1/P2 的拆分先完成——拆分后的小文件更容易补测试和降复杂度
- 每个批次内的改动建议小步提交，每次拆分或补测试独立一个 commit

## 验证策略

每个批次完成后运行：

```
lua tests/behavior.lua      # UI 行为回归
lua tests/contract.lua       # 边界与契约
lua tools/quality/arch.lua check  # 架构边界
lua tools/quality/crap.lua report --out tmp/crap_report.json --top 20  # CRAP 热点确认下降
```
