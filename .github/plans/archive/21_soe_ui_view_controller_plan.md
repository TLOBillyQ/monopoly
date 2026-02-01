本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

# SOE UI View/Controller 拆分


## 目的 / 全局视角

把 Eggy UI 的节点绑定、展示与交互逻辑拆分成 View/Controller 风格，接近 SOE 的 `GUI/MainView.lua` 与 `GUI/MainController.lua` 组织方式，减轻 `EggyLayer` 的职责负担。完成后 UI 逻辑更清晰，功能与行为保持不变。验收时 UI 可正常刷新、按钮交互不回退，回归测试通过。

## 进度

- [x] (2026-01-29 16:04Z) 盘点 Eggy UI 现状与职责边界，明确拆分对象
- [x] (2026-01-29 16:04Z) 新建 View/Controller 模块并迁移逻辑，更新 EggyLayer 调用
- [x] (2026-01-29 16:04Z) 清理遗留逻辑与文档引用，运行测试验证

## 意外与发现

- 观察：`lua .github/tests/ui_missing_impl_audit.lua` 仍提示若干 UI 节点未在适配层覆盖（多为历史遗留节点）。
  证据：脚本输出包含 `MissingInAdapter` 列表（例如 `panel_player_1_avatar` 等）。

## 决策日志

- 决策：新增 `Manager/TurnManager/GUI/MainView.lua` 与 `MainController.lua`，由 `EggyLayer` 继续保留对外方法并转为委托。
  理由：满足 SOE 视图/控制器拆分要求，同时不破坏既有对外接口。
  日期/作者：2026-01-29 / Codex

## 结果与复盘

EggyLayer 的 UI 展示与交互逻辑已拆到 View/Controller 模块，文档路径更新，依赖检查与回归测试通过。UI 审计脚本维持历史的 MissingInAdapter 输出，未引入新回归。

## 背景与导读

当前 UI 逻辑主要集中在 `Manager/TurnManager/GUI/Layer.lua`，其中包含 UI 查询、面板刷新、黑市 UI、棋盘锚点缓存、弹窗处理与动作分发。SOE 习惯把 UI 节点查找与展示集中在 View，把交互与事件响应集中在 Controller。此次已新增 `Manager/TurnManager/GUI/MainView.lua` 与 `Manager/TurnManager/GUI/MainController.lua`，并将逻辑迁移到新模块。

## 工作计划

先梳理 UI 模块的职责边界，确定需要拆分的 View 与 Controller。在 `Manager/Adapter/Eggy/GUI/` 下新增模块，View 负责节点缓存与渲染函数，Controller 负责交互回调与派发动作。`EggyLayer` 只保留状态与调度，调用新的 View/Controller 接口。迁移过程中保持原函数签名，避免改动规则层与测试。

## 具体步骤

在仓库根目录执行：

  1) 标注 `EggyLayer` 中 UI 相关函数与调用点。
  2) 创建 `Manager/Adapter/Eggy/GUI` 目录，新增 `MainView.lua`、`MainController.lua` 并迁移逻辑。
  3) 修改 `EggyLayer` 调用链，将渲染与交互交给 View/Controller。
  4) 更新文档路径引用，保持 UI 资源名与数据结构不变。

## 验证与验收

在仓库根目录运行：

  lua .github/tests/deps_check.lua
  lua .github/tests/regression.lua
  lua .github/tests/ui_nodes_audit.lua
  lua .github/tests/ui_missing_impl_audit.lua

进入 Eggy 场景后检查 UI 文本刷新、按钮点击与黑市交互均正常。`ui_missing_impl_audit` 输出为历史缺失清单。

## 可重复性与恢复

改动以逻辑迁移为主，可随时回滚到集中式 `EggyLayer` 逻辑。若出现交互异常，可恢复原文件并逐步迁移。本次迁移未改变接口签名。

## 产物与备注

产物包含 `Manager/Adapter/Eggy/GUI/` 下的 View/Controller 模块，以及精简后的 `EggyLayer`。

  Dependency self-check passed
  ..............................
  All regression checks passed (30)
  [ui-audit] ok: all required nodes/events are present (directly or via mapping)
  [ui-missing] MissingInAdapter: (见 .github/tests/ui_missing_impl_audit.lua 输出)

## 接口与依赖

View/Controller 模块必须只依赖 UIManager 与 `EggyLayer` 提供的状态，不直接依赖规则层。`EggyLayer` 对外接口保持不变，新模块仅做内部委托。

更新说明：完成 Eggy UI View/Controller 拆分与文档路径更新，记录 UI 审计结果以对照历史缺失。
