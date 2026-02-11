# 全回合角色控制硬锁（BUFF_FORBID_CONTROL）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agents/PLANS.md`，实施与停顿时都要保持本文档自洽、可接续、可复现。

## 目的 / 全局视角

当前对局中，客户端仍可通过摇杆或技能进行手动操作，可能干扰回合驱动与动画等待。目标是在现有 UI 锁与动作校验之上增加“角色控制硬锁”，对局期间强制所有角色进入不可控状态。改完后，玩家在对局未结束时无法手动移动/跳跃/前扑/技能，但 UI 流程（行动按钮、选择框）仍可正常推进。验收以“编辑器内手动操作无响应 + 回合流程不被阻断”为准。

## 进度

- [x] (2026-02-11 16:30Z) 清空并重写 `.agents/PLAN_CURRENT.md`，建立本任务活文档
- [x] (2026-02-11 16:40Z) 新增角色控制锁策略模块 `src/ui/UIRoleControlLockPolicy.lua`
- [x] (2026-02-11 16:50Z) 接入 UI 与端口：`src/ui/UIView.lua`、`src/game/turn/GameplayLoopPorts.lua`
- [x] (2026-02-11 16:55Z) 在 `GameplayLoop` 注入全回合锁定状态机
- [x] (2026-02-11 17:05Z) 扩展回归测试：`.agents/tests/suites/ui.lua`
- [x] (2026-02-11 17:15Z) 运行 `lua .agents/tests/regression.lua`，输出 `All regression checks passed (114)`
- [x] (2026-02-11 17:40Z) 调整移动动画步进期解锁，并重新回归，输出 `All regression checks passed (115)`

## 意外与发现

- 观察：全量回归通过（含步进期解锁补丁）。
  证据：`All regression checks passed (115)`。

## 决策日志

- 决策：仅使用 `BUFF_FORBID_CONTROL`，不启用 `Role.set_role_ctrl_enabled` 兜底。
  理由：需求已锁定“仅 BuffState”，避免引入跨版本行为差异。
  日期/作者：2026-02-11 / Codex

- 决策：锁定范围为“全回合、全玩家”，并在每 tick 重新同步。
  理由：最小改动下保证防干扰强度，并应对角色单位热切换。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

本次新增了角色控制锁策略模块，并在 GameplayLoop 内全回合同步；根据编辑器反馈补充“移动动画步进期解锁”。回归已通过，仍需在编辑器内完成手动验收（步进期可控、其他时间不可控，且 UI 流程正常）。若出现 UI 被连带阻断，可通过 `role_control_lock_enabled=false` 快速回滚。

## 背景与导读

核心入口在 `src/game/turn/GameplayLoop.lua` 的 tick 驱动与 `GameplayLoopPorts` 端口，UI 入口在 `src/ui/UIView.lua`。本次新增 `src/ui/UIRoleControlLockPolicy.lua`，通过 `Role.get_ctrl_unit()` 对 LifeEntity 的 BuffStateComp 执行 `BUFF_FORBID_CONTROL`。该策略不触碰 UI 节点显隐，只影响角色控制。

## 工作计划

先新增策略模块，封装对 `BUFF_FORBID_CONTROL` 的加解锁与“owned”标记，避免误删外部已有状态。然后扩展 `UIView` 与 `GameplayLoopPorts` 提供 `apply_role_control_lock`。最后在 `GameplayLoop` 中注入全回合同步逻辑，并补齐回归用例验证“加锁/解锁/单位切换/回合结束清理”等行为。

## 具体步骤

在仓库根目录按顺序执行：

1. 新增 `src/ui/UIRoleControlLockPolicy.lua`。
2. 修改 `src/ui/UIView.lua` 与 `src/game/turn/GameplayLoopPorts.lua`。
3. 修改 `src/game/turn/GameplayLoop.lua` 与 `src/app/init.lua`。
4. 修改 `.agents/tests/suites/ui.lua`，新增 3 个用例并挂入 suite。
5. 运行：

    lua .agents/tests/regression.lua

预期输出末尾包含：

    All regression checks passed (...)

## 验证与验收

自动回归必须通过 `lua .agents/tests/regression.lua`。编辑器内验收包括：开局后任意玩家尝试摇杆移动/跳跃/前扑/技能无响应；点击“行动按钮/选择框确认”仍能推进回合；对局结束或重开后锁不残留。

## 可重复性与恢复

本次改动不涉及数据迁移，回滚路径为：先移除 `GameplayLoop` 中的锁同步，再移除端口与 UI 接口，最后删除 `UIRoleControlLockPolicy` 并撤测试。每一步都可独立回滚并重新跑回归。

## 产物与备注

实际产物：

- `Config/GameplayRules.lua`
- `src/ui/UIRoleControlLockPolicy.lua`
- `src/ui/UIView.lua`
- `src/game/turn/GameplayLoopPorts.lua`
- `src/game/turn/GameplayLoop.lua`
- `src/app/init.lua`
- `.agents/tests/suites/ui.lua`

## 接口与依赖

新增接口：

- `ui_view.apply_role_control_lock(state, enabled)`
- `gameplay_loop_ports.apply_role_control_lock(state, enabled)`

新增配置：

- `Config.GameplayRules.role_control_lock_enabled`（默认 `true`）

依赖说明：

- `role.get_ctrl_unit()` 必须返回 LifeEntity（具备 BuffStateComp）。

(2026-02-11) 更新说明：完成代码实现与测试补齐，并通过全量回归。
(2026-02-11) 更新说明：按编辑器反馈补充“步进期解锁”，回归再次通过。
