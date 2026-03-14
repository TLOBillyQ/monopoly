# Monopoly Game Engine 架构分析

Lua 实现的大富翁游戏引擎，~366 文件，支持多人 + AI。

---

## 核心架构模式

| 模式 | 文件 | 职责 |
|-----|------|-----|
| Composition Root | `src/entry/compose_game.lua` | 组装 board、players、RNG、registries，初始化 tile state |
| Dirty Tracking | `src/core/utils/dirty_tracker.lua` | 追踪 players/board/turn/market/inventory 变化，批量 UI 更新 |
| Coroutine Scheduler | `src/turn/timing/init.lua` | 每回合一个 coroutine，yield 等待输入，维护 wait states |
| Registry | `src/rules/bootstrap/registries.lua` | Effect/Choice/Item/Chance 注册中心 |

---

## 目录结构

### `/src/state/` - 游戏状态
- `game_state.lua`：Game class（mixin player/board/turn operations）
- `board_state.lua`：tile ownership、upgrades、roadblocks、mines
- `player_state.lua`：status、balance、deity、vehicle、location
- `turn_state.lua`：animation queues、pending choices

### `/src/entry/`
- `start_game.lua`：role resolution、synthetic AI players
- `compose_game.lua`：composition root
- `game_factory.lua`：board、players、RNG factory

### `/src/turn/`

**Phase Pipeline**：start → roll → move → move_followup → landing → post_action → end_turn

**Scheduler** (`src/turn/loop/scheduler_runtime.lua`)：coroutine-based，session factory per turn，action router 转 signals

### `/src/rules/`

**Board** (`src/rules/board/init.lua`)：directional movement with facing，branch handling，roadblock/mine overlay

**Items** (20+ cards，3 tiers)：
- T1：Free Card、Remote Dice、Dice Multiplier、Roadblock、Mine、Clear Obstacles
- T2：Steal、Monster、Strong、Tax Free、Share Wealth、Exile
- T3：Missile、Tax Audit、Invite Deity、Send Poor God、Rich God、Poor God、Angel

Key files：`handlers.lua`、`phase.lua`（pre_action/pre_move/post_action）、`strategy.lua`（AI）、`executor.lua`

**Movement**：step-by-step encounter detection，roadblock collision，market/steal interrupts，facing persistence

**Effects Pipeline**：`effect_pipeline.lua`（orchestrate mandatory/optional）→ `effect_runner.lua`（scan/execute）→ `effect_registry.lua`

### `/src/config/`
- `tiles.lua`：47 tiles（34 land：福州路~上海路 1000-5000，special：Start/Hospital/Mountain/Tax/Market/Chance/Item）
- `items.lua`：tier/pricing/timing
- `market.lua`：currencies（金币、金豆、乐园币）
- `gameplay_rules.lua`：timings、phase queue、feature flags、turn limit（1000）

### `/src/ui/`
- **Input**：`intent_dispatcher.lua`、`touch_policy.lua`、`input_lock_policy.lua`、`role_control_lock_policy.lua`
- **Render**：`canvas_render_pipeline.lua`、`board/`、anim handlers（dice/movement/actions/tip）
- **Stores**：`canvas_store.lua`、`ui_runtime/`、`modal_state.lua`
- **Controllers**：`ui_runtime.lua`、`modal_controller.lua`、`popup_controller.lua`、`item_slots.lua`

### `/src/core/`
- `dirty_tracker.lua`、`logger.lua`、`number_utils.lua`、`runtime_ports.lua`

### `/src/host/eggy/` - Eggy 平台集成
`context.lua`、`paid_purchase_gateway.lua`、`synthetic_actor_registry.lua`

---

## 核心机制

| 机制 | 说明 |
|-----|-----|
| 三货币 | 金币（primary）、金豆（premium）、乐园币（shop） |
| Deities | 财神（rent x2）、穷神（rent x2）、天使（免疫负面） |
| Item Timing | pre_action/pre_move/post_action/manual/pass_player |
| Contiguous Rent | 相邻 property 倍率，最高 5x |
| Interrupts | Market/Steal/Roadblock 中断移动 |

---

## Data Flow

```
Scheduler → Turn Phase → Effect Pipeline → Intent Output → UI Render → Player Input → Game Action → [Loop]
```

State Change：`Mutation → Dirty Tracker → Canvas Store → Render Pipeline → Runtime UI`

---

## 技术细节

**Class System**：`Class("Name")` → `init()` → `new()`

**Event**：`monopoly_events.lua`（movement/land/market/chance/feedback/game/intent）→ `runtime_ports.emit_event()`

**Animation**：Queued sequential execution，gate ports 控制 wait

---

## 设计决策

1. **Coroutine-Based**：yield for animations/input，无 callback hell
2. **Dirty Tracking**：仅更新 changed domains
3. **Effect Pipeline**：definition/scanning/execution 分离
4. **Registry**：core code 不修改即可扩展
5. **Intent-Based UI**：separation of concerns
6. **Platform Abstraction**：Host ports 支持多平台

---

原文件 381 行 → 精简后 95 行 (-75%)
