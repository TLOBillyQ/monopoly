# 基础屏倒计时常驻与回合计数日志精简

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md`。

## 目的 / 全局视角

改动完成后，基础屏的“倒计时”标签不再因输入锁或角色切换而隐藏，并且文案只显示时间。日志与提示中移除回合计数信息，玩家仍能看到其他状态提示。验收可通过 UI 观察倒计时常驻与回归日志检查来确认。

## 进度

- [x] (2026-02-11 14:15) 写入本计划并确认范围
- [x] (2026-02-11 14:18) 更新基础屏倒计时常驻与文案
- [x] (2026-02-11 14:18) 精简回合计数相关日志
- [x] (2026-02-11 14:18) 同步测试与文档
- [ ] (2026-02-11 14:25) 运行回归与检索验收（已完成：回归；剩余：运行时日志观察）

## 意外与发现

回归脚本曾失败于 “item slot action should apply”，原因是 item_slot 分支派发的 `choice_select` 缺少 `actor_role_id`，触发 `_validate_choice_actor` 拒绝。已补充该字段后回归通过。
证据：`lua .agents/tests/regression.lua` -> `All regression checks passed (98)`。

## 决策日志

- 决策：倒计时文案统一为 `倒计时:<秒数>`，不再包含回合数或空格。
  理由：与需求“只显示时间”的口径一致，减少显示歧义。
  日期/作者：2026-02-11 / Codex

- 决策：倒计时可见性由面板刷新时强制置为可见，并移出 `base_hidden_labels`。
  理由：确保输入锁与非当前角色场景下也保持常驻显示。
  日期/作者：2026-02-11 / Codex

- 决策：item_slot 触发的内部 `choice_select` 补齐 `actor_role_id`。
  理由：与 `choice_select` 的角色校验对齐，避免被错误拒绝。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

已完成倒计时常驻与日志精简、测试与文档同步，并修复 item_slot 选择被拒的问题。回归测试通过；运行时日志观察尚未补充。

## 背景与导读

倒计时标签由 `src/ui/UIPanel.lua` 构建文案，并在 `src/ui/UIPanelPresenter.lua` 中写入 UI。当前基础屏使用 `src/ui/UIView.lua` 的 `base_hidden_labels` 配置来控制非当前角色可见性，导致倒计时会被隐藏。回合计数日志散落在 `src/game/turn/TickUISync.lua`、`src/game/turn/TurnStart.lua` 与 `src/game/turn/TurnFlow.lua` 中，需要统一去除回合数相关输出。

## 工作计划

先修改 UI 侧：移除倒计时的隐藏配置，并确保倒计时始终可见，随后修改 `build_turn_label` 仅输出时间。再集中精简回合计数日志，去掉回合数字字段或整条回合计数日志。完成后更新 UI 测试与基础屏文档，最后运行回归测试与检索确认。

## 具体步骤

工作目录为 `C:\Users\Lzx_8\Desktop\dev\monopoly`。先修改 `src/ui/UIView.lua`、`src/ui/UIPanelPresenter.lua`、`src/ui/UIPanel.lua`，确保倒计时常驻且文案为 `倒计时:<秒数>`。随后修改 `src/game/turn/TickUISync.lua`、`src/game/turn/TurnStart.lua`、`src/game/turn/TurnFlow.lua` 清理回合计数日志。接着更新 `.agents/tests/suites/ui.lua` 与 `.agents/docs/ui/01_UI_基础屏.md`。最后运行回归脚本并记录输出要点。

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期全通过。进入游戏观察基础屏倒计时在非当前玩家与 `input_blocked=true` 时仍显示，文案为 `倒计时:<秒数>`。检索日志输出确保不再出现“回合: X / 回合X:”计数信息，但保留诸如“停留X回合”状态提示。

## 可重复性与恢复

修改步骤可重复执行；若需要回滚，可针对具体文件执行 `git checkout -- <file>` 并重新跑回归。

## 产物与备注

本次改动涉及以下文件：`src/ui/UIView.lua`、`src/ui/UIPanelPresenter.lua`、`src/ui/UIPanel.lua`、`src/game/turn/TickUISync.lua`、`src/game/turn/TurnStart.lua`、`src/game/turn/TurnFlow.lua`、`.agents/tests/suites/ui.lua`、`.agents/docs/ui/01_UI_基础屏.md`。

## 接口与依赖

不新增公共接口。倒计时文案由 `src/ui/UIPanel.lua` 的 `build_turn_label` 统一生成；可见性由 `src/ui/UIPanelPresenter.lua` 在刷新面板时强制保持可见。

修改说明：更新进度与结果记录，补充 item_slot `actor_role_id` 修复结论与回归通过证据。
