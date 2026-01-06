# 蛋仔大富翁 - Spoke框架版本

## 项目概述

这是使用Spoke反应式框架完全重写的蛋仔大富翁游戏。Spoke框架提供了强大的反应式编程能力，使得游戏状态管理更加清晰、可维护且高效。

## 架构概念

### Spoke框架核心特性

1. **反应式状态（State）**：可观察的值，变化时自动通知依赖
2. **计算值（Memo）**：从其他状态计算得出的派生值，自动缓存
3. **副作用（Effect）**：响应状态变化执行副作用操作
4. **触发器（Trigger）**：事件发射器，支持发布-订阅模式
5. **树形结构（SpokeTree）**：管理所有Epoch的生命周期

## 项目结构

```
monopoly/
├── main.lua                          # 主入口（LÖVE2D框架）
├── config.lua                        # 游戏配置（常量、角色、地块、道具等）
├── GameManager.lua                   # 游戏总管理器（整合所有系统）
├── TestSuite.lua                     # 集成测试套件
├── Spoke/                            # Spoke框架（引入的库）
│   ├── SpokeRuntime.lua
│   ├── SpokeTree.lua
│   ├── State.lua
│   ├── Memo.lua
│   ├── Effect.lua
│   ├── Reaction.lua
│   ├── Trigger.lua
│   ├── LambdaEpoch.lua
│   └── ... (其他框架文件)
└── systems/                          # 游戏系统
    ├── PlayerSystem.lua              # 玩家系统
    ├── PropertySystem.lua            # 地块系统
    ├── GameFlowSystem.lua            # 游戏流程系统
    ├── ItemSystem.lua                # 物品/机会卡系统
    ├── EventSystem.lua               # 事件系统
    ├── AISystem.lua                  # AI决策系统
    ├── RenderSystem.lua              # 渲染系统
    └── InputSystem.lua               # 输入系统
```

## 系统说明

### 1. PlayerSystem（玩家系统）

使用Spoke反应式状态管理玩家的所有属性：

```lua
local PlayerSystem = require("systems.PlayerSystem")

-- 创建玩家
local player = PlayerSystem.createPlayer(1, 1001, 4001, false)

-- 操作金币
PlayerSystem.addMoney(player, 5000)
PlayerSystem.subtractMoney(player, 1000)

-- 获得/失去地块
PlayerSystem.acquireProperty(player, propertyId)
PlayerSystem.loseProperty(player, propertyId)

-- 道具操作
PlayerSystem.addItem(player, itemId)
PlayerSystem.removeItem(player, itemId)

-- 移动
PlayerSystem.moveTo(player, position)

-- 附身管理
PlayerSystem.applyBuff(player, "angel", 5)
PlayerSystem.removeBuff(player, "angel")
PlayerSystem.reduceBuff(player)
```

**反应式特性：**
- `money`：金币状态，变化时自动触发依赖更新
- `properties`：地块列表，变化时触发UI更新
- `totalAsset`（Memo）：自动计算的总资产
- `isBankrupt`（Memo）：自动计算的破产状态

### 2. PropertySystem（地块系统）

管理游戏地图和地块的所有状态：

```lua
-- 创建地图
local tiles = PropertySystem.createMap(config.tiles)

-- 购买地块
PropertySystem.buyProperty(tile, playerId, price)

-- 升级地块
PropertySystem.upgradeProperty(tile, price)

-- 计算租金
local rent = PropertySystem.calculateRent(tile)

-- 放置陷阱
PropertySystem.placeRoadblock(tile, playerId)
PropertySystem.placeLandmine(tile, playerId)
```

**反应式特性：**
- 每个地块的`owner`, `level`变化时自动更新UI和游戏逻辑
- 路障和地雷状态自动管理

### 3. GameFlowSystem（游戏流程系统）

管理游戏的回合制流程和阶段：

```lua
-- 创建游戏流程
local gameFlow = GameFlowSystem.createGameFlow()

-- 游戏阶段
GameFlowSystem.Phase = {
    BEFORE_ACTION,   -- 行动前（使用物品）
    ROLL_DICE,       -- 投掷骰子
    MOVE,            -- 移动
    LAND_EVENT,      -- 着陆事件
    AFTER_ACTION     -- 行动后（清算、检查破产等）
}

-- 操作
GameFlowSystem.rollDice(gameFlow)
GameFlowSystem.nextPhase(gameFlow)
GameFlowSystem.nextTurn(gameFlow, playerCount)
GameFlowSystem.addLog(gameFlow, message)
GameFlowSystem.endGame(gameFlow, winnerId)
```

**反应式特性：**
- `currentPhase`：阶段状态，变化时驱动游戏逻辑
- `currentPlayerIndex`：当前玩家索引
- `currentTurn`：回合计数
- `logs`：游戏日志流

### 4. EventSystem（事件系统）

处理着陆、购买、租金等游戏事件：

```lua
-- 处理着陆事件
local event = EventSystem.handleLandEvent(player, tile, gameContext)

-- 处理购买
EventSystem.handlePropertyPurchase(player, tile, context, price)

-- 破产检查
EventSystem.checkBankruptcy(player)

-- 计算租金
local rent = EventSystem.calculateRent(tile)
```

### 5. ItemSystem（物品系统）

管理道具卡和机会卡：

```lua
-- 创建数据库
local itemDb = ItemSystem.createItemDatabase(config.items)
local chanceDb = ItemSystem.createChanceDatabase(config.chanceCards)

-- 随机抽取
local itemId = ItemSystem.drawRandomItem(itemDb)
local chanceId = ItemSystem.drawRandomChance(chanceDb)

-- 应用效果
ItemSystem.applyItemEffect(itemId, itemDb, player, context)
ItemSystem.applyChanceEffect(chanceId, chanceDb, player, context)
```

### 6. AISystem（AI系统）

提供AI玩家的决策逻辑：

```lua
-- 创建AI玩家
local aiPlayer = AISystem.createAIPlayer(id, difficulty, characterId, vehicleId)

-- AI决策
local shouldBuy = AISystem.decideToBuyProperty(aiPlayer, price, tileType, context)
local shouldUse = AISystem.decideToUseItem(aiPlayer, itemId, situation, context)
local shouldUpgrade = AISystem.decideToUpgrade(aiPlayer, propId, cost, context)

-- 选择目标
local target = AISystem.selectTarget(aiPlayer, targets, context)

-- 评估形势
local situation = AISystem.evaluateGameSituation(aiPlayer, allPlayers, context)
```

**AI难度级别：**
- EASY：随机决策，容易战胜
- MEDIUM：考虑局势的平衡决策
- HARD：战术性决策，难以战胜

### 7. RenderSystem（渲染系统）

处理游戏画面绘制：

```lua
-- 创建渲染管道
local renderPipeline = RenderSystem.createRenderPipeline(gameFlow, players, properties, config)

-- 在 love.draw() 中调用
renderPipeline()
```

### 8. InputSystem（输入系统）

处理玩家输入和UI交互：

```lua
-- 处理按键
InputSystem.handleKeyPress(key, inputState, gameFlow, players)

-- 处理鼠标
InputSystem.handleMouseClick(x, y, button, inputState)

-- 显示对话框
InputSystem.showDialog(inputState, title, message, options)
InputSystem.promptBuyProperty(inputState, tileName, price)
InputSystem.promptUseItem(inputState, itemName)
```

## 反应式编程示例

### 基础反应式状态

```lua
local State = require("Spoke.State")

-- 创建状态
local money = State.Create(100000)

-- 获取值
local amount = money:Get()

-- 更新值（自动触发依赖更新）
money:Set(50000)
```

### 计算值（Memo）

```lua
local Memo = require("Spoke.Memo")

-- 创建自动计算的值
local totalAsset = Memo.new("TotalAsset", function(s)
    local playerMoney = s:D(money)
    local propertyValue = s:D(properties)
    return playerMoney + propertyValue
end, {money, properties})

-- totalAsset 会自动根据 money 或 properties 变化而更新
```

### 副作用（Effect）

```lua
local Effect = require("Spoke.Effect").Effect

-- 创建对状态变化的响应
local logEffect = Effect.new("MoneyLogger", function(s)
    local newMoney = s:D(money)
    print("金币变化为: " .. newMoney)
end, {money})

-- 当 money 变化时，会自动执行副作用
```

### 触发器（Trigger）

```lua
local Trigger = require("Spoke.Trigger")

-- 创建事件触发器
local onMoneyChange = Trigger.Create("onMoneyChange")

-- 发射事件
onMoneyChange:Fire({oldValue = 100000, newValue = 50000})

-- 监听事件（通过Reaction）
local reaction = Reaction.new("MoneyChangeReaction", function(s)
    -- 处理事件
end, {onMoneyChange})
```

## 运行游戏

### 启动游戏
```bash
love . 
```

### 运行测试
```bash
lua TestSuite.lua
```

### 键盘控制
- **SPACE**：推进游戏阶段
- **A**：切换自动/手动模式
- **H**：显示帮助
- **ESC**：退出游戏

## 与旧版本的主要改进

### 1. 状态管理
- **旧版本**：使用全局变量和table，难以追踪状态变化
- **新版本**：使用Spoke反应式状态，自动追踪依赖和变化

### 2. 事件处理
- **旧版本**：使用回调函数和事件表
- **新版本**：使用Trigger和Effect，更加声明式

### 3. 计算属性
- **旧版本**：手动计算，容易出错和不同步
- **新版本**：使用Memo自动缓存和同步

### 4. 异步处理
- **旧版本**：使用定时器和状态机
- **新版本**：使用Spoke树的生命周期管理

### 5. 代码组织
- **旧版本**：大量的单一文件，逻辑耦合
- **新版本**：系统化的模块设计，关注点分离

## 开发指南

### 添加新的游戏系统

1. 在 `systems/` 目录下创建新模块
2. 使用Spoke的State管理状态
3. 使用Memo创建计算属性
4. 使用Effect处理副作用
5. 在GameManager中整合

### 添加新的游戏阶段

1. 在GameFlowSystem中定义新的Phase常量
2. 在GameManager.createGameEpoch中添加处理逻辑
3. 更新相应的系统以支持新阶段

### 调试

启用调试模式查看所有状态变化：
```lua
local debug = require("Spoke.SpokeIntrospect")
debug.printTree(GameManager.context.spokeTree)
```

## 性能优化建议

1. **状态颗粒度**：将大状态对象分解为更小的原子状态
2. **Memo缓存**：合理使用Memo避免重复计算
3. **Effect去重**：避免创建重复的Effect
4. **树清理**：及时Dispose不需要的Epoch

## 已知限制

1. 当前实现是基础框架，具体游戏逻辑需要进一步完善
2. UI渲染系统仍在开发中
3. 网络多人功能暂未实现
4. 存档加载功能暂未实现

## 扩展计划

1. ✅ 核心系统重构（已完成）
2. ⏳ 完整的游戏逻辑实现
3. ⏳ 高级UI系统
4. ⏳ 本地网络对战
5. ⏳ 游戏存档系统
6. ⏳ 录制和回放系统

## 许可证

该项目基于原始游戏架构重写，遵循原始许可证。

## 贡献

欢迎提交问题和拉取请求！
