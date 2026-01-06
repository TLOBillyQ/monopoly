# 系统架构详解

## 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      LÖVE2D Framework                        │
│            (love.load, love.update, love.draw)               │
└────────────┬────────────────────────────────────────────────┘
             │
             ├─ main.lua ──────┐
             │                 │
             └─────────────────┼──────────────────────────────┐
                               │                              │
                           GameManager                     Config
                         (Game Orchestrator)            (Game Config)
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
    GameFlow              Players              Properties
    System                State                  System
         │                 │ │ │                   │
    ┌────┴─────┐       ┌──┴─┴─┴──┐            ┌────┴──┐
    │ Phases   │       │ P1│P2│P3 │            │Tiles  │
    │ Turns    │       │   │  │   │            │State  │
    │ Logs     │       └────────┘             │Rent   │
    │ Timeout  │                              │Owner  │
    └────┬─────┘                              └───────┘
         │
    ┌────┴───────────────┬──────────────┬──────────────┬──────────────┐
    │                    │              │              │              │
EventSystem          ItemSystem     AISystem       RenderSystem   InputSystem
    │                    │              │              │              │
    ├─ Events       ├─ Items        ├─ Decisions ├─ Board        ├─ Keyboard
    ├─ Triggers     ├─ Chances      ├─ Tactics   ├─ Players      ├─ Mouse
    └─ Handlers     └─ Database     └─ Strategy  └─ UI           └─ Dialog
```

## 数据流架构

```
State Changes
    │
    ├─→ Memo (Compute)
    │       │
    │       └─→ Cached Values
    │
    ├─→ Effect (React)
    │       │
    │       └─→ Side Effects
    │
    └─→ Trigger (Emit)
            │
            └─→ Event Listeners
```

## 核心对象生命周期

```
Game Start
    │
    ├─ Initialize GameManager
    │   │
    │   ├─ Create Players
    │   ├─ Create Properties
    │   ├─ Create GameFlow
    │   └─ Spawn SpokeTree
    │
Game Loop
    │
    ├─ Update Phase (Reactive State Changes)
    │   │
    │   ├─ State.Set() → Notify Dependencies
    │   ├─ Memo.Get() → Auto Compute
    │   ├─ Effect.Execute() → Side Effects
    │   └─ Trigger.Fire() → Events
    │
    ├─ Process Events
    │   │
    │   ├─ Land Event
    │   ├─ Buy Property
    │   ├─ Pay Rent
    │   └─ Draw Cards
    │
    ├─ Render (Reactive)
    │   │
    │   ├─ Read State → Re-render
    │   ├─ UI Updates
    │   └─ Display Results
    │
    └─ Handle Input
        │
        ├─ Keyboard
        ├─ Mouse
        └─ Dialog
            │
            └─ Next Phase/Turn
            
Game End
    │
    └─ Dispose SpokeTree & Cleanup
```

## 反应式系统详解

### State（反应式值）

```lua
-- 创建
local state = State.Create(initialValue)

-- 读取
local value = state:Get()

-- 修改（自动通知依赖）
state:Set(newValue)

-- 依赖自动更新
dependentMemo:Auto Update
dependentEffect:Auto Execute
```

### Memo（派生值）

```lua
-- 创建（从state推导）
local derived = Memo.new("DerivedValue", 
    function(s)
        local v1 = s:D(state1)
        local v2 = s:D(state2)
        return v1 + v2  -- 自动缓存
    end,
    {state1, state2}  -- 依赖列表
)

-- 自动特性：
-- - 当 state1 或 state2 变化时自动重新计算
-- - 结果被缓存，相同输入不重新计算
-- - Get() 返回缓存结果
```

### Effect（副作用）

```lua
-- 创建（响应state变化）
local effect = Effect.new("MyEffect",
    function(s)
        local value = s:D(state)
        -- 执行副作用（打印、更新UI等）
        print("State changed: " .. value)
    end,
    {state}  -- 当state变化时自动执行
)
```

### Trigger（事件）

```lua
-- 创建
local trigger = Trigger.Create("myEvent")

-- 发射
trigger:Fire({data = "value"})

-- 监听（通过Effect或Reaction）
local reaction = Reaction.new("myReaction",
    function(s)
        -- 处理事件
    end,
    {trigger}
)
```

## 玩家状态树

```
Player
├─ id: State(1)
├─ characterId: State(1001)
├─ vehicleId: State(4001)
├─ money: State(100000)
│  └─ Triggers: onMoneyChange
├─ position: State(1)
├─ properties: State([])
│  └─ Triggers: onPropertyChange
├─ items: State([])
├─ state: State("normal")
├─ buffs: State({})
│  └─ buffTurns: State({})
│
├─ Computed Values (Memo)
│  ├─ totalAsset: Memo
│  │   = money + propertyValue
│  ├─ isBankrupt: Memo
│  │   = money <= 0
│  └─ propertyCount: Memo
│      = #properties
│
└─ Effects
    ├─ onMoneyChange
    ├─ onPropertyChange
    └─ onStateChange
```

## 地块状态树

```
Tile
├─ id: State(1)
├─ name: State("地块名")
├─ type: State("property")
├─ basePrice: State(500)
├─ owner: State(nil/playerId)
├─ level: State(0-3)
│  └─ Triggers: onLevelChange
├─ roadblocks: State([])
├─ landmines: State([])
│
└─ Computed Values (Memo)
    ├─ rentPrice: Memo
    │   = basePrice × 2^(level-1) × 0.5
    ├─ upgradeCost: Memo
    │   = basePrice × 2^level
    └─ isOwned: Memo
        = owner != nil
```

## 游戏流程状态树

```
GameFlow
├─ currentTurn: State(1)
├─ currentPlayerIndex: State(1)
├─ currentPhase: State("beforeAction")
│  └─ Triggers: onPhaseChange
├─ lastDiceRoll: State(0)
├─ movementSteps: State(0)
├─ gameFinished: State(false)
├─ winner: State(nil)
├─ logs: State([])
├─ autoMode: State(false)
├─ autoSpeed: State(1.0)
│
└─ Effects
    ├─ phaseController
    ├─ logWriter
    └─ autoModeController
```

## 事件流动图

```
玩家着陆
    │
    ├─→ EventSystem.handleLandEvent()
    │       │
    │       ├─→ Check tile.type
    │       │
    │       ├─→ "property": Check owner
    │       │   ├─ Not owned: Trigger "canBuyProperty"
    │       │   ├─ Owned by other: Trigger "payRent"
    │       │   └─ Owned by self: No event
    │       │
    │       ├─→ "chance_card": Trigger "drawChance"
    │       │
    │       ├─→ "hospital": Trigger "enterHospital"
    │       │
    │       └─→ ... (Other tile types)
    │
    ├─→ Trigger fires
    │       │
    │       └─→ Effect listener executes
    │           │
    │           └─→ State updates
    │               │
    │               ├─→ Player money changes
    │               ├─→ Player state changes
    │               └─→ Triggers dependent updates
    │
    └─→ UI Re-renders (Reactive)
            │
            └─→ Display updated values
```

## 系统间通信

```
PlayerSystem ←→ PropertySystem
    ├─ acquire/lose property
    └─ read ownership for rent

GameFlowSystem ←→ EventSystem
    ├─ phase triggers events
    └─ events advance phases

PlayerSystem ←→ AISystem
    ├─ AI reads player state
    ├─ AI makes decisions
    └─ AI triggers actions

All Systems ←→ GameManager
    ├─ Integration point
    ├─ Coordinates all systems
    └─ Manages lifecycle
```

## 状态更新序列图

```
用户输入 (love.keypressed)
    │
    └─→ InputSystem.handleKeyPress()
            │
            ├─→ Advance Phase
            │   │
            │   └─→ gameFlow.currentPhase:Set("nextPhase")
            │       │
            │       └─→ Notify all listeners
            │           │
            │           ├─→ Memo automatically recomputes
            │           │   (if depend on currentPhase)
            │           │
            │           ├─→ Effect re-executes
            │           │   (if depend on currentPhase)
            │           │
            │           └─→ Trigger fires
            │               (phase change event)
            │
            ├─→ Player Action
            │   │
            │   └─→ player.money:Set(newAmount)
            │       │
            │       └─→ Cascade updates:
            │           ├─→ totalAsset Memo recomputes
            │           ├─→ isBankrupt Memo recomputes
            │           ├─→ All Effects re-execute
            │           └─→ Trigger fires
            │
            └─→ UI Update
                │
                └─→ RenderSystem.draw()
                    └─→ Read all States and Memos
                        └─→ Display current values
```

## 性能优化机制

```
State Change Event
    │
    ├─→ Mark dependent Memo as dirty
    │   │
    │   └─→ Only recompute if accessed
    │
    ├─→ Notify dependent Effects
    │   │
    │   └─→ Effect deduplication
    │       (merge multiple changes)
    │
    └─→ Notify dependent Triggers
        │
        └─→ Listener execution
            (batched updates)
```

## 模块依赖图

```
main.lua
    ├─→ Config
    └─→ GameManager
            ├─→ PlayerSystem
            ├─→ PropertySystem
            ├─→ GameFlowSystem
            ├─→ ItemSystem
            ├─→ EventSystem
            ├─→ AISystem
            ├─→ RenderSystem
            └─→ InputSystem
                    └─→ All depend on Spoke Framework
```

## 生命周期管理

```
SpokeTree
    │
    ├─ Init Phase
    │   ├─ Create all Epochs
    │   ├─ Initialize States
    │   └─ Register Effects
    │
    ├─ Tick Phase (每帧)
    │   ├─ Process State Changes
    │   ├─ Execute Effects
    │   ├─ Fire Triggers
    │   └─ Update Dependencies
    │
    └─ Cleanup Phase
        ├─ Dispose all Epochs
        ├─ Clear States
        └─ Release Resources
```

这个架构通过Spoke框架的反应式特性，实现了：

1. **自动依赖追踪** - 状态变化自动通知依赖
2. **高效缓存** - Memo避免重复计算
3. **清晰事件流** - Trigger实现发布-订阅
4. **模块化设计** - 每个系统独立但可相互通信
5. **易于扩展** - 添加新系统或功能无需修改现有代码
