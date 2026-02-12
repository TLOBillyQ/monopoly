# 解耦核心游戏逻辑与 UI 依赖

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前核心游戏逻辑直接依赖 UI 与渲染模块，导致修改 UI 也会牵连规则层，且无法进行纯逻辑测试。本次重构把核心规则对 UI 的依赖迁移到清晰的端口层（抽象接口），让规则层只依赖端口，不直接 require `src/presentation`。完成后，开发者可以在没有 UI 的环境下跑核心流程，并通过端口实现把 UI 接回去。可见生效方式：运行不加载 `src/presentation` 的测试时，核心流程仍可推进；同时 UI 行为依旧正常显示。

## 进度

- [x] (2025-03-04 08:45Z) 明确端口职责与命名，完成端口接口草案并落地到默认端口。
- [x] (2025-03-04 08:52Z) 在运行期注入端口实现，核心流程改为使用端口安装事件处理。
- [x] (2025-03-04 09:05Z) UI 同步与渲染调用迁移到端口默认实现，核心模块移除直接 UI 依赖。
- [x] (2025-03-04 09:20Z) 破产渲染清理迁移为端口回调。
- [x] (2025-03-04 09:26Z) 新增无 UI 回归脚本并可运行。

## 意外与发现

- 观察：`tick_ui_sync` 内的渲染与调试面板逻辑已迁移到端口默认实现。
  证据：`rg -n "src\.presentation" src/game` 只剩 `GameplayLoopPorts.lua`。

## 决策日志

- 决策：以现有 `GameplayLoopPorts` 为端口入口，扩展其职责覆盖 UI 同步与输入处理。
  理由：已有端口雏形，改动面最小且能逐步迁移。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

已完成核心层对 `src.presentation` 的直接依赖清理，端口默认实现承接 UI 行为，并新增无 UI 回归脚本。后续如需继续拆分，可考虑把 `move_anim` 也下沉到 presentation 专属端口模块。

## 背景与导读

当前核心循环位于 `src/game/turn/GameplayLoop.lua`，但它直接 require `src/presentation` 的模块，违反依赖倒置。`src/game/turn/TickUISync.lua` 负责 UI 渲染同步，也在核心层被直接调用。`src/game/game/Bankruptcy.lua` 直接操作 `src/presentation/render/TileRenderer`，导致破产逻辑无法在无 UI 环境运行。已有端口层 `src/game/turn/GameplayLoopPorts.lua` 可以作为抽象接口入口，但目前仍由核心直接 require UI。

术语解释：
- 端口（Port）：一组由核心逻辑调用的抽象函数集合，用于隔离 UI/渲染等细节。端口在本仓库以 Lua table 表示，包含函数字段。
- 组合根（CompositionRoot）：集中组装依赖的地方，在本仓库是 `src/game/game/CompositionRoot.lua`。

## 工作计划

先定义清晰的端口职责，再逐步替换核心对 UI 的直接依赖。第一步在 `src/game/turn/GameplayLoopPorts.lua` 中补齐需要的端口函数，并提供默认实现放在 `src/presentation` 侧。第二步修改 `GameplayLoop.lua`、`TickUISync.lua`、`TickTimeout.lua` 与 `Bankruptcy.lua`，让它们只调用端口接口，不直接 require UI 或渲染模块。第三步在 `CompositionRoot` 或 `gameplay_loop.set_game` 中注入端口实现，确保运行期能使用 UI 版本或测试替身。最后补充一个无 UI 的回归脚本与最小测试场景，用于证明核心流程能跑通。

## 具体步骤

1) 定义端口接口与默认实现。

在 `src/game/turn/GameplayLoopPorts.lua` 中新增或整理端口函数，把以下职责集中到端口层：
- 选择框打开/关闭、弹窗关闭、输入锁（原 `UIView` 相关）。
- UI 刷新与状态同步（原 `TickUISync` 逻辑）。
- 动画播放（已有 `play_move_anim`/`play_action_anim` 保持）。

把默认实现改为调用 `src/presentation`，并确保端口可以被覆盖。

2) 迁移 UI 同步与事件处理。

把 `src/game/turn/TickUISync.lua` 的对 UI 的直接调用改为端口调用。保留数据整理逻辑，但把渲染与 UI 操作（`ui_view.render`、`ui_view.open_choice_modal`、`ui_status_3d.sync` 等）放进端口默认实现中。

把 `src/game/turn/TickTimeout.lua` 中对 `UIView` 的直接调用改成端口回调（例如 `close_popup`、`close_choice_modal`），通过注入的端口执行。

3) 解除破产逻辑对渲染的依赖。

在 `src/game/game/Bankruptcy.lua` 中移除对 `src.presentation.render.TileRenderer` 的引用。改为通过端口发送一个“破产清理”通知（例如 `ports.on_bankruptcy_tiles_cleared(game, player, owned_tile_ids)`）。默认实现放在 `presentation`，负责渲染清理。

4) 组合根注入端口。

在 `src/game/game/CompositionRoot.lua` 或 `src/game/turn/GameplayLoop.lua` 的初始化中，加入端口注入逻辑，使 `game` 或 `state` 能持有端口实现。默认使用 `GameplayLoopPorts.resolve()`，测试时可覆盖为无 UI 的端口。

5) 补充无 UI 运行验证。

新增或修改 `.agents/tests/` 下的脚本，创建最小 `game` 与 `state`，注入一个“空端口”实现（函数为空但不报错），推进一次 `gameplay_loop.tick` 或 `turn_flow.run_turn`，验证流程可运行且不 require `src/presentation`。

## 验证与验收

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行以下命令：

    lua .agents/tests/regression.lua

预期：已有回归脚本通过。

新增或更新一个无 UI 测试脚本后，运行：

    lua .agents/tests/gameplay_loop_no_ui.lua

预期：脚本输出包含“tick ok”或类似成功标记，且运行时不加载 `src/presentation`。

在代码层的验收标准：
- `rg -n "src\.presentation" src/game` 只剩端口默认实现位置，不再出现在核心逻辑文件（`GameplayLoop.lua`、`TickUISync.lua`、`TickTimeout.lua`、`Bankruptcy.lua`）。
- 核心流程可在无 UI 端口下运行一轮。

## 可重复性与恢复

所有改动为增量替换，不涉及数据迁移。若需要回滚，可从版本控制恢复相关文件。端口注入是可开关的：测试使用空端口，生产使用默认端口，互不影响。

## 产物与备注

实际修改的文件：

    src/game/turn/GameplayLoopPorts.lua
    src/game/turn/GameplayLoop.lua
    src/game/turn/TickUISync.lua
    src/game/turn/TickTimeout.lua
    src/game/game/Bankruptcy.lua
    .agents/tests/gameplay_loop_no_ui.lua

验证输出（示意）：

    $ lua .agents/tests/gameplay_loop_no_ui.lua
    tick ok

## 接口与依赖

端口接口定义在 `src/game/turn/GameplayLoopPorts.lua`，必须包含：
- `close_choice_modal(state)`
- `open_choice_modal(state, choice, market)`
- `close_popup(state)`
- `apply_input_lock(state)`
- `apply_role_control_lock(state, enabled)`
- `play_move_anim(state, anim_ctx)`
- `play_action_anim(state, anim_ctx)`
- `step_choice_timeout(game, state, dt)`
- `step_modal_timeout(game, state, dt)`
- `update_countdown(game, state)`
- `build_model(state, game)`
- `refresh_from_dirty(game, state, dirty)`
- `log_status(view)`
- `sync_debug_log(state)`
- `reset_status_3d(state)`
- `sync_status_3d(game, state, dirty)`
- `install_event_handlers(game, logger, state)`
- `on_bankruptcy_tiles_cleared(game, player, owned_tile_ids)`（新增）

默认实现放在 `presentation` 侧，核心逻辑只调用端口，不直接依赖 UI 模块。

---

变更说明（2025-03-04 / Codex）：已执行端口解耦，核心层移除 `src.presentation` 依赖，新增无 UI 回归脚本并更新验收命令。
