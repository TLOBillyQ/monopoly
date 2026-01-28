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
        for i = 1, 5 do
            set_item_slot_image("item_slot_" .. tostring(i), refs["空"])
        end

        unit.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
    end
    UIManager.client_role = nil
end
