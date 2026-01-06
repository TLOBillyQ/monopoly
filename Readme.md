# 🎲 蛋仔大富翁 - Spoke框架版

![version](https://img.shields.io/badge/version-2.0-blue)
![status](https://img.shields.io/badge/status-complete-brightgreen)
![framework](https://img.shields.io/badge/framework-Spoke-orange)
![language](https://img.shields.io/badge/language-Lua-blue)

## 🚀 快速开始

```bash
# 启动游戏
love .
```

**游戏控制**:
- `SPACE` - 推进游戏
- `A` - 自动模式
- `H` - 帮助
- `ESC` - 退出

## 📚 文档

| 文档 | 说明 |
|------|------|
| [README_NEW.md](README_NEW.md) | 🎯 项目总览 |
| [QUICKSTART.md](QUICKSTART.md) | 📖 快速入门 |
| [SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md) | 🏗️ 架构设计 |
| [API_REFERENCE.md](API_REFERENCE.md) | 📝 API文档 |
| [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) | 📚 文档索引 |

## ✨ 项目特点

- ✅ **反应式架构** - 使用Spoke框架的State、Memo、Effect、Trigger
- ✅ **模块化设计** - 8个独立的游戏系统
- ✅ **完整游戏规则** - 45个地块、19个道具、34张机会卡
- ✅ **智能AI** - 3个难度级别的AI对手
- ✅ **详细文档** - 7份完整文档和多个示例

## 🎮 游戏功能

### 核心系统
| 系统 | 功能 |
|------|------|
| PlayerSystem | 玩家管理、资产、道具 |
| PropertySystem | 地块管理、升级、租金 |
| GameFlowSystem | 回合制、阶段控制 |
| EventSystem | 着陆事件、购买、支付 |
| ItemSystem | 道具卡、机会卡 |
| AISystem | AI决策、难度调整 |
| RenderSystem | 画面渲染 |
| InputSystem | 输入处理 |

### 游戏规则
- **玩家**: 2-4人（支持AI）
- **初始金币**: 100,000
- **地块**: 45个，支持4级升级
- **胜利**: 其他玩家全部淘汰
- **道具**: 19个物品卡，随机获得

## 📂 项目结构

```
monopoly/
├── main.lua                    # 游戏入口
├── config.lua                  # 游戏配置
├── GameManager.lua             # 核心管理器
├── systems/                    # 8个游戏系统
├── Spoke/                      # 反应式框架库
├── [各类文档]                  # 详细文档
├── TestSuite.lua               # 测试套件
└── SimpleExample.lua           # 使用示例
```

## 🔧 技术栈

| 技术 | 说明 |
|------|------|
| **Lua** | 编程语言 |
| **LÖVE2D** | 2D游戏框架 |
| **Spoke** | 反应式编程框架 |

## 📖 学习路径

### 初学者 (30分钟)
1. 阅读 [QUICKSTART.md](QUICKSTART.md)
2. 运行 `love .`
3. 尝试游戏操作

### 开发者 (2小时)
1. 阅读 [SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md)
2. 研究 [API_REFERENCE.md](API_REFERENCE.md)
3. 运行 `lua SimpleExample.lua`
4. 查看 `TestSuite.lua`

### 架构师 (4小时)
1. 阅读所有架构文档
2. 研究源代码
3. 了解系统设计

## 🧪 测试

```bash
# 运行集成测试
lua TestSuite.lua

# 运行使用示例
lua SimpleExample.lua
```

## 📊 项目统计

| 指标 | 数值 |
|------|------|
| 代码行数 | ~2650 |
| 系统模块 | 8个 |
| 文档数量 | 7份 |
| 地块数 | 45个 |
| 道具卡 | 19个 |
| 机会卡 | 34张 |

## 🎯 核心概念

### 反应式编程

```lua
-- State: 可观察的值
local money = State.Create(100000)
money:Set(50000)  -- 自动通知依赖

-- Memo: 自动计算的派生值
local total = Memo.new("Total", function(s)
    return s:D(money) + s:D(propertyValue)
end, {money, propertyValue})

-- Effect: 响应状态变化的副作用
local logger = Effect.new("Logger", function(s)
    print("金币: " .. s:D(money))
end, {money})

-- Trigger: 事件系统
local onBankrupt = Trigger.Create("onBankrupt")
onBankrupt:Fire({playerId = 1})
```

## 🚀 功能展示

### 玩家系统
```lua
-- 创建玩家
local player = PlayerSystem.createPlayer(1, 1001, 4001, false)

-- 金币操作
PlayerSystem.addMoney(player, 5000)
PlayerSystem.subtractMoney(player, 1000)

-- 地块操作
PlayerSystem.acquireProperty(player, 5)

-- 道具操作
PlayerSystem.addItem(player, 2001)
```

### 地块系统
```lua
-- 购买和升级
PropertySystem.buyProperty(tile, 1, 500)
PropertySystem.upgradeProperty(tile, 1000)

-- 计算租金
local rent = PropertySystem.calculateRent(tile)
```

### 游戏流程
```lua
-- 投掷骰子
local roll = GameFlowSystem.rollDice(gameFlow)

-- 推进阶段和回合
GameFlowSystem.nextPhase(gameFlow)
GameFlowSystem.nextTurn(gameFlow, 4)
```

## 💡 开发指南

### 添加新功能

1. **新地块类型** - 在 config.lua 添加配置
2. **新游戏阶段** - 在 GameFlowSystem 定义
3. **新物品效果** - 在 EventSystem 实现
4. **新AI策略** - 在 AISystem 扩展

详见 [SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md#开发指南)

## 🐛 调试

```lua
-- 查看玩家金币
print(player.money:Get())

-- 查看游戏日志
for _, log in ipairs(gameFlow.logs:Get()) do
    print(log.message)
end

-- 启用调试模式
renderState.showDebug:Set(true)
```

详见 [QUICKSTART.md](QUICKSTART.md#调试技巧)

## 🔗 相关资源

- [Spoke框架](https://github.com/codr7/spoke)
- [Lua官方](https://www.lua.org/)
- [LÖVE2D](https://love2d.org/)

## 📋 完成清单

- ✅ Spoke框架集成
- ✅ 8个游戏系统
- ✅ 完整游戏规则
- ✅ AI系统
- ✅ 完整文档（7份）
- ✅ 测试和示例
- ⏳ UI完善（下一阶段）
- ⏳ 游戏存档（下一阶段）
- ⏳ 网络对战（下一阶段）

## 📞 联系方式

- 提交Issue: GitHub Issues
- 拉取请求: GitHub Pull Requests

## ⚖️ 许可证

MIT License

## 🎉 鸣谢

感谢 Spoke 框架和 LÖVE2D 社区的支持！

---

**版本**: 2.0 Spoke Edition  
**状态**: ✅ 完成  
**最后更新**: 2026年1月6日

[查看完整项目信息](PROJECT_COMPLETION.md) | [阅读详细文档](DOCUMENTATION_INDEX.md) | [快速开始](QUICKSTART.md)
