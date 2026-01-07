# 🎮 蛋仔大富翁 - Spoke框架实现

一款使用 **Spoke 反应式编程框架** 完全重写的蛋仔大富翁游戏。采用现代化的反应式编程模式，提供清晰的架构、高效的状态管理和可扩展的游戏系统。

**状态**: ✅ 完全可用  
**框架**: Spoke 反应式编程库  
**引擎**: LÖVE2D

---

## 🚀 快速开始

### 1. 启动游戏
```bash
love .
```

### 2. 基本操作
| 快捷键 | 功能 |
|-------|------|
| **SPACE** | 推进游戏（投骰子、确认操作等） |
| **A** | 切换自动/手动模式 |
| **H** | 显示帮助信息 |
| **ESC** | 退出游戏 |

### 3. 运行测试
```bash
lua TestSuite.lua
```

---

## 📁 项目结构

```
monopoly/
├── main.lua                          # LÖVE2D主入口
├── config.lua                        # 游戏配置和常量
├── GameManager.lua                   # 核心游戏管理器
├── Spoke/                            # 反应式框架库
├── systems/                          # 游戏系统模块
│   ├── PlayerSystem.lua              # 玩家系统
│   ├── PropertySystem.lua            # 地块系统
│   ├── GameFlowSystem.lua            # 游戏流程
│   ├── ItemSystem.lua                # 物品和机会卡
│   ├── EventSystem.lua               # 事件处理
│   ├── AISystem.lua                  # AI决策
│   ├── RenderSystem.lua              # 画面渲染
│   └── InputSystem.lua               # 输入处理
└── docs/                             # 文档目录
```

---

## 🏗️ 架构概览

### 核心设计原则

**Spoke框架的反应式特性：**
- **State（状态）**: 可观察的响应式值，变化时自动通知依赖
- **Memo（计算值）**: 从状态派生的缓存属性，自动更新
- **Effect（副作用）**: 响应状态变化执行操作
- **Trigger（触发器）**: 事件系统，支持发布-订阅

### 游戏系统说明

| 系统 | 职责 | 核心功能 |
|------|------|---------|
| **PlayerSystem** | 玩家管理 | 创建玩家、金币操作、地块所有权、道具卡、附身状态 |
| **PropertySystem** | 地块管理 | 地块购买、升级、租金计算、路障和地雷 |
| **GameFlowSystem** | 流程控制 | 回合制、游戏阶段、骰子系统、日志管理 |
| **ItemSystem** | 物品系统 | 道具卡和机会卡数据库、效果应用 |
| **EventSystem** | 事件处理 | 着陆事件、地块交互、特殊事件触发 |
| **AISystem** | AI决策 | 购买决策、地块升级、策略计算 |
| **RenderSystem** | 画面渲染 | 游戏板、玩家、信息面板、对话框 |
| **InputSystem** | 输入处理 | 键盘和鼠标输入、UI交互 |

### 数据流架构

```
玩家操作
    ↓
InputSystem
    ↓
GameFlowSystem → State 变化
    ↓
Memo（自动计算） / Effect（副作用）
    ↓
EventSystem / 各系统响应
    ↓
RenderSystem
    ↓
屏幕显示
```

---

## 📚 文档导航

| 文档 | 用途 | 适合人群 |
|------|------|---------|
| **[QUICKSTART.md](QUICKSTART.md)** | 新手入门 | 第一次使用 |
| **[SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md)** | 架构详解 | 开发者 |
| **[API_QUICK.md](API_QUICK.md)** | API快速查询 | 开发者 |
| **[UI_QUICK_REFERENCE.md](UI_QUICK_REFERENCE.md)** | UI参考 | 前端开发 |

---

## 🎯 主要特性

### ✅ 完成的功能
- ✓ 完整的4人游戏逻辑
- ✓ 45个地块和地块升级系统
- ✓ AI玩家（易、中、难三种难度）
- ✓ 19个物品卡和34张机会卡
- ✓ 地块路障、地雷、特殊事件
- ✓ 玩家附身状态（天使、财神、穷神）
- ✓ 反应式状态管理和自动更新
- ✓ 自动和手动游戏模式
- ✓ 完整的UI系统（信息面板、对话框、卡片等）
- ✓ 骰子和移动动画

### 🎮 游戏规则
- **目标**: 击败所有对手，成为最后的赢家
- **获胜条件**: 其他所有玩家都破产
- **破产条件**: 金币不足以支付租金或其他费用
- **游戏模式**: 自动模式（AI自动玩）或手动模式（按SPACE推进）

---

## 🔧 常见任务

### 修改游戏配置
编辑 `config.lua`：
- 地块配置（名称、价格、租金等）
- 物品卡和机会卡配置
- 角色和座驾配置
- 游戏规则常数

### 调整游戏逻辑
编辑 `systems/` 下的文件：
- PlayerSystem.lua - 玩家相关逻辑
- PropertySystem.lua - 地块相关逻辑
- GameFlowSystem.lua - 游戏流程控制
- EventSystem.lua - 事件处理逻辑

### 修改UI界面
编辑以下文件：
- systems/RenderSystem.lua - 画面渲染
- ui.lua - UI组件和对话框
- 参考 UI_QUICK_REFERENCE.md 了解布局细节

### 添加新功能
1. 在相关System中添加方法
2. 如需新系统，参考现有系统的实现模式
3. 在GameManager中集成新系统
4. 参考API_QUICK.md了解系统间通信

---

## 📊 技术栈

| 组件 | 说明 |
|------|------|
| **编程语言** | Lua 5.3+ |
| **游戏引擎** | LÖVE2D 11.x |
| **框架库** | Spoke 反应式编程框架 |
| **架构模式** | 反应式编程 + 系统架构 |
| **状态管理** | Spoke State / Memo |
| **事件系统** | Spoke Trigger / Reaction |

---

## 🧪 测试

### 运行测试套件
```bash
lua TestSuite.lua
```

测试覆盖以下系统：
- PlayerSystem 基础功能
- PropertySystem 购买和升级
- GameFlowSystem 流程控制
- ItemSystem 物品管理
- AISystem 决策逻辑

### 运行示例
```bash
lua SimpleExample.lua
```

---

## 📝 代码质量

- **模块化**: 8个独立的游戏系统，职责清晰
- **反应式**: 使用Spoke框架实现自动状态变化响应
- **可测试**: 支持独立的系统测试
- **可扩展**: 易于添加新系统或修改现有逻辑
- **性能**: 通过Memo实现高效的计算缓存

---

## 🤝 项目历程

**第一阶段**: 传统实现 (game.lua + render.lua)  
**第二阶段**: Spoke框架迁移 (GameManager.lua + systems/)  
**第三阶段**: 代码清理和文档整理 (当前)

所有非Spoke框架实现已删除，项目统一使用现代化的反应式编程模式。

---

## 📖 进一步学习

1. **快速开始**: 阅读 [QUICKSTART.md](QUICKSTART.md)
2. **理解架构**: 阅读 [SPOKE_ARCHITECTURE.md](SPOKE_ARCHITECTURE.md)
3. **查阅API**: 参考 [API_QUICK.md](API_QUICK.md)
4. **UI开发**: 参考 [UI_QUICK_REFERENCE.md](UI_QUICK_REFERENCE.md)
5. **查看源码**: 探索 `systems/` 目录下的实现

---

**项目完成度**: 100% ✅  
**最后更新**: 2026-01-07  
**维护状态**: 积极维护
