local ItemConfig = require("Config.ItemConfig")

---@alias ItemID integer
local id = 1
---@class Item : Class
---@field id ItemID
---@field data {code: ItemCode}
---@field new fun(self: Item, data: {code: ItemCode}): Item
local Item = Class("Item")

function Item.__custom_index(tbl, key)
    local role = rawget(tbl, "role")
    if role and (type(role[key]) == "function") then
        return function(...)
            return role[key](...)
        end
    end
end

---@param config {code: ItemCode, data: table}
function Item:init(config)
    self.code = config.code
    self.data = config.data
    self.id = id
    id = id + 1
end

---@param player Player
---@param slot_type Enums.EquipmentSlotType
---@param slot_index integer
---@return Equipment
function Item:create_to_slot(player, slot_type, slot_index)
    local character = player.get_ctrl_unit()
    local item_config = ItemConfig[self.code]
    local equip = character.create_equipment_to_slot(item_config.id, slot_type)
    equip.set_name(item_config.name)
    equip.set_desc(item_config.desc)
    equip.move_to_slot(slot_type, slot_index)
    equip.set_droppable(false)
    return equip
end

---@return {name: string, description: string}
function Item:get_info()
    local item_config = ItemConfig[self.code]
    return {
        name = item_config.name,
        description = item_config.desc
    }
end

function Item:export()
    return {
        code = self.code,
        data = self.data
    }
end

return Item
