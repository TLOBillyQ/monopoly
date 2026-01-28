require "src.adapters.eggy.macro"
require "UIManager.Utils"

local move_anim = require "src.adapters.eggy.move_anim"
local TileRenderer = require "src.adapters.eggy.tile_renderer"
local Prefab = require("Data.Prefab")

G = {
    tiles = {},
    buildings = {},
    refs = require "src.adapters.eggy.refs",
    lvs = {},
    role = { GameAPI.get_role(1),
        GameAPI.get_role(2),
        GameAPI.get_role(3),
        GameAPI.get_role(4) },
    unit = {
        GameAPI.get_role(1).get_ctrl_unit(),
        GameAPI.get_role(2).get_ctrl_unit(),
        GameAPI.get_role(3).get_ctrl_unit(),
        GameAPI.get_role(4).get_ctrl_unit(),
    }
}
UIManager.Builder(require "Data.ui_data")


return function()
    UIManager.forward_eca_event(ECA_EVENT.UI.open_loading_screen)

    local refs = G.refs
    local role = GameAPI.get_role(1)
    local unit = role.get_ctrl_unit()

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
    GameAPI.create_unit_group(Prefab.group.lv1, pos1 + offset1, q1)
    GameAPI.create_unit_group(Prefab.group.lv2, pos2 + offset2, q1)
    GameAPI.create_unit_group(Prefab.group.lv3, pos3 + offset3, q1)


    -- 渲染测试
    for i = 1, #G.tiles do
        TileRenderer.render_tile(G.tiles[i], i, nil)
    end


    local function set_item_slot_image(slot_name, image_key)
        if not (slot_name and image_key) then
            return
        end
        local nodes = UIManager.query_nodes_by_name(slot_name) or {}
        for _, node in ipairs(nodes) do
            if node and node.image_texture ~= nil then
                node.image_texture = image_key
            end
        end
    end

    for _, r in ipairs(GameAPI.get_all_valid_roles()) do
        UIManager.client_role = r
        set_item_slot_image("item_slot_1", refs["3036"])
        set_item_slot_image("item_slot_2", refs["2002"])
        set_item_slot_image("item_slot_3", refs["3036"])
        set_item_slot_image("item_slot_4", refs["空"])
        set_item_slot_image("item_slot_5", refs["2002"])

        -- unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end
    UIManager.client_role = nil


    unit.set_position(G.tiles[35].get_position() + math.Vector3(0, 1.5, 0))


    LuaAPI.call_delay_time(0.5, function()
        UIManager.forward_eca_event(ECA_EVENT.UI.close_loading_screen)
        UIManager.forward_eca_event(ECA_EVENT.UI.open_base_screen)

        --载具测试
        VehicleManager.forward_eca_event_enter(1, 4001)
    end)

    LuaAPI.call_delay_time(2.0, function()
        local final_id = 4
        move_anim.one_step(1, V3_LEFT, 35, final_id)
        print("Moving to tile:", final_id)
    end)

    LuaAPI.call_delay_time(8.0, function()
        local dist = unit.get_position() - G.tiles[35].get_position()
        print("Final Dist:", dist:length())
    end)
end
