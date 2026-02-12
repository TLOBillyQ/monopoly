# 重构 `src/ui` 为 `presentation` 分层目录（UI + Render + 交互编排）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前 `src/ui` 同时承载渲染、UI 组件、交互策略、状态投影和对 game 层入口，职责混杂导致定位困难和改动风险扩大。本次重构将其拆分为 `src/presentation` 六层结构，并保留 `src/ui` 兼容桥接。完成后，开发者可以在 1 分钟内定位展示层代码归属；旧调用方仍可运行；game 层关键调用切到新路径。

可见生效方式：
1. `src/presentation/*` 模块可独立 `require`。
2. `src/ui/*` 仍可 `require`（桥接到新目录）。
3. `GameplayLoop/TickTimeout/TickUISync/Bankruptcy` 改用新路径后可正常加载。

## 进度

- [x] (2026-02-12 13:48Z) 确认现状与约束：读取 `AGENTS.md`、`.agents/CODING.md`、`.agents/PLANS.md`，盘点 `src/ui` 文件与 game 层依赖点。
- [x] (2026-02-12 15:12Z) 执行目录重构：创建 `src/presentation` 六层并迁移 `src/ui` 现有文件。
- [x] (2026-02-12 15:16Z) 修正新目录内部 require 路径为 `src.presentation.*`。
- [x] (2026-02-12 15:18Z) 建立 `src/ui` 全量兼容桥接（每文件单行 re-export）。
- [x] (2026-02-12 15:20Z) 迁移 game 层四个直接依赖点到 `src.presentation.*`。
- [x] (2026-02-12 15:26Z) 增加并执行 require 回归验证脚本（覆盖 `src.presentation.*` 与 `src.ui.*`）。
- [x] (2026-02-12 15:30Z) 更新文档：补充分层导读、deprecated 说明与后续删除条件。
- [x] (2026-02-12 15:32Z) (收尾) 更新“意外与发现/决策日志/结果与复盘”并同步真实状态。

## 意外与发现

- 观察：原 `src/ui` 内部互相 `require("src.ui.*")`，迁移后必须补全子层路径，否则出现 `src.presentation.<Module>` 找不到。
  证据：运行 `lua .agents/tests/presentation_require_smoke.lua` 初次失败报错 `module 'src.presentation.BoardView' not found`，修正后通过。

## 决策日志

- 决策：采用 `src/presentation` 作为新根目录，保留 `src/ui` 作为过渡兼容层。
  理由：语义比 `view/client` 更准确，且可降低一次性迁移风险。
  日期/作者：2026-02-12 / Codex

- 决策：本次不改函数签名与业务语义，只做结构迁移与路径替换。
  理由：确保风险可控，便于行为等价验证。
  日期/作者：2026-02-12 / Codex

- 决策：兼容层使用每文件 `return require("src.presentation.<layer>.<Name>")` 直转发，不做额外逻辑。
  理由：减少维护点，保证旧路径行为与新路径一致。
  日期/作者：2026-02-12 / Codex

## 结果与复盘

已完成 `src/ui` -> `src/presentation` 的六层迁移，game 侧关键依赖已切换到新路径；兼容层可保证旧路径继续可用。新增冒烟脚本验证新旧路径 require 均通过。

遗留：无。

经验：迁移前应统一规范模块内的 require 路径，避免出现“新路径下还在 require 旧路径”的混用。

## 背景与导读

当前展示层代码集中在 `/Users/billyq/Dev/Github/Lua/monopoly/src/ui`，包含 `BoardView/TileRenderer` 等渲染模块、`UIPanel/UIChoice` 等组件模块、`UIEventRouter/UIInputLockPolicy` 等交互模块，以及 `UIView/UIEventHandlers/UIRuntimePort` 入口模块。game 层已有直接依赖：
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/turn/GameplayLoop.lua` 依赖 `src.ui.UIEventHandlers`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/turn/TickTimeout.lua` 依赖 `src.ui.UIView`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/turn/TickUISync.lua` 依赖 `src.ui.UIView`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/game/Bankruptcy.lua` 依赖 `src.ui.TileRenderer`

“兼容桥接”是指旧路径文件仅返回新路径模块，不包含任何逻辑，从而保证旧调用可运行。

## 工作计划

先创建 `src/presentation/api|render|ui|state|interaction|shared` 六个目录。随后把 `src/ui` 文件按职责迁移到新目录，迁移时只调整 `require("src.ui...")` 到对应 `require("src.presentation...")`，不改函数语义。

迁移后在 `src/ui` 位置重建同名桥接文件，内容统一为 `return require("src.presentation....")`。完成兼容层后，修改四个 game 模块依赖到新路径，优先使用 `src.presentation.api` 与 `src.presentation.render`。

最后新增一个轻量回归脚本（放在 `.agents/tests`）批量 require 新旧模块，执行并记录输出。若有路径错误或循环依赖，回到对应模块修正。最终更新项目文档，加入分层导读、deprecated 说明和兼容层清理条件。

## 具体步骤

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行：

    mkdir -p src/presentation/{api,render,ui,state,interaction,shared}

按映射迁移文件（示意，实际将逐个 mv 并改 require）：

- api: `UIView`, `UIEventHandlers`, `UIRuntimePort`
- render: `BoardView`, `MarketView`, `TileRenderer`, `BoardScene`, `ActionAnim`, `MoveAnim`, `BuildingEffects`, `UIStatus3DLayer`
- ui: `UIPanel`, `UIPanelPresenter`, `UIModalPresenter`, `UIChoice`
- state: `UIModel`, `UIModelProjection`, `UIModelPanelBuilder`, `UIRoleContext`, `UIRoleAvatar`
- interaction: `UIEventRouter`, `UICanvasCoordinator`, `UIModalStateCoordinator`, `UIInputLockPolicy`, `UIRoleControlLockPolicy`, `UIChoiceRoutePolicy`
- shared: `UIAliases`, `UIEvents`, `PlayerColors`, `MarketLayout`

其余 `src/ui` 下文件若未在映射中，默认归入最贴近职责层，并在决策日志补充理由。

替换 game 侧路径：

    src/game/turn/GameplayLoop.lua
    src/game/turn/TickTimeout.lua
    src/game/turn/TickUISync.lua
    src/game/game/Bankruptcy.lua

执行回归：

    lua .agents/tests/presentation_require_smoke.lua

预期输出包含“OK/All requires passed”字样。

## 验证与验收

验收以行为为准：
1. 运行 require 冒烟脚本，新旧路径模块全部加载成功。
2. 四个 game 模块能被 require（或项目启动链路加载）且无 `module not found`。
3. 旧路径 `src.ui.UIView/UIEventHandlers/UIRuntimePort` 仍可加载。

若有现成项目测试命令，再补跑一轮并记录通过情况。

## 可重复性与恢复

本次迁移是可重复的：目录和桥接文件可反复生成，覆盖时保持相同内容。若中途失败：
- 先用 `git status` 定位未完成文件。
- 按映射补齐缺失迁移与桥接。
- 若需回滚可执行 `git checkout -- src/ui src/presentation src/game`（按需）。

## 产物与备注

实施后将在此补充关键证据片段：

    $ lua .agents/tests/presentation_require_smoke.lua
    All requires passed: 60

以及关键 diff 摘要（路径迁移 + 桥接 + game 引用替换）。

## 接口与依赖

本次对外接口保持不变；新增稳定分层路径：
- `src.presentation.api.UIView`
- `src.presentation.api.UIEventHandlers`
- `src.presentation.api.UIRuntimePort`

保留兼容路径（过渡）：
- `src.ui.* -> src.presentation.*`

game 层后续应优先依赖 `src.presentation.api` 或明确子层（如 `src.presentation.render.TileRenderer`），避免直接跨层耦合。

---

变更说明（2026-02-12 / Codex）：完成分层迁移、路径修正、兼容层搭建与回归脚本，并更新活文档章节与验收证据。
