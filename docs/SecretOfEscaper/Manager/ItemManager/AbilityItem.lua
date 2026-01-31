local ItemConfig = require("Config.ItemConfig")
local Item = require("Manager.ItemManager.Item")
---@class AbilityItem : Item
---@field id ItemID
---@field data {code: ItemCode}
---@field new fun(self: AbilityItem, data: {code: ItemCode}): AbilityItem
local AbilityItem = Class("AbilityItem", Item)


---@param config {code: ItemCode, data: table}
function AbilityItem:init(config)
    Item.init(self, config)
end

---@param player Player
---@param slot_type Enums.EquipmentSlotType
---@param slot_index integer
function AbilityItem:create_to_slot(player, slot_type, slot_index)
    local role = player.role
    local unit = role.get_ctrl_unit()
    local equip = Item.create_to_slot(self, player, slot_type, slot_index)
    if slot_type == Enums.EquipmentSlotType.EQUIPPED then
        LuaAPI.unit_register_trigger_event(equip, { EVENT.SPEC_EQUIPMENT_SELECT }, function(_, _, data)

        end)
    end
end

return AbilityItem
