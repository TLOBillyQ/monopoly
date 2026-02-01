# 里程碑 1：启动与 UI 适配逻辑落地到具体模块（子计划）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并作为总计划 `pilots/15_monopoly_solid_refactor_plan.md` 的子计划。

## 目的 / 全局视角

本里程碑把“Runtime / System / AdapterLayer”这些抽象层拆散到具体行为位置：日志时间格式化放回 `Library/Monopoly/Logger.lua`，GAME_INIT 的 UI 与单位初始化放到 `Manager/TurnManager/GUI/Layer.lua`，帧循环启动也由 `Layer` 负责；`AdapterLayer` 的逻辑并入 `Layer`，不再保留该文件；入口从 `Manager/System/Runtime.lua` 迁移到更具体的 `Manager/GameManager/Entry.lua`。完成后，目录与文件名不再体现这些抽象层级，但对外入口仍能从 `init.lua` 启动游戏。

可观察结果：

1) `init.lua` 改为调用 `Manager/GameManager/Entry.lua` 后，回归测试通过；
2) `Manager/System/Runtime.lua` 与 `Manager/System/AdapterLayer.lua` 被移除或只剩兼容空壳；
3) `EggyLayer` 内部仍能创建游戏、响应 UI 事件并推进回合。

## 进度

- [x] (2026-01-30 08:56Z) 建立新的游戏入口（Entry）并替换 `init.lua` 调用点
- [x] (2026-01-30 08:56Z) 合并 `AdapterLayer` 逻辑到 `Manager/TurnManager/GUI/Layer.lua`
- [x] (2026-01-30 08:56Z) 迁移 `Presenter`、`AutoRunner`、`ECA` 到更具体位置并更新引用
- [x] (2026-01-30 08:56Z) 调整依赖检查以允许 Entry 作为运行时入口例外
- [x] (2026-01-30 08:56Z) 回归验证与最小启动测试

## 意外与发现

- 观察：回归测试中 `require("Manager.TurnManager.GUI.Layer")` 触发 `Globals/Macro.lua` 依赖，导致本地 Lua 环境缺失 `math.Vector3` 报错。
  证据：`lua .github/tests/regression.lua` 报错 `Globals/Macro.lua:1: attempt to call field 'Vector3' (a nil value)`。

## 决策日志

- 决策：入口文件改为 `Manager/GameManager/Entry.lua`，`init.lua` 调用该入口。
  理由：入口属于玩法层，不应使用抽象层名称。
  日期/作者：2026-01-30 / Codex

- 决策：`AdapterLayer` 逻辑直接折叠进 `Manager/TurnManager/GUI/Layer.lua`。
  理由：这是 UI 适配行为的实际落点，拆掉抽象层可读性更强。
  日期/作者：2026-01-30 / Codex

- 决策：`Presenter` 与 `AutoRunner` 迁移到 `Manager/TurnManager/GUI/`，`ECA` 迁移到 `Globals/`。
  理由：这些功能分别属于 UI 视图、UI 自动行为与全局事件桥接。
  日期/作者：2026-01-30 / Codex

- 决策：在 `Layer.lua` 内对 `MoveAnim` 与 `ActionAnim` 使用延迟 `require`。
  理由：测试环境仅需要 `step_*` 方法，不应触发 `Globals.Macro` 对引擎类型的依赖。
  日期/作者：2026-01-30 / Codex

- 决策：`.github/tests/deps_check.lua` 将 `Manager/GameManager/Entry.lua` 视为运行时入口例外。
  理由：入口需要依赖 GUI 层，规则上与原 `Runtime.lua` 同类。
  日期/作者：2026-01-30 / Codex

## 结果与复盘

已完成入口迁移、适配层合并与模块搬迁，运行时入口改为 `Entry.install()`，回归测试与入口加载测试通过。当前里程碑没有遗留项，后续继续执行事件化与注册表里程碑。

## 背景与导读

目前启动流程集中在 `Manager/System/Runtime.lua`，UI 适配集中在 `Manager/System/AdapterLayer.lua`，并在 `Manager/TurnManager/GUI/Layer.lua` 中被调用。`Presenter` 与 `AutoRunner` 也位于 `Manager/System/`，`ECA` 放在 `Manager/System/ECA.lua`。这些命名属于抽象层次，不符合“按行为落位”的结构原则，因此本里程碑将其迁移到更具体的模块位置。

相关文件：
`init.lua`
`Manager/System/Runtime.lua`
`Manager/System/AdapterLayer.lua`
`Manager/System/Presenter.lua`
`Manager/System/AutoRunner.lua`
`Manager/System/ECA.lua`
`Manager/TurnManager/GUI/Layer.lua`
`Library/Monopoly/Logger.lua`

## 工作计划

先建立新的入口文件，再把 AdapterLayer 的逻辑并入 `Layer`，最后搬迁辅助模块并更新引用。入口文件负责：配置日志时间、创建 Layer、注册 GAME_INIT 处理、启动帧循环。`Layer` 内部要拥有原先 AdapterLayer 的功能（选择超时、动画同步、自动运行、游戏创建等），并确保对外方法名尽量兼容。`Presenter` 与 `AutoRunner` 迁移到 `Manager/TurnManager/GUI/`，`ECA` 迁移到 `Globals/`，以“行为所属位置”为准更新 require。

## 具体步骤

所有命令在 `C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly` 执行。

1) 新建游戏入口并替换调用点。
   - 新增 `Manager/GameManager/Entry.lua`，提供 `Entry.install()`，内部完成：
     - 调用 `Library/Monopoly/Logger.lua` 新增的 `configure_game_time(GameAPI)`。
     - 创建 `EggyLayer` 实例。
     - 调用 `layer:install_game_init()` 注册 GAME_INIT 的 UI/单位初始化。
     - 调用 `layer:start_tick_loop()` 启动帧循环。
   - 修改 `init.lua`，由 `require("Manager.GameManager.Entry").install()` 启动。
   - `Manager/System/Runtime.lua` 若保留，则仅作为兼容转发，并标记废弃；优先删除并更新引用。

2) 合并 AdapterLayer 逻辑到 `Manager/TurnManager/GUI/Layer.lua`。
   - 把 `AdapterLayer.attach` 的字段初始化、`IntentDispatcher` 监听逻辑、`game_factory/auto_runner` 初始化迁移到 `EggyLayer.new()` 或私有函数。
   - 把 `AdapterLayer.set_game/new_game/build_item_index` 合并为 `EggyLayer:set_game/new_game/build_item_index` 内部逻辑。
   - 把 `step_choice_timeout/step_modal_timeout/step_move_anim/step_action_anim/step_auto_runner` 合并为 `EggyLayer:_step_*` 私有方法，并在 `EggyLayer:tick` 内调用。
   - 删除 `Manager/System/AdapterLayer.lua` 并移除所有 `require`。

3) 迁移辅助模块并更新引用。
   - 将 `Manager/System/Presenter.lua` 移动为 `Manager/TurnManager/GUI/Presenter.lua`，更新 `Layer.lua` 的 require 路径。
   - 将 `Manager/System/AutoRunner.lua` 移动为 `Manager/TurnManager/GUI/AutoRunner.lua`，更新 `Layer.lua` 引用。
   - 将 `Manager/System/ECA.lua` 移动为 `Globals/ECA.lua`，更新 `Runtime`/入口文件与任何调用处。

4) 增补日志时间配置入口。
   - 在 `Library/Monopoly/Logger.lua` 添加 `configure_game_time(game_api)`，内部调用 `set_timestamp_provider` 与 `set_time_formatter`。
   - 在 `Entry.install()` 中调用此函数，传入 `GameAPI`。

5) 最小启动验证。
   - 新建 `.github/tests/entry_smoke_test.lua`，只验证 `require("Manager.GameManager.Entry")` 可加载，且 `Entry.install` 存在（不实际调用引擎依赖）。

## 验证与验收

运行回归测试：
    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

运行入口加载测试：
    lua .github/tests/entry_smoke_test.lua
    ok - entry load

人工验证（可选）：执行入口，观察日志仍能输出回合信息，UI 初始化无报错。

## 可重复性与恢复

迁移以文件移动与局部合并为主，可逐步提交。若合并后出现行为差异，优先恢复单个模块并重新对比 AdapterLayer 原逻辑。删除文件前先确保所有 require 都已更新，避免运行时找不到模块。

## 产物与备注

预期新增或改动文件：
`Manager/GameManager/Entry.lua`
`Manager/TurnManager/GUI/Layer.lua`
`Manager/TurnManager/GUI/Presenter.lua`
`Manager/TurnManager/GUI/AutoRunner.lua`
`Globals/ECA.lua`
`Library/Monopoly/Logger.lua`
`init.lua`
`.github/tests/entry_smoke_test.lua`

预期移除文件：
`Manager/System/Runtime.lua`
`Manager/System/AdapterLayer.lua`
`Manager/System/Presenter.lua`
`Manager/System/AutoRunner.lua`
`Manager/System/ECA.lua`

测试输出示例：
    lua .github/tests/entry_smoke_test.lua
    ok - entry load

## 接口与依赖

在 `Manager/GameManager/Entry.lua` 中定义：
    local Entry = {}
    function Entry.install() end

在 `Manager/TurnManager/GUI/Layer.lua` 中新增：
    function EggyLayer:install_game_init() end
    function EggyLayer:start_tick_loop(interval) end

在 `Library/Monopoly/Logger.lua` 中新增：
    function logger.configure_game_time(game_api) end

`EggyLayer` 内部方法命名允许调整，但对外公开接口应保持 `new/set_game/new_game/dispatch_action/step_turn` 等不变。

改动记录：本计划为首次版本，尚未实施。
改动记录：按要求移除“System/Runtime/AdapterLayer”抽象命名，改为具体模块落位，并调整步骤与产物清单。
改动记录：执行里程碑 1，完成入口迁移、适配层合并、依赖检查调整与测试验证，并记录测试环境的 Macro 依赖问题。
