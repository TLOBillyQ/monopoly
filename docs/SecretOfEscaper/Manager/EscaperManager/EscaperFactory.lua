local HealthSystem = require("Components.HealthSystem")
---@class EscaperFactory
local EscaperFactory = {}

---@param code EscaperCode
---@param health_system HealthSystem
---@return Escaper?
EscaperFactory.create = function(code, player, health_system)
    if code == "miner" then
        local Miner = require("Manager.EscaperManager.Escapers.Miner")
        return Miner:new(player, health_system)
    end
    if code == "hunter" then
        local Hunter = require("Manager.EscaperManager.Escapers.Hunter")
        return Hunter:new(player, health_system)
    end
    return nil
end

return EscaperFactory