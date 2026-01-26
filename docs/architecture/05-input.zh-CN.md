# 05 输入系统：mouse / touch / keyboard（含 IME）

输入系统的设计目标是：**统一 focus 概念**，并让 touch 设备能复用 mouse 逻辑，同时支持文字输入（IME）。

## 关键文件

- `core/mouse.lua`：鼠标状态、click/press、focus region/object
- `core/touch.lua`：把 touch 映射为 mouse 左键（支持长按、双击确认）
- `core/keyboard.lua`：键盘事件 + IME 编辑框逻辑
- `core/widget.lua` + `visual/button.lua`：命中测试与 focus 设置
- `main.lua`：把引擎回调转发给上述模块

## focus 模型：region + object

`core/mouse.lua` 的 focus 由两部分组成：

- `focus.region`：当前悬停/命中的 UI 区域名（例如 `hand`、`map`、`button1`）
- `focus.object`：区域内具体对象（例如某张卡牌、某个 sector）

视觉层通过命中测试来“设置 focus”：

- `visual/button.lua` 的 `button.test()` 在命中时调用 `mouse.set_focus(name, true)`
- 其他区域（卡牌区、地图区）也会在 test 时设置 `mouse.set_focus(region, object)`

游戏逻辑侧用 `mouse.get(focus_state)` 拉取变化，并用：

- `mouse.click(focus_state, "left"/"right")` 获取一次性点击
- `mouse.press("left", object)` 获取按住时长（用于长按确认）

参考：`core/mouse.lua`、`visual/button.lua`、各状态模块里对 `mouse` 的使用（如 `gameplay/action.lua`）

## touch：双击确认 + 长按

`core/touch.lua` 将 touch 转换为 mouse 左键行为，并为特定 region 引入“二次确认”：

- `DOUBLE_TAP_REGIONS`：需要确认的区域集合（hand/neutral/homeworld/colony/...）
- `TOUCH_LONG_PRESS_FRAMES`：长按阈值（到时触发 press）
- `TOUCH_MOVE_THRESHOLD2`：滑动阈值（移动超过阈值就不算 tap）

这让移动端能复用同一套 `mouse.click/press` 逻辑，避免为 touch 写第二套交互代码。

参考：`core/touch.lua`

## keyboard + IME：编辑框是“被驱动的对象”

`core/keyboard.lua` 的核心思路是：

- 全局只有一个 `CURRENT_EDITBOX`
- `keyboard.editbox(desc)` 每帧被调用，用于：
  - 消化 `callback.char` 收集的输入
  - 处理光标移动/删除/回车/ESC
  - 更新 IME 候选框位置：`app.set_ime_rect(...)`
  - 返回“是否退出编辑”（enter/esc）

这种“每帧驱动的编辑框”非常适合与游戏循环整合，不需要额外线程或阻塞式输入。

参考：`core/keyboard.lua`

## 可复用模式

- **focus 作为交互的唯一入口**：逻辑只关心“当前 focus 在哪里、点了什么”，不直接读屏幕坐标细节。
- **touch 复用 mouse**：通过映射与少量策略（双击/长按）覆盖移动端主要需求。
- **编辑框状态对象化**：把输入框当作数据结构，每帧更新并渲染，不做阻塞式输入。

