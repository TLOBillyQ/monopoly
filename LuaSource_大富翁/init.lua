require 'macro'
require "UIManager.Utils"

local move = require "move"

G = {
    tiles = {},
    buildings = {},
    refs = require "refs",
    lvs = {}
}

UIManager.Builder(require "ui_data")


return function()
    UIManager.ForwardUIEvent("显示加载屏")

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

    local ground = LuaAPI.query_unit("ground")
    ground.set_model_visible(false)

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
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位4"], refs["空"], false)
        role.set_image_texture_by_key_with_auto_resize(refs["道具槽位5"], refs["2002"], false)

        local unit = role.get_ctrl_unit()
        -- unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end


    LuaAPI.call_delay_time(3.0, function()
        UIManager.ForwardUIEvent("隐藏加载屏")
        UIManager.ForwardUIEvent("显示基础屏")

        local role = GameAPI.get_role(1)

        --载具测试
        -- LuaAPI.global_send_custom_event("玩家上载具", {})
    end)


    local handle = LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 2 }, function()
        move.one_step(DIR_LEFT, 1)
    end)

    LuaAPI.call_delay_time(16.0, function()
        LuaAPI.global_unregister_trigger_event(handle)
    end)

    -- LuaAPI.call_delay_time(2.0, function()
    --     move.start_to_finish(1, 35, 2)
    -- end)
end
