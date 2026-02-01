# 删除 IntentDispatcher 并在调用点实现行为


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


移除 Library/Monopoly/IntentDispatcher.lua，将其“创建 choice、写入 game.store、触发 need_choice 事件、push_popup 调用”的行为下放到各调用点。用户视角行为保持不变：需要选择时仍会打开选择框并写入 pending_choice，弹窗仍会出现。验证方式是跑一次回归脚本，或在运行流程中触发 choice 和 popup，观察 UI 与日志无变化。


## 进度


- [x] (2026-01-31 15:20Z) 盘点 IntentDispatcher 的依赖点与行为范围
- [x] (2026-02-01 12:39Z) 在各调用点内联 need_choice/push_popup 行为并移除 require
- [x] (2026-02-01 12:39Z) 删除 IntentDispatcher 模块并自检
- [ ] (2026-02-01 12:39Z) 验证行为不变并记录证据（tests/regression.lua 当前失败）


## 意外与发现


- 观察：运行 `lua tests/regression.lua` 失败，报错指向 `Globals/ServiceKeys.lua` 的语法错误。
  证据：`Globals\ServiceKeys.lua:2: unexpected symbol near '<'`。


## 决策日志


- 决策：保留 MONOPOLY_EVENT.intent 事件名，在内联逻辑中继续触发 need_choice/push_popup 事件。
  理由：保持 UI 层与其它监听方的现有契约，避免 UI 行为回退。
  日期/作者：2026-01-31 Codex


## 结果与复盘


已完成：移除 IntentDispatcher 模块并将 need_choice/push_popup 行为下放到各调用点；init.lua 直接使用自定义事件监听；仓库内不再引用 IntentDispatcher。
待补充：回归脚本未通过，需先修复 `Globals/ServiceKeys.lua` 的语法错误后再完成验证与记录。


## 背景与导读


IntentDispatcher 当前负责两件事：一是处理 need_choice（递增 turn.choice_seq、写入 turn.pending_choice、广播 need_choice 事件），二是处理 push_popup（调用 ui_port.push_popup、广播 push_popup 事件）。调用点分布在 TurnMove、ItemPhase、EffectPipeline、ChoiceHandlers 等文件；UI 侧通过 RegisterCustomEvent 监听 need_choice。删除该模块需要把上述逻辑移到各调用点，并清理 require。

关键文件：
- Library/Monopoly/IntentDispatcher.lua
- Manager/TurnManager/Turn/TurnMove.lua
- Manager/ItemManager/Item/ItemPhase.lua
- Manager/EffectManager/Effect/EffectPipeline.lua
- Manager/ChoiceManager/Choice/ChoiceHandlers/*.lua
- Manager/ItemManager/Item/ItemInventory.lua
- init.lua、Manager/System/Runtime.lua


## 里程碑


里程碑一：替换调用点逻辑。完成后，所有 IntentDispatcher.dispatch/on 的调用被移除，改为本地内联 choice 与 popup 逻辑，并保持 need_choice 事件可触发。验证方式是：运行回归脚本或在流程中触发一次 need_choice，观察 pending_choice 与 UI 行为仍正常。

里程碑二：删除 IntentDispatcher 模块与引用。完成后，Library/Monopoly/IntentDispatcher.lua 被删除，rg 不再命中该名称；回归脚本通过。


## 工作计划


先改 UI 侧监听：在 init.lua 与 Manager/System/Runtime.lua 中用 RegisterCustomEvent 直接监听 MONOPOLY_EVENT.intent.need_choice，并保留 payload 归一化。然后逐个替换调用点：对每个 IntentDispatcher.dispatch，内联处理 payload.intent 或 payload.kind；对 need_choice 生成 entry 并写入 store；对 push_popup 直接调用 ui_port 并触发自定义事件。最后删除 IntentDispatcher 模块文件及所有 require，并运行回归脚本确认。


## 具体步骤


在仓库根目录执行下列步骤，并在每步完成后更新进度和日志。

1) 列出依赖点。

   运行：
     rg -n "IntentDispatcher" Manager Library init.lua

   预期：列出 dispatch/on 的调用点与 require。

2) 修改 init.lua 与 Manager/System/Runtime.lua 的监听逻辑。

   预期：使用 RegisterCustomEvent + MONOPOLY_EVENT.intent.need_choice，保留 payload 归一化。

3) 逐个替换 IntentDispatcher.dispatch。

   预期：各文件内联 need_choice/push_popup 行为并触发事件。

4) 删除 IntentDispatcher 模块并清理 require。

   预期：rg 不再命中 IntentDispatcher。


## 验证与验收


- 运行回归脚本：

    lua tests/regression.lua

  预期：输出 All regression checks passed。

- 如可运行游戏流程，触发一次需要选择与一次弹窗，观察 UI 行为与日志无变化。


## 可重复性与恢复


变更仅涉及 Lua 文件修改与文件删除，可重复执行。需要回退时，可使用版本管理工具恢复相关文件。


## 产物与备注


变更后应看到：

  rg -n "IntentDispatcher" Manager Library init.lua
  (无输出或仅剩文档引用)


## 接口与依赖


依赖 Globals/__init.lua 暴露的 RegisterCustomEvent/TriggerCustomEvent，以及 Globals/MonopolyEvents.lua 的 intent 事件名。需要保持 choice_spec 的字段语义不变，避免影响 ChoiceService 与 UI。


更新记录：首次创建该可执行计划，用于删除 IntentDispatcher 并下放行为，确保实施过程可追溯。
更新记录：完成调用点内联与模块删除，并记录回归脚本报错，原因是验证步骤被 `Globals/ServiceKeys.lua` 语法错误阻断。
