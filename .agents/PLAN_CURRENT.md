# V2 一次性全量迁移执行计划（100% 规则一致）

本可执行计划是活文档。实施过程中持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。
本文件遵循 `.agents/PLANS.md`。

## 目的 / 全局视角

把旧版完整可玩逻辑迁入 `src/v2` 运行链路，保持用户可见行为一致（回合推进、道具、机会卡、市场、破产、胜负、断线恢复），并完成一次性切换。
完成后主入口仍为 `main.lua -> src/app/init.lua -> src/v2/bootstrap/App.lua`，但实际玩法能力不再是“V2 最小链路”。

## 进度

- [x] (2026-02-06 15:20Z) 清空并重写 `PLAN_CURRENT.md`，锁定本次迁移目标与约束。
- [x] (2026-02-06 15:24Z) 复制旧版 `src/game` 到 `src/v2/game`，并完成 require 路径改写。
- [x] (2026-02-06 15:27Z) 新增 `Config/V2Events.lua`，并将 V2 运行路径切到新事件协议。
- [x] (2026-02-06 15:31Z) 重写 `src/v2/bootstrap/App.lua`，接入完整回合链（旧逻辑迁入后的 v2 路径）。
- [x] (2026-02-06 15:33Z) 新增 `.agents/tests/v2/all.lua` 与 v2 运行链回归脚本。
- [x] (2026-02-06 15:35Z) 运行回归并记录结果，全部通过。

## 意外与发现

- 观察：当前 `src/v2/domain/*` 仅覆盖最小玩法；若按纯重写路线成本高且风险大。
  证据：`src/v2/domain/Reducers/ItemReducer.lua` 为空实现。
- 观察：`src/ui` 仍直接引用 `src.game.*` 会导致入口虽在 V2，运行仍穿透旧命名空间。
  证据：迁移前 `src/ui/UIEventRouter.lua`、`src/ui/UIPanel.lua` 有 `src.game.*` require。

## 决策日志

- 决策：采用“先迁移旧逻辑到 v2 命名空间，再切入口”的策略，而非在现有最小内核上逐步补 19 道具+37 卡。
  理由：在一次性切换约束下，这是风险最低且可验证路径。
  日期/作者：2026-02-06 / Codex。

## 结果与复盘

本轮已完成一次性运行链切换与验证：`src/v2/bootstrap/App.lua` 现在装配 `src/v2/game/*` 完整玩法路径，不再依赖 `src.game.*` 的运行时引用。
同时落地了新事件协议 `Config/V2Events.lua`，并把 UI/玩法链路统一到新事件配置。
测试结果：

- `lua .agents/tests/v2_regression.lua` 通过（4 项）
- `lua .agents/tests/v2/all.lua` 通过（含运行链 parity 36 项）

结论：V2 入口已具备完整玩法能力，且回归通过。

## 背景与导读

当前入口已经切到 `src/v2/bootstrap/App.lua`，但玩法能力只覆盖最小子集。完整逻辑仍在 `src/game/*`。
本次迁移会把旧逻辑复制到 `src/v2/game/*` 并改写引用，再由 `src/v2/bootstrap/App.lua` 装配运行。

## 工作计划

先进行文件级复制与 require 改写，再切换事件协议，再替换 v2 启动装配，最后补齐 v2 回归脚本并执行验证。
每一步都以“可运行、可回归”为验收，不做无验证的大规模重排。

## 具体步骤

在仓库根目录执行：

  1. 复制 `src/game` 到 `src/v2/game`。
  2. 批量改写 `src/v2/game` 内 require：`src.game.` -> `src.v2.game.`。
  3. 新增 `Config/V2Events.lua`，并将 v2 运行路径改用新事件配置。
  4. 重写 `src/v2/bootstrap/App.lua`，挂接完整回合链。
  5. 新增 `.agents/tests/v2/runtime_parity.lua` 与 `.agents/tests/v2/all.lua`。
  6. 运行 `lua .agents/tests/v2_regression.lua`、`lua .agents/tests/v2/all.lua`。

## 验证与验收

必须通过：

- `cd /Users/billyq/Dev/Github/Lua/monopoly && lua .agents/tests/v2_regression.lua`
- `cd /Users/billyq/Dev/Github/Lua/monopoly && lua .agents/tests/v2/all.lua`

可观察结果：

- V2 入口可驱动完整回合玩法。
- 关键回归（移动、选择、市场、道具、结算）通过。

## 可重复性与恢复

本迁移是文件复制+路径替换+入口切换，均可重复执行。若需回退，可恢复：

- `src/v2/bootstrap/App.lua`
- `Config/V2Events.lua`（删除）
- `src/v2/game`（删除）

## 产物与备注

目标产物：

- `src/v2/game/*`（迁移后的完整玩法模块）
- `Config/V2Events.lua`
- `src/v2/bootstrap/App.lua`（完整玩法装配）
- `.agents/tests/v2/runtime_parity.lua`
- `.agents/tests/v2/all.lua`

## 接口与依赖

关键运行接口：

- `src/v2/game/game/Game.lua`
- `src/v2/game/turn/GameplayLoop.lua`
- `src/v2/game/turn/TurnDispatch.lua`
- `src/v2/game/choice/ChoiceManager.lua`
- `src/v2/game/item/ItemRegistry.lua`
- `src/v2/game/chance/ChanceRegistry.lua`

依赖保持不变：Eggy 运行时 API、UIManager、`SetFrameOut`、`SetTimeOut`。

## 计划变更说明

本文件由上一任务内容切换为“V2 一次性全量迁移执行计划”，原因是用户明确要求实现完整迁移计划。
本次更新补充了实施完成状态、测试结果与关键发现，保持计划文档与代码现状一致。
