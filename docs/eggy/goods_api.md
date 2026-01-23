# 付费道具（Goods）API 用法文档

本文档介绍 Eggy 平台的付费道具（商品）相关接口，涵盖获取商品列表、控制商城界面、弹出指定商品购买页以及监听购买成功事件。

---

## 核心类型

### UgcGoods
- **类型**：`string`
- **说明**：商品 ID，与 UGC 后台配置一致

### GoodsInfo
商品信息结构，包含以下字段：
- `goods_id`：`UgcGoods` - 商品 ID
- `name`：`string` - 商品名称
- `commodity_infos`：`CommodityInfo[]` - 商品项列表

### CommodityInfo
- **类型**：`{[1]: UgcCommodity, [2]: integer}`
- **说明**：包含商品项目 ID 和道具数量的二元表

---

## API 说明

### GameAPI.get_goods_list()

获取当前可售商品列表。

**返回值**：`GoodsInfo[] | nil`
- 成功：返回商品信息列表
- 失败：返回 `nil`（无配置或拉取失败）

---

### Role.set_goods_panel_visible(visible)

显示或隐藏付费道具商城整体面板。

**参数**：
- `visible`：`boolean` - `true` 打开商城，`false` 隐藏商城

**别名**：`Role.set_ugc_goods_panel_visible(visible)`

---

### Role.set_goods_visible(goods_key, visible)

控制单个商品在商城中的可见性，不改变商品配置本身。

**参数**：
- `goods_key`：`UgcGoods` - 商品 ID
- `visible`：`boolean` - `true` 显示该商品，`false` 隐藏该商品

---

### Role.show_goods_purchase_panel(raw_goods_id, show_time)

直接弹出指定商品的购买界面。

**参数**：
- `raw_goods_id`：`UgcGoods` - 商品 ID
- `show_time`：`Fixed`（可选）- 界面停留时长，不传则采用默认值

**别名**：`Role.show_ugc_good_purchase_panel(raw_goods_id, show_time)`

---

### EVENT.SPEC_ROLE_PURCHASE_GOODS

玩家成功购买任意付费商品后触发的事件。

**事件类型**：全局触发器事件

**注册参数**：
- `_role`：`RoleID` - 目标玩家

**回调参数**：
- `event_name`：`string` - 事件名称
- `actor`：事件触发者
- `data`：包含以下字段的表
  - `role`：`Role` - 购买的玩家对象
  - `goods_id`：`UgcGoods` - 购买的商品 ID

---

## 注意事项

1. **接口调用前提**：以上接口需在本地玩家 `Role` 上调用，确保角色已创建并可见界面

2. **商品 ID 一致性**：`goods_id` 必须与 UGC 后台配置一致；过滤或定向弹窗都应使用同一个字符串标识

3. **商品列表为空**：当商品列表为空时不应强行打开界面，可提示"暂未上架"或降级处理

4. **可见性控制**：`set_goods_visible()` 只影响展示，不会修改商品库存或售价；库存与支付流程由平台托管

5. **购买事件触发条件**：
   - **会触发**：玩家完成支付并成功购买商品
   - **不会触发**：
     - 玩家取消购买
     - 支付失败
     - 余额不足
   - 如需兜底处理，请结合 UI 回调自定义处理

6. **多玩家场景**：在多人游戏中，每个玩家看到的商城界面是独立的，需要为每个玩家单独注册购买事件监听

---

## 组合示例

目标：拉取商品列表，筛选展示并打开商城，同时监听购买成功事件。

```lua
local goods_list = GameAPI.get_goods_list()
if goods_list and #goods_list > 0 then
    Role.set_goods_visible(goods_list[1].goods_id, true)
    Role.set_goods_panel_visible(true)
end

LuaAPI.global_register_trigger_event(
    {EVENT.SPEC_ROLE_PURCHASE_GOODS, role},
    function(event_name, actor, data)
        local goods_id = data.goods_id
        -- 在这里做奖励发放或统计
        GlobalAPI.show_tips("购买成功: " .. goods_id, 3.0)
    end
)
```

---

## 相关文档

- [EggyAPI 完整文档](./EggyAPI.md)
- [EggyAPI.lua 类型定义](./EggyAPI.lua)
