# 蛋仔大富翁 - Spoke框架版

## 🎮 项目简介

**蛋仔大富翁**是一个使用**Spoke反应式编程框架**完全重写的Lua游戏项目。该项目展示了如何使用现代反应式编程范式构建复杂的游戏系统。

### 核心特性

- ✅ **反应式状态管理** - 使用Spoke框架管理所有游戏状态
- ✅ **自动依赖追踪** - 状态变化自动通知所有依赖
- ✅ **模块化架构** - 8个独立的游戏系统，清晰的职责分离
- ✅ **完整的游戏规则** - 45个地块、19个道具、34张机会卡
- ✅ **智能AI** - 三个难度级别的AI对手
- ✅ **事件驱动** - 使用Trigger和Effect实现事件系统

## 📂 文件导航

### 快速开始
1. **第一次使用？** → 阅读 [QUICKSTART.md](./docs/QUICKSTART.md)
2. **想了解架构？** → 阅读 [SPOKE_ARCHITECTURE.md](./docs/SPOKE_ARCHITECTURE.md)
3. **想看详细设计？** → 阅读 [ARCHITECTURE_DETAILS.md](./docs/ARCHITECTURE_DETAILS.md)
4. **想看完成总结？** → 阅读 [COMPLETION_REPORT.md](./docs/COMPLETION_REPORT.md)

### 核心文件

| 文件 | 说明 | 行数 |
|------|------|------|
| [main.lua](main.lua) | LÖVE2D主入口 | 20 |
| [config.lua](config.lua) | 游戏配置（常量、地块、道具等） | 400+ |
| [GameManager.lua](GameManager.lua) | 核心游戏管理器 | 200+ |

### 游戏系统

| 系统 | 文件 | 说明 |
|------|------|------|
| 玩家系统 | [systems/PlayerSystem.lua](systems/PlayerSystem.lua) | 玩家属性和操作 |
| 地块系统 | [systems/PropertySystem.lua](systems/PropertySystem.lua) | 地块和地产管理 |
| 流程系统 | [systems/GameFlowSystem.lua](systems/GameFlowSystem.lua) | 回合制流程控制 |
| 物品系统 | [systems/ItemSystem.lua](systems/ItemSystem.lua) | 道具和机会卡 |
| 事件系统 | [systems/EventSystem.lua](systems/EventSystem.lua) | 着陆事件处理 |
| AI系统 | [systems/AISystem.lua](systems/AISystem.lua) | AI玩家决策 |
| 渲染系统 | [systems/RenderSystem.lua](systems/RenderSystem.lua) | 画面渲染 |
| 输入系统 | [systems/InputSystem.lua](systems/InputSystem.lua) | 输入处理 |

### 框架文件

| 文件 | 说明 |
|------|------|
| Spoke/ | Spoke反应式框架库 |

### 测试和示例

| 文件 | 说明 |
|------|------|
| [TestSuite.lua](TestSuite.lua) | 集成测试套件 |
| [SimpleExample.lua](SimpleExample.lua) | 实际使用示例 |

## 🚀 快速开始

### 启动游戏
```bash
# 需要安装 LÖVE2D 框架
love .
```

### 运行测试
```bash
lua TestSuite.lua
```

### 运行示例
```bash
lua SimpleExample.lua
```

## 🎮 游戏操作

| 按键 | 功能 |
|------|------|
| **SPACE** | 推进游戏阶段（投骰子、移动等） |
| **A** | 切换自动/手动模式 |
| **H** | 显示帮助信息 |
| **ESC** | 退出游戏 |

## 📚 学习路径

### 初学者

1. 安装LÖVE2D框架
2. 阅读 [QUICKSTART.md](QUICKSTART.md)
3. 运行 [SimpleExample.lua](SimpleExample.lua)
4. 尝试修改config.lua中的参数

### 中级开发者

1. 阅读 [SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md)
2. 学习Spoke框架的基本概念（State、Memo、Effect、Trigger）
3. 研究各个系统的实现（systems/目录）
4. 尝试添加新的游戏功能

### 高级开发者

1. 阅读 [ARCHITECTURE_DETAILS.md](ARCHITECTURE_DETAILS.md)
2. 研究系统间的通信机制
3. 优化性能和扩展能力
4. 贡献新功能和改进

## 💡 Spoke框架基础

### 什么是反应式编程？

反应式编程是一种编程范式，其中程序是围绕数据流和变化传播来组织的。

```lua
-- 传统方式（命令式）
function updateGame()
    player.money = player.money - 1000
    updateDisplay()  -- 需要手动更新
end

-- 反应式方式（Spoke）
local money = State.Create(player.money)
money:Set(money:Get() - 1000)  -- 自动更新依赖
```

### 核心概念

#### 1. State（反应式值）
```lua
local money = State.Create(100000)
local newAmount = money:Get()
money:Set(50000)  -- 自动通知依赖
```

#### 2. Memo（派生值）
```lua
local totalAsset = Memo.new("Total", function(s)
    return s:D(money) + s:D(propertyValue)
end, {money, propertyValue})
-- 自动根据依赖重新计算
```

#### 3. Effect（副作用）
```lua
local logger = Effect.new("Logger", function(s)
    print("Money: " .. s:D(money))
end, {money})
-- 当money变化时自动执行
```

#### 4. Trigger（事件）
```lua
local onBankrupt = Trigger.Create("onBankrupt")
onBankrupt:Fire({playerId = 1})  -- 发射事件
```

## 🎯 主要系统说明

### PlayerSystem（玩家系统）
- 管理玩家的所有属性（金币、位置、地块、道具等）
- 提供玩家操作接口
- 自动计算总资产和破产状态

### PropertySystem（地块系统）
- 管理45个地块的状态
- 实现地块购买、升级、租金计算
- 支持路障和地雷

### GameFlowSystem（游戏流程）
- 管理5个游戏阶段
- 实现回合制逻辑
- 提供日志和超时管理

### EventSystem（事件系统）
- 处理着陆事件
- 处理购买和租金
- 处理特殊地块（医院、深山等）

### ItemSystem（物品系统）
- 管理19个物品卡
- 管理34张机会卡
- 支持随机抽取

### AISystem（AI系统）
- 提供三个难度级别
- 实现购买、升级等决策
- 评估游戏局势

## 📊 游戏规则

### 基本规则
- 2-4人游戏
- 初始金币：100,000
- 胜利条件：其他玩家全部淘汰
- 淘汰条件：金币 ≤ 0

### 地块系统
- 11个可购买地块
- 4个等级（初级→房屋→别墅→高楼）
- 租金 = 上次升级费用 × 0.5

### 特殊地块
- **起点**：经过获得2,000金币
- **黑市**：可购买道具
- **医院**：支付费用后停留2回合
- **深山**：停留2回合，无法收租
- **税务局**：缴纳50%税金

### 道具和机会卡
- 19个物品卡（增强游戏多样性）
- 34张机会卡（随机事件）
- 附身系统（天使、财神、穷神）

## 🏗️ 项目统计

| 指标 | 数值 |
|------|------|
| 总行数 | ~2650行 |
| 核心文件 | 2个 |
| 系统模块 | 8个 |
| 地块数量 | 45个 |
| 道具数量 | 19个 |
| 机会卡 | 34张 |
| 测试用例 | 5个 |
| 文档页数 | 5份 |

## 🔧 开发指南

### 添加新功能

#### 1. 添加新地块类型
```lua
-- 在 config.lua 的 tiles 中添加
{
    id = 99,
    name = "新地块",
    type = "custom",
    basePrice = 500,
}

-- 在 EventSystem.lua 中处理事件
elseif tileType == "custom" then
    return {event = "customEvent"}
end
```

#### 2. 添加新游戏阶段
```lua
-- 在 GameFlowSystem.lua 中
GameFlowSystem.Phase = {
    -- ... 现有阶段
    NEW_PHASE = "newPhase",
}

-- 在 GameManager.createGameEpoch 中处理
elseif phase == GameFlowSystem.Phase.NEW_PHASE then
    -- 执行新阶段逻辑
end
```

#### 3. 添加新的物品效果
```lua
-- 在 config.lua 的 items 中添加
[3000] = {
    id = 3000,
    name = "新道具",
    description = "新效果",
    effect = "newEffect",
}

-- 在 EventSystem.lua 或 ItemSystem.lua 中实现效果
```

## 📈 性能优化

1. **使用Memo缓存** - 避免重复计算
2. **依赖精细化** - 只监听必要的状态
3. **批量更新** - 合并多个状态更新
4. **及时清理** - 移除不需要的Effect和Trigger

## 🐛 调试技巧

### 查看状态值
```lua
print("玩家金币: " .. player.money:Get())
print("玩家位置: " .. player.position:Get())
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

## 🎓 推荐学习资源

### Spoke框架
- [Spoke官方文档](https://github.com/codr7/spoke) (C# 版本)
- [Lua实现](./Spoke/README.md)

### Lua编程
- [Lua官方文档](https://www.lua.org/manual/)
- [Lua学习指南](https://www.lua.org/learning.html)

### LÖVE2D
- [LÖVE2D官方文档](https://love2d.org/docs)
- [LÖVE2D论坛](https://love2d.org/forums)

## 📝 文档清单

| 文档 | 内容 |
|------|------|
| [QUICKSTART.md](QUICKSTART.md) | 快速开始指南 |
| [SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md) | 架构设计详解 |
| [ARCHITECTURE_DETAILS.md](ARCHITECTURE_DETAILS.md) | 系统架构图解 |
| [COMPLETION_REPORT.md](COMPLETION_REPORT.md) | 完成总结报告 |
| [README.md](README.md) | 本文件 |

## 🤝 贡献指南

欢迎提交以下内容：
- 🐛 Bug修复
- ✨ 新功能
- 📚 文档改进
- 🎨 UI改进
- ⚡ 性能优化

## ⚖️ 许可证

该项目遵循原始游戏的许可证协议。

## 📞 联系方式

- 提交Issue: GitHub Issues
- 拉取请求: GitHub Pull Requests
- 讨论: GitHub Discussions

## 🗺️ 项目路线图

### ✅ 已完成
- [x] Spoke框架集成
- [x] 8个核心系统
- [x] 完整的游戏规则
- [x] AI系统
- [x] 测试和示例
- [x] 文档

### ⏳ 进行中
- [ ] UI完善（图形界面）
- [ ] 音效系统
- [ ] 游戏存档

### 📅 计划中
- [ ] 网络多人
- [ ] 游戏录制回放
- [ ] 更多游戏内容

## 🎉 致谢

感谢Spoke框架的优秀设计，使得这个项目成为可能。

---

**项目版本**: 2.0 Spoke Edition  
**最后更新**: 2026年1月6日  
**框架**: Spoke Lua (反应式编程框架)  
**引擎**: LÖVE2D 2D游戏框架  
**语言**: Lua

**开始游戏**: `love .`  
**运行测试**: `lua TestSuite.lua`
