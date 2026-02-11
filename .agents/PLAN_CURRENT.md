# 非当前回合屏幕显示策略调整

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `\.agents\PLANS.md` 的要求，并在实现前先清空并写入 `\.agents\PLAN_CURRENT.md`。

## 摘要

目标是在非当前回合时隐藏除“机会卡/道具卡展示屏、破产屏”以外的所有额外屏幕，同时保留基础HUD（玩家信息、倒计时等）。实现后可观察到：非当前玩家只会看到基础HUD与机会/道具卡展示屏、破产屏，其它选择屏、黑市屏与一般弹窗不再显示。

## 假设与默认

默认“自己的回合”以 `UIRoleContext.resolve(...).can_operate` 为准。若没有角色列表，按单人/本地模式处理，仍显示当前屏幕。

## 进度

- [x] (2026-02-11 19:20Z) 写入 `\.agents\PLAN_CURRENT.md` 并开始实现
- [x] (2026-02-11 19:20Z) 完成代码修改与回归验证

## 意外与发现

- 观察：回归脚本通过。
  证据：`All regression checks passed (119)`。

## 决策日志

- 决策：非当前回合仍显示“机会卡/道具卡展示屏、破产屏”，其余屏幕隐藏，基础HUD常驻
  理由：用户明确要求“破产屏显示，玩家信息常驻，其他不显示”
  日期/作者：2026-02-11 / Codex
- 决策：机会卡/道具卡通过新增 `popup.kind` 标识进行放行
  理由：标题文本易变且容易误判，显式字段更稳定
  日期/作者：2026-02-11 / Codex

## 结果与复盘

已完成按角色控制的屏幕显隐策略，非当前回合仅展示机会卡/道具卡/破产屏，其余弹窗与选择屏对非当前回合隐藏，基础HUD常驻。新增回归用例覆盖弹窗可见性。回归脚本通过，待编辑器内多人实测验证显示效果。

## 背景与导读

当前 UI 屏幕通过 `src/ui/UICanvasCoordinator.lua` 调用 `UIEvents.send_to_all` 对所有角色同步显示/隐藏，导致非当前回合同样看到选择屏、黑市屏与普通弹窗。弹窗展示由 `src/ui/UIModalPresenter.lua` 触发，机会卡/道具卡展示来源于 `src/game/land/Landing.lua` 的 `push_popup` 逻辑，破产屏通过 `payload.kind = "bankruptcy"` 区分。

关键文件与职责：
- `src/ui/UIModalPresenter.lua`：负责选择屏、黑市屏、弹窗的打开/关闭与可见性。
- `src/ui/UICanvasCoordinator.lua`：切换当前可见 Canvas（屏幕）。
- `src/ui/UIEvents.lua`：向角色发送 UI 显示/隐藏事件。
- `src/game/land/Landing.lua`：机会卡/道具卡弹窗入口。
- `src/ui/UIRoleContext.lua`：判断当前角色是否可操作（是否“自己的回合”）。

## 接口与对外行为变更

新增或扩展对外接口/类型：
- `push_popup` 新增 `payload.kind` 可选值：`"chance_card"`、`"item_card"`。
- `src/ui/UIEvents.lua` 新增 `send_to_role(role, event_name, payload)`。
- `src/ui/UICanvasCoordinator.lua` 新增 `switch_for_role(ui, target, role)`，用于按角色切换屏幕。

对外行为变更：
- 非当前回合仅显示基础HUD与机会/道具卡展示屏、破产屏，其它屏幕隐藏。
- 当前回合显示行为保持不变。

## 工作计划

先为机会卡/道具卡弹窗补充明确的 `payload.kind`，确保可稳定识别。然后新增“按角色切换 Canvas”的能力，并在 `UIModalPresenter` 中基于角色上下文决定是否展示选择屏、黑市屏、普通弹窗。最后补充 UI 测试覆盖：验证非当前回合只展示允许屏幕，并确认当前回合不受影响。

## 具体步骤

在仓库根目录 `c:\Users\Lzx_8\Desktop\dev\monopoly` 执行。

1. 清空并写入 `\.agents\PLAN_CURRENT.md` 为本计划内容。
2. 修改 `src/game/land/Landing.lua`：在机会卡与道具卡弹窗 `payload` 中加入 `kind = "chance_card"` 与 `kind = "item_card"`。
3. 修改 `src/ui/UIEvents.lua`：新增 `send_to_role`，封装 `role.send_ui_custom_event`。
4. 修改 `src/ui/UICanvasCoordinator.lua`：新增 `switch_for_role`，按角色发送显示/隐藏事件，逻辑与 `switch` 保持一致但仅作用于指定角色。
5. 修改 `src/ui/UIModalPresenter.lua`：
   - 引入 `UIRoleContext`，判断角色是否可操作。
   - 为选择屏/黑市屏/弹窗建立“按角色可见性”判断：
     - 当前回合角色：全部显示。
     - 非当前回合角色：仅允许 `kind = "chance_card" / "item_card" / "bankruptcy"`。
   - 在 `open_choice_modal`、`close_choice_modal`、`push_popup`、`close_popup` 中改用 `switch_for_role`，对非当前回合角色强制回到基础屏，并仅对允许弹窗展示对应屏幕。
   - 对非当前回合角色执行“只隐藏屏幕可见性”的逻辑，避免改动全局 `ui.choice_active / ui.market_active / ui.popup_active` 状态。
6. 补充测试 `\.agents\tests\suites\ui.lua`：
   - 新增用例：非当前回合时，普通弹窗不触发非当前角色的 Canvas 显示事件。
   - 新增用例：非当前回合时，`kind = "chance_card"` 与 `kind = "item_card"` 的弹窗会触发显示事件。
   - 新增用例：`kind = "bankruptcy"` 弹窗对非当前回合角色可见。

## 测试场景与验收

1. 运行回归测试：
   命令：`lua .agents/tests/regression.lua`
   预期：全部通过，新增 UI 用例通过。
2. 手动场景：
   触发机会卡/道具卡与破产流程，观察非当前回合玩家能看到对应屏幕；触发黑市/选择屏/偷窃弹窗时，非当前回合玩家不再看到这些屏幕。

## 可重复性与恢复

改动可重复应用。若需回滚，删除新增的 `payload.kind` 标识与按角色切换逻辑，恢复 `UICanvasCoordinator.switch` 的全员广播路径。

## 产物与备注

预期新增片段示例：
    Landing 弹窗：
      payload = { title = "道具卡", body = "...", kind = "item_card", ... }

    UIEvents 新增：
      function ui_events.send_to_role(role, event_name, payload) ... end

## 接口与依赖

需使用：
- `src/ui/UIRoleContext.lua`：判定是否当前回合。
- `src/ui/UIEvents.lua`：新增按角色发送事件。
- `src/ui/UICanvasCoordinator.lua`：新增按角色切换屏幕。

里程碑结束时必须存在的新接口：
- `UIEvents.send_to_role(role, event_name, payload)`
- `UICanvasCoordinator.switch_for_role(ui, target, role)`
- `push_popup payload.kind` 新值：`chance_card` / `item_card`
