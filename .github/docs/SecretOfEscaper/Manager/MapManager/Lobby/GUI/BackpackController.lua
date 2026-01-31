local BackpackView = require 'Manager.MapManager.Lobby.GUI.BackpackView'
local MainView = require 'Manager.MapManager.Lobby.GUI.MainView'
local ItemConfig = require("Config.ItemConfig")
local config = require("Library.Behavior.config")

local show_button = BackpackView.show_button
show_button:listen("click", function(data)
    MainView:show("BackpackCanvas")
    BackpackView:show("全部")
end)

local hide_button = BackpackView.hide_button
hide_button:listen("click", function(data)
    MainView:show("LobbyCanvas")
    BackpackView:hide()
end)
BackpackView:hide()

local equip_button = BackpackView.equip_button
local equip_button_text = BackpackView.equip_button:get_first_node_by_name("Text") --[[@as UIManager.ELabel]]
local name = BackpackView.info_frame_name
local description = BackpackView.info_frame_description
for _, role in ipairs(ALLROLES) do
    local player = PlayerManager.find_player_by_role(role)
    local unit = role.get_ctrl_unit()
    for i = 1, 99 do
        LuaAPI.unit_register_trigger_event(
            unit,
            {
                EVENT.SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT,
                Enums.EquipmentSlotType.BACKPACK,
                i
            },
            function(_, _, data)
                local temp = UIManager.client_role
                UIManager.client_role = role
                local item = player.inventory.items[i]
                name.text = ""
                description.text = ""
                if item then
                    local info = item:get_info()
                    local item_config = ItemConfig[item.code]
                    if item_config.tag == "特殊道具" then
                        equip_button.visible = true
                        equip_button_text.text = "装备道具"
                        equip_button.custom_data.is_equipment = nil
                        equip_button.custom_data.select_item_index = i
                    else
                        equip_button.visible = false
                        equip_button.custom_data.select_item_index = nil
                    end
                    name.text = info.name
                    description.text = info.description
                end
                UIManager.client_role = temp
            end
        )
    end

    for i = 1, 3 do
        LuaAPI.unit_register_trigger_event(
            unit,
            {
                EVENT.SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT,
                Enums.EquipmentSlotType.EQUIPPED,
                i
            },
            function()
                local temp = UIManager.client_role
                UIManager.client_role = role
                local item = player.equipment.items[i]
                name.text = ""
                description.text = ""
                if item then
                    local info = item:get_info()
                    local item_config = ItemConfig[item.code]
                    if item_config.tag == "特殊道具" then
                        equip_button.visible = true
                        equip_button_text.text = "卸下道具"
                        equip_button.custom_data.is_equipment = true
                        equip_button.custom_data.select_item_index = i
                    else
                        equip_button.visible = false
                        equip_button.custom_data.is_equipment = nil
                        equip_button.custom_data.select_item_index = nil
                    end
                    name.text = info.name
                    description.text = info.description
                end
                UIManager.client_role = temp
            end
        )
    end
end

local canvas = BackpackView.canvas
equip_button:listen("click", function(data)
    local role = data.role
    local player = PlayerManager.find_player_by_role(role)
    local inventory = player.inventory
    local equipment = player.equipment
    local custom_data = equip_button.custom_data
    local index = custom_data.select_item_index
    if custom_data.is_equipment then
        local item = table.remove(equipment.items, index)
        table.insert(inventory.items, item)
        inventory:show(player, Enums.EquipmentSlotType.BACKPACK, function(_, item_config)
            return canvas.custom_data.current_tab and canvas.custom_data.current_tab.name == item_config.tag or true
        end)
        equipment:show(player, Enums.EquipmentSlotType.EQUIPPED)
        return
    end
    if #equipment.items >= 3 then
        role.show_tips("装备栏已满", 2.0)
        return
    end
    if index then
        local item = table.remove(inventory.items, index)
        table.insert(equipment.items, item)
        inventory:show(player, Enums.EquipmentSlotType.BACKPACK, function(_, item_config)
            return canvas.custom_data.current_tab and canvas.custom_data.current_tab.name == item_config.tag or true
        end)
        equipment:show(player, Enums.EquipmentSlotType.EQUIPPED)
    end
end)

---@type Lobby.Backpackview.Tag
local Tag = {
    All = "全部",
    Recycle = "回收物",
    Equip = "特殊道具"
}

local tag_bar = BackpackView.tag_bar
tag_bar:forEach(function(e)
    e:listen("click", function(data)
        BackpackView:show(Tag[e.name])
    end)
end)
