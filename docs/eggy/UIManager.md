# UIManager

蛋仔派对 UI 节点管理库。将原始 EUI 节点封装为类型化对象，提供属性绑定、事件委托和异步链式调用。

---

## 设计

### 核心思想

**节点封装**：原始 `ENode` ID 被包装成带类型的对象（ELabel、EImage 等），通过 getter/setter 自动同步游戏引擎状态。

**客户端隔离**：通过 `UIManager.client_role` 控制属性修改的作用域——设置后仅影响该玩家，置空则影响所有玩家。

**事件委托**：统一的事件监听机制，支持按节点绑定回调，监听器可随时销毁。

### 架构

```
UIManager
├── Builder          # 从配置数据构建节点树
├── 节点类型
│   ├── ENode        # 基类：可见性、禁用、子节点查询、事件
│   ├── ELabel       # 文本、字体、描边、阴影
│   ├── EImage       # 图片纹理、颜色
│   ├── EButton      # 按钮文本、状态
│   ├── EProgressbar # 进度条
│   └── EInputField  # 输入框
├── Promise          # 异步链式调用
├── Listener         # 事件监听器
└── Array            # 工具数组
```

### 属性响应式

节点属性采用响应式设计。赋值时自动调用引擎 API 同步状态：

```lua
label.text = "Hello"  -- 内部调用 role.set_label_text(id, "Hello")
label.visible = false -- 内部调用 role.set_node_visible(id, false)
```

### 客户端隔离机制

```lua
-- 全局模式：影响所有玩家
UIManager.client_role = nil
node.visible = false

-- 单玩家模式：仅影响指定玩家
UIManager.client_role = some_role
node.visible = false

-- for_all_roles：在单玩家模式下强制全局生效
node:for_all_roles("visible", true)
```

---

## 用法

### 初始化

```lua
require "UIManager.Utils"

local ui_data = require "your_ui_data"
UIManager.Builder(ui_data)
```

大量节点时分批构建，避免卡顿：

```lua
UIManager.Builder(ui_data, 200, 1)  -- 每批200个，间隔1帧

LuaAPI.global_register_custom_event(UIManager.EVENTS.BUILDER_INIT_DONE, function()
    -- 构建完成，开始业务逻辑
end)
```

### 查询节点

```lua
-- 按名称（返回数组）
local labels = UIManager.query_nodes_by_name("ScoreLabel")
local label = labels[1]

-- 按 ID
local node = UIManager.query_node_by_id(eui_id)

-- 类型检查
if UIManager.typeof(node, "UIManager.ELabel") then
    node.text = "已确认是 Label"
end
```

### 子节点查询

```lua
-- 直接子节点
local child = parent:get_first_node_by_name("Icon")
local children = parent:query_nodes_by_name("Item")

-- 深度优先
local deep = parent:get_first_node_by_name_dfs("NestedNode")
```

### 修改属性

```lua
-- 文本
label.text = "得分: 100"
label.text_color = 0xFF0000
label.font_size = 24

-- 图片
image.image_texture = texture_key
image.image_color = 0x00FF00

-- 进度条
bar.max_value = 100
bar.transition_time = 0.3
bar.value = 75

-- 通用
node.visible = false
node.disabled = true
```

### 事件监听

```lua
local listener = button:listen("CLICK", function(data)
    local role = data.role      -- 触发者
    local target = data.target  -- 节点
    target.disabled = true
end)

-- 销毁
listener:destroy()
```

手动触发事件：

```lua
node:trigger(role, "CLICK")
```

### 异步链式调用

```lua
node
    :wait(30)
    :done_then(function(n)
        n.visible = false
        return { step = 1 }
    end)
    :wait(30)
    :done_then(function(result)
        print(result.step)  -- 1
    end)
```

协程中使用：

```lua
coroutine.wrap(function()
    local result = promise:await()
end)()
```

### 计时器

```lua
local timer = UIManager.set_frame_out(30, function(t)
    print(t.frame, t.left_count)
end, 5, false)  -- 间隔30帧，5次，不立即执行

timer.pause()
timer.resume()
timer.destroy()
```

---

## API 速查

### UIManager

| 方法 | 说明 |
|------|------|
| `Builder(data, batch?, interval?)` | 构建节点树 |
| `query_nodes_by_name(name)` | 按名称查询（数组） |
| `query_node_by_id(id)` | 按 ID 查询 |
| `typeof(node, type)` | 类型检查 |
| `set_frame_out(interval, cb, count?, immediate?)` | 帧计时器 |

### ENode

| 属性/方法 | 说明 |
|------|------|
| `id`, `name`, `parent`, `children` | 只读属性 |
| `visible`, `disabled` | 可写属性 |
| `get_first_node_by_name(name)` | 查找子节点 |
| `get_first_node_by_name_dfs(name)` | 深度优先查找 |
| `listen(event, callback)` | 监听事件 |
| `trigger(role, event)` | 触发事件 |
| `wait(frames)` | 返回 Promise |
| `for_all_roles(key, value)` | 全局设置属性 |

### ELabel

`text`, `text_color`, `font_family`, `font_size`, `label_background_color`, `label_background_opacity`, `outline`, `outline_color`, `outline_width`, `shadow`, `shadow_color`, `shadow_x_offset`, `shadow_y_offset`, `transition_time`

### EImage

`image_color`, `image_texture`, `transition_time`, `reset_size()`

### EButton

`text`, `text_color`, `font_size`, `normal_image`, `pressed_image`

### EProgressbar

`value`, `max_value`, `min_value`, `transition_time`

### EInputField

`text`, `text_color`

### Promise

| 方法 | 说明 |
|------|------|
| `wait(frames)` | 等待后继续 |
| `done_then(callback)` | 链式回调 |
| `await()` | 协程等待 |

### 事件

| 事件 | 说明 |
|------|------|
| `BUILDER_COMPLETE_ONE_BATCH` | 每批完成，参数 `{processd, total}` |
| `BUILDER_INIT_DONE` | 全部完成 |
