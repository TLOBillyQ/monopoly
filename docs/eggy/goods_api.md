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

**示例**：
```lua
local goods_list = GameAPI.get_goods_list()
if goods_list then
    for _, info in ipairs(goods_list) do
        print("商品ID: " .. info.goods_id)
        print("商品名称: " .. info.name)
        print("包含道具数量: " .. #info.commodity_infos)
    end
else
    print("未获取到商品列表")
end
```

---

### Role.set_goods_panel_visible(visible)

显示或隐藏付费道具商城整体面板。

**参数**：
- `visible`：`boolean` - `true` 打开商城，`false` 隐藏商城

**别名**：`Role.set_ugc_goods_panel_visible(visible)`

**示例**：
```lua
-- 打开商城面板
Role.set_goods_panel_visible(true)

-- 隐藏商城面板
Role.set_goods_panel_visible(false)
```

---

### Role.set_goods_visible(goods_key, visible)

控制单个商品在商城中的可见性，不改变商品配置本身。

**参数**：
- `goods_key`：`UgcGoods` - 商品 ID
- `visible`：`boolean` - `true` 显示该商品，`false` 隐藏该商品

**示例**：
```lua
-- 隐藏某个商品
Role.set_goods_visible("vip_pack", false)

-- 显示某个商品
Role.set_goods_visible("starter_pack", true)
```

---

### Role.show_goods_purchase_panel(raw_goods_id, show_time)

直接弹出指定商品的购买界面。

**参数**：
- `raw_goods_id`：`UgcGoods` - 商品 ID
- `show_time`：`Fixed`（可选）- 界面停留时长，不传则采用默认值

**别名**：`Role.show_ugc_good_purchase_panel(raw_goods_id, show_time)`

**示例**：
```lua
-- 弹出指定商品购买界面（使用默认时长）
Role.show_goods_purchase_panel("dice_buff_pack")

-- 弹出指定商品购买界面（自定义显示时长）
Role.show_goods_purchase_panel("premium_pack", 10.0)
```

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

**示例**：
```lua
-- 监听玩家购买商品事件
LuaAPI.global_register_trigger_event(
    {EVENT.SPEC_ROLE_PURCHASE_GOODS, role}, 
    function(event_name, actor, data)
        local buyer = data.role
        local goods_id = data.goods_id
        
        print(buyer, "购买了商品", goods_id)
        
        -- 在这里处理购买后逻辑：
        -- - 发放额外奖励
        -- - 上报数据统计
        -- - 触发特殊效果等
    end
)
```

---

## 常用流程

### 完整使用流程

1. **拉取商品列表**：调用 `GameAPI.get_goods_list()` 获取当前可售商品
2. **过滤商品**：根据运营或关卡需求，使用 `Role.set_goods_visible()` 控制商品可见性
3. **打开商城**：调用 `Role.set_goods_panel_visible(true)` 打开商城面板
4. **定向推荐**：需要时使用 `Role.show_goods_purchase_panel()` 弹出指定商品购买界面
5. **监听购买**：通过 `EVENT.SPEC_ROLE_PURCHASE_GOODS` 监听购买成功，执行发奖或数据上报

### 完整示例

```lua
-- 1. 获取商品列表并打印
local goods_list = GameAPI.get_goods_list()
if goods_list then
    print("当前可售商品数量: " .. #goods_list)
    for _, info in ipairs(goods_list) do
        print(string.format("- %s (%s)", info.name, info.goods_id))
    end
end

-- 2. 根据游戏进度控制商品可见性
local player_level = 5
if player_level < 10 then
    -- 低等级玩家隐藏高级商品
    Role.set_goods_visible("advanced_pack", false)
else
    Role.set_goods_visible("advanced_pack", true)
end

-- 3. 打开商城面板
Role.set_goods_panel_visible(true)

-- 4. 特定时机定向推荐商品
local function recommend_goods_on_event()
    Role.show_goods_purchase_panel("special_offer", 15.0)
end

-- 5. 监听购买成功事件
LuaAPI.global_register_trigger_event(
    {EVENT.SPEC_ROLE_PURCHASE_GOODS, role}, 
    function(event_name, actor, data)
        local goods_id = data.goods_id
        local player = data.role
        
        print(player, "成功购买商品", goods_id)
        
        -- 根据商品类型发放额外奖励
        if goods_id == "vip_pack" then
            -- 发放 VIP 专属道具
            print("发放 VIP 奖励")
        elseif goods_id == "starter_pack" then
            -- 发放新手礼包内容
            print("发放新手礼包奖励")
        end
    end
)
```

---

## 注意事项

1. **接口调用前提**：以上接口需在本地玩家 `Role` 上调用，确保角色已创建并可见界面

2. **商品 ID 一致性**：`goods_id` 必须与 UGC 后台配置一致；过滤或定向弹窗都应使用同一个字符串标识

3. **商品列表为空**：当商品列表为空时不应强行打开界面，可提示"暂未上架"或降级处理
   ```lua
   local goods_list = GameAPI.get_goods_list()
   if not goods_list or #goods_list == 0 then
       Role.show_tips("商城暂未上架商品", 3.0)
       return
   end
   Role.set_goods_panel_visible(true)
   ```

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

## 相关文档

- [EggyAPI 完整文档](./EggyAPI.md)
- [EggyAPI.lua 类型定义](./EggyAPI.lua)
