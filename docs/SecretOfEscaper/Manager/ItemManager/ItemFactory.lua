local ItemConfig = require("Config.ItemConfig")
local ItemFactory = {}

---@generic T : Item
---@param data {code: ItemCode, data: table}
---@return T
function ItemFactory.create_item(data)
    local item_config = ItemConfig[data.code]
    local item_type = item_config and item_config.type or "Item" --[[@as `T`]]
    local Item = require (("Manager.ItemManager.%s"):format(item_type)) --[[@as T]]
    local item = Item:new(data)
    return item
end

return ItemFactory