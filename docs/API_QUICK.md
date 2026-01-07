# API 快速参考

## PlayerSystem - 玩家系统

### 创建玩家
```lua
local player = PlayerSystem.createPlayer(id, characterId, vehicleId, isAI)
-- 返回包含响应式状态的玩家对象
```

### 金币操作
```lua
PlayerSystem.addMoney(player, amount)           -- 增加金币
PlayerSystem.subtractMoney(player, amount)      -- 减少金币
PlayerSystem.transfer(fromPlayer, toPlayer, amount)  -- 转账
```

### 地块操作
```lua
PlayerSystem.addProperty(player, propertyId)    -- 获得地块
PlayerSystem.removeProperty(player, propertyId) -- 失去地块
```

### 道具操作
```lua
PlayerSystem.addItem(player, itemId)            -- 获得道具
PlayerSystem.removeItem(player, itemId)         -- 失去道具
PlayerSystem.hasItem(player, itemId)            -- 检查是否有道具
```

### 位置和移动
```lua
PlayerSystem.moveTo(player, position, boardSize)    -- 移动到位置
PlayerSystem.moveForward(player, steps, boardSize)  -- 向前移动
```

### 状态管理
```lua
PlayerSystem.enterHospital(player, turns)       -- 进入医院
PlayerSystem.exitHospital(player)               -- 离开医院
PlayerSystem.applyBuff(player, buffType, turns) -- 应用附身状态
PlayerSystem.reduceBuff(player)                 -- 减少附身时间
```

### 响应式属性
```lua
player.money:Get()                              -- 获取金币
player.position:Get()                           -- 获取位置
player.properties:Get()                         -- 获取拥有的地块列表
player.items:Get()                              -- 获取道具列表
player.totalAsset:Get()                         -- 总资产（自动计算）
player.isBankrupt:Get()                         -- 是否破产（自动计算）
```

---

## PropertySystem - 地块系统

### 创建地块
```lua
local tile = PropertySystem.createTile(id, tileConfig)
```

### 地块操作
```lua
PropertySystem.buyProperty(tile, buyerId)       -- 购买地块
PropertySystem.upgradeProperty(tile)            -- 升级地块
PropertySystem.calculateRent(tile, level)       -- 计算租金
PropertySystem.setRoadblock(tile, playerId)     -- 放置路障
PropertySystem.setLandmine(tile, ownerId)       -- 放置地雷
```

### 地块属性查询
```lua
tile.name:Get()                                 -- 地块名称
tile.type:Get()                                 -- 地块类型
tile.owner:Get()                                -- 拥有者ID
tile.basePrice:Get()                            -- 基础价格
tile.level:Get()                                -- 升级等级
```

---

## GameFlowSystem - 游戏流程

### 阶段定义
```lua
GameFlowSystem.Phase.BEFORE_ACTION    -- 回合前准备
GameFlowSystem.Phase.ROLL_DICE        -- 投掷骰子
GameFlowSystem.Phase.MOVE             -- 移动
GameFlowSystem.Phase.LAND_EVENT       -- 着陆事件
GameFlowSystem.Phase.AFTER_ACTION     -- 回合后处理
```

### 流程控制
```lua
local gameFlow = GameFlowSystem.createGameFlow()
GameFlowSystem.nextPhase(gameFlow, players)     -- 进入下一阶段
GameFlowSystem.rollDice(gameFlow)               -- 投掷骰子
GameFlowSystem.addLog(gameFlow, message)        -- 添加日志
GameFlowSystem.endGame(gameFlow, winnerId)      -- 结束游戏
```

### 状态查询
```lua
gameFlow.currentPhase:Get()                     -- 当前阶段
gameFlow.currentPlayerIndex:Get()               -- 当前玩家索引
gameFlow.currentTurn:Get()                      -- 当前回合数
gameFlow.gameLog:Get()                          -- 游戏日志
```

---

## ItemSystem - 物品系统

### 物品操作
```lua
ItemSystem.drawRandomItem(config)               -- 抽取随机道具
ItemSystem.drawRandomChance(config)             -- 抽取随机机会卡
ItemSystem.applyItemEffect(itemId, player)      -- 应用物品效果
ItemSystem.applyChanceEffect(chanceId, player, context)  -- 应用机会卡效果
```

### 数据库
```lua
ItemSystem.createItemDatabase(items)            -- 创建物品数据库
ItemSystem.createChanceDatabase(chances)        -- 创建机会卡数据库
```

---

## EventSystem - 事件系统

### 事件处理
```lua
EventSystem.handleLandEvent(player, tile, context)     -- 处理着陆事件
EventSystem.handlePropertyPurchase(player, tile, context, price)  -- 处理购买
EventSystem.handleRent(player, tile, context)          -- 处理租金
EventSystem.checkBankruptcy(player)                    -- 检查破产
```

### 特殊事件
```lua
EventSystem.applySpecialEvent(eventType, player, context)  -- 应用特殊事件
EventSystem.resolveBuff(player)                        -- 处理附身状态
```

---

## AISystem - AI系统

### AI创建
```lua
local aiPlayer = AISystem.createAIPlayer(id, difficulty, characterId, vehicleId)
-- difficulty: "easy", "medium", "hard"
```

### AI决策
```lua
AISystem.decideToBuyProperty(player, price, tileType, context)   -- 决定是否购买
AISystem.decideToUpgrade(player, tile, upgradeCost, context)     -- 决定是否升级
AISystem.decideItemUsage(player, context)                        -- 决定是否使用道具
```

---

## RenderSystem - 渲染系统

### 渲染管道
```lua
local renderPipeline = RenderSystem.createRenderPipeline(
    gameFlow, players, properties, config, renderState, animationState
)
renderPipeline()  -- 执行渲染
```

### 组件
```lua
RenderSystem.renderBoard(properties, animationState)    -- 绘制游戏板
RenderSystem.renderPlayers(players, properties)         -- 绘制玩家
RenderSystem.renderStatusPanel(gameFlow, players)       -- 绘制状态面板
RenderSystem.renderGameLog(gameFlow)                    -- 绘制日志
```

---

## InputSystem - 输入系统

### 输入处理
```lua
InputSystem.handleKeyPress(key, inputState, gameFlow, players)   -- 处理键盘
InputSystem.handleMouseClick(x, y, inputState)                   -- 处理鼠标点击
```

### UI交互
```lua
InputSystem.promptBuyProperty(inputState, tileName, price)       -- 弹出购买提示
InputSystem.promptAction(inputState, actionType, data)           -- 弹出动作提示
```

---

## GameManager - 游戏管理器

### 初始化
```lua
GameManager.initialize(config)                  -- 初始化游戏
GameManager.createNewGame(config, playerCount, aiDifficulty)  -- 创建新游戏
```

### 游戏循环
```lua
GameManager.update(dt)                          -- 更新游戏逻辑
GameManager.draw()                              -- 绘制游戏
GameManager.handleInput(key)                    -- 处理输入
```

### 上下文访问
```lua
GameManager.context                             -- 游戏上下文（包含所有状态）
GameManager.context.players:Get()               -- 获取玩家列表
GameManager.context.properties:Get()            -- 获取地块列表
GameManager.context.gameFlow                    -- 游戏流程状态
```

---

## Spoke框架 - 反应式基础

### State（响应式状态）
```lua
local State = require("Spoke.State")
local value = State.Create(initialValue)
value:Set(newValue)                             -- 更新值
value:Get()                                     -- 读取值
```

### Memo（计算值）
```lua
local Memo = require("Spoke.Memo")
local computed = Memo.new(function(s)
    return someState:Get() * 2
end)
computed:Get()                                  -- 获取计算结果
```

### Trigger（触发器）
```lua
local Trigger = require("Spoke.Trigger")
local trigger = Trigger.new("eventName")
trigger:Listen(function(data)
    print("事件触发: " .. data)
end)
trigger:Fire(data)                              -- 触发事件
```

---

## 常见使用模式

### 创建新玩家
```lua
local PlayerSystem = require("systems.PlayerSystem")
local player = PlayerSystem.createPlayer(1, 1001, 4001, false)
PlayerSystem.addMoney(player, 1000)
```

### 监听状态变化
```lua
local function setupMoney监听(player)
    -- 金币变化会自动更新UI
    return player.money:Get()
end
```

### 处理游戏事件
```lua
local EventSystem = require("systems.EventSystem")
local event = EventSystem.handleLandEvent(player, tile, context)
if event.event == "canBuyProperty" then
    -- 处理购买事件
end
```

### 执行AI决策
```lua
local AISystem = require("systems.AISystem")
if AISystem.decideToBuyProperty(player, price, tileType, context) then
    PropertySystem.buyProperty(tile, player.id:Get())
end
```

---

**最后更新**: 2026-01-07
