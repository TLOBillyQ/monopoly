# Spoke框架蛋仔大富翁 - 快速启动指南

## 概述

这是使用**Spoke反应式编程框架**完全重写的蛋仔大富翁游戏。新架构使用状态驱动的反应式模式，使游戏逻辑更清晰、更易维护。

## 快速开始

### 1. 启动游戏
```bash
love .
```

### 2. 基本操作
- **SPACE** - 推进游戏（投骰子、移动、结束回合）
- **A** - 切换自动模式
- **H** - 显示帮助
- **ESC** - 退出游戏

### 3. 运行测试
```bash
lua TestSuite.lua
```

## 项目架构概览

### 核心文件

| 文件 | 说明 |
|-----|------|
| `main.lua` | LÖVE2D主入口 |
| `config.lua` | 游戏配置（常量、角色、地块等） |
| `GameManager.lua` | 核心游戏管理器 |
| `Spoke/` | Spoke反应式框架库 |
| `systems/` | 游戏系统模块 |

### 游戏系统

| 系统 | 职责 |
|-----|------|
| **PlayerSystem** | 玩家属性和操作 |
| **PropertySystem** | 地块和地产管理 |
| **GameFlowSystem** | 回合制流程控制 |
| **ItemSystem** | 道具和机会卡 |
| **EventSystem** | 着陆事件处理 |
| **AISystem** | AI玩家决策 |
| **RenderSystem** | 画面渲染 |
| **InputSystem** | 玩家输入处理 |

## Spoke框架入门

### 什么是反应式编程？

反应式编程是一种基于数据流和变化传播的编程范式。当数据变化时，依赖该数据的代码会自动执行。

```lua
-- 传统方式
function updateDisplay()
    playerMoney = 100000
    -- 手动更新UI
    redraw()
end

-- 反应式方式（Spoke）
local playerMoney = State.Create(100000)
-- 自动响应变化，无需手动更新
```

### 核心概念

#### 1. State（反应式状态）

```lua
local State = require("Spoke.State")

-- 创建可观察的值
local money = State.Create(100000)

-- 获取值
local amount = money:Get()

-- 修改值（自动通知依赖）
money:Set(50000)
```

#### 2. Memo（计算属性）

```lua
local Memo = require("Spoke.Memo")

-- 自动计算和缓存的派生值
local totalAsset = Memo.new("TotalAsset", function(s)
    local m = s:D(playerMoney)
    local p = s:D(propertyValue)
    return m + p
end, {playerMoney, propertyValue})

-- totalAsset 会自动根据依赖更新
```

#### 3. Effect（副作用）

```lua
local Effect = require("Spoke.Effect").Effect

-- 响应状态变化执行操作
local logger = Effect.new("MoneyLogger", function(s)
    local m = s:D(playerMoney)
    print("金币: " .. m)
end, {playerMoney})
```

#### 4. Trigger（事件触发）

```lua
local Trigger = require("Spoke.Trigger")

local onBankrupt = Trigger.Create("onBankrupt")

-- 发射事件
onBankrupt:Fire({playerId = 1})
```

### 实际示例

#### 创建玩家

```lua
local PlayerSystem = require("systems.PlayerSystem")

-- 创建新玩家
local player = PlayerSystem.createPlayer(1, 1001, 4001, false)

-- 访问反应式属性
print(player.money:Get())           -- 100000
print(player.position:Get())        -- 1
print(#player.properties:Get())     -- 0

-- 修改属性（自动触发依赖）
PlayerSystem.addMoney(player, 5000) -- money 变为 105000
```

#### 购买地块

```lua
local PropertySystem = require("systems.PropertySystem")

-- 创建地块
local tile = PropertySystem.createTile(1, {
    name = "翡翠花园",
    type = "property",
    basePrice = 500
})

-- 购买地块
PropertySystem.buyProperty(tile, 1, 500)

-- 升级地块
PropertySystem.upgradeProperty(tile, 1000)

-- 计算租金
local rent = PropertySystem.calculateRent(tile)
```

## 游戏流程

### 回合阶段

游戏分为5个阶段，每个阶段执行特定操作：

```lua
GameFlowSystem.Phase = {
    BEFORE_ACTION,  -- 可使用物品、确认准备
    ROLL_DICE,      -- 投掷骰子
    MOVE,           -- 自动移动
    LAND_EVENT,     -- 处理着陆事件（购买、支付租金等）
    AFTER_ACTION    -- 清算、减少时间、检查破产
}
```

### 典型游戏流程

1. 玩家1的BEFORE_ACTION阶段
2. 玩家1投掷骰子（例如投出3点）
3. 玩家1移动3格
4. 处理着陆事件（可能购买、支付租金、抽卡等）
5. 行动后处理（减少附身时间等）
6. 进入玩家2的回合...

## 配置说明

### config.lua

包含所有游戏的常量和配置：

```lua
-- 基本常量
Config.constants.initialMoney = 100000  -- 初始金币
Config.constants.pasStartReward = 2000  -- 经过起点奖励

-- 地块配置
Config.tiles = { ... }  -- 45个地块

-- 道具配置
Config.items = { ... }  -- 19个道具

-- 机会卡配置
Config.chanceCards = { ... }  -- 34张机会卡

-- 角色配置
Config.characters = { ... }  -- 4个角色

-- 座驾配置
Config.vehicles = { ... }  -- 3个座驾
```

## 常见操作

### 添加金币

```lua
PlayerSystem.addMoney(player, 5000)
```

### 获得地块

```lua
PlayerSystem.acquireProperty(player, propertyId)
```

### 获得道具

```lua
PlayerSystem.addItem(player, itemId)
```

### 应用附身

```lua
PlayerSystem.applyBuff(player, "angel", 5)  -- 5回合的天使附身
```

### 检查破产

```lua
if player.money:Get() <= 0 then
    player.state:Set("bankrupt")
end
```

### 添加日志

```lua
GameFlowSystem.addLog(gameFlow, "玩家1获得了1000金币")
```

## 调试技巧

### 检查状态值

```lua
print("玩家金币: " .. player.money:Get())
print("玩家位置: " .. player.position:Get())
print("玩家地块: " .. table.concat(player.properties:Get(), ","))
```

### 查看游戏日志

```lua
local logs = gameFlow.logs:Get()
for _, log in ipairs(logs) do
    print(log.message)
end
```

### 启用调试模式

```lua
renderState.showDebug:Set(true)
```

## 性能建议

1. **避免频繁修改**：批量修改状态而不是多次单独修改
2. **合理使用Memo**：对于复杂计算，使用Memo而不是在Effect中计算
3. **及时清理**：移除不需要的Effect和Trigger

## 下一步

1. 阅读 `SPOKE_ARCHITECTURE.md` 了解详细的系统设计
2. 查看 `systems/` 目录下的各个系统实现
3. 运行 `TestSuite.lua` 了解各个系统的API
4. 根据需要扩展和自定义游戏逻辑

## 文件导航

```
monopoly/
├── main.lua                      # ← 从这里开始
├── config.lua                    # ← 游戏配置
├── GameManager.lua               # ← 核心管理器
├── SPOKE_ARCHITECTURE.md         # ← 详细文档
├── QUICKSTART.md                 # ← 本文件
├── TestSuite.lua                 # ← 测试代码
├── Spoke/                        # ← 框架库
└── systems/                      # ← 游戏系统
    ├── PlayerSystem.lua
    ├── PropertySystem.lua
    ├── GameFlowSystem.lua
    └── ... (其他系统)
```

## 常见问题

**Q: 什么是Spoke框架？**
A: Spoke是一个Lua反应式编程框架，提供基于状态和依赖的自动更新机制。

**Q: 如何添加新玩家类型？**
A: 可以在PlayerSystem中创建玩家，通过isAI标志区分人类和AI。

**Q: 如何修改游戏规则？**
A: 大多数规则都在config.lua中配置，也可以修改各个系统的逻辑函数。

**Q: 游戏保存如何实现？**
A: 可以通过序列化所有State的值来实现存档，目前暂未实现。

## 支持

如有问题或建议，欢迎开issue或提交PR！

---

**最后更新：2026年1月**
