# 下一轮：Clean Code 小步重构（UI 路由与配置清理）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本轮目标是在不改变行为的前提下，做小步、低风险的 Clean Code 清理，范围仅限 `src/` 与 `Config/`。完成后，UI 事件路由的函数参数符合团队规范，配置文件无噪音格式问题，可读性更好。可见结果：回归脚本通过，文件 diff 主要是结构与格式优化。

## 进度

- [x] (2025-03-04 14:30Z) 清理 Config 中的格式噪音。
- [x] (2025-03-04 14:30Z) UIEventRouter 参数规约与小幅整理。
- [x] (2025-03-04 14:30Z) 回归验证。

## 意外与发现

暂无。实施过程中记录发现与证据。

## 决策日志

- 决策：只做低风险重构，不改变行为。
  理由：需求为 clean code，优先稳定与可读性。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

完成小步 clean code 改造，配置噪音消除，UI 路由参数符合规范，回归通过。

## 背景与导读

`UIEventRouter` 里存在超过 3 个参数的函数（违反编码纪律），且有轻微排版噪音。`Config/RuntimeRefs.lua` 存在尾随空格。此次仅做局部整理。

相关文件：
- `src/presentation/interaction/UIEventRouter.lua`
- `Config/RuntimeRefs.lua`

## 工作计划

先清理 `Config/RuntimeRefs.lua` 的尾随空格。然后把 `UIEventRouter` 内 `_dispatch` 改为接收单一上下文表，避免超过 3 个参数，并顺带移除多余空行，保持行为不变。最后运行回归脚本确认无行为变化。

## 具体步骤

1) 清理配置格式。

在 `Config/RuntimeRefs.lua` 移除尾随空格，避免无意义 diff。

2) UIEventRouter 参数规约。

把 `_dispatch(state, game, intent, opts)` 改为 `_dispatch(ctx)`，由调用处传入 `{ state = ..., game = ..., intent = ..., opts = ... }`。保证所有调用点更新且行为不变。

3) 回归验证。

运行现有回归脚本，确认无行为变化。

## 验证与验收

在仓库根目录执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

预期：全部通过。

## 可重复性与恢复

每一步为小改动，可独立回滚。若回归失败，先回滚 UIEventRouter 参数调整。

## 产物与备注

预期修改：

    Config/RuntimeRefs.lua
    src/presentation/interaction/UIEventRouter.lua

## 接口与依赖

- `_dispatch` 改为单参数上下文对象，避免超过 3 个参数。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入 Clean Code 小步重构计划。
变更说明（2025-03-04 / Codex）：完成全部步骤并回归验证。
