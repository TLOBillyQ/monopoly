local Player = require("Manager.PlayerManager.Player")
---@generic T : Escaper
---@class Escaper
---@field health_system HealthSystem
---@field new fun(self: T, player: Player, health_system: HealthSystem): T
local Escaper = Class("Escaper")

---@param player Player
---@param health_system HealthSystem
function Escaper:init(player, health_system)
    self.player = player
    self.health_system = health_system
    table.insert(health_system.components, self)
end

---@param player Player
function Escaper:init_apperance(player) end

function Escaper:on_damage()
    self:update_view()
end

function Escaper:on_dead()
    self.player.get_ctrl_unit().disable_gravity()
    self.player.get_ctrl_unit().set_position(math.Vector3(0, -20, 0))
    self.player.show_tips("你已阵亡，观战中", 2.0)
    self.player.enter_watch_mode(false, false)
    LootEscaper.some_one_dead()
end

function Escaper:update_view() end

function Escaper:destroy()
    local index = nil
    for i, component in ipairs(self.health_system.components) do
        if component == self then
            index = i
            break
        end
    end
    if index then
        table.remove(self.health_system.components, index)
    end
    self.health_system = nil
end

return Escaper
