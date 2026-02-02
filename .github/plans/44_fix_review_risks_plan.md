# 修复代码审查高中风险（初始化、动画调度、状态存储）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角

本次改动要解决代码审查报告中的高风险与中风险问题，避免游戏启动或回合推进时出现断言崩溃。完成后，游戏在 GAME_INIT 之后再开始 tick；回合没有动画时不会触发动画断言；`state.game_factory` 能可靠创建新游戏；`Store.get/set` 的行为与注释一致且对缺失路径更可预测。可观察结果是：启动流程不再因为 nil 游戏或动画阶段不匹配而崩溃，回归脚本可完整跑通，并且新增的 Store 行为测试能够通过。


## 进度

- [x] (2026-02-02 20:30Z) 核对代码审查风险点对应的文件与调用链，确认需要修改的最小范围。
- [x] (2026-02-02 20:30Z) 修复 `init.lua` 的 `game_factory` 与 tick 启动时机，保证 GAME_INIT 后才进入循环。
- [x] (2026-02-02 20:30Z) 为 `GameplayLoop.tick` 增加动画阶段的调用边界，避免无动画时触发断言。
- [x] (2026-02-02 20:30Z) 让 `Store.get/set` 与注释一致，并补上回归测试覆盖缺失路径行为。
- [x] (2026-02-02 20:30Z) 运行回归脚本并记录关键输出片段，更新“结果与复盘”。


## 意外与发现

目前无。执行过程中如发现引擎事件顺序、动画事件派发或存储结构与预期不一致，需记录对应日志片段。


## 决策日志

- 决策：将 `state.game_factory` 改为返回 `Game:new(...)` 的函数，并在每次调用时生成新的 seed。
  理由：当前把实例当函数调用会直接崩溃；工厂函数还能保证新游戏拥有新随机种子。
  日期/作者：2026-02-02 / Codex
- 决策：tick 循环在 `EVENT.GAME_INIT` 内启动，并在 `GameplayLoop.tick` 首行对 `game` 做防御性判空直接返回。
  理由：引擎事件顺序不确定，双重保护能避免启动期崩溃，并不影响正常流程。
  日期/作者：2026-02-02 / Codex
- 决策：在 `GameplayLoop.tick` 中仅当 phase 为 `wait_move_anim` / `wait_action_anim` 且对应 anim 存在时调用 `step_*_anim`。
  理由：当前每帧调用会在无动画阶段触发断言；把判断放在 tick 入口最直观。
  日期/作者：2026-02-02 / Codex
- 决策：`Store.set` 自动创建中间表，`Store.get` 在路径缺失时返回 nil，若遇到非 table 的中间节点则抛断言。
  理由：与注释一致，减少“新增路径即崩溃”的风险，同时仍保持类型错误可见。
  日期/作者：2026-02-02 / Codex


## 结果与复盘

已完成实施。新增回归测试覆盖 `Store` 缺失路径与 tick 非动画阶段调用；回归脚本通过（32 项）。暂无需要额外启动期防御日志的新增需求。


## 背景与导读

入口脚本在 `main.lua` 与 `init.lua`，其中 `init.lua` 构建全局状态并启动游戏循环。回合主循环在 `Manager/TurnManager/GameplayLoop.lua`，它负责每帧 tick、处理动画等待、推进回合。回合阶段与动画等待状态由 `Manager/TurnManager/Turn/TurnManager.lua` 和 `GameState` 存储在 `Store` 中。`Components/Store.lua` 是状态树读写的基础设施；其注释宣称可以自动创建路径，但实现目前不会，导致新增路径时崩溃且与注释不符。本计划要在这些文件中做最小修改，消除启动期 nil、动画阶段断言以及 Store 行为不一致的问题。

术语说明：
“tick”指每隔固定帧数触发的循环回调；“phase”是回合当前阶段字符串（例如 `wait_move_anim`）；“动画等待”指回合流程暂停，等待 UI/动画结束后继续。


## 工作计划

先修复 `init.lua` 的工厂与 tick 启动顺序。具体做法是把 `state.game_factory` 替换成函数，并将 `start_tick_loop(state)` 移入 `EVENT.GAME_INIT` 回调，在 `current_game` 创建完成后启动；同时给 `state` 增加一个 `tick_started` 标记，避免重复启动。随后在 `GameplayLoop.tick` 中添加两个保护：若 `game` 为空直接返回；仅当 phase 与动画对象存在时才调用 `step_move_anim` 与 `step_action_anim`。最后修复 `Components/Store.lua`，让 `set` 自动创建中间 table，`get` 在路径缺失时返回 nil，遇到非 table 的中间节点则 assert，并同步更新注释。为保证行为可验证，在 `.github/tests/regression.lua` 增加一组测试覆盖 `Store.get/set` 的缺失路径行为，以及 `GameplayLoop.tick` 在非动画阶段不会触发动画断言的最小用例。


## 具体步骤

1) 定位当前实现位置，确认只修改计划中的文件。

   工作目录：仓库根目录

   运行：

       rg -n "game_factory|start_tick_loop|GAME_INIT" init.lua
       rg -n "step_move_anim|step_action_anim|function GameplayLoop.tick" Manager/TurnManager/GameplayLoop.lua
       rg -n "function Store:get|function Store:set" Components/Store.lua

2) 修改 `init.lua`。

   将 `state.game_factory` 改成函数形式，并在函数内调用 `Game:new`；seed 在函数内重新取 `GameAPI.get_timestamp()`。新增 `state.tick_started`，把 `start_tick_loop(state)` 移入 `EVENT.GAME_INIT` 回调，并在调用前判断 `state.tick_started` 防止重复启动。

3) 修改 `Manager/TurnManager/GameplayLoop.lua`。

   在 `GameplayLoop.tick` 函数开头加入：当 `game` 为空时直接返回。获取 `phase` 与动画对象后再调用 `step_move_anim`/`step_action_anim`。保持 `step_move_anim` 与 `step_action_anim` 内部断言不变，确保只有在正确阶段才会被调用。

4) 修改 `Components/Store.lua`。

   `Store.set` 在遍历路径时遇到 nil 便创建 `{}`，遇到非 table 的中间节点则 assert。`Store.get` 若路径中节点缺失，直接返回 nil；若遇到非 table 的中间节点则 assert。同步更新注释，使行为与实现一致。

5) 更新回归脚本 `.github/tests/regression.lua`。

   增加两类最小测试：
   - 缺失路径的 `Store.get` 返回 nil，`Store.set` 能创建中间表后再读出值。
   - 构造一个 phase 非动画阶段的最小 `game/store`，调用 `GameplayLoop.tick` 不会触发动画断言（可通过计数器或不抛错验证）。


## 验证与验收

在仓库根目录运行回归脚本：

    lua .github/tests/regression.lua

预期输出包含：

    All regression checks passed (N)

其中 N 为新增测试后的总数量。若脚本失败，先检查 `Store` 新行为是否影响已有用例，再确认 `GameplayLoop.tick` 的 phase 判断是否正确。


## 可重复性与恢复

本改动是幂等的，可重复执行。若需要回退，优先使用 Git 仅恢复被修改的文件；或在修改前复制这些文件为备份，回退时用备份覆盖。回退后再次运行回归脚本确认状态一致。


## 产物与备注

应保留以下证据片段（简短即可）：

    lua .github/tests/regression.lua
    All regression checks passed (N)

以及关键改动的局部 diff 片段，例如 `init.lua` 中 `game_factory` 的函数化与 tick 启动位置。


## 接口与依赖

- `init.lua` 中 `state.game_factory` 必须是函数，签名为：

    local function build_game() -> Game

- `GameplayLoop.tick(game, state, dt)` 必须允许 `game` 为空并直接返回；当 `phase == "wait_move_anim"` 且 `move_anim` 存在时才调用 `step_move_anim`，`wait_action_anim` 同理。
- `Store.get(path)`：路径缺失返回 nil；路径中遇到非 table 且仍需继续遍历时 assert。
- `Store.set(path, value)`：缺失中间节点自动创建为 table，遇到非 table 中间节点 assert。

这些行为都需要在 `.github/tests/regression.lua` 有可执行的验证用例覆盖。
