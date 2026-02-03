# 代码审查报告（2026-02-02）

## 范围
- 入口与循环：`main.lua`、`init.lua`
- 核心循环：`Manager/TurnManager/GameplayLoop.lua`
- 回合流转：`Manager/TurnManager/Turn/TurnManager.lua`
- 状态存储：`Components/Store.lua`
- 棋盘渲染：`Manager/BoardManager/GUI/BoardView.lua`

## 总结
- 高风险：3
- 中风险：1
- 低风险：1
- 主要集中在：游戏初始化、动画等待逻辑、状态存取约定

## 发现

### 高风险
1) `init.lua:46-53` + `Manager/TurnManager/GameplayLoop.lua:122-123`
- `state.game_factory` 被赋值为 Game 实例，但后续当函数调用。
- 触发点：`GameplayLoop.new_game()`（启动/重开游戏）。
- 影响：运行时错误（attempt to call a table value），直接中断流程。
- 建议：改为函数工厂（`function() return Game:new(...) end`）或保存类+参数并在调用处实例化。

2) `init.lua:185-191` + `Manager/TurnManager/GameplayLoop.lua:371-372`
- tick 循环在 `GAME_INIT` 前启动，`current_game` 仍为 nil。
- `GameplayLoop.tick` 有 `assert(game ~= nil)`，并且后续依赖 `G`/`ALLROLES` 的 UI 刷新也未初始化。
- 影响：取决于引擎事件顺序，可能启动即崩。
- 建议：在 `GAME_INIT` 后再 `start_tick_loop`，或在 tick 内判空直接返回。

3) `Manager/TurnManager/GameplayLoop.lua:232-272` + `414-438`
- `step_move_anim`/`step_action_anim` 在每帧无条件调用，但内部要求 `phase == wait_*` 且动画对象存在。
- 当阶段为 `wait_choice` 或无动画时，会触发 `missing move_anim`/`missing action_anim` 断言。
- 影响：任何无动画的回合都会崩溃。
- 建议：在 tick 中按 `phase`/`anim` 判断再调用，或把 guard 放进 `step_*` 内部。

### 中风险
4) `Components/Store.lua:24-44`
- 注释声明 set 会“自动创建中间表”、get “不存在返回 nil”，但实现会 assert 且不创建中间表。
- 影响：新增任意未预先创建的路径会直接崩溃，且与注释不一致。
- 建议：统一实现与注释（补齐自动创建逻辑或修正说明）。

### 低风险
5) `init.lua:152-153`
- `G.ground` 未做 nil 校验就调用 `set_model_visible`。
- 影响：地面单位缺失时启动崩溃。
- 建议：增加 assert 或降级处理。

## 测试/验证缺口
- 未发现自动化测试或回归脚本。
- 建议最少覆盖：
  - `wait_choice`/`wait_move_anim`/`wait_action_anim` 三种阶段下的 tick 行为
  - `GameplayLoop.new_game()` / 重开流程
  - `Store.set/get` 对缺失路径的行为
