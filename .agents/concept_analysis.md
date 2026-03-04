# Monopoly 项目概念一致性分析报告

## 方法论声明

本分析采用分析哲学的方法论：
1. **概念分析** - 澄清每个概念的必要和充分条件
2. **逻辑一致性** - 检查概念间的逻辑关系是否自洽
3. **本体论分类** - 区分实体、属性、事件、过程
4. **语言分析** - 识别命名混淆和同义词问题

---

## 第一部分：核心概念清单

### 一、领域本体论（Domain Ontology）

#### 1.1 实体（Substances/Entities）

实体是独立存在的对象，具有持久身份。

| 实体 | 身份标识 | 核心属性 | 存在周期 |
|------|----------|----------|----------|
| **Player** | player.id | role_id, name, is_ai, seat_id | 游戏生命周期 |
| **Tile** | tile.id (数组索引) | type, name, row, col | 游戏生命周期 |
| **Board** | 单例 | path[], tile_lookup | 游戏生命周期 |
| **Item** | item.id (配置定义) | name, tier, timing, usage | 永久（配置） |
| **ChanceCard** | card.id (配置定义) | weight, negative, effect | 永久（配置） |
| **Game** | 单例 | players[], board, turn | 游戏生命周期 |

#### 1.2 属性（Attributes/Properties）

属性是依附于实体的特征，不能独立存在。

| 属性 | 宿主实体 | 值类型 |  mutable |
|------|----------|--------|----------|
| **position** | Player | integer (tile index) | 是 |
| **cash** | Player | integer | 是 |
| **status** | Player | table (复合状态) | 是 |
| **level** | Tile | integer (建筑等级) | 是 |
| **owner_id** | Tile | string (player.id) | 是 |
| **phase** | Turn | string | 是 |
| **eliminated** | Player | boolean | 是 |

**status 复合结构分析**：
```lua
status = {
  stay_turns = integer,        -- 扣留回合数
  deity = string,              -- 财神/穷神/天使
  deity_duration_turns = integer,
  pending_remote_dice = boolean,
  pending_dice_multiplier = integer,
  pending_free_rent = boolean,
  pending_tax_free = boolean,
}
```

#### 1.3 事件（Events）

事件是时间中的发生，具有瞬间性。

| 事件 | 触发条件 | 参与者 | 效果 |
|------|----------|--------|------|
| **Roll** | 玩家投骰 | Player | 产生随机步数 |
| **Move** | Roll之后 | Player | 改变position |
| **Land** | Move到达目标 | Player, Tile | 触发地块效果 |
| **Purchase** | 玩家决策 | Player, Tile | 转移所有权 |
| **Upgrade** | 玩家决策 | Player, Tile | 增加level |
| **Elimination** | cash < 0 | Player | 设置eliminated |

#### 1.4 过程（Processes）

过程是延展在时间中的活动，由多个阶段组成。

| 过程 | 阶段序列 | 持续时间 |
|------|----------|----------|
| **Turn** | start → roll → move → landing → post_action → end_turn | 可变 |
| **ItemPhase** | pre_action / pre_move / post_action | 即时 |
| **Movement** | 逐格移动，经过路障检查 | 动画时间 |

---

### 二、架构概念分析

#### 2.1 端口/接口（Ports）

端口定义系统边界，是依赖倒置的关键。

**RuntimePorts**（核心→外部）：
- `rng_next_int` - 随机数生成
- `schedule` - 延迟执行
- `resolve_role` - 角色解析
- `emit_event` - 事件发射
- `wall_now_seconds` - 墙上时钟

**PresentationPorts**（表现层→核心）：
- `modal` - 模态窗口
- `anim` - 动画控制
- `ui_sync` - UI状态同步
- `clock` - 时钟服务

#### 2.2 注册表模式（Registry Pattern）

注册表是管理映射关系的组件。

| 注册表 | 键类型 | 值类型 | 一致性评价 |
|--------|--------|--------|------------|
| **EffectRegistry** | effect_id | executor对象 | 符合模式 |
| **ChoiceRegistry** | kind | handler函数 | 符合模式 |
| **ItemRegistry** | item_id | handler函数 | 符合模式 |
| **PhaseRegistry** | phase_name | phase函数 | 符合模式 |

**⚠️ 命名不一致**：
- `EffectRegistry` 使用 Class 风格
- `ChoiceRegistry` 使用 Class 风格
- `ItemRegistry` 使用 Class 风格
- `PhaseRegistry` 使用 module 风格（无Class）
- `ChanceHandlers` 使用 module 风格，但命名为Handlers而非Registry

#### 2.3 处理器/解析器/执行器（Handler/Resolver/Executor）

这三者区分模糊，需要澄清：

| 类型 | 职责 | 输入 | 输出 | 示例 |
|------|------|------|------|------|
| **Handler** | 处理请求 | request | response/void | ItemHandlers, CashHandlers |
| **Resolver** | 解析决策 | context | decision | ChanceResolver, LandRentResolver |
| **Executor** | 执行效果 | effect_spec | side effects | EffectExecutor, LandingEffectExecutors |

**⚠️ 概念混淆**：
1. `ChanceHandlers` 实际上是Registry（汇集handlers）
2. `LandingEffectExecutors` 是Registry，但命名为Executors
3. `EffectExecutor` 是验证器，不是执行器

---

### 三、状态管理概念

#### 3.1 状态分层

```
GameState (核心状态)
├── players: Player[]
├── board: Board
├── turn: TurnState
└── dirty: DirtyTracker

RuntimeState (运行时状态)
├── ui_runtime
├── board_runtime
├── anim_runtime
├── turn_runtime
└── debug_runtime

SessionState (协程会话)
├── current_state: string (phase name)
├── wait_state: string | nil
├── queue: signal[]
└── script: coroutine
```

#### 3.2 脏数据跟踪（Dirty Tracking）

| 脏标记 | 对应状态 | 用途 |
|--------|----------|------|
| `dirty.any` | 全局 | 快速检查 |
| `dirty.players` | players数组 | 玩家列表变更 |
| `dirty.board_tiles` | tiles数组 | 地块状态变更 |
| `dirty.turn` | turn对象 | 回合状态变更 |
| `dirty.market` | 市场状态 | 黑市数据变更 |

---

## 第二部分：概念一致性检查

### 检查 #1：Player/Role 区分

**问题**：`player.id` 与 `role_id` 的关系是什么？

**分析**：
- `player.id` 是游戏逻辑标识
- `role_id` 是外部系统（Eggy）标识
- 映射关系：player.id ↔ role_id 是一对一

**不一致**：
```lua
-- TurnDispatch.lua:15
local actor_role_id = action and action.actor_role_id or nil
-- 这里 actor_role_id 实际上是 player.id，不是 role_id
```

**建议**：统一术语，`actor_role_id` 应改为 `actor_player_id`

---

### 检查 #2：Cash/Balance/Money 术语混乱

**问题**：资金概念有三种表述方式。

**代码证据**：
```lua
-- Player.lua
player.cash  -- 主货币

-- BalanceOps.lua
function balance_ops.add_balance(player, currency, amount)  -- 多货币

-- Config
shop_currency = "gold_bean" | "coin" | "paradise"
```

**本体论分析**：
- `cash` 是特定货币（金币）的属性
- `balance` 是通用概念，包含多种货币
- `money` 未使用，但可能被误解

**建议**：
1. 单数 `cash` 保持为金币专用
2. 复数 `balances` 表示多货币映射表
3. 避免使用 `money`

---

### 检查 #3：Turn/Phase/Step 层次混淆

**问题**：这三个概念的包含关系不清晰。

**当前定义**：
- `Turn` = 完整回合
- `Phase` = turn的阶段（start, roll, move, landing, post_action, end_turn）
- `Step` = 未正式定义，但TurnStart等模块暗示存在

**不一致**：
```lua
-- PhaseRegistry.lua
phases = {
  start = turn_start,  -- 这是一个"Phase"
  roll = turn_roll,
  ...
}

-- TurnStart.lua 返回的是下一个 phase name
return "roll", { player = player }  -- 状态机转换
```

**逻辑分析**：
- `Phase` 实际上是状态机中的状态（state）
- `TurnStart` 等是状态处理函数
- 应该区分 "phase/state" 和 "phase handler"

**建议**：
1. 明确使用 `state` 代替 `phase` 以减少混淆
2. 或保持 `phase` 但文档中明确其为状态机状态

---

### 检查 #4：Item/Card 区分

**问题**：道具和卡片是同一概念吗？

**分析**：
- `Item` = 道具卡（玩家背包中的物品）
- `ChanceCard` = 机会卡（随机事件）
- 配置中都有 `card` 隐喻，但代码中严格区分

**不一致**：
```lua
-- 机会卡配置
{ id="chance_001", description="...", effect="..." }

-- 道具配置
{ id="remote_dice", name="遥控骰子", timing="pre_move" }
```

**建议**：保持区分，文档中明确 `Card` 是通用隐喻，`Item` 和 `ChanceCard` 是具体类型。

---

### 检查 #5：Handler/Executor/Resolver 命名不一致

**问题**：相似概念使用不同命名模式。

**矩阵分析**：

| 模块 | 实际类型 | 命名模式 | 一致性 |
|------|----------|----------|--------|
| EffectRegistry | Registry | Registry | ✅ |
| ChoiceRegistry | Registry | Registry | ✅ |
| ItemRegistry | Registry | Registry | ✅ |
| PhaseRegistry | Registry | Registry | ✅ |
| ChanceHandlers | Registry | Handlers | ❌ |
| ItemHandlers | Handler集合 | Handlers | ✅ |
| CashHandlers | Handler集合 | Handlers | ✅ |
| EffectExecutor | Validator | Executor | ❌ |
| LandingEffectExecutors | Registry | Executors | ❌ |
| ChanceResolver | Resolver | Resolver | ✅ |
| LandRentResolver | Resolver | Resolver | ✅ |
| ChoiceResolver | Resolver | Resolver | ✅ |

**命名模式建议**：

1. **Registry** - 用于注册和管理映射关系的组件
   - 方法：`register(key, value)`, `get(key)`

2. **Handlers** - 处理特定领域请求的函数集合
   - 结构：module 包含多个 handler 函数

3. **Resolver** - 解析复杂决策的组件
   - 方法：`resolve(context)` → decision

4. **Executor** - 执行具体效果的组件
   - 方法：`execute(effect)` → side effects

---

### 检查 #6：Flow/Script/Scheduler 关系

**问题**：这三个概念都涉及流程控制，职责有重叠。

**分析**：

| 概念 | 职责 | 抽象层级 |
|------|------|----------|
| **TurnScript** | 回合状态机协程 | 高（领域） |
| **Scheduler** | 协程调度与信号分发 | 中（系统） |
| **GameplayLoopTickFlow** | 游戏循环流程定义 | 高（领域） |

**不一致**：
- `TurnScript` 使用协程实现状态机
- `Scheduler` 管理协程生命周期
- `Flow` 是配置/定义，但 `TurnScript` 是硬编码

**建议**：
1. `TurnScript` 实际上是 `TurnStateMachine`
2. `Scheduler` 保持为 `Scheduler`
3. `Flow` 用于声明式流程定义

---

### 检查 #7：Action/Signal/Intent/Event 消息类型

**问题**：四种消息/事件概念，区分不清晰。

**代码证据**：
```lua
-- Scheduler.lua
local SIGNAL_ACTION = "action"
-- signal = { type = "action", action = ... }

-- TurnDispatch.lua
action = { type = "ui_button", id = "next", actor_role_id = ... }

-- PresentationPorts
intent = { kind = "need_choice", choice_spec = ... }

-- MonopolyEvents
event = { type = "land", player_id = ..., tile_id = ... }
```

**本体论分析**：

| 概念 | 方向 | 用途 | 处理者 |
|------|------|------|--------|
| **Action** | UI→Core | 用户操作 | TurnDispatch |
| **Signal** | Core内部 | 协程通信 | Scheduler |
| **Intent** | Core→UI | UI更新请求 | PresentationPorts |
| **Event** | Core→外部 | 游戏事件通知 | RuntimePorts.emit_event |

**不一致**：
- `action` 在 Scheduler 中被包装为 `signal`
- `intent` 和 `event` 功能相似，但方向不同

**建议**：
1. 保持四者区分
2. 文档中明确方向性和用途
3. 考虑合并 `intent` 和 `event` 为 `notification`

---

### 检查 #8：DirtyTracker 与 State 的关系

**问题**：`dirty` 是 `Game` 的属性还是独立概念？

**代码证据**：
```lua
-- Game.lua
game.dirty = { any = false, players = false, ... }

-- DirtyTracker.lua
function dirty_tracker.mark(dirty, field)
  dirty.any = true
  dirty[field] = true
end
```

**分析**：
- `dirty` 是 `Game` 状态的一部分
- `DirtyTracker` 是操作 `dirty` 的工具模块
- 这是合理的分离：状态 + 操作

**一致性**：✅ 符合面向对象设计原则

---

### 检查 #9：Auto/AI 区分

**问题**：`auto` 和 `ai` 是同一概念吗？

**代码证据**：
```lua
-- Player.lua
player.is_ai  -- 是否是AI
player.auto   -- 是否自动托管

-- Agent.lua
function agent.is_auto_player(player)
  return player.auto == true
end
```

**分析**：
- `is_ai` = 玩家类型（AI vs Human）
- `auto` = 托管状态（自动执行 vs 手动操作）
- 关系：AI玩家总是auto，Human玩家可以临时auto

**一致性**：✅ 概念区分合理，但命名可以更清晰

**建议**：
- `is_ai` → `player_type` ("ai" | "human")
- `auto` → `is_autoplay` (boolean)

---

### 检查 #10：Canvas/View/Screen 术语

**问题**：UI层级使用 `Canvas` 作为主要术语。

**分析**：
- `Canvas` = 独立UI界面单元（base, market, player_choice等）
- `Node` = Canvas内的UI元素
- `Presenter` = Canvas的业务逻辑控制器

**与MVC对比**：
- Canvas ≈ View
- Presenter ≈ Controller
- Model = GameState

**一致性**：✅ 术语一致，但与传统MVC不同

---

## 第三部分：本体论关系图

### 实体关系图（ER）

```
Game (1) ─────┬─────> Player (N)
              │         ├── Inventory (1)
              │         │     └── ItemSlot (N)
              │         ├── Status (1)
              │         └── balances: Map<Currency, number>
              │
              ├─────> Board (1)
              │         └── Tile (N)
              │               ├── Land (subtype)
              │               ├── Start (subtype)
              │               └── ...
              │
              ├─────> Turn (1)
              │         ├── Phase (state machine)
              │         └── pending_choice: Choice | nil
              │
              └─────> Registries (N)
                        ├── EffectRegistry
                        ├── ChoiceRegistry
                        ├── ItemRegistry
                        └── PhaseRegistry
```

### 过程层次图

```
GameSession (协程容器)
  └── TurnScript (状态机)
        ├── Phase "start"
        │     └── ItemPhase "pre_action"
        ├── Phase "roll"
        │     └── ItemPhase "pre_move"
        ├── Phase "move"
        │     └── Movement (逐格移动)
        ├── Phase "landing"
        │     └── LandingEffect (地块效果)
        ├── Phase "post_action"
        │     └── ItemPhase "post_action"
        └── Phase "end_turn"
```

### 数据流图

```
User Input
    │
    ▼
TurnDispatch ──Action──> Scheduler ──Signal──> TurnScript
    │                                          │
    │                                          ▼
    │                                    Game (状态变更)
    │                                          │
    │                                          ▼
    └─────────────────Intent───────────> PresentationLayer
                                              │
                                              ▼
                                         UI Update
```

---

## 第四部分：问题汇总与建议

### 严重问题（影响理解）

| 问题 | 位置 | 建议 |
|------|------|------|
| `actor_role_id` 实际是 player.id | TurnDispatch.lua | 改名为 `actor_player_id` |
| `EffectExecutor` 是验证器 | EffectExecutor.lua | 改名为 `EffectValidator` |
| `ChanceHandlers` 是 Registry | ChanceHandlers.lua | 改名为 `ChanceRegistry` |

### 中等问题（命名不一致）

| 问题 | 位置 | 建议 |
|------|------|------|
| `LandingEffectExecutors` 是 Registry | LandingEffectExecutors.lua | 改名为 `LandingEffectRegistry` |
| `Phase` 实际是 State | PhaseRegistry.lua | 文档中明确说明 |
| `TurnScript` 是 StateMachine | TurnScript.lua | 改名为 `TurnStateMachine` |

### 轻微问题（风格差异）

| 问题 | 位置 | 建议 |
|------|------|------|
| PhaseRegistry 无 Class | PhaseRegistry.lua | 可选择性添加 Class 封装 |
| ItemPhase 命名风格 | ItemPhase.lua | 保持现状，文档说明 |

### 概念澄清建议

1. **明确 `Phase` 的状态机本质**：
   ```lua
   -- 建议添加注释
   -- Phase represents a state in the turn state machine
   local phases = {
     start = TurnStart,    -- Initial state
     roll = TurnRoll,      -- Rolling dice
     ...
   }
   ```

2. **统一 Handler/Executor/Resolver 文档**：
   - Handler: 处理请求的函数
   - Resolver: 解析决策的组件
   - Executor: 执行效果的组件
   - Registry: 管理映射关系的容器

3. **区分消息类型**：
   ```lua
   -- Action: UI -> Core (用户操作)
   -- Signal: Core内部 (协程通信)
   -- Intent: Core -> UI (UI更新请求)
   -- Event: Core -> External (游戏事件)
   ```

---

## 结论

经过概念分析，该项目整体架构清晰，但存在以下模式层面的不一致：

1. **命名模式不一致**：Registry/Handlers/Executors 混用
2. **术语隐喻不一致**：Role/Player, Phase/State 的区分
3. **消息类型过多**：Action/Signal/Intent/Event 的边界模糊

建议优先修复严重问题（改名），然后逐步统一命名模式。
