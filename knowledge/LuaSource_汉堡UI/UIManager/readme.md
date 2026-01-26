# UIManager 使用文档

UIManager 用于把 EUI 节点封装成可读写属性的对象，并提供事件监听、异步链和帧计时器。

## 快速开始

```lua
require "UIManager.Utils"

local ui_data = require "test_data"
UIManager.Builder(ui_data)

LuaAPI.global_register_custom_event(UIManager.EVENTS.BUILDER_INIT_DONE, function()
    print("UIManager 初始化完成")
end)
```

## 构建与进度事件

- `UIManager.Builder(data, batch_size?, batch_cost?)`：构建节点树
- `UIManager.EVENTS.BUILDER_COMPLETE_ONE_BATCH`：每批构建完成
- `UIManager.EVENTS.BUILDER_INIT_DONE`：全部构建完成

```lua
UIManager.Builder(ui_data, 200, 1)

LuaAPI.global_register_custom_event(UIManager.EVENTS.BUILDER_COMPLETE_ONE_BATCH, function(_, _, data)
    print(data.processd, data.total)
end)
```

配置数据结构示例（`length` 建议填写，便于进度统计）：

```lua
return {
    ["1519736575|1354508986"] = {"正方形", "EImage"},
    length = 1,
}
```

构建会根据 `type` 查找 `UIManager[type]`（如 `EImage`、`ELabel`、`EButton`）。找不到时会退回到 `ENode`。

## 查询节点

```lua
local nodes = UIManager.query_nodes_by_name("ScoreLabel")
local node = UIManager.query_node_by_id(eui_id)

if UIManager.typeof(node, "UIManager.ELabel") then
    node.text = "OK"
end
```

## 通用节点能力（ENode）

- 只读：`id`、`name`、`parent`、`children`
- 可写：`visible`、`disabled`、`custom_data`
- 子节点查询：`get_first_node_by_name` / `query_nodes_by_name`
- 深度查询：`get_first_node_by_name_dfs` / `query_nodes_by_name_dfs`
- 自定义字段：`set_attribute(key, value)` / `get_attribtue(key)`
- 事件：`listen(event, callback)` / `trigger(role, event)`
- 异步：`wait(frames)`
- 其它：`reset_animation()` / `for_all_roles(key, value)`

## 常用控件属性

- `ELabel`：`text`、`text_color`、`font_family`、`font_size`、`label_background_color`、`label_background_opactiy`、`outline`、`outline_color`、`outline_width`、`outline_opacity`、`shadow`、`shadow_color`、`shadow_x_offset`、`shadow_y_offset`、`transition_time`
- `EImage`：`image_texture`、`image_color`、`transition_time`、`reset_size()`
- `EButton`：`text`、`text_color`、`font_size`、`disabled`
- `EProgressbar`：`value`、`max_value`、`min_value`、`transition_time`
- `EInputField`：`text`
- `EBagSlot`：`related_lifeentity`

## 事件监听

```lua
local listener = button:listen(UIManager.EVENT.CLICK, function(data)
    local role = data.role
    local target = data.target
    target.disabled = true
end)

listener:destroy()
```

## 异步链

```lua
node
    :wait(30)
    :done_then(function(n)
        n.visible = false
        return { step = 1 }
    end)
    :wait(30)
    :done_then(function(result)
        print(result.step)
    end)
```

协程中可用 `promise:await()`。

## 帧计时器

```lua
local timer = UIManager.set_frame_out(30, function(t)
    print(t.frame, t.left_count)
end, 5, false)

timer.pause()
timer.resume()
timer.destroy()
```

## 注意事项

- 构建完成后再访问 `children`、按名称查询子节点等层级关系。
- `UIManager.client_role = role` 时，属性修改只影响该玩家；置回 `nil` 会影响所有玩家。
- `label_background_opactiy` 与 `get_attribtue` 的拼写以代码为准，使用时按当前名称写。
