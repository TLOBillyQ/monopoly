
# 蛋仔大富翁（Lua / LÖVE2D）

以“可维护性优先”的方式实现的类大富翁回合制棋盘游戏原型。

- 运行时：LÖVE2D 11.x（自带 Lua）
- 目标：在不改玩法语义的前提下，持续降低复杂度、保持回归可跑

## 快速开始

1. 安装 LÖVE2D 11.x
2. 在项目根目录运行：`love .`

入口文件是 [main.lua](main.lua)，会设置 `package.path` 并启动 LÖVE 适配层。

## 常用命令

- 运行游戏：`love .`
- 依赖规则自检：`lua scripts/deps_check.lua`
- 纯 Lua 小回归：`lua scripts/regression.lua`
- 统计 Lua 行数：`lua scripts/count_lines.lua`
- 静态死代码扫描（保守）：`lua scripts/debloat_report.lua`

## 代码结构（高层）

- [src/app.lua](src/app.lua)：游戏实例装配与状态容器（store/rng/players/services/turn_manager）
- [src/gameplay](src/gameplay)：规则与流程
	- `app/`：流程编排、回合状态机、解析器、服务
	- `domain/`：领域对象与规则（effect、item、landing 等）
	- `infra/`：基础设施（rng、store）
	- `ports/`：端口抽象（例如 UI 端口）
- [src/adapters/love2d](src/adapters/love2d)：LÖVE2D 适配层（渲染、输入、面板、弹窗）
- [src/config](src/config)：地图、地块、角色、道具、常量等配置
- [scripts](scripts)：自检与统计脚本
- [docs](docs)：架构/设计与路线图（中文为主）

## 分层与依赖规则

项目使用轻量的“分层 + 自检脚本”来防止依赖倒灌：

- `src/gameplay/**` 不应 `require("src.adapters.*")`
- `src/gameplay/domain/**` 不应依赖 `src.gameplay.app.*`
- `src/gameplay/app/services/**` 不应互相 `require("src.gameplay.app.services.*")`（应走注入/聚合入口）

运行 `lua scripts/deps_check.lua` 可以检查以上规则。

## 回归基线

`lua scripts/regression.lua` 通过纯 Lua 构造 `App` 并跑一组关键路径断言（例如：经过起点奖励、路障停留、道具效果、可选行动等待/自动购买等）。

建议每次重构/删代码前后都跑一次：

- `lua scripts/deps_check.lua && lua scripts/regression.lua`

## Debloat（删代码）工作流

推荐顺序：

1. `lua scripts/deps_check.lua`（保证依赖方向没被破坏）
2. `lua scripts/regression.lua`（保证关键行为未变）
3. `lua scripts/debloat_report.lua`（找未被 require 到的 Lua 文件；保守静态分析）

如果 `debloat_report.lua` 报告“Unused runtime-scope Lua files”，通常可以先从“明显弃用/空壳模块”开始清理。

## 路线图与文档

- [docs/reviews/structure%20review.md](docs/reviews/structure%20review.md)：结构审查与迁移计划（进行中）
- [docs/ROADMAP_CODE_REDUCTION.md](docs/ROADMAP_CODE_REDUCTION.md)：代码行数降低路线图
- [docs/CODE_ANALYSIS.md](docs/CODE_ANALYSIS.md)：分析与改进点
- [docs/REFACTORING_GUIDE.md](docs/REFACTORING_GUIDE.md)：重构快速指南

