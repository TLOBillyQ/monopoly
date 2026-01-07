# 架构设计 - Spoke 反应式框架

## 核心概念

### Spoke 框架特性

| 特性 | 说明 | 用途 |
|------|------|------|
| **State** | 响应式状态 | 可观察的值，变化时自动通知依赖 |
| **Memo** | 计算值 | 从状态派生的缓存属性，自动更新 |
| **Effect** | 副作用 | 响应状态变化执行操作 |
| **Trigger** | 触发器 | 事件系统，支持发布-订阅 |
| **SpokeTree** | 树形结构 | 管理所有 Epoch 的生命周期 |

## 系统架构

```
GameManager (核心管理器)
├── PlayerSystem        # 玩家管理（金币、地块、道具、状态）
├── PropertySystem      # 地块管理（购买、升级、租金、陷阱）
├── GameFlowSystem      # 流程控制（回合、阶段、骰子、日志）
├── ItemSystem          # 物品系统（道具卡、机会卡）
├── EventSystem         # 事件处理（着陆、购买、租金）
├── AISystem            # AI决策（购买、升级、使用道具）
├── RenderSystem        # 画面渲染（游戏板、玩家、UI）
└── InputSystem         # 输入处理（键盘、鼠标、对话框）
```

## 游戏流程

### 回合制阶段

```lua
GameFlowSystem.Phase = {
    BEFORE_ACTION,   -- 行动前（使用物品）
    ROLL_DICE,       -- 投掷骰子
    MOVE,            -- 移动
    LAND_EVENT,      -- 着陆事件
    AFTER_ACTION     -- 行动后（清算、破产检查）
}
```

### 数据流

```
用户输入 → InputSystem
           ↓
       GameFlowSystem (状态机)
           ↓
    ┌─────┴─────┐
    ↓           ↓
EventSystem  PlayerSystem/PropertySystem
    ↓           ↓
RenderSystem ← Spoke State (响应式更新)
```

## 反应式编程示例

### 创建响应式状态

```lua
local State = require("Spoke.State")

-- 创建状态
local money = State.Create(100000)

-- 读取和更新
local amount = money:Now()
money:Set(50000)  -- 自动触发依赖更新
```

### 计算属性（Memo）

```lua
local Memo = require("Spoke.Memo")

-- 自动计算总资产
local totalAsset = Memo.new("TotalAsset", function(s)
    return s:D(money) + s:D(propertyValue)
end, {money, propertyValue})

-- totalAsset 自动根据依赖更新
```

### 副作用（Effect）

```lua
local Effect = require("Spoke.Effect").Effect

-- 监听状态变化
local logger = Effect.new("Logger", function(s)
    print("金币: " .. s:D(money))
end, {money})
```

## 系统详解

### PlayerSystem

**核心状态**：
- `money`: 金币（State）
- `position`: 位置（State）
- `properties`: 拥有的地块（State）
- `items`: 道具列表（State）
- `state`: 玩家状态（active/hospital/mountain/bankrupt）
- `buffs`: 附身状态（angel/demon/wealth/poor）
- `totalAsset`: 总资产（Memo，自动计算）
- `isBankrupt`: 破产状态（Memo，自动计算）

**核心操作**：
```lua
PlayerSystem.addMoney(player, amount)
PlayerSystem.subtractMoney(player, amount)
PlayerSystem.transfer(from, to, amount)
PlayerSystem.addProperty(player, propId)
PlayerSystem.moveTo(player, position, boardSize)
PlayerSystem.applyBuff(player, buffType, turns)
```

### PropertySystem

**地块状态**：
- `owner`: 所有者（State）
- `level`: 建筑等级（State）
- `roadblock`: 路障（State）
- `landmine`: 地雷（State）

**核心操作**：
```lua
PropertySystem.createTile(id, config)
PropertySystem.buyProperty(tile, playerId, price)
PropertySystem.upgradeProperty(tile, price)
PropertySystem.calculateRent(tile)
PropertySystem.placeRoadblock(tile, playerId)
PropertySystem.placeLandmine(tile, playerId)
```

### GameFlowSystem

**流程状态**：
- `currentPhase`: 当前阶段
- `currentPlayerIndex`: 当前玩家
- `currentTurn`: 回合数
- `lastDiceRoll`: 骰子点数
- `isGameOver`: 游戏结束标志
- `logs`: 游戏日志流

**核心操作**：
```lua
GameFlowSystem.createGameFlow()
GameFlowSystem.rollDice(gameFlow)
GameFlowSystem.nextPhase(gameFlow, players)
GameFlowSystem.nextTurn(gameFlow, playerCount)
GameFlowSystem.addLog(gameFlow, message)
GameFlowSystem.endGame(gameFlow, winnerId)
```

### AISystem

**难度级别**：
- `EASY`: 随机决策
- `MEDIUM`: 平衡决策（考虑资金和局势）
- `HARD`: 战术决策（评估风险和收益）

**核心决策**：
```lua
AISystem.createAIPlayer(id, difficulty, charId, vehicleId)
AISystem.decideToBuyProperty(ai, price, type, context)
AISystem.decideToUpgrade(ai, propId, cost, context)
AISystem.decideToUseItem(ai, itemId, situation, context)
AISystem.selectTarget(ai, targets, context)
AISystem.evaluateGameSituation(ai, players, context)
```

## 设计优势

### 对比传统实现

| 方面 | 传统实现 | Spoke实现 |
|------|---------|----------|
| **状态管理** | 全局变量/table | 响应式 State |
| **数据同步** | 手动更新 | 自动同步 |
| **计算属性** | 手动计算 | Memo 自动缓存 |
| **事件处理** | 回调函数 | Effect/Trigger |
| **代码组织** | 单一大文件 | 系统化模块 |
| **可维护性** | 低（逻辑耦合） | 高（关注点分离） |
| **扩展性** | 低（修改风险大） | 高（独立系统） |

### 核心优势

1. **自动依赖追踪**：无需手动管理状态更新链
2. **计算缓存**：Memo 自动优化重复计算
3. **清晰的数据流**：单向数据流，易于调试
4. **模块化设计**：每个系统职责单一，易于测试
5. **类型安全**（通过约定）：状态变化可预测

## 开发指南

### 添加新系统

1. 在 `systems/` 创建模块文件
2. 使用 State 管理状态
3. 使用 Memo 创建派生属性
4. 使用 Effect 处理副作用
5. 在 GameManager 中整合

### 添加新阶段

1. 在 `GameFlowSystem.Phase` 定义常量
2. 在 `GameManager.update()` 添加逻辑
3. 更新相关系统支持新阶段

### 调试技巧

```lua
-- 查看 Spoke 树结构
local debug = require("Spoke.SpokeIntrospect")
debug.printTree(GameManager.context.spokeTree)

-- 追踪状态变化
player.money:Now()  -- 在关键点打印状态
```

## 性能优化

1. **状态颗粒度**：拆分大对象为多个小状态
2. **Memo 使用**：避免重复计算昂贵操作
3. **Effect 控制**：避免创建过多 Effect
4. **及时清理**：Dispose 不需要的 Epoch

## 扩展计划

- ✅ 核心系统重构
- ⏳ 完整游戏逻辑
- ⏳ 高级 UI 系统
- ⏳ 本地网络对战
- ⏳ 存档系统
- ⏳ 录制回放系统
