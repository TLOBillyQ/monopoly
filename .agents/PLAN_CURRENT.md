# 事件日志全量 Showtips 与提示文案清理

本可执行计划是活文档。实施过程中持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md`。

## 目的 / 全局视角

把所有事件日志都改为走 `show_tips`，并清理提示文本，移除坐标、索引、玩家 ID 等内部信息，优先使用 `Config/Generated` 的 `name/description` 数据。完成后玩家能看到更友好的提示文本，并能通过回归脚本与手工场景确认提示正确显示。

## 进度

- [x] (2026-02-11 14:12Z) 重写计划，明确改动范围与验收路径。
- [x] (2026-02-11 14:12Z) 修改 `src/ui/UIEventHandlers.lua`，移动事件统一走 `log.event`。
- [x] (2026-02-11 14:12Z) 修改 `src/game/movement/Movement.lua`，移动提示移除坐标。
- [x] (2026-02-11 14:12Z) 修改 `src/game/chance/ChanceRegistry.lua`，机会卡座驾提示使用名称。
- [x] (2026-02-11 14:12Z) 修改 `src/ui/ActionAnim.lua`，动画提示使用地块/玩家名称。
- [ ] (2026-02-11 14:12Z) 运行回归测试（失败：`.agents/tests/suites/ui.lua:810` 断言未通过）。

## 意外与发现

- 观察：回归脚本在 `item slot action should apply` 断言处失败，需确认是否与本次 UI 提示改动无关。
  证据：`lua .agents/tests/regression.lua` 报错 `.agents/tests/suites/ui.lua:810`。

## 决策日志

- 决策：移动事件不再使用 `event_no_tips`，统一走 `log.event`。
  理由：满足“所有 event log 走 show_tips”的需求。
  日期/作者：2026-02-11 / Codex

- 决策：动作动画提示解析地块与玩家名称，缺失时降级显示“未知地块/玩家 ID”。
  理由：去除内部索引信息，同时保证提示稳定可用。
  日期/作者：2026-02-11 / Codex

- 决策：机会卡送座驾提示使用 `Config/Generated/Vehicles.lua` 的 `name`。
  理由：玩家侧文案优先显示名称而不是 ID。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

当前已完成所有代码修改，但回归测试失败，尚未完成验证。需要确认失败是否与本次改动相关，并在验证通过后补充最终结果与证据。

## 背景与导读

事件日志由 `src/core/Logger.lua` 触发 `show_tips`，UI 事件在 `src/ui/UIEventHandlers.lua` 中注册并写入日志。移动事件文本在 `src/game/movement/Movement.lua` 生成。机会卡与动作动画的提示文本分别在 `src/game/chance/ChanceRegistry.lua` 与 `src/ui/ActionAnim.lua` 生成。`Config/Generated` 目录提供名称与描述数据（例如 `Vehicles.lua`）。

## 工作计划

先确保移动类事件统一写入 `log.event`，保证所有事件日志都能显示提示。再清理移动提示中的坐标信息。随后补齐机会卡座驾提示使用名称，并调整动作动画提示为地块/玩家名称。最后运行回归脚本并记录结果。

## 具体步骤

工作目录：`C:\Users\Lzx_8\Desktop\dev\monopoly`

1. 修改 `src/ui/UIEventHandlers.lua` 移动事件处理为统一 `log.event(data.text)`。
2. 修改 `src/game/movement/Movement.lua` 的 `_tile_label`，移除坐标拼接。
3. 修改 `src/game/chance/ChanceRegistry.lua`，新增座驾名映射并替换事件文案。
4. 修改 `src/ui/ActionAnim.lua`，新增名称解析并用于提示文本。
5. 运行回归：
    lua .agents/tests/regression.lua

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期全部通过；当前在 `.agents/tests/suites/ui.lua:810` 失败。需修复或确认无关后补充通过证据。

## 可重复性与恢复

改动可重复执行。若需回滚，可对修改文件执行 `git checkout -- <file>`，然后重新运行回归测试确认恢复。

## 产物与备注

本次修改文件：

    src/ui/UIEventHandlers.lua
    src/game/movement/Movement.lua
    src/game/chance/ChanceRegistry.lua
    src/ui/ActionAnim.lua

回归失败摘要：

    lua .agents/tests/regression.lua
    .agents/tests/suites/ui.lua:810: item slot action should apply

## 接口与依赖

- 内部接口调整：`src/ui/ActionAnim.lua` 的 `_build_tip` 签名变为 `_build_tip(state, anim)`，仅供模块内部调用。
- 依赖新增：`src/game/chance/ChanceRegistry.lua` 引入 `Config.Generated.Vehicles` 用于座驾名称映射。
- 对外协议不变。

本次修订：按新需求重写计划并记录已完成的代码改动与当前回归失败情况，便于后续确认与修复。
