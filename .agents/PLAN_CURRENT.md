# `.agents/docs/ui` 新 UI 文档重建（含建筑升级屏）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次只改文档，不改运行代码。完成后，`/.agents/docs/ui/` 将以 `Data/UIManagerNodes.lua` 为唯一节点真相源，旧 UI 文档冻结为 Legacy，新文档明确新分屏架构（含建筑升级屏进入选择系统）。

可观察结果：

1. `/.agents/docs/ui/` 下存在 `*_Legacy.md` 旧文归档；
2. 新 `00-05` 文档完整描述 V2 画布、路由和节点语义；
3. 文档中“弹窗/选择/建筑升级/黑市”按钮语义无冲突。

## 进度

- [x] (2026-02-10 21:50Z) 读取旧文档、`UIManagerNodes` 与现有 UI 代码，确认旧文与现状不一致。
- [x] (2026-02-10 22:05Z) 与需求方锁定文档策略：Legacy 冻结 + 新规范重写。
- [x] (2026-02-10 22:14Z) 执行旧文重命名并加入冻结声明。
- [x] (2026-02-10 22:19Z) 重写新 `00-05` 文档，纳入建筑升级屏选择路由。
- [x] (2026-02-10 22:21Z) 完成一致性校验并记录复盘。

## 意外与发现

- 观察：`Data/UIManagerNodes.lua` 已无 `通用选择屏/弹窗屏` 节点，旧文档节点名已失真。
  证据：`rg "通用选择屏|弹窗屏" Data/UIManagerNodes.lua` 无结果。

- 观察：`建筑升级屏` 已存在 `建筑升级_确定按钮/建筑升级_取消`，可直接承接地产可选确认流。
  证据：`Data/UIManagerNodes.lua` 可检索到上述节点。

## 决策日志

- 决策：旧文保留为历史并冻结，避免丢失背景信息。
  理由：既保留追溯能力，又确保新文成为唯一规范入口。
  日期/作者：2026-02-10 / Codex

- 决策：`landing_optional_effect/land_optional_effect` 且 `option_id ∈ {buy_land, upgrade_land}` 时文档路由到 `建筑升级屏`。
  理由：与现有玩法语义一致，且节点能力匹配“确认/取消”模式。
  日期/作者：2026-02-10 / Codex

- 决策：`机会卡屏` 的确认语义由 `取消按钮` 承担，`建筑升级屏` 仍使用 `建筑升级_确定按钮`。
  理由：严格贴合当前节点集，避免跨画布按钮混用。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

本轮文档重建已完成，且仅涉及 `/.agents/docs/ui/` 与 `/.agents/PLAN_CURRENT.md`。

完成项：

1. 旧文已归档为 `*_Legacy.md`，并补充冻结声明。
2. 新规范已重建为 6 篇 V2 文档，覆盖总览、基础屏、机会卡屏、选择系统、黑市屏、加载与调试。
3. 选择系统已纳入 `建筑升级屏`，并明确地产可选路由条件（`buy_land` / `upgrade_land`）。
4. 文档中确认了按钮语义边界：机会卡确认、建筑升级确认、黑市关闭互不混用。

验收证据：

- 文件结构校验：`ls -1 .agents/docs/ui`
- 节点存在性校验：批量 `rg` 检索关键节点均返回 `OK`
- 路由关键字校验：`00_UI_架构与画布.md` 与 `03_UI_选择系统.md` 均覆盖目标 kind

## 背景与导读

相关文件：

- `/.agents/docs/ui/*.md`：当前 UI 文档（旧）
- `/Data/UIManagerNodes.lua`：节点与画布真相源
- `/src/ui/UIView.lua`、`/src/ui/UIModalPresenter.lua`、`/src/ui/UIEventRouter.lua`：现有 UI 运行路径（用于写“当前代码差距”）
- `/Config/LandingEffects.lua`：地产可选效果来源（`buy_land`/`upgrade_land`）

## 工作计划

先改名冻结旧文，再写新总览文档（00）和选择系统文档（03），最后补齐机会卡、基础屏、黑市、加载与调试。每篇新文都包含“当前状态 vs 目标状态”并统一交叉引用。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 将旧 `00-05` 文件改名为 `*_Legacy.md`。
2. 在每个 Legacy 文件顶部插入冻结声明。
3. 新建/重写 `00-05` 正文文件（含 `02_UI_机会卡屏.md`、`03_UI_选择系统.md`）。
4. 执行检索校验：节点存在、路由规则覆盖、旧术语隔离。

## 验证与验收

- 节点一致性：新文档提到的节点均可在 `Data/UIManagerNodes.lua` 检索。
- 路由一致性：地产可选规则、黑市规则、遥控骰子规则、玩家/位置选择规则完整。
- 语义一致性：
  - 建筑升级屏确认=`建筑升级_确定按钮`
  - 机会卡屏确认=`取消按钮`
  - 黑市关闭=`关闭`
- 历史隔离：`通用选择屏/弹窗屏` 仅在 Legacy 或“当前代码差距”中出现。

## 可重复性与恢复

- 文档改造可重复执行。
- 若需回退：可按文件级 `git checkout -- .agents/docs/ui/*` 恢复。

## 产物与备注

本轮预期产物：

- `/.agents/docs/ui/*_Legacy.md`（6 篇）
- `/.agents/docs/ui/00_UI_架构与画布.md`
- `/.agents/docs/ui/01_UI_基础屏.md`
- `/.agents/docs/ui/02_UI_机会卡屏.md`
- `/.agents/docs/ui/03_UI_选择系统.md`
- `/.agents/docs/ui/04_UI_黑市屏.md`
- `/.agents/docs/ui/05_UI_加载屏与调试屏.md`

## 接口与依赖

文档定义的后续实现契约：

- `push_popup` -> `机会卡屏`
- `landing_optional_effect/land_optional_effect` + `buy_land|upgrade_land` -> `建筑升级屏`
- `item_target_player` -> `玩家选择屏`
- `roadblock_target/demolish_target` -> `位置选择屏`
- `remote_dice_value` -> `遥控骰子屏`
- `market_buy` -> `黑市屏`
- 其他通用选择 -> `位置选择屏`（7 槽复用）

计划更新说明（2026-02-10）：完成文档重建执行，补全“进度”和“结果与复盘”，将计划状态从“待实施”更新为“已验收”。
