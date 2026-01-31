local ItemConfig = require("Config.ItemConfig")
local AbilityConfig = require("Config.AbilityConfig")
---@class AbilityManager
---@field pool table<UnitID, {unit: Ability, index: AbilitySlot}> 技能池
---@field ability_index integer
---@field new fun(self: AbilityManager, role: Role): AbilityManager
local AbilityManager = Class("AbilityManager")

---@param role Role
function AbilityManager:init(role)
    self.pool = {}
    self.role = role
    self.ability_index = 50
end

---@param ability_config AbilityConfig
function AbilityManager:append(ability_config)
    local unit = self.role.get_ctrl_unit()
    self.ability_index = self.ability_index + 1
    local ability = unit.add_ability_to_slot(self.ability_index, ability_config.id)
    local ability_id = ability.get_id()
    self.pool[ability_id] = { unit = ability, index = self.ability_index }
end

return AbilityManager
