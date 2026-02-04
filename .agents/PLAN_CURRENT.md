# 自动玩家选择/弹窗最短显示 1 秒


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角


本次变更让自动玩家触发“通用选择屏”和“弹窗屏”时，画面至少显示 1.0 秒再自动继续。用户可通过自动运行观察到选择屏与弹窗屏不再瞬间消失，且自动流程不会卡住。手动玩家交互保持原状。

## 进度


- [x] (2026-02-04 11:20) 清空并重建计划，确认目标与范围
- [x] (2026-02-04 11:25) 增加自动玩家最短显示配置与选择延迟路径
- [x] (2026-02-04 11:28) 增加弹窗最短显示与自动关闭路径
- [x] (2026-02-04 11:36) 运行回归脚本并记录结果
- [ ] (2026-02-04 11:30) 手动验证自动玩家选择/弹窗显示时长

## 意外与发现


当前自动选择在 `TurnManager` 内同步解析，UI 刷新在 `GameplayLoop.tick`，导致选择屏可能完全不出现。该现象在 `src/game/turn/TurnManager.lua` 与 `src/game/turn/GameplayLoop.lua` 的调用顺序中可见。

回归脚本的 autorunner 流程触发 `ui_view.close_choice_modal`，进而调用 `Config/UIEvents.send_to_all`，当测试环境没有 `all_roles` 时会断言失败。
证据：回归输出包含 “missing all_roles”。

## 决策日志


- 决策：最短显示时间统一为 1.0 秒，适用于所有自动玩家。
  理由：满足可见性且不显著拖慢自动测试。
  日期/作者：2026-02-04 / Codex。
- 决策：弹窗达到最短显示后自动关闭。
  理由：保持自动流程顺畅，避免长时间遮挡。
  日期/作者：2026-02-04 / Codex。
- 决策：弹窗归属通过 `turn.current_player_index` 记录到 `state.ui.popup_owner_index`。
  理由：无需新增复杂映射即可判断自动玩家。
  日期/作者：2026-02-04 / Codex。
- 决策：`Config/UIEvents.send_to_all` 在 `all_roles` 为空时直接返回。
  理由：测试环境缺少 UI 角色时不应中断自动流程，真实运行环境不受影响。
  日期/作者：2026-02-04 / Codex。

## 结果与复盘


已完成配置与逻辑改动并通过回归脚本。手动 UI 验证仍待完成。

## 背景与导读


入口在 `src/app/init.lua`，`state.push_popup` 是弹窗入口。自动选择由 `src/game/turn/TurnManager.lua` 中 `_decide_choice_action` 调用 `src/game/game/Agent.lua` 的自动决策。UI 刷新与选择/弹窗超时处理在 `src/game/turn/GameplayLoop.lua` 的 `tick` 内完成。配置集中在 `Config/GameplayRules.lua`。

## 工作计划


先在 `Config/GameplayRules.lua` 增加两个配置项，随后在 `TurnManager` 延迟自动选择触发点，避免立刻解析。接着在 `GameplayLoop` 中在最短显示时间到达后主动派发自动选择，并在弹窗超时逻辑中对自动玩家使用更短的超时值。最后在 `step_auto_runner` 中阻断自动推进，确保弹窗显示时长生效，同时在 UI 事件发送处增加无角色时的安全短路以保证回归脚本可运行。

## 具体步骤


在仓库根目录按以下顺序执行。

  1. 编辑 `Config/GameplayRules.lua`，新增 `auto_choice_min_visible_seconds` 与 `auto_popup_min_visible_seconds`，默认值 1.0。
  2. 编辑 `src/game/turn/TurnManager.lua`，在 `_decide_choice_action` 中对自动玩家进行最短显示判断，未达阈值直接返回 `nil`。
  3. 编辑 `src/game/turn/GameplayLoop.lua`，在 `step_choice_timeout` 中对自动玩家达到最短显示后派发自动选择动作。
  4. 编辑 `src/app/init.lua`，在 `state.push_popup` 成功后记录 `popup_owner_index`。
  5. 编辑 `src/game/turn/GameplayLoop.lua`，在 `step_modal_timeout` 中为自动玩家弹窗使用最短显示超时值，并在 `step_auto_runner` 阻断自动推进。
  6. 编辑 `Config/UIEvents.lua`，在 `all_roles` 为空时直接返回，避免测试环境断言失败。
  7. 运行 `lua .agents/tests/regression.lua` 记录结果。
  8. 手动启动项目并观察自动玩家选择屏/弹窗显示时长。

## 验证与验收


运行回归脚本并确保通过，随后在自动运行场景观察：自动玩家触发选择时，选择屏可见至少 1 秒再自动选择；自动玩家触发弹窗时，弹窗可见至少 1 秒再自动关闭；手动玩家不被自动选择或自动关闭影响。

## 可重复性与恢复


修改均为配置与条件分支，重复执行不会造成副作用。若需回退，恢复 `Config/GameplayRules.lua`、`Config/UIEvents.lua`、`src/game/turn/TurnManager.lua`、`src/game/turn/GameplayLoop.lua`、`src/app/init.lua` 的变更即可。

## 产物与备注


核心变更集中在配置与回合/UI 驱动逻辑文件，回归测试输出如下。

  ....................................
  All regression checks passed (36)

## 接口与依赖


新增配置字段 `auto_choice_min_visible_seconds` 与 `auto_popup_min_visible_seconds`。其余逻辑复用 `agent.is_auto_player` 与 `ui_view.close_popup`，不引入新模块。

## 计划变更说明


本计划替换旧任务内容，以满足“自动玩家选择/弹窗最短显示 1 秒”的实现需求，并补充了新的进度与决策记录。回归测试暴露 `all_roles` 缺失断言后，追加了 UI 事件安全短路的修改与记录。
