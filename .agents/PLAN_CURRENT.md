# UI 新布局全量切换（Data/UIManagerNodes 对齐）

本可执行计划是活文档。实施过程中持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md`。

## 目的 / 全局视角

把代码、测试、文档全部切到 `Data/UIManagerNodes.lua` 新节点，避免运行时再查旧节点报错。  
完成后可观察到三点：玩家/位置选择点选即提交；弹窗改为卡牌展示屏（标题+图片）；托管状态文案落到 `托管_文本`。

## 进度

- [x] (2026-02-11 09:40Z) 重写本计划，锁定执行范围和验收命令。
- [x] (2026-02-11 09:48Z) 修改 `src/ui`：节点映射与交互切换到新布局。
- [x] (2026-02-11 09:50Z) 修改 `UIEventRouter`：玩家/位置改点选即提交。
- [x] (2026-02-11 09:54Z) 修改 `/.agents/tests/suites/ui.lua`：夹具与断言对齐新节点，并新增直提交流程覆盖。
- [x] (2026-02-11 09:56Z) 修改 `/.agents/docs/ui/00~04`：文档口径切到新布局。
- [x] (2026-02-11 09:58Z) 完成回归与检索验收，记录结果。

## 意外与发现

- 观察：当前代码仍引用 `机会卡屏`、`玩家选择_确认按钮`、`位置_放置确认`、`自动控制按钮`。
  证据：`rg -n "机会卡屏|玩家选择_确认按钮|位置_放置确认|自动控制按钮" src/ui`

- 观察：按验收命令检索旧节点时，文档标题与索引文本仍会命中 `机会卡屏`。
  证据：`rg -n "机会卡屏|..." src/ui .agents/tests/suites .agents/docs/ui` 命中 `02_UI_机会卡屏.md` 标题与 00 文档索引。

## 决策日志

- 决策：玩家选择屏与位置选择屏统一改“点选即提交”。
  理由：新布局已移除两个确认按钮节点，继续双步提交流程会产生缺失节点。
  日期/作者：2026-02-11 / Codex

- 决策：弹窗屏只保留标题+图片，不再渲染正文节点。
  理由：`Data/UIManagerNodes.lua` 新布局没有弹窗正文节点。
  日期/作者：2026-02-11 / Codex

- 决策：托管状态文案写入 `托管_文本`，`托管按钮`只承载点击。
  理由：新布局把旧 `自动控制按钮` 改名为 `托管_文本` 且类型为标签。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

本轮已完成“新布局全量切换”目标：`src/ui`、`ui` 测试、UI 文档全部切到 `Data/UIManagerNodes.lua` 新节点口径，旧节点引用在目标范围内清零。

关键结果：

1. 玩家选择与位置选择改为“点选即提交”（`UIEventRouter` 直接发 `choice_select`）。
2. 弹窗画布改为 `卡牌展示屏`，只渲染标题与图片。
3. 托管文案改写到 `托管_文本`，`托管按钮`仅负责点击。
4. 回归通过并新增 1 条 UI 路由测试，总数从 95 到 96。

验收证据：

- `lua .agents/tests/regression.lua` -> `All regression checks passed (96)`
- `rg -n "机会卡屏|机会卡_标题|机会卡_图片|请输入文字|玩家选择_确认按钮|位置_放置确认|自动控制按钮" src/ui .agents/tests/suites .agents/docs/ui` -> 无命中
- `rg -n "卡牌展示屏|卡牌展示_标题|卡牌展示_图片|托管_文本|建筑升级_文本" src/ui .agents/tests/suites .agents/docs/ui` -> 命中范围正确

## 背景与导读

本次改动涉及三类文件：

1. 运行时代码：`src/ui/*.lua`（节点名、画布名、事件路由）。
2. 回归测试：`/.agents/tests/suites/ui.lua`（测试夹具与断言）。
3. UI 文档：`/.agents/docs/ui/00~04`（节点和交互规则描述）。

真相源始终是 `Data/UIManagerNodes.lua`，本任务不改该文件。

## 工作计划

先处理运行时代码，消除旧节点查询风险；再改路由交互，确保玩家/位置能直接提交；然后更新测试与文档，最后执行回归和检索验收。

## 具体步骤

工作目录：`C:\Users\Lzx_8\Desktop\dev\monopoly`

1. 改 `UIView/UICanvasCoordinator/UIPanelPresenter/UIModalPresenter`。
2. 改 `UIEventRouter` 与 `UIChoiceRoutePolicy`。
3. 改 `/.agents/tests/suites/ui.lua`。
4. 改 `/.agents/docs/ui/00~04`。
5. 跑：
   - `lua .agents/tests/regression.lua`
   - `rg -n "机会卡屏|机会卡_标题|机会卡_图片|请输入文字|玩家选择_确认按钮|位置_放置确认|自动控制按钮" src/ui .agents/tests/suites .agents/docs/ui`
   - `rg -n "卡牌展示屏|卡牌展示_标题|卡牌展示_图片|托管_文本|建筑升级_文本" src/ui .agents/tests/suites .agents/docs/ui`

## 验证与验收

- 回归：`lua .agents/tests/regression.lua` 全通过。
- 旧节点清零检索：无命中。
- 新节点落地检索：命中范围与改造文件一致。

## 可重复性与恢复

- 所有步骤可重复执行。
- 若中途失败可按文件回滚：`git checkout -- <file>`，再重跑回归与检索。

## 产物与备注

预期修改：

- `src/ui/UIView.lua`
- `src/ui/UICanvasCoordinator.lua`
- `src/ui/UIPanelPresenter.lua`
- `src/ui/UIModalPresenter.lua`
- `src/ui/UIEventRouter.lua`
- `src/ui/UIChoiceRoutePolicy.lua`
- `.agents/tests/suites/ui.lua`
- `.agents/docs/ui/00_UI_架构与画布.md`
- `.agents/docs/ui/01_UI_基础屏.md`
- `.agents/docs/ui/02_UI_机会卡屏.md`
- `.agents/docs/ui/03_UI_选择系统.md`
- `.agents/docs/ui/04_UI_黑市屏.md`

## 接口与依赖

保持协议不变：

- `choice_select` / `choice_cancel` / `ui_button` action 协议不变。
- `Data/UIManagerNodes.lua` 仍是 UI 节点真相源。

内部约束更新：

- `UIChoiceRoutePolicy.requires_confirm(screen_key)` 仅 `building` 返回 true。
- `ui_state.auto_control_nodes` 改为 `{"托管按钮", "托管_文本"}`。
