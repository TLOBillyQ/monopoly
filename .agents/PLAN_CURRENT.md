# 移动事件不弹 tips


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角


目标是让移动相关事件不再弹出 tips，同时继续保留调试日志记录。完成后用户在游戏中移动时不会被提示打扰，其它事件提示保持可见。验收方式是触发移动事件时不出现 tips，触发非移动事件时仍出现 tips。

## 进度


- [x] (2026-02-07 16:56Z) 调整事件日志提示策略，移动事件不弹 tips
- [x] (2026-02-07 16:56Z) 运行 `lua .agents/tests/all.lua` 并记录结果
- [ ] (2026-02-07 16:55Z) 手动验证移动事件不弹 tips

## 意外与发现


暂无。

## 决策日志


决策：通过新增事件日志入口来跳过 tips，仅在移动事件注册处使用。理由：避免影响其它日志级别与事件来源。日期/作者：2026-02-07 / Codex。

## 结果与复盘


已新增移动事件不弹 tips 的日志入口，并在事件注册处应用。回归测试通过。手动验证仍待完成。

## 背景与导读


`src/core/Logger.lua` 负责 event 日志并在 event 时弹出 tips。`src/ui/UIEventHandlers.lua` 会注册事件日志回调，把移动、地块、市场、机会卡等事件转为 `logger.event` 调用。移动事件属于 `monopoly_event.movement.*`。

## 工作计划


先在 `Logger.lua` 增加“事件不弹 tips”的入口。再在 `UIEventHandlers.lua` 中把移动事件改为使用该入口，其它事件仍走原 `logger.event`。完成后运行测试并做手动验证。

## 具体步骤


在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行以下步骤。

1. 编辑 `src/core/Logger.lua`，新增不弹 tips 的事件记录入口。
2. 编辑 `src/ui/UIEventHandlers.lua`，移动事件使用新入口。
3. 运行测试命令并记录结果。

    lua .agents/tests/all.lua

## 验证与验收


运行 `lua .agents/tests/all.lua` 通过。进入一局游戏触发移动事件不出现 tips，触发非移动事件仍出现 tips，调试日志记录仍存在。

## 可重复性与恢复


上述改动可重复执行且风险低。如需回滚，恢复 `src/core/Logger.lua` 与 `src/ui/UIEventHandlers.lua` 到改动前版本并重新运行测试。

## 产物与备注


产物为 `src/core/Logger.lua` 与 `src/ui/UIEventHandlers.lua` 的局部修改，以及测试运行记录，测试输出包含 “All tests passed”。

## 接口与依赖


新增内部函数 `logger.event_no_tips` 用于仅记录事件日志。外部接口保持不变。

---

变更说明（2026-02-07）：清空旧计划，写入“移动事件不弹 tips”的可执行计划，明确目标、步骤与验收方式。
变更说明（2026-02-07）：更新进度，记录代码改动与测试结果，标记手动验证仍待执行。
