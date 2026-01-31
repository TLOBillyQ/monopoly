# Eggy 直连 Gameplay 重构计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .agent/PLANS.md 的要求。

## 目的 / 全局视角


目标是把 Monopoly 在 Eggy 平台上的启动与循环改成“直接启动并驱动 gameplay”，不再通过 Runtime/RuntimeLoop/RuntimeUI 这种运行时层级中转。完成后入口仍是 main.lua -> init.lua -> Manager.GameManager.Entry.install，但 Entry 会直接完成 Eggy 初始化、创建 game、绑定 UI 事件、启动帧循环，并在每一帧驱动 gameplay 与 UI 刷新。可观察结果是：在 Eggy 场景中启动后，UI 在 GAME_INIT 触发后出现，点击“下一步”可推进回合，自动模式与弹窗行为保持不变；同时运行 lua tests/regression.lua 仍能通过。

## 进度


- [x] (2026-01-31 14:49Z) 创建可执行计划骨架并确认入口链路与 Runtime 相关文件清单。
- [ ] (2026-01-31 14:49Z) 合并 RuntimeLoop/RuntimeUI 行为为 gameplay 直连循环模块，完成 Entry 与 UIEventRouter 改造。
- [ ] (2026-01-31 14:49Z) 删除 Runtime 层文件与引用，完成测试与 Eggy 场景验证。

## 意外与发现


观察：tests/regression.lua 直接 require 了 Manager.System.GUI.RuntimeLoop 并调用 step_move_anim 与 step_modal_timeout。
证据：rg -n "RuntimeLoop" tests/regression.lua 返回对应行号。

## 决策日志


决策：移除 Manager/System/Runtime.lua 与 Manager/System/GUI/RuntimeLoop.lua、RuntimeUI.lua，并把其行为合并到 Entry + gameplay 循环中，代码里不再出现 Runtime 层级命名。
理由：用户要求“不要出现 runtime layer”，同时希望直接启动并驱动 gameplay，合并后路径最短且更直观。
日期/作者：2026-01-31 / Codex。

决策：新增 Manager/GameManager/GameplayLoop.lua 承接原 RuntimeLoop 的循环与分步函数，避免重复逻辑并满足 tests/regression.lua 的调用需求。
理由：需要保留 step_move_anim / step_modal_timeout 作为可复用入口，但不属于运行时适配层。
日期/作者：2026-01-31 / Codex。

## 结果与复盘


尚未实施，待重构完成后补充结果与复盘。

## 背景与导读


当前入口链路是 main.lua -> init.lua -> Manager.GameManager.Entry.install。Entry 通过 Manager.System.Runtime.install 创建运行时，再由 Runtime.install_game_init 监听 EVENT.GAME_INIT 完成 UIManager 初始化、G 全局表构建、地图单位查询与 UIEventRouter 绑定，并在 Runtime.start_tick_loop 中用 SetFrameOut 驱动 RuntimeLoop.tick。RuntimeLoop 负责 gameplay 驱动、自动操作、超时处理与动画等待；RuntimeUI 负责 Presenter.present 与 MainView 刷新与弹窗。UIEventRouter 依赖 RuntimeLoop 与 RuntimeUI，把 UI 点击转为 gameplay action。tests/regression.lua 直接调用 RuntimeLoop 的 step_move_anim 与 step_modal_timeout。

Eggy 约束必须保留：UI 创建必须在 GAME_INIT 之后；时间换算固定 30 FPS（30 帧 = 1 秒，使用显式浮点）；Eggy API 调用只用点号；触发器与 UIManager 初始化依赖 GameAPI / LuaAPI / GlobalAPI。gameplay 的核心仍在 Manager/GameManager/Game.lua 与 TurnManager 体系，改动必须保持行为不变，只改变启动与驱动路径。

## 工作计划


重构后路径：Entry.install 直接构建 gameplay 状态表（不命名为 runtime），在 GAME_INIT 回调里完成 UIManager 初始化、G 表准备、创建 game 并绑定 UIEventRouter，随后启动帧循环并调用 GameplayLoop.tick。RuntimeUI 的 UI 刷新与弹窗职责合并到 GameplayLoop 内部逻辑里，直接调用 MainView 与 Presenter，不再保留 RuntimeUI 模块。RuntimeLoop 的 dispatch_action、step_turn、step_* 函数迁移到 GameplayLoop.lua，并把形参命名为 state 或 ctx，避免 runtime 命名。

Entry 需要保留原 Runtime.build_runtime 的状态字段（ui、pending_choice、auto_runner、wait_move_anim 等），但以“gameplay 状态表”的形式存在，不再抽象为运行时层。IntentDispatcher.on("need_choice") 的监听从 Runtime.build_runtime 迁到 Entry.install，并直接调用 MainView.open_choice_modal。EventHandlers.install 仍负责日志与弹窗桥接，但 ui_port 指向 gameplay 状态表，状态表提供 push_popup/on_tile_upgraded/on_tile_owner_changed 方法，这些方法内部直接调用 MainView。

UIEventRouter 改为依赖 GameplayLoop.dispatch_action，并直接调用 MainView.close_popup / MainView.select_market_option 处理 UI 行为；原 RuntimeUI 的功能只保留在 GameplayLoop 内部，不再作为独立模块存在。完成迁移后删除 Manager/System/Runtime.lua 与 Manager/System/GUI 目录，并更新所有 require 引用与 tests/regression.lua 的 RuntimeLoop 调用。

## 具体步骤


第一步：列出 Runtime 相关引用，形成修改清单。

  工作目录：仓库根目录。
  命令：
    rg -n "Manager.System.Runtime|RuntimeLoop|RuntimeUI" Manager tests
  预期：输出只包含 Manager/GameManager/Entry.lua、Manager/System/Runtime.lua、Manager/System/GUI/RuntimeLoop.lua、Manager/System/GUI/RuntimeUI.lua、Manager/TurnManager/GUI/UIEventRouter.lua 与 tests/regression.lua。

第二步：新增 gameplay 循环模块并迁移 RuntimeLoop 逻辑。

  新建 Manager/GameManager/GameplayLoop.lua，迁移原 RuntimeLoop.lua 的代码并完成以下调整：
  1) 所有形参统一命名为 state 或 ctx；内部字段访问不使用 runtime 命名。
  2) 将 RuntimeUI.build_view/refresh_view 逻辑内联为 GameplayLoop 内部函数，直接调用 Presenter.present 与 MainView.refresh_*。
  3) 保留 step_move_anim / step_action_anim 的动画等待与超时逻辑，MoveAnim 与 ActionAnim 的调用路径保持不变。

第三步：改造 Entry.install 为直连 Eggy 启动。

  编辑 Manager/GameManager/Entry.lua：移除对 Manager.System.Runtime 的 require；新增 GameplayLoop、MainView、IntentDispatcher、EventHandlers、AutoRunner 等依赖；把 Runtime.install_game_init 与 Runtime.start_tick_loop 的内容合并到 Entry.install 内部的局部函数。GAME_INIT 回调中完成 UIManager.Builder、G 表初始化、tile/building 查询、UIEventRouter.bind，以及 GameplayLoop.set_game(state, GameplayLoop.new_game(state))。随后启动 SetFrameOut 循环调用 GameplayLoop.tick(state, tick_seconds)。logger 的 show_tips 适配逻辑保持不变。

第四步：更新 UIEventRouter 的依赖与调用。

  编辑 Manager/TurnManager/GUI/UIEventRouter.lua，把 require("Manager.System.GUI.RuntimeLoop") 替换为 require("Manager.GameManager.GameplayLoop")，把 RuntimeUI 的调用替换为 MainView 的直接调用（close_popup 与 select_market_option），UI 点击到 action 的映射逻辑保持一致。

第五步：删除 Runtime 层文件并修复引用。

  删除 Manager/System/Runtime.lua 与 Manager/System/GUI/RuntimeLoop.lua、Manager/System/GUI/RuntimeUI.lua。再次运行 rg 确认仓库内不再出现 Runtime 层引用，且新模块路径正确。

第六步：更新 tests/regression.lua 的调用点。

  将 tests/regression.lua 中的 RuntimeLoop require 替换为 GameplayLoop，并调整 step_move_anim / step_modal_timeout 的调用保持参数不变。确保测试仍可独立运行。

## 验证与验收


在仓库根目录运行：

  lua tests/regression.lua

预期输出包含连续的点号，以及结尾：

  All regression checks passed (30)

在 Eggy 编辑器中启动场景后，验证以下行为：GAME_INIT 后 UI 正常显示；点击“下一步”可推进回合；“自动”按钮可切换自动推进；弹窗出现后能自动超时关闭或手动确认；市场面板与选择弹窗的交互仍然可用。以上行为与改动前保持一致。

## 可重复性与恢复


本重构是纯代码迁移，改动可重复执行。若发现 UI 或回合推进异常，可临时回退到原 Runtime 层：恢复 Manager/System/Runtime.lua 与 Manager/System/GUI 目录，并把 Entry.install 恢复为调用 Runtime.install；UIEventRouter 与 tests/regression.lua 恢复原 require 即可。完成后应确保删除的 Runtime 文件不再被引用。

## 产物与备注


最终产物包括新增的 Manager/GameManager/GameplayLoop.lua、更新后的 Manager/GameManager/Entry.lua 与 Manager/TurnManager/GUI/UIEventRouter.lua，以及删除的 Runtime 层文件。完成后执行 rg 检查应无 Runtime 层引用，例如：

  rg -n "RuntimeLoop|RuntimeUI|Manager.System.Runtime" Manager tests

应无输出。

## 接口与依赖


GameplayLoop.lua 需要导出以下接口，供 Entry、UIEventRouter 与 tests/regression.lua 调用：

  GameplayLoop.new_game(state) -> game
  GameplayLoop.set_game(state, game)
  GameplayLoop.dispatch_action(state, action)
  GameplayLoop.tick(state, dt)
  GameplayLoop.step_auto_runner(state, dt, context)
  GameplayLoop.step_choice_timeout(state, dt, opts)
  GameplayLoop.step_modal_timeout(state, dt, opts)
  GameplayLoop.step_move_anim(state, opts)
  GameplayLoop.step_action_anim(state, opts)
  GameplayLoop.step_turn(state)
  GameplayLoop.clear_choice(state, opts)

Entry 内部依赖 UIManager.Builder、RegisterTriggerEvent、SetFrameOut、SetTimeOut、GameAPI、LuaAPI、GlobalAPI、EventHandlers.install 与 IntentDispatcher.on。GameplayLoop 内部依赖 Presenter.present、MainView.refresh_*、MainView.open_choice_modal / close_choice_modal / push_popup / close_popup / select_market_option，以及 MoveAnim/ActionAnim。所有 Eggy API 调用继续使用点号形式，并保持 30 FPS 的时间换算与显式浮点数。

变更记录：2026-01-31 创建首版可执行计划，原因是新增“直连 gameplay”重构需求。
