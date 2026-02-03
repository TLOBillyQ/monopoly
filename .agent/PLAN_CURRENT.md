# 拆分 GameplayLoop：分发与动画模块化


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角


本次改动把 `src/game/turn/GameplayLoop.lua` 的动作分发与动画等待流程抽成独立模块，减少文件长度与重复逻辑，同时保持行为一致。验证方式是运行回归脚本，并在游戏内手动检查动画等待与选择交互是否与原来一致。

## 进度


- [x] (2026-02-03 18:06) 清空并重写 `PLAN_CURRENT.md`，记录 GameplayLoop 拆分任务目标与验收标准
- [x] (2026-02-03 18:16) 新增 `src/game/turn/TurnDispatch.lua` 与 `src/game/turn/TurnAnim.lua` 并迁移动作分发与动画通用流程
- [x] (2026-02-03 18:20) 调整 `src/game/turn/GameplayLoop.lua` 与 `src/ui/UIEventRouter.lua`，更新依赖关系与调用点
- [x] (2026-02-03 18:21) 调整 `src/app/init.lua`，为重启动作提供回调并保持游戏切换行为不变
- [x] (2026-02-03 18:22) 运行回归脚本通过
- [ ] (2026-02-03 18:22) 手动验收动画等待期与选择交互

## 意外与发现


暂无。

## 决策日志


- 决策：将动作分发逻辑集中到 `src/game/turn/TurnDispatch.lua`，并由 `GameplayLoop` 与 `UIEventRouter` 直接调用。
  理由：减少 `GameplayLoop` 体积并消除 UI 路由对 GameplayLoop 的耦合。
  日期/作者：2026-02-03 / Codex。

- 决策：把动画等待的通用流程抽成 `TurnAnim.step_anim`，由 `step_move_anim` 与 `step_action_anim` 调用。
  理由：合并重复流程，保留各自动画细节逻辑。
  日期/作者：2026-02-03 / Codex。

- 决策：重启动作通过 `opts.on_restart` 回调处理，并在 `GameplayLoop.restart_game` 中实现。
  理由：避免模块间循环引用，并保持重启逻辑单一实现。
  日期/作者：2026-02-03 / Codex。

## 结果与复盘


回归脚本已通过，行为未见异常。手动验收尚未完成，需要在游戏内确认动画等待期与选择弹窗行为。

## 背景与导读


GameplayLoop 是回合驱动入口，原本包含动作分发与动画等待逻辑，文件过长。UI 事件入口在 `src/ui/UIEventRouter.lua`，回合初始化在 `src/app/init.lua`。本次新增 `src/game/turn/TurnDispatch.lua` 负责动作分发与重启回调，新增 `src/game/turn/TurnAnim.lua` 负责动画等待的通用流程。

## 工作计划


先建立两个新模块并迁移逻辑，再在 `GameplayLoop` 中改为薄封装与调用，最后更新 UI 路由与初始化的依赖关系并补齐重启回调。完成后运行回归脚本，并进行一次手动交互确认。

## 具体步骤


在仓库根目录依次修改以下文件：`src/game/turn/TurnDispatch.lua`、`src/game/turn/TurnAnim.lua`、`src/game/turn/GameplayLoop.lua`、`src/ui/UIEventRouter.lua`、`src/app/init.lua`。

运行回归脚本：

    lua .agent/tests/regression.lua

预期输出包含：

    All regression checks passed (34)

## 验证与验收


回归脚本需通过且输出包含 `All regression checks passed`。手动验收时需要确认：动画等待期点击按钮不触发任何行为、动画结束后恢复可点击；回合“下一步”按钮冷却逻辑与重启逻辑不变；选择弹窗与市场选择逻辑不变。

## 可重复性与恢复


本修改可重复执行。若需回退，恢复上述 Lua 文件到修改前版本即可。

## 产物与备注


产物为 GameplayLoop 拆分后的新模块与调用点调整，无新增外部依赖。

## 接口与依赖


新增模块与接口：

`src/game/turn/TurnDispatch.lua`：

    turn_dispatch.dispatch_action(game, state, action, opts)
    turn_dispatch.clear_choice(state, opts)
    turn_dispatch.step_turn(game)

`src/game/turn/TurnAnim.lua`：

    turn_anim.step_anim(game, state, opts)

`src/game/turn/GameplayLoop.lua` 新增：

    gameplay_loop.restart_game(state, opts)

变更记录：2026-02-03 18:06 重写 `PLAN_CURRENT.md`，原因是进入 GameplayLoop 拆分任务并记录实施与验收标准。
