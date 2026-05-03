# T2: 神仙状态卡生命周期审计 (tick + 调用点)

> 审计范围：`tick_player_deity` 实现、调用点、相对回合阶段顺序、与 Q1 规格 "5 own turns" 的对齐。
> 不涉及：apply-sites (T1)、clear-sites (T3)、读取站点（T4 等）。

---

## 1. tick 调用图

### 1.1 实现位置

- `src/player/actions/state_ops/deity_ops.lua:41-54` — `deity_ops.tick_player_deity(self, player)` 唯一定义。

```
41: function deity_ops.tick_player_deity(self, player)
42:   local status = common.player_status_table(player)
43:   status.deity = status.deity or { type = "", remaining = 0 }
44:   local deity = status.deity
45:   if deity.remaining <= 0 then
46:     return
47:   end
48:   deity.remaining = deity.remaining - 1
49:   if deity.remaining <= 0 then
50:     self:clear_player_deity(player)
51:     return
52:   end
53:   common.mark_players(self)
54: end
```

### 1.2 全部调用点（生产代码）

经 `grep -r "tick_player_deity" src/` 排查，生产代码中**唯一调用点**：

- `src/turn/phases/registry.lua:60` — 在 `_phase_end(turn_mgr, args)` 内：
  ```
  60:   turn_mgr.game:tick_player_deity(player)
  ```

测试调用点（spec/）：`spec/behavior/domain/deity_ops_coverage_spec.lua:148, 155, 164, 173`，仅作单元覆盖，不影响生产生命周期。

### 1.3 调用图（文字版）

```
turn loop
└── _phase_end(turn_mgr, args)                       [registry.lua:51]
    ├── player := args.player                        [registry.lua:52]   ← 当前回合 player
    ├── event_feed.publish(turn_end ...)             [registry.lua:55-59]
    ├── tick_player_deity(player)                    [registry.lua:60]   ← ★ 唯一 tick 点
    ├── clear_player_temporal_flags(player)          [registry.lua:61]
    ├── stop_all_players_movement()                  [registry.lua:62]
    └── ... inter_turn_wait / next_player ...        [registry.lua:68-77]
```

`_phase_end` 在 `build_default_phases()` 注册为 `end_turn` 阶段（`registry.lua:89`），即**每位玩家每次回合结束时**都会进入此阶段。

---

## 2. tick 顺序与本回合 effect 的相对位置

回合阶段的注册顺序（`registry.lua:80-91`）：

```
start → roll → pre_move → move → move_followup → landing → post_action → end_turn
```

- 房租结算、机会卡、地块效果均发生在 `landing`（`turn_land.run`）与 `post_action`（`_phase_post`，`registry.lua:37-49`）阶段，**早于** `end_turn`。
- `tick_player_deity` 位于 `end_turn` 内，且在 `event_feed.publish(turn_end ...)` 之后、`clear_player_temporal_flags` 之前（`registry.lua:60`）。

**结论：本回合所有读取神仙状态的 effect（如 `player_has_angel` 用于房租减免、机会卡判定）都在 tick 之前发生。** 即"本回合仍享受神仙效果，回合末才扣减剩余次数"。这一相对顺序与 Q1 规格的"按回合数计数"语义一致，无 off-by-one 问题。

### 2.1 tick 内部 off-by-one 检查

- 入口处 `remaining <= 0 → return`（`deity_ops.lua:45-47`），不会从 0 再减到 -1。
- 先减 1（`deity_ops.lua:48`），再判定 `<= 0` 触发 clear（`deity_ops.lua:49-52`）。
- 因此当 `remaining` 由 1 减到 0 时立即 `clear_player_deity`，将 `type` 置空、`remaining = 0`（参见 `deity_ops.lua:18-24`）。
- `player_has_deity` 判定要求 `deity.type == name and deity.remaining > 0`（`deity_ops.lua:11`），与 clear 后的零态一致，不会出现"类型已空但 remaining 仍 >0" 的窗口。

**tick 自身实现：WORKING。**

---

## 3. 规格对齐分析

### 3.1 Q1 规格摘录

> 神仙状态卡的 duration 单位为"5 own turns"——即只在**该神仙持有者本人的回合**结束时才递减一次剩余次数。

### 3.2 代码现状

- `_phase_end` 接收的 `player` 是**当前回合的玩家**（`registry.lua:52: player = args.player`，由 `next_player()` 流转得来）；调用 `tick_player_deity(player)` 时只对该玩家自身的 `status.deity` 做减一。
- `_phase_end` 本身**对所有玩家都会触发**：每次 `next_player()` 切换后，新玩家走完 `start → ... → end_turn` 流水线，都会进入 `_phase_end`。
- 但 `tick_player_deity` 的参数 `player` 始终是"当前在回合中的玩家"，即只对**当前回合玩家自己**减计；其他玩家的神仙剩余次数不会因为别人的回合结束而变化。

### 3.3 与 `own_turn_started_count` 的对照

代码库已有 "own turn" 概念基础设施：

- `src/player/actions/player.lua:32` — 默认值 `own_turn_started_count = 0`。
- `src/turn/phases/start.lua:38-42, 114` — `_increment_own_turn_started_count` 在 `_phase_start` 中只对 `current_player()` 自增。
- 用例：`src/rules/effects/mine.lua:73-76`、`src/rules/items/post_effects.lua:243` 据此实现"自身回合数"语义。

`tick_player_deity` 通过"只对当前回合 player 调用"达到了同样的效果——**每位玩家的 deity.remaining 只在他自己回合的 end_turn 阶段减 1**，与 `own_turn_started_count` 在 `start.lua:114` 只对自身自增的语义对称。

### 3.4 论证

考察玩家集合 P = {A, B, C, D}。设 A 在某回合结束时持有 `remaining = 5` 的神仙。回合时间线如下：

| 时刻 | 当前 player | `_phase_end.player` | 对 A.deity.remaining 的影响 |
|------|-------------|---------------------|------------------------------|
| t0 | A (本回合) | A | 5 → 4（`registry.lua:60`，参数 = A） |
| t1 | B | B | 不变（参数 = B，`tick_player_deity(B)` 只读 B.status.deity） |
| t2 | C | C | 不变 |
| t3 | D | D | 不变 |
| t4 | A (下一轮) | A | 4 → 3 |
| t5..t7 | B,C,D | — | 不变 |
| t8 | A | A | 3 → 2 |
| t12 | A | A | 2 → 1 |
| t16 | A | A | 1 → 0 → clear |

A 的神仙总共历时 **5 个 A 自己的回合**才到期，与 Q1 规格 "5 own turns" 完全一致。

关键依据：
- `tick_player_deity(self, player)` 参数 `player` 来自 `_phase_end` 的 `args.player`（`registry.lua:52, 60`），而 `args.player` 由调度器在每次 `next_player()` 后传入新当前玩家。
- 函数内部 `local status = common.player_status_table(player)`（`deity_ops.lua:42`）只读写**该 player 自己**的 status，不访问其他玩家的 deity。
- 因此即使 `_phase_end` 在每位玩家的回合末都触发，**别人的回合不会减少 A 的 deity.remaining**。

### 3.5 分类

**WORKING** — `tick_player_deity` 在 `_phase_end` 中被调用，参数恒为当前回合玩家；由此实现"5 own turns"语义，与 Q1 规格对齐，且与 `own_turn_started_count` 的"自身回合"概念在结构上一致。

---

## 4. 相邻风险（仅记录，不在本任务修复范围）

- ⚠ **被扣留 (`stay_turns > 0`) 仍会进入 `_phase_end` 吗？** 见 `start.lua:124` 直接 `return _configure_detained_wait(...)`，最终经 `detained_wait` 状态走到 `end_turn`（`start.lua:78`），意味着**被扣留回合也算 1 个 own turn**，会消耗 1 点神仙剩余。是否符合 Q1 规格需 PM 确认（NEEDS-SPEC，留给 T6 整合阶段）。
- ⚠ **出局玩家** (`player.eliminated`) 在 `_skip_eliminated_player`（`start.lua:44-51`）后直接跳到 `end_turn`，同样会触发一次 `tick_player_deity`，对已出局玩家来说无业务影响但行为存在（SUSPICIOUS，超出 T2 范围）。

以上两点不影响 T2 主结论，仅供 T6 汇总参考。

---

## 5. 结论汇总

| 子项 | 分类 | 关键引用 |
|------|------|----------|
| `tick_player_deity` 实现正确性（off-by-one、clear 时机） | WORKING | `deity_ops.lua:41-54`、`deity_ops.lua:11, 18-24` |
| 调用点完备性（仅 `_phase_end`） | WORKING | `registry.lua:60`，全 `src/` 仅此一处 |
| tick 与本回合 effect 的相对顺序 | WORKING | `registry.lua:80-91`（end_turn 在 landing/post_action 之后） |
| 与 Q1 "5 own turns" 规格对齐 | WORKING | `registry.lua:52, 60` + `deity_ops.lua:42` 论证见 §3.4 |
| 被扣留/出局回合是否算 own turn | NEEDS-SPEC | `start.lua:44-51, 123-124`，留给 T6 |

T2 静态审计结论：**生命周期主路径 WORKING**。

---

## 6. 未审查清单

以下相关代码本次未覆盖，不影响主结论，供后续参考：

- `src/turn/phases/start.lua` 完整流程（仅抽查了 detained/eliminated 分支，未全量审计）
- `src/turn/phases/` 其余阶段文件（pre_move、landing、post_action 等）与 deity tick 的交互
- cheat / debug 入口是否有直接操控 `remaining` 的路径
- 测试 fixture 中对 `tick_player_deity` 的 stub/mock 是否与真实行为一致
- save/load 序列化对 `status.deity.remaining` 的保存与恢复（Q3 已排除，仅记录）
