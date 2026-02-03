# 修复 UI 绑定降级与回合分发解耦

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角

用户在 UI 配置不完整时不应直接崩溃；回合分发逻辑不应依赖 UI 模块；相机跟随逻辑应避免无效判断。完成后，缺失 UI 节点只会降级提示并跳过绑定，选择流程仍能正确关闭弹窗并提交动作，相机跟随行为与当前一致但逻辑更清晰。验收方式是启动游戏并操作按钮、触发选择流程、观察无崩溃且功能正常。

## 进度

- [x] (2026-02-03 21:01) 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-03 21:01) 调整 `src/ui/UIEventRouter.lua` 的节点绑定为“缺失降级”
- [x] (2026-02-03 21:01) 移除 `src/game/turn/GameplayLoop.lua` 中相机跟随的无效判断
- [x] (2026-02-03 21:01) 通过回调注入改造 `src/game/turn/TurnDispatch.lua`，并补齐调用方回调
- [x] (2026-02-03 21:01) 运行 `lua .agents/tests/regression.lua` 并记录结果
- [ ] 手动验证首回合按钮与选择流程、相机跟随行为

## 意外与发现

- 观察：`GameplayLoop` 中的相机跟随判断从未更新状态，因此条件永远为真。
  证据：`src/game/turn/GameplayLoop.lua` 仅读取 `state.camera_follow_player_id`，未见写入点。

- 观察：`TurnDispatch` 直接依赖 `UIView`，违反依赖倒置。
  证据：`src/game/turn/TurnDispatch.lua` 在处理 choice 时调用 `ui_view.close_choice_modal`。

- 观察：`UIEventRouter` 对缺失节点使用断言，导致 UI 皮肤变更即崩溃。
  证据：`src/ui/UIEventRouter.lua` 的 `_register_node_click` 对空节点 `assert`。

## 决策日志

- 决策：删除相机跟随的无效判断，直接将目标角色设置为当前玩家并触发事件。
  理由：当前判断没有写回，逻辑无效；移除判断可简化且不改变实际行为。
  日期/作者：2026-02-03 / Codex。

- 决策：让 `TurnDispatch` 只通过 `opts.on_close_choice` 触发 UI 关闭，不再直接依赖 `UIView`。
  理由：满足 SOLID 的依赖倒置原则，保持回合逻辑可复用。
  日期/作者：2026-02-03 / Codex。

- 决策：UI 绑定缺失时仅提示并跳过绑定，避免硬崩溃。
  理由：符合“未适配提示”的意图，降低配置变动风险。
  日期/作者：2026-02-03 / Codex。

- 决策：自动回合与超时派发补齐 `opts.on_close_choice`。
  理由：确保自动选择与超时选择仍能关闭选择弹窗，保持行为一致。
  日期/作者：2026-02-03 / Codex。

## 结果与复盘

尚未实施。完成后补充实现结果、残留问题与经验总结。

## 背景与导读

`src/ui/UIEventRouter.lua` 负责将 UI 节点点击转为意图并派发。`src/game/turn/TurnDispatch.lua` 负责将意图转为游戏动作并处理回合推进。`src/game/turn/GameplayLoop.lua` 驱动 UI 刷新与相机跟随。`src/ui/UIView.lua` 提供 UI 弹窗与选择关闭能力。

## 工作计划

先改 `UIEventRouter`，让 `_register_node_click` 在节点不存在时记录提示并直接返回，不再 `assert`。然后移除 `GameplayLoop` 中相机跟随的无效条件判断，直接设置 `camera_helper.target_role_id` 并触发事件。接着把 `TurnDispatch` 中对 `UIView` 的直接调用替换为 `opts.on_close_choice` 回调，同时在 `UIEventRouter.bind` 与 `GameplayLoop` 自动/超时选择流程中提供该回调，以保持原有 UI 关闭行为不变。最后运行回归脚本并进行手动验证。

## 具体步骤

在仓库根目录开始，先清空 `.agents/PLAN_CURRENT.md` 并写入本计划。然后编辑 `src/ui/UIEventRouter.lua`，让 `_register_node_click` 在 `UIManager.query_nodes_by_name` 结果为空时调用 `_show_missing_button_tip(name)` 并返回，同时避免 `assert`。接着编辑 `src/game/turn/GameplayLoop.lua`，删除对 `state.camera_follow_player_id` 的判断与相关分支，直接设置 `camera_helper.target_role_id = current_id` 后触发事件。然后编辑 `src/game/turn/TurnDispatch.lua`，移除对 `src.ui.UIView` 的 `require`，将 choice 关闭改为调用 `opts.on_close_choice`，并保证 `opts` 缺失时安全降级为不调用。再在 `src/ui/UIEventRouter.lua` 的 `bind` 中为 `opts.on_close_choice` 注入 `ui_view.close_choice_modal`，并在 `GameplayLoop.step_choice_timeout` 与自动回合派发处补齐同样的回调。

最后运行回归脚本：

    工作目录：仓库根目录
    命令：lua .agents/tests/regression.lua

## 验证与验收

自动验证要求回归脚本通过，输出应包含 “All regression checks passed”。手动验证包含三步：进入游戏首回合点击“行动按钮”和“托管按钮”均应响应；触发一次选择流程后应能正常关闭选择弹窗；回合切换时相机跟随应与当前行为一致，且无异常报错或卡顿。如需验证缺失节点降级，可临时将任一按钮名改为不存在后启动，确认不会崩溃且有提示，再恢复。

## 可重复性与恢复

修改可重复执行。若需回退，恢复 `src/ui/UIEventRouter.lua`、`src/game/turn/GameplayLoop.lua`、`src/game/turn/TurnDispatch.lua` 到变更前版本即可。

## 产物与备注

预期变更片段示例：

    -- TurnDispatch.lua
    -- 删除 UI 依赖，并使用 opts.on_close_choice

## 接口与依赖

在 `src/game/turn/TurnDispatch.lua` 的 `dispatch_action(game, state, action, opts)` 中新增对 `opts.on_close_choice` 的调用约定，类型为函数 `(state) -> nil`，当 action 为 choice_select 或 choice_cancel 时调用。`UIEventRouter.bind` 需保证该回调存在，`GameplayLoop` 自动选择流程也需传入该回调以维持 UI 行为。

变更记录：2026-02-03 20:30 新建计划，覆盖“UI 绑定降级 + TurnDispatch 回调注入 + 相机跟随无效判断移除”，原因是落实代码审查结论并修复 SOLID 问题。

计划变更说明：补充自动回合派发的 `opts.on_close_choice` 回调，并更新进度与决策日志，确保自动选择也能关闭选择弹窗。

计划变更说明：更新进度并记录回归脚本已通过，方便后续手动验证时对照状态。
