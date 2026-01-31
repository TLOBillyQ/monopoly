---@class HealthComponent
---@field on_damage fun(self: HealthComponent, value: integer)
---@field on_dead fun(self: HealthComponent)

---@class HealthSystem
---@field max_value integer
---@field value integer
---@field is_dead boolean
---@field components HealthComponent[]
---@field new fun(self: HealthSystem, max_value: integer): HealthSystem
local HealthSystem = Class("HealthSystem")

---@param max_value integer
function HealthSystem:init(max_value)
    self._max_value = max_value
    self._value = max_value
    self.components = {}
end

function HealthSystem:__get_max_value()
    return self._max_value
end

---@param value integer
function HealthSystem:__set_max_value(value)
    self._max_value = value
end

function HealthSystem:__get_value()
    return self._value
end

---@param value integer
function HealthSystem:__set_value(value)
    self._value = value
end

---@param value integer
function HealthSystem:damage(value)
    self._value = self._value - value
    for _, comp in ipairs(self.components) do
        comp:on_damage(value)
    end
    if self._value <= 0 then
        self:dead()
    end
end

function HealthSystem:dead()
    self._is_dead = true
    for _, comp in ipairs(self.components) do
        comp:on_dead()
    end
end

function HealthSystem:__get_is_dead()
    return self._is_dead
end

function HealthSystem:__set_is_dead()
    error("is_dead is read-only")
end

return HealthSystem