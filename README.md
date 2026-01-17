# 蛋仔大富翁 Monopoly

一个以**可维护性优先**设计的大富翁回合制棋盘游戏，使用 Lua + LÖVE2D 实现。

## 项目特点

- **表驱动设计**：游戏数据（地图、道具、角色）通过配置表定义，易于修改和扩展
- **清晰的架构分层**：核心游戏逻辑与渲染层解耦，遵循好莱坞原则和 SOLID 原则
- **代码质量保障**：内置依赖检查、回归测试和静态分析脚本
- **持续简化**：优先删除和复用代码，避免过度抽象

## 快速开始

### 环境要求

- [LÖVE2D](https://love2d.org/) 11.x（自带 Lua 解释器）

### 运行游戏

```bash
# 在项目根目录运行
love .
```

游戏入口为 [main.lua](main.lua)，会自动加载配置并启动游戏。

## 项目结构

```
monopoly/
├── main.lua              # 游戏入口，配置 package.path 并启动 LÖVE 适配层
├── src/
│   ├── game.lua         # 游戏实例装配（依赖注入、服务组装）
│   ├── core/            # 核心领域对象（Board, Player, Dice, Tile 等）
│   ├── gameplay/        # 游戏逻辑与流程（包含 choice_handlers 子目录）
│   │   ├── composition_root.lua  # 依赖注入装配
│   │   ├── *_service.lua         # 业务服务（movement, market, bankruptcy, turn_manager）
│   │   ├── turn_*.lua            # 回合阶段处理
│   │   ├── item_*.lua            # 道具系统
│   │   ├── land*.lua             # 地块逻辑
│   │   ├── landing*.lua          # 落地效果处理
│   │   ├── choice*.lua           # 选择系统
│   │   ├── agent.lua             # AI 决策
│   │   ├── rng.lua, store.lua    # 基础设施
│   │   └── choice_handlers/      # 选择处理器
│   ├── adapters/       # 适配器层
│   │   └── love2d/    # LÖVE2D 渲染、输入、UI 适配
│   ├── config/         # 游戏配置表（地图、地块、角色、道具）
│   └── util/           # 通用工具函数
├── tests/              # 测试脚本
├── docs/               # 设计文档和技术文档
└── assets/             # 游戏资源
```

### 核心模块说明

| 模块 | 职责 |
|------|------|
| `src/game.lua` | 游戏实例装配，初始化服务和状态管理器 |
| `src/core/` | 核心领域对象（Board, Player, Dice, Tile, Inventory） |
| `src/gameplay/` | 游戏逻辑（扁平化结构，包含服务、回合、道具、AI 等） |
| `src/adapters/love2d/` | LÖVE2D 框架适配（渲染、输入、UI 组件） |
| `src/config/` | 游戏数据配置（地图、地块、角色、道具、常量） |

## 开发工具

### 常用命令

```bash
# 运行游戏
love .

# 依赖规则检查（确保架构分层正确）
lua tests/deps_check.lua

# 回归测试（验证核心游戏逻辑）
lua tests/regression.lua
```

### 推荐工作流

在重构或修改代码前后，运行以下检查：

```bash
lua scripts/deps_check.lua && lua scripts/regression.lua
```

### 代码精简工作流（Debloat）

遵循"删代码优先"原则，推荐按以下顺序执行：

1. **依赖检查**：`lua tests/deps_check.lua` - 确保依赖方向未被破坏
2. **回归测试**：`lua tests/regression.lua` - 确保关键行为未变

### 依赖规则

- ✅ **Gameplay 层独立**：`src/gameplay/**` 不能依赖 `src/adapters/**`
- ✅ **服务解耦**：services 之间不能互相依赖（通过依赖注入组装）

运行 `lua tests/deps_check.lua` 验证这些规则。

### 设计原则

本项目遵循 [AGENTS.md](AGENTS.md) 中定义的编码规则：

1. **无默认抽象**：除非有 2 个以上调用点，否则不添加接口或辅助层
2. **单一实现**：类似逻辑必须合并，新代码替换旧代码而非共存
3. **激进删除**：删除未使用的函数、模块、参数和分支
4. **保持简单**：优先使用普通表和函数，避免元表和继承模式
5. **限制增长**：优先编辑现有文件，添加新文件需要充分理由
6. **强制清理**：每次改动后必须问"现在能删除什么代码？"

**目标：最少代码、最少概念、最少文件。**
tes
## 回归测试基线

`scripts/regression.lua` 通过纯 Lua 构造游戏实例，验证关键路径：

- ✓ 经过起点获得奖励
- ✓ 路障停留机制
- ✓ 道具效果触发
- ✓ 可选行动（等待/自动购买）
- ✓ 破产和游戏结束

## 文档

- **设计文档**：[docs/design/](docs/design/) - 游戏策划、数据表设计
- **架构文档**：[docs/deepfuture/](docs/deepfuture/) - 架构演进计划
- **蛋仔相关**：[docs/eggy/](docs/eggy/) - 蛋仔乐园相关文档
- **API 文档**：[docs/api.md](docs/api.md) - 核心入口函数说明
- **ADR**：[docs/adr/](docs/adr/) - 架构决策记录
- **开发规范**：[AGENTS.md](AGENTS.md) - 编码规则和原则

## 技术栈

- **语言**：Lua 5.1+
- **游戏引擎**：LÖVE2D 11.x
- **架构风格**：六边形架构（端口-适配器模式）
- **设计原则**：SOLID、好莱坞原则、依赖注入

## 贡献指南

在提交代码前，请：

1. 阅读 [AGENTS.md](AGENTS.md) 了解编码规则
2. 运行 `lua tests/deps_check.lua` 检查依赖规则
3. 运行 `lua tests/regression.lua` 确保回归测试通过
4. 优先考虑删除或复用代码，而非添加新代码
