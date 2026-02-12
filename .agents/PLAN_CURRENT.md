# 第二轮：提取 Presentation 端口适配层并清理核心依赖

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

上一轮已通过端口把 UI 调用集中到 `GameplayLoopPorts.lua`，但它仍位于 `src/game` 且直接 require `src/presentation`。本轮目标是把端口默认实现移到 `src/presentation`，让 `src/game` 只保留纯接口与解析逻辑，彻底消除核心层对 UI 的依赖。完成后，核心层不再 require `src/presentation`，UI 侧通过适配器注入端口。可见生效方式：`rg -n "src\.presentation" src/game` 无结果；无 UI 测试与回归测试同时通过。

## 进度

- [ ] (2025-03-04 10:00Z) 设计并落地端口适配器模块与注入点。
- [ ] (2025-03-04 10:00Z) 迁移 `GameplayLoopPorts.lua` 的默认实现到 `src/presentation`。
- [ ] (2025-03-04 10:00Z) 清理核心层对 UI 的残留依赖与回退逻辑。
- [ ] (2025-03-04 10:00Z) 更新测试注入端口并验证回归。

## 意外与发现

- 观察：上一轮把 UI 渲染逻辑移动到 `GameplayLoopPorts.lua`，导致核心层仍依赖 `src/presentation`。
  证据：`rg -n "src\.presentation" src/game` 目前仅命中 `src/game/turn/GameplayLoopPorts.lua`。

## 决策日志

- 决策：新增 `src/presentation/api/GameplayLoopPortsAdapter.lua` 作为默认 UI 端口实现入口。
  理由：保持 `src/game` 的端口接口纯净，同时让 UI 层可集中管理默认行为。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

待完成后补充，重点评估：核心层是否完全无 UI 依赖、端口注入是否稳定、回归是否通过。

## 背景与导读

`src/game/turn/GameplayLoopPorts.lua` 当前包含 UI 渲染、调试面板、动画与破产清理等默认实现，仍 require `src/presentation`。核心层的理想状态是只依赖“端口接口”，默认实现应位于 `src/presentation`。本轮将新增一个 UI 适配器模块，由应用入口注入到 `state.gameplay_loop_ports`，核心层只做解析与调用。

术语解释：
- 端口适配器（Adapter）：面向 UI 的默认实现模块，提供端口函数集合并绑定到运行时状态。
- 端口接口：核心层调用的一组函数签名，位于 `src/game/turn/GameplayLoopPorts.lua`。

## 工作计划

先新增一个 presentation 侧端口适配器模块，承接所有 UI/渲染逻辑。随后把 `src/game/turn/GameplayLoopPorts.lua` 改为只提供接口解析与默认空实现。再调整入口注入点与测试，确保端口在 UI 环境和无 UI 环境都能被正确注入。最后清理 `TickTimeout` 的 UI 回退与 `Bankruptcy` 的 UI 端口获取路径，使核心层完全无 UI 依赖。

## 具体步骤

1) 新增 UI 端口适配器模块。

创建 `src/presentation/api/GameplayLoopPortsAdapter.lua`，导出 `build(state)`，返回一组端口函数，内容迁移自 `src/game/turn/GameplayLoopPorts.lua` 中的默认实现，包括：
- 选择框/弹窗/输入锁。
- UI 刷新与调试面板。
- 动画播放与相机跟随。
- 事件处理安装与破产清理。

2) 精简 `src/game/turn/GameplayLoopPorts.lua`。

把当前默认实现替换为“无 UI 的空实现”，仅保留 `resolve(override_ports)` 与端口签名。该模块不能 require `src/presentation`。如需日志或规则配置，保留在核心层。

3) 注入端口适配器。

在 `src/app/init.lua` 的 `_install_game_init` 中，在 `gameplay_loop.set_game` 之前设置：

    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)

同时在测试需要 UI 的位置（例如 `presentation_ui.lua`）设置同样的注入；无 UI 测试继续注入空端口。

4) 清理核心层 UI 回退。

删除 `TickTimeout` 中对 `UIView` 的回退逻辑，改为必须通过端口关闭弹窗。若端口缺失，直接返回并保持状态不变，让测试显式注入端口。

5) 修正破产清理端口来源。

把 `Bankruptcy.lua` 中的端口访问从 `game.ui_port.gameplay_loop_ports` 改为 `game.gameplay_loop_ports`，并在 `gameplay_loop.set_game` 设置 `game.gameplay_loop_ports = ports`，避免依赖 UI state。

## 验证与验收

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行：

    rg -n "src\.presentation" src/game

预期：无输出。

运行回归与无 UI 脚本：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua

预期：回归 119 通过；无 UI 脚本输出 `tick ok`。

## 可重复性与恢复

改动为增量迁移。若 UI 适配器出现问题，可暂时在入口不注入端口并回退到上一版 `GameplayLoopPorts.lua`。所有改动可通过版本控制回滚。

## 产物与备注

预期修改或新增的文件：

    src/presentation/api/GameplayLoopPortsAdapter.lua
    src/game/turn/GameplayLoopPorts.lua
    src/game/turn/GameplayLoop.lua
    src/game/turn/TickTimeout.lua
    src/game/game/Bankruptcy.lua
    src/app/init.lua
    .agents/tests/suites/presentation_ui.lua

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
- `on_bankruptcy_tiles_cleared(game, player, owned_tile_ids)`

默认实现由 `src/presentation/api/GameplayLoopPortsAdapter.lua` 提供，核心层仅解析并调用端口。

---

变更说明（2025-03-04 / Codex）：新建第二轮计划，目标是将端口默认实现迁移到 presentation 侧，彻底清理核心层 UI 依赖。
