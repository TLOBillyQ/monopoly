# API参考文档

## 目录
1. [PlayerSystem](#playersystem)
2. [PropertySystem](#propertysystem)
3. [GameFlowSystem](#gameflowsystem)
4. [ItemSystem](#itemsystem)
5. [EventSystem](#eventsystem)
6. [AISystem](#aisystem)
7. [RenderSystem](#rendersystem)
8. [InputSystem](#inputsystem)
9. [GameManager](#gamemanager)

---

## PlayerSystem

玩家系统，管理玩家的所有属性和操作。

### 创建玩家

```lua
local PlayerSystem = require("systems.PlayerSystem")

-- 创建新玩家
local player = PlayerSystem.createPlayer(id, characterId, vehicleId, isAI)

-- 参数
-- id: 玩家编号 (1, 2, 3, 4)
-- characterId: 角色ID (1001-1004)
-- vehicleId: 座驾ID (4001-4003)
-- isAI: 是否为AI玩家 (true/false)

-- 返回值
-- player: 包含以下反应式状态的玩家对象
--   id: State
--   money: State
--   position: State
--   properties: State
--   items: State
--   state: State
--   buffs: State
--   totalAsset: Memo (自动计算的总资产)
--   isBankrupt: Memo (自动计算的破产状态)
```

### 金币操作

```lua
-- 增加金币
PlayerSystem.addMoney(player, amount)
-- amount: 增加的金额

-- 减少金币
PlayerSystem.subtractMoney(player, amount)
-- amount: 减少的金额

-- 示例
PlayerSystem.addMoney(player, 5000)
PlayerSystem.subtractMoney(player, 1000)
```

### 地块操作

```lua
-- 获得地块
PlayerSystem.acquireProperty(player, propertyId)
-- propertyId: 地块ID

-- 失去地块
PlayerSystem.loseProperty(player, propertyId)
-- propertyId: 地块ID

-- 示例
PlayerSystem.acquireProperty(player, 5)
PlayerSystem.loseProperty(player, 5)
```

### 道具操作

```lua
-- 添加道具
local success = PlayerSystem.addItem(player, itemId)
-- itemId: 道具ID
-- 返回: true 如果添加成功，false 如果已达到上限(5个)

-- 移除道具
local removed = PlayerSystem.removeItem(player, itemId)
-- itemId: 道具ID
-- 返回: true 如果移除成功，false 如果不存在

-- 示例
if PlayerSystem.addItem(player, 2001) then
    print("获得道具成功")
else
    print("道具已满")
end
```

### 移动操作

```lua
-- 移动到指定位置
PlayerSystem.moveTo(player, position, maxPos)
-- position: 目标位置
-- maxPos: 最大位置（默认45）

-- 示例
PlayerSystem.moveTo(player, 10, 45)
```

### 状态操作

```lua
-- 进入医院
PlayerSystem.enterHospital(player)

-- 进入深山
PlayerSystem.enterMountain(player)

-- 示例
PlayerSystem.enterHospital(player)
-- player.state 变为 "hospital"
-- player.stayTurns 变为 2
```

### 附身操作

```lua
-- 应用附身
PlayerSystem.applyBuff(player, buffType, duration)
-- buffType: 附身类型 ("angel", "wealth", "poor")
-- duration: 持续回合数

-- 移除附身
PlayerSystem.removeBuff(player, buffType)
-- buffType: 附身类型

-- 减少附身时间
PlayerSystem.reduceBuff(player)
-- 自动减少所有活跃附身的时间

-- 示例
PlayerSystem.applyBuff(player, "angel", 5)
PlayerSystem.reduceBuff(player)
PlayerSystem.removeBuff(player, "angel")
```

---

## PropertySystem

地块系统，管理游戏地图和地块状态。

### 创建地块

```lua
local PropertySystem = require("systems.PropertySystem")

-- 创建单个地块
local tile = PropertySystem.createTile(id, config)
-- id: 地块编号
-- config: {
--   name: string,      -- 地块名称
--   type: string,      -- 地块类型
--   basePrice: number  -- 基础价格
-- }

-- 创建完整地图
local map = PropertySystem.createMap(tileConfigs)
-- tileConfigs: 地块配置数组
```

### 购买和升级

```lua
-- 购买地块
PropertySystem.buyProperty(tile, playerId, price)
-- playerId: 购买玩家ID
-- price: 购买价格

-- 升级地块
PropertySystem.upgradeProperty(tile, price)
-- price: 升级费用
-- 返回: 实际升级费用

-- 示例
PropertySystem.buyProperty(tile, 1, 500)
PropertySystem.upgradeProperty(tile, 1000)
```

### 计算和查询

```lua
-- 计算租金
local rent = PropertySystem.calculateRent(tile)
-- 返回: 租金额度

-- 示例
local myRent = PropertySystem.calculateRent(tile)
print("租金: " .. myRent)
```

### 陷阱操作

```lua
-- 放置路障
PropertySystem.placeRoadblock(tile, playerId)
-- playerId: 放置者ID

-- 放置地雷
PropertySystem.placeLandmine(tile, playerId)
-- playerId: 放置者ID

-- 清除陷阱
PropertySystem.clearObstacles(tile)

-- 示例
PropertySystem.placeRoadblock(tile, 1)
PropertySystem.clearObstacles(tile)
```

---

## GameFlowSystem

游戏流程系统，管理回合制逻辑。

### 游戏阶段

```lua
local GameFlowSystem = require("systems.GameFlowSystem")

GameFlowSystem.Phase = {
    BEFORE_ACTION = "beforeAction",   -- 行动前
    ROLL_DICE = "rollDice",           -- 投掷骰子
    MOVE = "move",                    -- 移动
    LAND_EVENT = "landEvent",         -- 着陆事件
    AFTER_ACTION = "afterAction"      -- 行动后
}
```

### 创建游戏流程

```lua
local gameFlow = GameFlowSystem.createGameFlow()
-- 返回游戏流程状态对象，包含以下反应式状态：
--   currentTurn: State(1)
--   currentPlayerIndex: State(1)
--   currentPhase: State("beforeAction")
--   lastDiceRoll: State(0)
--   movementSteps: State(0)
--   gameFinished: State(false)
--   winner: State(nil)
--   logs: State([])
```

### 游戏操作

```lua
-- 投掷骰子
local roll = GameFlowSystem.rollDice(gameFlow)
-- 返回: 1-6的随机数

-- 推进阶段
GameFlowSystem.nextPhase(gameFlow)

-- 推进回合
GameFlowSystem.nextTurn(gameFlow, playerCount)
-- playerCount: 玩家数量

-- 添加日志
GameFlowSystem.addLog(gameFlow, message)
-- message: 日志消息

-- 结束游戏
GameFlowSystem.endGame(gameFlow, winnerId)
-- winnerId: 赢家玩家ID

-- 示例
local diceRoll = GameFlowSystem.rollDice(gameFlow)
print("骰子: " .. diceRoll)

GameFlowSystem.nextPhase(gameFlow)
GameFlowSystem.nextTurn(gameFlow, 4)

GameFlowSystem.addLog(gameFlow, "玩家1获得1000金币")
GameFlowSystem.endGame(gameFlow, 1)
```

---

## ItemSystem

物品系统，管理道具和机会卡。

### 创建数据库

```lua
local ItemSystem = require("systems.ItemSystem")

-- 创建物品数据库
local itemDb = ItemSystem.createItemDatabase(config.items)

-- 创建机会卡数据库
local chanceDb = ItemSystem.createChanceDatabase(config.chanceCards)
```

### 随机抽取

```lua
-- 随机抽取物品
local itemId = ItemSystem.drawRandomItem(itemDb)
-- 返回: 物品ID

-- 随机抽取机会卡
local chanceId = ItemSystem.drawRandomChance(chanceDb)
-- 返回: 机会卡ID

-- 示例
local item = ItemSystem.drawRandomItem(itemDb)
local chance = ItemSystem.drawRandomChance(chanceDb)
```

### 效果应用

```lua
-- 应用物品效果
local success = ItemSystem.applyItemEffect(itemId, itemDb, player, context)

-- 应用机会卡效果
local success = ItemSystem.applyChanceEffect(chanceId, chanceDb, player, context)

-- 示例
ItemSystem.applyItemEffect(2001, itemDb, player, context)
ItemSystem.applyChanceEffect(3001, chanceDb, player, context)
```

---

## EventSystem

事件系统，处理游戏中的各种事件。

### 事件处理

```lua
local EventSystem = require("systems.EventSystem")

-- 处理着陆事件
local event = EventSystem.handleLandEvent(player, tile, context)
-- 返回: {event = eventType, ...}

-- 处理购买
local result = EventSystem.handlePropertyPurchase(player, tile, context, price)
-- 返回: {success = true/false, message = string}

-- 检查破产
local isBankrupt = EventSystem.checkBankruptcy(player)
-- 返回: true 如果破产

-- 计算租金
local rent = EventSystem.calculateRent(tile)
-- 返回: 租金额度

-- 示例
local event = EventSystem.handleLandEvent(player, tile, context)
if event.event == "canBuyProperty" then
    EventSystem.handlePropertyPurchase(player, tile, context, 500)
end
```

---

## AISystem

AI系统，提供AI玩家的决策逻辑。

### 难度级别

```lua
local AISystem = require("systems.AISystem")

AISystem.Difficulty = {
    EASY = "easy",
    MEDIUM = "medium",
    HARD = "hard",
}
```

### 创建AI玩家

```lua
local aiPlayer = AISystem.createAIPlayer(id, difficulty, characterId, vehicleId)
-- id: 玩家编号
-- difficulty: 难度级别
-- characterId: 角色ID
-- vehicleId: 座驾ID
-- 返回: AI玩家对象
```

### AI决策

```lua
-- 决定是否购买
local shouldBuy = AISystem.decideToBuyProperty(aiPlayer, price, tileType, context)
-- 返回: true/false

-- 决定是否使用物品
local shouldUse = AISystem.decideToUseItem(aiPlayer, itemId, situation, context)
-- 返回: true/false

-- 决定是否升级
local shouldUpgrade = AISystem.decideToUpgrade(aiPlayer, propId, cost, context)
-- 返回: true/false

-- 选择目标
local target = AISystem.selectTarget(aiPlayer, availableTargets, context)
-- 返回: 目标玩家对象

-- 评估局势
local situation = AISystem.evaluateGameSituation(aiPlayer, allPlayers, context)
-- 返回: {isLeading, moneyAdvantage, propertyAdvantage, needsHelp}

-- 示例
if AISystem.decideToBuyProperty(aiPlayer, 500, "property", context) then
    -- 购买地块
end
```

---

## RenderSystem

渲染系统，处理游戏画面。

### 创建渲染管道

```lua
local RenderSystem = require("systems.RenderSystem")

-- 创建完整的渲染管道
local renderPipeline = RenderSystem.createRenderPipeline(gameFlow, players, properties, config)
-- 返回: 可调用的渲染函数

-- 示例（在 love.draw() 中调用）
function love.draw()
    renderPipeline()
end
```

### 创建渲染状态

```lua
local renderState = RenderSystem.createRenderState()
-- 返回: 包含以下状态的对象
--   cameraX, cameraY: 相机位置
--   scale: 缩放比例
--   showDebug: 调试模式开关
```

---

## InputSystem

输入系统，处理玩家输入。

### 创建输入状态

```lua
local InputSystem = require("systems.InputSystem")

local inputState = InputSystem.createInputState()
-- 返回: 包含输入相关状态的对象
```

### 输入处理

```lua
-- 处理按键
InputSystem.handleKeyPress(key, inputState, gameFlow, players)

-- 处理鼠标点击
InputSystem.handleMouseClick(x, y, button, inputState)

-- 显示对话框
InputSystem.showDialog(inputState, title, message, options)

-- 隐藏对话框
InputSystem.hideDialog(inputState)

-- 示例
function love.keypressed(key)
    InputSystem.handleKeyPress(key, inputState, gameFlow, players)
end

function love.mousepressed(x, y, button)
    InputSystem.handleMouseClick(x, y, button, inputState)
end
```

---

## GameManager

游戏管理器，整合所有系统。

### 初始化

```lua
local GameManager = require("GameManager")

-- 初始化游戏
local context = GameManager.initialize(config)
```

### 创建新游戏

```lua
-- 创建新游戏
GameManager.createNewGame(config, playerCount, aiDifficulty)
-- config: 游戏配置
-- playerCount: 玩家数量(默认4)
-- aiDifficulty: AI难度级别(默认"medium")

-- 示例
GameManager.createNewGame(Config, 4, "medium")
```

### 游戏操作

```lua
-- 处理输入
GameManager.handleInput(key)

-- 绘制游戏
GameManager.draw()

-- 示例（在 love.keypressed 和 love.draw 中调用）
function love.keypressed(key)
    GameManager.handleInput(key)
end

function love.draw()
    GameManager.draw()
end
```

---

## Spoke框架API

### State（反应式值）

```lua
local State = require("Spoke.State")

-- 创建
local state = State.Create(initialValue)

-- 读取
local value = state:Get()

-- 修改
state:Set(newValue)
```

### Memo（派生值）

```lua
local Memo = require("Spoke.Memo")

-- 创建
local memo = Memo.new("Name", function(s)
    local v1 = s:D(state1)
    local v2 = s:D(state2)
    return v1 + v2
end, {state1, state2})

-- 读取
local value = memo:Get()
```

### Effect（副作用）

```lua
local Effect = require("Spoke.Effect").Effect

-- 创建
local effect = Effect.new("Name", function(s)
    local value = s:D(state)
    -- 执行副作用
end, {state})
```

### Trigger（事件）

```lua
local Trigger = require("Spoke.Trigger")

-- 创建
local trigger = Trigger.Create("eventName")

-- 发射
trigger:Fire({data = "value"})
```

---

## 配置参考

### 游戏常量（config.lua）

```lua
Config.constants = {
    initialMoney = 100000,      -- 初始金币
    pasStartReward = 2000,      -- 经过起点奖励
    hospitalFee = 1000,         -- 医院费用
    buffDuration = 5,           -- 附身持续回合数
}
```

### 地块配置

```lua
{
    id = 1,                 -- 地块ID
    name = "地块名",        -- 地块名称
    type = "property",      -- 地块类型
    basePrice = 500,        -- 基础价格
}
```

### 物品配置

```lua
[2001] = {
    id = 2001,              -- 物品ID
    name = "物品名",        -- 物品名称
    level = 1,              -- 物品等级
    description = "描述",   -- 物品描述
}
```

### 机会卡配置

```lua
[3001] = {
    id = 3001,              -- 卡牌ID
    name = "卡牌名",        -- 卡牌名称
    type = "gain_money",    -- 卡牌类型
    value = 2000,           -- 卡牌值
}
```

---

## 常见使用模式

### 创建游戏并运行

```lua
local Config = require("config")
local GameManager = require("GameManager")

-- 创建新游戏
GameManager.createNewGame(Config, 4, "medium")

-- 在 love.draw() 中绘制
function love.draw()
    GameManager.draw()
end

-- 在 love.keypressed() 中处理输入
function love.keypressed(key)
    GameManager.handleInput(key)
end
```

### 访问玩家状态

```lua
local players = GameManager.context.players:Get()
local player = players[1]

local money = player.money:Get()
local position = player.position:Get()
local properties = player.properties:Get()
```

### 监听状态变化

```lua
local money = player.money
local onMoneyChange = Effect.new("MoneyWatcher", function(s)
    local newMoney = s:D(money)
    print("金币变化: " .. newMoney)
end, {money})
```

---

## 相关文档

- [快速启动指南](QUICKSTART.md)
- [架构设计详解](SPOKE_ARCHITECTURE.md)
- [系统架构图解](ARCHITECTURE_DETAILS.md)
- [完成总结报告](COMPLETION_REPORT.md)
