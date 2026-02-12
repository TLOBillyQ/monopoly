# 第三轮：重构 src/game 目录层级（按领域分包）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前 `src/game` 目录按技术与概念混排，导致同一玩法的代码分散在多个目录，违反“同一变化原因聚合”的原则，新增功能或修规则时需要跨目录修改。此轮目标是按领域/特性分包，并用分阶段兼容迁移的方式，逐步把旧路径切到新路径。完成后，开发者能在单一领域目录内完成规则修改，并用依赖方向检查确认高层不依赖低层细节。

可见生效方式：
1) `src/game` 出现清晰的领域目录（例如 `systems/land`、`systems/items`、`systems/market`）。
2) `rg -n "src\.game\." src/game` 的引用符合新路径规则，且能跑完回归与无 UI 脚本。
3) 依赖方向检查脚本对违规路径直接报错。

## 进度

- [x] (2025-03-04 11:00Z) 产出目录映射与依赖方向规则。
- [x] (2025-03-04 11:00Z) 增加兼容层与新目录入口。（已建 core/、flow/、systems/ 入口与旧路径薄包装）
- [x] (2025-03-04 11:00Z) 分批迁移领域代码与引用。（已完成：上述目录文件已移动到 core/flow/systems；旧目录保留兼容薄包装）
- [x] (2025-03-04 11:00Z) 清理兼容层并固化依赖检查。（已删除旧目录兼容层并新增 .agents/tests/dep_rules.lua）

## 意外与发现

- 观察：待补充。
  证据：待补充。

## 决策日志

- 决策：采用“按领域/特性分包 + 分阶段兼容迁移”。
  理由：兼顾边界清晰与迁移风险控制。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

待完成后补充，重点总结：目录重组对修改效率的影响、依赖方向检查是否有效、遗留的跨域耦合。

## 背景与导读

`src/game` 目前目录为：`board/ chance/ choice/ commerce/ effect/ game/ intent/ item/ land/ market/ movement/ player/ turn/ vehicle/`。回合流程与具体系统（地块/道具/市场/机会卡）相互穿插，导致规则修改跨目录。此轮将引入“系统目录”概念，把同一领域聚合，同时保留兼容层，避免一次性全量迁移引发回归失控。

术语解释：
- 领域/特性分包：以“系统”作为目录边界，例如地块系统、道具系统、市场系统。
- 兼容层：在旧路径保留薄包装，内部 `require` 新路径，保证旧引用暂时可用。
- 依赖方向规则：高层流程只能依赖系统接口，不直接依赖系统内部实现。

## 工作计划

先列出旧目录到新目录的映射表，并定义依赖方向规则与静态检查脚本。然后在 `src/game/systems/` 下建立新目录与入口文件，并在旧目录增加兼容层转发。再按领域分批迁移代码与 `require` 路径，优先迁移地块与道具系统，因为它们被多处引用。最后移除兼容层并启用依赖方向检查为必过条件。

## 具体步骤

1) 产出目录映射与依赖规则。

在 `/.agents/docs/reports/pending.md` 增加本轮映射草案，明确旧目录对应的新系统目录。例如：
- `land/` -> `systems/land/`
- `item/` -> `systems/items/`
- `market/` -> `systems/market/`
- `chance/` -> `systems/chance/`
- `vehicle/` -> `systems/vehicle/`
- `movement/` -> `systems/movement/`
- `turn/` -> `flow/turn/`（流程层）
- `game/` -> `core/`（核心模型与组合根）

并定义依赖方向规则：`core/` 与 `flow/` 可依赖 `systems/*` 的公开入口，但 `systems/*` 不得反向依赖 `flow/` 或 `core/` 的实现文件。

2) 新建系统目录与入口。

在 `src/game/` 新建 `core/`、`flow/`、`systems/` 目录，并为每个系统添加 `index.lua` 或入口模块（名称以现有模块风格为准），作为系统对外暴露的唯一入口。入口内部 re-export 原模块内容，供迁移期使用。

3) 增加兼容层。

在旧目录中创建薄包装文件（或批量替换路径），让旧路径 `require` 新入口。例如 `src/game/land/LandActions.lua` 变为仅转发 `require("src.game.systems.land.LandActions")`。

4) 分批迁移与替换引用。

按系统分批迁移，并在每批结束后跑回归。建议顺序：
- land 系统（依赖面广）
- item 系统
- market 与 chance 系统
- movement 与 vehicle 系统
- turn 流程与 core 模块

每批迁移包括：移动文件、更新 `require` 路径、更新测试引用与兼容层。

5) 清理兼容层与依赖检查。

当所有引用完成迁移后，删除旧目录中的兼容文件，更新 `rg` 检查与静态脚本，确保新目录为唯一来源。

## 验证与验收

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua

预期：回归通过；无 UI 脚本输出 `tick ok`。

新增依赖方向检查脚本（例如 `.agents/tests/dep_rules.lua`）后，执行：

    lua .agents/tests/dep_rules.lua

预期：无违规输出；若违规，应明确提示“高层依赖低层细节”的具体文件路径。

## 可重复性与恢复

迁移按系统分批进行，每批完成后可单独回滚。若出现大范围失败，可暂时保留兼容层并停止迁移，确保回归可运行。所有路径迁移均可通过版本控制恢复。

## 产物与备注

预期新增/修改：

    src/game/core/
    src/game/flow/
    src/game/systems/
    .agents/tests/dep_rules.lua
    .agents/docs/reports/pending.md

迁移完成后应保证：

    rg -n "src\.game\.land" src

无旧路径引用。

## 接口与依赖

系统入口必须明确，举例：

    src/game/systems/land/index.lua
    src/game/systems/items/index.lua

入口只暴露对外 API，不暴露内部实现细节。`flow/` 中的回合流程只依赖系统入口与 `core/` 的抽象接口。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入“按领域分包 + 分阶段兼容迁移”的第三轮重构计划。

变更说明（2025-03-04 / Codex）：更新进度，开始第 2 步（新增入口与兼容层）。

变更说明（2025-03-04 / Codex）：完成第 2 步并推进第 3 步，先替换 require 路径到新入口，暂未移动文件。

变更说明（2025-03-04 / Codex）：完成第 3 步，已移动文件并保留旧路径兼容层，开始第 4 步。

变更说明（2025-03-04 / Codex）：新增依赖方向检查脚本 .agents/tests/dep_rules.lua，尚未删除兼容层。

变更说明（2025-03-04 / Codex）：完成第 4 步，删除旧目录兼容层，仅保留 core/flow/systems。
