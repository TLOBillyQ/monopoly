V3_ONE = math.Vector3(1, 1, 1)
Q_ZERO = math.Quaternion(0, 0, 0)

Q_LEFT = math.Quaternion(0, -180, 0)
Q_RIGHT = Q_ZERO
Q_UP = math.Quaternion(0, -90, 0)
Q_DOWN = math.Quaternion(0, 90, 0)

-- local pos1 = math.Vector3(81.99, 2.05, 80.45)
-- local pos2 = math.Vector3(82.04, 5.13, 70.28)
-- local pos3 = math.Vector3(82.11, 2.01, 58.41)

G = {
    tiles = {},
    buildings = {},
    refs = require "refs",
    lvs = {}
}

return function()
    LuaAPI.global_send_custom_event("显示加载屏", {})

    local refs = G.refs

    -- 场景索引
    local tile_names = {}
    local building_names = {}
    for i = 1, 45 do
        tile_names[i] = "t" .. tostring(i)
        building_names[i] = "b" .. tostring(i)
    end
    G.tiles = LuaAPI.query_units(tile_names)
    G.buildings = LuaAPI.query_units(building_names)

    -- local u1 = LuaAPI.query_unit("一级建筑")
    -- local u2 = LuaAPI.query_unit("二级建筑")
    -- local u3 = LuaAPI.query_unit("三级建筑")
    -- G.lvs[1] = u1.get_scale()
    -- G.lvs[2] = u2.get_scale()
    -- G.lvs[3] = u3.get_scale()
    -- local pos1 = u1.get_position()
    -- local pos2 = u2.get_position()
    -- local pos3 = u3.get_position()
    -- local q1 = u1.get_orientation()
    -- u1.set_model_visible(false)
    -- u2.set_model_visible(false)
    -- u3.set_model_visible(false)

    local ground = LuaAPI.query_unit("ground")
    ground.set_model_visible(false)

    --GameAPI.create_obstacle(refs["lv1"], pos1, q1, G.lvs[1])
    --GameAPI.create_obstacle(refs["lv2"], pos2, q1, G.lvs[2])
    --GameAPI.create_obstacle(refs["lv3"], pos3, q1, G.lvs[3])

    local offset1 = math.Vector3(0, 1.5, 0)
    local offset2 = math.Vector3(0, 1.5, 0)
    local offset3 = math.Vector3(1, 1.5, 0)
    local q1 = Q_ZERO
    local pos1 = G.buildings[1].get_position()
    local pos2 = G.buildings[2].get_position()
    local pos3 = G.buildings[3].get_position()
    GameAPI.create_unit_group(refs["lv1"], pos1 + offset1, q1)
    GameAPI.create_unit_group(refs["lv2"], pos2 + offset2, q1)
    GameAPI.create_unit_group(refs["lv3"], pos3 + offset3, q1)


    -- 渲染测试
    for i = 1, 34 do
        local u_color = G.tiles[i].get_child_by_name("color")
        local u_name = G.tiles[i].get_child_by_name("name")
        local u_price = G.tiles[i].get_child_by_name("price")
        u_color.set_paint_area_color(1, 0xFF0000)
        u_name.set_billboard_text("test")
        u_price.set_billboard_text("￥000")
    end




    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位1"], refs["3036"], false)
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位2"], refs["2002"], false)
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位3"], refs["3036"], false)
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位4"], refs["2002"], false)
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位5"], refs["2002"], false)

        local unit = role.get_ctrl_unit()
        unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end


    LuaAPI.call_delay_time(1.0, function()
        LuaAPI.global_send_custom_event("隐藏加载屏", {})

        LuaAPI.global_send_custom_event("显示基础屏", {})
        local role = GameAPI.get_role(1)

        LuaAPI.global_send_custom_event("玩家1刷小摩托", {})
        -- LuaAPI.call_delay_time(0.5, function()
        --     LuaAPI.global_send_custom_event("玩家1上车", {})
        -- end)
    end)
end
