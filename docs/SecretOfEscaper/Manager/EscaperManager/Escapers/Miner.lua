local Escaper = require("Manager.EscaperManager.Escaper")
local EscaperConfig = require("Config.EscaperConfig")
---@class Escaper.Miner : Escaper
---@field name string
---@field code EscaperCode
local Miner = Class("Escaper.Miner", Escaper)

---@param player Player
---@param health_system HealthSystem
function Miner:init(player, health_system)
    Escaper.init(self, player, health_system)
    self.name = "卢修斯"
    self.code = "miner"
    self:init_apperance(player)
end

---@param player Player
function Miner:init_apperance(player)
    local config = EscaperConfig[self.code]
    local unit = player.get_ctrl_unit()
    unit.set_model_by_creature_key(config.id, true, true, true)
end

return Miner
