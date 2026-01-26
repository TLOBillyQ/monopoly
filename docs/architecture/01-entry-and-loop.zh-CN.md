# 01 入口与帧循环：从 `main.lua` 看整条链路

本工程的“入口”不是传统 `love.update/draw`，而是 **soluna 运行时回调表**：`main.lua` 返回一个 `callback` 表，包含 `frame`、`mouse_*`、`touch_*`、`window_resize`、`key/char` 等函数。

## 入口文件与职责

- `main.lua`：组装模块、初始化资源、初始化 `visual.desktop`、加载状态机、绑定输入回调。
- `main.game`：运行时设置（窗口大小、DPI、API 版本等）。

关键初始化顺序（简化）：

1. `widget.scripts(require "visual.ui")`：把 UI “脚本扩展”注入 widget/layout 系统
2. `language.init()` + `language.switch(LANG)`：加载并切换语言
3. `vdesktop.init{ batch, font_id, sprites, width, height }`：初始化渲染端的桌面 UI 组合
4. 构造 `game` 表：挂载 `init/load/idle` 与一组 `gameplay.*` 状态模块
5. `flow.load(game)`：把状态表装载进 `core/flow.lua`
6. 选择初始状态：`flow.enter(flow.state.startmenu)` 或 `flow.enter(flow.state.chooselang)` 等
7. `keyboard.setup(callback)`：给 callback 注入 `key/char` 处理（含 IME）

参考实现：`main.lua`

## 帧循环：`callback.frame(count)`

`callback.frame(count)` 是每帧的主调度点（`count` 代表帧计数）。其逻辑（按调用顺序）：

1. `mouse.sync(count)`：把本帧鼠标坐标与帧序号绑定
2. `flow.update()`：推进状态机（可能执行/继续一个协程）
3. `touch.update(count)`：在 touch 设备上做长按/双击映射（转换成 mouse 事件）
4. `vdesktop.card_count(...)` / `map.update()`：把模型态变化推给视觉层
5. `vdesktop.draw(count)`：执行绘制与命中测试
6. `mouse.frame()`：收尾，清理“release/click/focus”一次性状态

参考实现：`main.lua` 的 `callback.frame`

## 事件回调：输入/窗口

- `callback.window_resize = vdesktop.flush`：窗口变化时刷新布局与绘制列表
- `callback.mouse_move/button/scroll`：转发到 `core.mouse`
- `callback.touch_begin/end/moved`：转发到 `core.touch`
- `callback.key/char`：由 `core.keyboard.setup(callback)` 注入

## 可复用模式

- **入口只做 wiring**：`main.lua` 不写“游戏规则”，只负责把核心组件接起来。
- **把每帧逻辑拆成可独立测试的小模块**：`mouse`、`touch`、`flow`、`vdesktop`、`map` 都有清晰入口。
- **避免跨层反向依赖**：`gameplay` 驱动 `visual`，`visual` 不直接改 `gameplay` 核心数据结构。

