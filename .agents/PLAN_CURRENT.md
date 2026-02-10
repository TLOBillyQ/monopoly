# Legacy UI 全量迁移到新 UI（并删除旧文档）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次目标是把代码库 UI 从 legacy 节点（`通用选择屏`/`弹窗屏`）迁移到 `Data/UIManagerNodes.lua` 的新节点体系，并移除所有 legacy 兼容代码与 legacy 文档。完成后：

1. `src/ui` 不再引用 `通用选择_*` 与 `弹窗*` 节点；
2. 选择分屏按新规则运行（玩家/位置/遥控骰子/建筑升级/黑市）；
3. `/.agents/docs/ui/*_Legacy.md` 删除，`PENDING_PLAN.md` 为空文件；
4. 回归测试通过并且 legacy 关键词清零。

## 进度

- [x] (2026-02-10 22:32Z) 完成现状勘察，确认 legacy 节点残留在 `UIView/UIModalPresenter/UICanvasCoordinator/UIEventRouter/UIAliases` 与 `ui` 测试。
- [x] (2026-02-10 22:36Z) 清空 `/.agents/docs/PENDING_PLAN.md`（保留空文件）。
- [x] (2026-02-10 22:36Z) 重写当前可执行计划到 `/.agents/PLAN_CURRENT.md`。
- [x] (2026-02-10 22:39Z) 迁移 `UIView/UIInputLockPolicy` 到新状态结构（`choice_screens/popup_screen/active_choice_screen_key`）。
- [x] (2026-02-10 22:44Z) 完成 `UIModalPresenter/UIChoiceRoutePolicy/UICanvasCoordinator` 新分屏路由改造，移除 legacy 画布常量。
- [x] (2026-02-10 22:48Z) 完成 `UIEventRouter/UIModalStateCoordinator/MarketView/init` 字段收敛为 `choice_visible_option_ids`。
- [x] (2026-02-10 22:52Z) 完成 `/.agents/tests/suites/ui.lua` 迁移到新节点断言与路由覆盖（含建筑升级屏与回退规则）。
- [x] (2026-02-10 22:57Z) 删除 `/.agents/docs/ui/*_Legacy.md` 并重写新 00-05 文档为最终态口径。
- [x] (2026-02-10 23:01Z) 完成回归与门禁检索并记录结果。

## 意外与发现

- 观察：`Data/UIManagerNodes.lua` 中已无 `通用选择屏` 与 `弹窗屏`，说明运行时代码必须彻底切换，否则会触发 missing ui node。
  证据：`rg "通用选择屏|弹窗屏" Data/UIManagerNodes.lua` 无命中。

- 观察：`取消按钮` 在多个新画布复用（机会卡屏、玩家/位置选择），事件路由必须基于运行态判定语义。
  证据：`Data/UIManagerNodes.lua` 仅存在一个 `取消按钮` 节点名。

- 观察：全量迁移后回归用例从 94 增至 95，新增用例用于覆盖新分屏路由与建筑升级屏规则。
  证据：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (95)`。

## 决策日志

- 决策：保留 `/.agents/docs/PENDING_PLAN.md` 文件但清空内容。
  理由：满足“清空”要求并避免路径引用失效。
  日期/作者：2026-02-10 / Codex

- 决策：legacy 兼容彻底移除，不保留回退分支。
  理由：用户明确要求迁移后不需要旧代码和旧文档。
  日期/作者：2026-02-10 / Codex

- 决策：`位置脚下` 使用固定规则识别（label 含“脚下”或“当前位置”）。
  理由：现有 choice 数据无标准化字段，只能使用稳定文本匹配策略。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

本轮已完成“legacy UI 全量迁移到新 UI”的目标，代码与文档均切换到最终态，不再保留旧节点兼容。`src/ui` 已移除 `通用选择屏/弹窗屏` 路由与命名；选择系统改为玩家/位置/遥控骰子/建筑升级/黑市分流；`PENDING_PLAN.md` 已清空且保留空文件；`/.agents/docs/ui/*_Legacy.md` 已全部删除，新 00-05 文档均为最终态口径。

验收结果：

1. 回归通过：`lua .agents/tests/regression.lua` -> `All regression checks passed (95)`。
2. 旧代码清零：`rg -n "通用选择屏|弹窗屏|通用选择_|弹窗标题|弹窗正文|弹窗确认|弹窗卡牌" src/ui .agents/tests` 无命中。
3. 旧文档清零：`ls -1 .agents/docs/ui | rg "_Legacy\\.md$"` 无命中。
4. 计划文件状态：`test ! -s .agents/docs/PENDING_PLAN.md && echo OK_PENDING_EMPTY` 输出 `OK_PENDING_EMPTY`。

复盘结论：本次风险最高点是“取消按钮”复用语义冲突，已通过 `UIEventRouter` 运行态判定（`popup_active` 优先）收敛；建筑升级屏仅承接地产可选，其他 optional 回退位置选择屏，行为与约束一致。

## 背景与导读

关键改动文件：

- `src/ui/UIView.lua`
- `src/ui/UIInputLockPolicy.lua`
- `src/ui/UIModalPresenter.lua`
- `src/ui/UICanvasCoordinator.lua`
- `src/ui/UIEventRouter.lua`
- `src/ui/UIModalStateCoordinator.lua`
- `src/ui/MarketView.lua`
- `src/ui/UIAliases.lua`
- `src/app/init.lua`
- `.agents/tests/suites/ui.lua`
- `.agents/docs/ui/*.md`

## 工作计划

先改 UI 状态模型与画布路由，再改事件绑定与状态字段，随后调整回归测试，最后清理文档与 legacy 文件并执行全量验证。中间不改玩法层数据结构，保持 `choice.kind` 与 action 协议不变。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 清空 `PENDING_PLAN` 并更新 `PLAN_CURRENT`。
2. 新增 `src/ui/UIChoiceRoutePolicy.lua`。
3. 改造 `UIView/UIModalPresenter/UICanvasCoordinator/UIInputLockPolicy`。
4. 改造 `UIEventRouter/UIModalStateCoordinator/MarketView/init` 状态字段。
5. 更新 `ui` 套件测试与断言。
6. 删除 `/.agents/docs/ui/*_Legacy.md` 并重写新文档为最终态。
7. 执行回归与门禁检索。

## 验证与验收

- `lua .agents/tests/regression.lua` 通过。
- `rg -n "通用选择屏|弹窗屏|通用选择_|弹窗标题|弹窗正文|弹窗确认|弹窗卡牌" src/ui .agents/tests` 无结果。
- `ls -1 .agents/docs/ui | rg "_Legacy\\.md$"` 无结果。
- `test ! -s .agents/docs/PENDING_PLAN.md && echo OK_PENDING_EMPTY` 输出 `OK_PENDING_EMPTY`。

## 可重复性与恢复

- 本计划步骤可重复执行。
- 若中途失败，按文件粒度回滚：`git checkout -- <file>`。
- 恢复后必须重新跑回归与门禁检索。

## 产物与备注

预期新增：

- `src/ui/UIChoiceRoutePolicy.lua`

预期删除：

- `/.agents/docs/ui/*_Legacy.md`（6 个）

预期重写：

- `/.agents/docs/ui/00_UI_架构与画布.md`
- `/.agents/docs/ui/01_UI_基础屏.md`
- `/.agents/docs/ui/02_UI_机会卡屏.md`
- `/.agents/docs/ui/03_UI_选择系统.md`
- `/.agents/docs/ui/04_UI_黑市屏.md`
- `/.agents/docs/ui/05_UI_加载屏与调试屏.md`

## 接口与依赖

保持不变的外部接口：

- `ui_view.open_choice_modal(state, choice, market)`
- `ui_view.push_popup(state, payload)`
- `ui_view.close_choice_modal(state)`
- `ui_view.close_popup(state)`

新增内部路由接口：

- `UIChoiceRoutePolicy.resolve(choice) -> screen_key`
- `UIChoiceRoutePolicy.is_building_choice(choice) -> boolean`
- `UIChoiceRoutePolicy.requires_confirm(screen_key) -> boolean`

## 本次更新说明

2026-02-10：将计划状态从“执行中”更新为“已完成”，补充了最终验收结果与复盘结论，目的是让后续接手者无需再对照聊天记录即可确认交付状态。
