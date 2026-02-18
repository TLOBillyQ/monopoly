# 运行时测试计划（Presentation 交互优先）

本可执行计划是活文档。实施中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件必须遵循 `.github/PLANS.md` 格式。

## 目的 / 全局视角

目标是把“运行时测试各系统”任务转化为一个完整的三层测试矩阵：离线回归（gameplay vs presentation）、编辑器内运行时冒烟、以及能在双端中验证的Presentation交互/输入锁行为。实现后，开发者可以按固定顺序执行命令验证核心游戏逻辑、UI交互和输入锁约束，且能够在蛋仔编辑器中证明 UI click/弹窗/黑市/choice 逻辑在两个角色视角中一致。

## 进度

- [ ] (2026-02-18) 收集现有回归和运行时文档，确认 baseline 136 条回归通过。
- [ ] (pending) 建立三层测试矩阵：游戏系统回归、Presentation 回归、全量回归。
- [ ] (pending) 部署到 Eggy 编辑器并跑双端手测（交互与输入锁重点）。
- [ ] (pending) 补充运行时验证输出（日志、UI行为截图/描述），在 plan 末尾记录。

## 意外与发现

- 观察：Presentation 回归拆分成 60 条可单独运行，运行稳定。证据：`lua presentation_ui_*.lua` 输出 `All regression checks passed (60)`。
- 观察：gameplay 相关回归可拆成 75 条，输出全绿。证据：`lua chance...gameplay_loop` 命令。
- 观察：全量回归命令还额外跑 `dep_rules` 与 `tick`，输出 `dep_rules ok`、`tick ok`。证据：`lua .github/tests/regression.lua` 输出。

## 决策日志

- 决策：三层矩阵必须先后执行，Presentation 层交互+输入锁作为运行时手测重点。理由：以防变更破换 UI 交互，不先确认交互逻辑就无法收口。日期/作者：2026-02-18 / Codex。
- 决策：手测要求至少两端客户端并保持 Eggy 默认角色隔离，以便验证 `基础_行动日志` 等按角色展开。理由：输入锁/调试切换的传播依赖角色隔离。日期/作者：2026-02-18 / Codex。

## 结果与复盘

（待完成后补）在每轮测试后补充：运行命令、日志输出、发现的问题。对照“可观察的行为”列出成功/失败。

## 背景与导读

项目入口是 `main.lua` -> `src/app/init.lua` -> `UIBootstrap`。Presentation 相关交互由 `UIEventRouter`、`UIViewService`、`GameplayLoopPorts` 组成。上层点击经由 `UIEventRouter` 走 `UIIntentDispatcher` 触发 `TurnDispatch`，展示层再通过 `UIViewService.render` 调用 `BoardRuntime`/`UIPanelPresenter`。输入锁逻辑存在 `UIInputLockPolicy`，它在 `GameplayLoop` tick 中通过 ports `ui_sync.apply_input_lock` 控制 `UIManager`，并允许 `UITouchPolicy` 处理特定控制和调试开关。测试参数在 `.github/tests/suites/presentation_ui.lua` 中精确定义，`names[]` 给出覆盖点。离线命令和手册都依赖 `lua` 运行。

## 工作计划

1. 先构建验证环境：确认 `lua .github/tests/regression.lua` 及拆分命令都能运行；记录输出作为 baseline。
2. 定义测试矩阵：分别执行 “gameplay 系统回归” 、 “presentation 专项回归” 、 “全量回归（含 dep_rules/tick）”，确认每阶段输出和返回码。
3. 运行时手测：部署到 Eggy 编辑器路径（/Users/billyq/Documents/eggy/LuaSource_monopoly），用两个客户端按 UI 文档场景逐一测试点击/弹窗/输入锁/调试切换。
4. 补充验证记录：把每条命令输出、手测观察（行为/失败）写入此 plan 末尾，保持“可观察结果”。

## 具体步骤

1. `cd /Users/billyq/Dev/Github/Lua/monopoly`；`lua .github/tests/regression.lua`（期待 136 全绿 + dep_rules ok + tick ok）。
2. 运行上述拆分的两条 `lua` 命令（75 条 gameplay、60 条 presentation），记录各自输出 `All regression checks passed`。
3. 执行 `pwsh .github/scripts/deploy.ps1 -TargetPath "/Users/billyq/Documents/eggy/LuaSource_monopoly"`，确认部署成功。
4. 在 Eggy 编辑器中分别打开两个客户端，执行手测清单中的 7 条场景（加载屏、调试开关、输入锁、choice、popup、黑市、回合稳定性）。
5. 每完成一次运行/手测，追加“验证与验收”部分的描述（命令/输入/输出/确认结果）。

## 验证与验收

1. 离线回归矩阵：75 条 + 60 条 + 136 条（含 dep_rules ok、tick ok）全部指标绿灯。
2. 运行时交互：加载屏/调试开关/输入锁/choice/弹窗/黑市/稳定性 7 个场景全部达标，且每条都有运行步骤和观察结果。
3. 在 plan 中记录特定输出（命令文本 + 结果），作为可观察证据。

## 可重复性与恢复

所有命令都是 `lua` 或 `pwsh` 直接可重放；如某阶段失败，修复后从那条命令起再跑一次，不需额外脚本。

## 产物与备注

1. `regression` 输出。  
2. 拆分 `presentation_ui` 回归输出。  
3. Eggy 手测记录（日期/命令/观察）。  
4. 如发现问题，在“意外与发现”补充并记录对应命令。

## 接口与依赖

测试依赖 `lua` 运行时、`pwsh`（部署），及现有 `TestHarness`/`presentation_ui_*` 模块；手测依赖 `Eggy` 编辑器运行环境与 `UIManager` 节点定义。

## 假设与默认值

1. 134+1 但 zeros? 以命令输出判断成功，不依赖硬编码计数。  
2. 至少两个编辑器客户端可以同时跑（角色隔离）。  
3. 计划不新增测试或代码，只跑现有命令/手测。  
4. 若需要额外脚本记录（如 log capture），再行补充。

## 产物与备注

略（见“产物与备注”）。

## 更新记录

- 2026-02-18：首次写入运行时测试计划，包含三层矩阵与手测清单，锁定 Presentation 交互/输入锁作为本轮重点。
