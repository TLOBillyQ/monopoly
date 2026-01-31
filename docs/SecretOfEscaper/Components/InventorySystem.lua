---@class InventorySystem
---@field items Item[]
---@field new fun(self: InventorySystem, config: {type: string, data: table}[]): InventorySystem
local InventorySystem = Class("InventorySystem")
local ItemFactory = require 'Manager.ItemManager.ItemFactory'
local ItemConfig = require("Config.ItemConfig")

---@param config {code: ItemConfig, data: table}[]
function InventorySystem:init(config)
    self.items = {}
    self.config_mapping = {}
    for _, item in pairs(config) do
        table.insert(self.items, ItemFactory.create_item(item))
    end
end

function InventorySystem:export()
    local data = {}
    for _, item in ipairs(self.items) do
        table.insert(data, item:export())
    end
    return data
end

---@param item_code ItemCode
function InventorySystem:append(item_code)
    table.insert(self.items, ItemFactory.create_item({ code = item_code }))
end

---@param viewer Player
---@param slot_type Enums.EquipmentSlotType
---@param _callback? fun(item: Item, config: ItemConfig): boolean
function InventorySystem:show(viewer, slot_type, _callback)
    _callback = _callback and _callback or function(item, config) return true end
    local unit = viewer.get_ctrl_unit()
    local equipments = unit.get_equipment_list_by_slot_type(slot_type)
    for _, equip in ipairs(equipments) do
        equip.destroy_equipment()
    end
    local show_list = {}
    for _, item in ipairs(self.items) do
        if _callback(item, ItemConfig[item.code]) then
            table.insert(show_list, item)
        end
    end
    for idx, item in ipairs(show_list) do
        item:create_to_slot(viewer, slot_type, idx)
    end
end

return InventorySystem
