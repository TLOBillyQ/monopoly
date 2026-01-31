local Escaper = require("Manager.EscaperManager.Escaper")
local EscaperConfig = require("Config.EscaperConfig")
---@class Escaper.Hunter : Escaper
---@field name string
---@field code EscaperCode
local Hunter = Class("Escaper.Hunter", Escaper)

---@param player Player
---@param health_system HealthSystem
function Hunter:init(player, health_system)
    Escaper.init(self, player, health_system)
    self.name = "亨特"
    self.code = "hunter"
    self:init_apperance(player)
end

---@param player Player
function Hunter:init_apperance(player)
    local config = EscaperConfig[self.code]
    local unit = player.get_ctrl_unit()
    unit.set_model_by_creature_key(config.id, true, true, true)
end

return Hunter
