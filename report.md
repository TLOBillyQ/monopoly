# src/ui 代码审查报告

依据 Clean Code 原则 + 项目 `.agents/CODING.md` 纪律。
严重度：🔴 高 / 🟡 中 / 🟢 低

---

## 1 合并与删除（CODING.md §5）

### 🔴 1.1 `_set_label` 与 `_set_button` 完全相同

`UIView.lua:35-43`

```lua
local function _set_label(_, name, text)
  local node = _query_node(name)
  node.text = text or ""
end
local function _set_button(_, name, text)
  local node = _query_node(name)
  node.text = text or ""
end
```

两个函数体一字不差，应合并为一个 `_set_text`。

### 🔴 1.2 三处纯转发包装

`UIView.lua:213-215, 289-295`

```lua
function ui_view.refresh_board(state, ui_model, log_once, build_log_prefix)
  board_view.refresh_board(state, ui_model, log_once, build_log_prefix)
end
function ui_view.on_tile_upgraded(state, tile_id, level)
  board_view.on_tile_upgraded(state, tile_id, level)
end
function ui_view.on_tile_owner_changed(state, tile_id, owner_id)
  board_view.on_tile_owner_changed(state, tile_id, owner_id)
end
```

CODING.md 第 5 条："只做转发的包装层应删除。" 调用方应直接使用 `board_view`。

### 🔴 1.3 `UIModel.build` / `update` 大面积重复

| 逻辑块 | `build()` 行号 | `update()` 行号 |
|---------|---------------|-----------------|
| item_slots 构建 | 56-68 | 177-192 |
| choice/market 构建 | 78-94 | 194-214 |
| popup 构建 | 95-102 | 217-226 |

三段逻辑几乎拷贝粘贴，应提取为共用的私有函数，`build` 和 `update` 都调用。

### 🟡 1.4 `tiles_by_id` 查找表重复构建

`TileRenderer.lua:3-6` 和 `UIModel.lua:6-9` 各自构建相同的 `tiles_by_id`：

```lua
local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end
```

应提取到一处（如 `tiles_cfg` 模块自身导出），两处引用。

### 🔴 1.5 死代码 — MoveAnim.lua

| 位置 | 内容 |
|------|------|
| 行 3-5 | `rad_to_deg` 仅在注释代码中使用 |
| 行 27 | `one_step` 的 `dir` 参数未使用 |
| 行 31-53 | 大段注释掉的朝向计算代码 |

CODING.md 第 5 条："未使用的函数/参数/分支直接删除。"

### 🟡 1.6 死代码 — BoardScene.lua

| 位置 | 内容 |
|------|------|
| 行 21 | 注释掉的 `set_physics_active` |
| 行 25-29 | 注释掉的 TODO 禁用逻辑 |

### 🟡 1.7 `_set_label` / `_set_button` / `_set_visible` / `_set_touch_enabled` 的未使用参数 `_`

`UIView.lua:35, 40, 45, 50` — 四个私有函数的第一个参数 `_` 从未使用。这是因为它们被挂载到 `build_ui_state()` 返回的表上以 `self:method()` 方式调用，但作为闭包不需要 `self`。签名中的 `_` 使读者困惑于这些函数依赖了什么。

---

## 2 单一职责（CODING.md §3）

### 🔴 2.1 `open_choice_modal` 承担两项不同工作

`UIView.lua:305-371` — 该函数内部 `if choice.kind == "market_buy"` 分支走市场面板逻辑，`else` 走通用选择弹窗逻辑。两套完全不同的 UI 操作序列在一个函数内，应拆为 `_open_market_panel` 和 `_open_generic_choice`。

### 🟡 2.2 `UIEventRouter.bind()` 过长

`UIEventRouter.lua:133-285` — ~150 行，负责注册 7 类不同 UI 节点的点击处理。可按逻辑分组提取：
- 行动/托管按钮
- 道具槽位
- 弹窗确认
- 通用选择选项
- 市场按钮
- 兜底注册

### 🟡 2.3 `build_player_statuses` 混合数据查询与格式化

`UIPanel.lua:19-54` — 遍历 properties 计算资产（数据查询/业务逻辑）与拼接 `"现金: "` 等字符串（视图格式化）混在同一函数。符合"多个变化理由必须拆分"条件。

---

## 3 可读性（CODING.md §7）

### 🟡 3.1 标点不一致

`UIPanel.lua:58,60`

```lua
return "自动：开"   -- 全角冒号
return "自动:关"    -- 半角冒号
```

统一使用一种。

### 🟡 3.2 模块名与文件名不匹配

`MoveAnim.lua:7` — 模块变量名 `movement_manager`，文件名 `MoveAnim`。读者需要额外记忆映射。建议统一命名为 `move_anim`。

### 🟡 3.3 魔法数字 45

`BoardScene.lua:35, 46` — 循环中硬编码 `45` 作为地块数。应使用 `#tile_ids` 或命名常量：

```lua
for i = 1, 45 do            -- ❌
for i = 1, #tile_ids do     -- ✅
```

### 🟢 3.4 `price_label` 节点名含硬编码价格

`MarketLayout.lua:5` — `price_label = "售价：100"` 是编辑器节点名，但读起来像是一个显示值。不影响功能，但降低可读性。

### 🟢 3.5 别名双重注册

`UIAliases.lua:19-20, 38-39` — `choice_option1` 和 `choice_option_1` 同时指向同一节点。如果是有意为之的兼容手段，应加注释说明原因。

---

## 4 依赖方向与隐式状态（CODING.md §4）

### 🔴 4.1 `UIEventHandlers` — 模块级可变状态

`UIEventHandlers.lua:4-6`

```lua
local installed = false
local current_logger = nil
local current_state = nil
```

`install()` 注册的事件回调通过闭包捕获 `current_state`。`current_state` 在每次 `install` 调用时被替换，但之前注册的回调（`installed` 阻止重注册）仍指向同一个 upvalue。这使得：
- 难以测试（无法隔离模块状态）
- 隐含时序依赖（回调行为取决于最后一次 `install` 调用的参数）

建议将 `state` 和 `logger` 作为事件注册闭包的显式参数传入，或在 `install` 时销毁旧注册再重建。

### 🟡 4.2 `missing_button_tips` 无重置路径

`UIEventRouter.lua:9` — 模块级 `missing_button_tips = {}` 随 `_show_missing_button_tip` 累积条目，但 `unbind()` 不清除它。场景重载后可能产生误导。

### 🟡 4.3 `bind()` 内部懒加载 `require`

`UIEventRouter.lua:275` — `local nodes = require("Data.UIManagerNodes")` 出现在函数体内部，与模块其余 require 在顶部的惯例不一致。

### 🟡 4.4 Canvas 名称字符串散落

`UIView.lua` 第 10-14 行定义了 `CANVAS_BASE` 等常量，但 `build_ui_state()` 内（行 105, 117）直接写了 `"通用选择屏"` / `"弹窗屏"` 字面量而非引用常量。

---

## 5 `state` 作为上帝对象

`state` 表在调用链中被多个模块写入字段：

| 写入方 | 字段举例 |
|--------|---------|
| UIView.build_ui_state | ui, ui_refs |
| BoardScene.init | board_scene |
| BoardView.refresh_board | tile_positions, tile_units, player_units, tile_spacing, board_sync_pending, board_last_positions |
| UIEventRouter.bind | ui_event_router_listeners, ui_event_router_registered |
| MarketView | pending_choice_selected_option_id, market_choice_option_ids, pending_choice_id |
| UIModel | ui_model |
| 外部 | game, push_popup |

没有任何地方文档化或约束 `state` 的字段集合。任何模块都可以任意向其添加字段，耦合隐藏在运行时。

**建议**：定义一个 `state` 的初始化函数，集中列出所有字段及其初始值。各模块通过固定键名访问，不自行发明新字段。

---

## 6 其他观察

### 🟢 6.1 `MarketView` 图标重置逻辑重复

`MarketView.lua:97-109`（`refresh_market_selection`）和 `195-200`（`close_market_panel`）都包含"设置图标 + reset_size"的相同序列。

### 🟢 6.2 `_each_player` 抽象

`BoardView.lua:93-98` — 对 `ipairs` 的薄包装，只增加了一个 `assert(player ~= nil)` 检查。使用 4 次尚可接受，但 assert 在 ipairs 迭代中不会遇到 nil，属冗余检查。

### 🟢 6.3 `MarketLayout.is_ready()` 永远返回 true

`MarketLayout.lua:49-52` — 检查 `container` 和 `confirm_button` 是否为非空字符串，但二者在模块顶部已硬编码赋值，结果恒为 `true`。如果不会在运行时被修改，此检查无实际意义。

---

## 按严重度汇总

| 严重度 | 数量 | 关键项 |
|--------|------|--------|
| 🔴 高 | 5 | 重复函数(1.1)、纯转发(1.2)、build/update 重复(1.3)、死代码(1.5)、模块隐式状态(4.1) |
| 🟡 中 | 9 | tiles_by_id 重复(1.4)、BoardScene 死代码(1.6)、无用参数(1.7)、open_choice_modal 职责(2.1)、bind 过长(2.2)、数据/格式混杂(2.3)、标点(3.1)、命名(3.2)、魔法数字(3.3) |
| 🟢 低 | 5 | 节点名(3.4)、双重别名(3.5)、图标重复(6.1)、each_player(6.2)、恒真检查(6.3) |

---

## 建议优先级

1. **删除死代码**（MoveAnim 注释块、BoardScene 注释块、未使用参数 `dir` 和 `rad_to_deg`）— 改动量最小、收益最高
2. **合并 `_set_label`/`_set_button`**，删除三处纯转发包装 — 减少代码行数
3. **提取 UIModel 中 item_slots / choice / popup 构建逻辑**为共用函数 — 消除 build/update 之间的重复
4. **拆分 `open_choice_modal`** 的市场/通用选择分支
5. **重构 `UIEventHandlers.install`**，消除模块级可变状态
6. **定义 `state` 初始化契约** — 长期可维护性
