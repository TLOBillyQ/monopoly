# 04 渲染与 UI 系统：`visual.desktop` + `core.widget`

本工程的 UI 渲染由两部分组合而成：

1. **layout/widget 系统**：负责“UI 框架、文本、背景、可点击区域”的组织
2. **region + card/map 等绘制模块**：负责“卡牌/地图等游戏物件”的绘制与动画

## 关键文件

- `visual/desktop.lua`：桌面 UI 的总装配（hud/describe/额外层）
- `core/widget.lua`：layout 加载、生成 draw list、生成 test list、绘制与命中测试
- `asset/layout/*.dl`：布局数据
- `visual/region.lua`：卡牌区域容器与动画（transfer/focus/moving）

## widget 的两个产物：draw list 与 test list

`core/widget.lua` 的设计点是“一份 layout 同时用于绘制与交互”：

- `widget.draw_list(dom, texts, font_id, sprites)`：
  - 把 layout 计算后的节点序列变成“可绘制对象列表”
  - 其中 `obj.text` 走本地化 + 图标文本转换
  - `obj.region` 变成回调函数（用于卡牌区/地图等自定义绘制）

- `widget.test_list(dom, funcs)`：
  - 只提取 `region` 节点，生成用于命中测试的列表

参考：`core/widget.lua`

## `visual.desktop` 如何组合 UI

`visual/desktop.lua` 做了三件核心事：

1. **注册区域绘制/测试函数**：把 `visual.region`、`visual.map`、`visual.track`、`visual.button`、`visual.tips` 等拼到同一个“hud/test”表里
2. **根据窗口尺寸刷新布局**：`update_draw_list(w,h)` 重新计算 layout、生成 draw list/test list
3. **每帧绘制 + focus 处理**：`M.draw(count)` 在绘制前后处理 focus（例如地图聚焦、相机层）

参考：`visual/desktop.lua` 的 `init/draw/flush` 等逻辑

## region：用容器承载卡牌并实现 transfer 动画

`visual/region.lua` 把“某个 pile 的卡牌如何摆放/如何移动”从 gameplay 中剥离出来：

- `region:add/remove/replace/clear`
- `region:transfer(card, new_region)`：标记转移，下一次 `region:update()` 时把对象放入全局 TRANSFER 队列
- `region:animation_update()`：维护 focus 缓动（sin 插值）
- `region:draw()`：统一调用 `visual.card.draw`
- `region:test()`：命中测试（从上到下）

这使得 `gameplay` 只需要说“从 hand 转移到 deck”，无需关心动画细节。

## 可复用模式

- **渲染组合器（desktop）**：单点汇聚“所有视觉模块”，便于管理层级与刷新策略。
- **layout 负责结构、Lua 负责行为**：layout 定义“有什么区域”，Lua 决定“区域里画什么/怎么交互”。
- **动画与逻辑解耦**：transfer/focus 动画在 visual 层实现，gameplay 只做状态变更与调度等待（`flow.sleep`）。

