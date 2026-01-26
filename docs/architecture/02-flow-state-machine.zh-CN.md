# 02 状态机与协程调度：`core/flow.lua`

本工程的状态机不是“switch-case + update”，而是 **协程 + 状态函数** 的组合：每个状态是一个 Lua 函数，执行到需要等待动画/输入时 `flow.sleep()`，下一帧继续从断点处执行。

## 关键文件

- `core/flow.lua`：状态机运行时（load/enter/update/sleep）
- `main.lua`：组装 `game` 状态表并 `flow.load(game)`
- `gameplay/*.lua`：具体状态实现（`setup/start/action/...`）

## 核心 API

- `flow.load(states)`：注册状态表，并生成 `flow.state.<name>` 校验器（拼错会报错）
- `flow.enter(state, args)`：进入一个状态（创建协程）
- `flow.update()`：每帧推进一次当前协程
- `flow.sleep(tick)`：让出执行权，等待 `tick` 帧后恢复

参考实现：`core/flow.lua`

## 状态模块约定（非常关键）

每个 `gameplay/<state>.lua` 最终 `return function(args) ... end`，并且：

- 函数可以循环、可以 `flow.sleep(0)` 做“等输入/等条件”
- 函数结束时返回下一个状态（通常是 `flow.state.xxx` 或字符串）

例子（真实工程风格）：

- `gameplay/startmenu.lua`：构建菜单，返回 `menu(MENU) or flow.state.startmenu`
- `gameplay/setup.lua`：一段长流程，途中多次 `flow.sleep()`，结束返回 `flow.state.start`

## 为什么这个模式适合“带动画/交互”的回合制逻辑

传统写法需要把流程拆成大量“子状态 + 计时器 + 回调”。这里用协程：

- 动画等待：`flow.sleep(5)` 直接写在流程里
- 等待输入：循环 `mouse.get(...)` + `mouse.click(...)`，中间 `flow.sleep(0)` 让出一帧
- 逻辑结构更接近规则书步骤，减少状态爆炸

## `flow.sleep()` 的语义细节

`flow.sleep(tick)` 并不是 `os.sleep`，而是协程 yield 指令：

- `tick <= 0`：本帧结束后立刻继续（常用于“等一帧”，或驱动输入轮询）
- `tick > 0`：通过内部 `sleep()` 协程计数若干帧，再 `RESUME` 回原协程

参考实现：`core/flow.lua` 的 `command.SLEEP` / `sleep()`

## 可复用模式（落地建议）

- 把“长流程”写成 **顺序代码**：setup、发牌、动画迁移等都可读可维护。
- 把“渲染/交互细节”封装进 `visual/*`：状态只调用 `vdesktop.transfer`、`vtips.set` 之类 API。
- 规范状态边界：状态函数末尾统一返回下一个状态，避免“隐式跳转”。

