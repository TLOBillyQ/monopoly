-- State.lua
-- A read-write reactive value with event subscriptions

local Trigger = require("spoke.trigger")

local State = {}
State.__index = State

function State.Create(val)
    return State.new(val)
end

function State.new(value)
    local self = setmetatable({}, State)
    self.value = value
    self.trigger = Trigger.Create()
    return self
end

function State:Now()
    return self.value
end

function State:Subscribe(action)
    if type(action) ~= "function" then
        error("Subscribe requires a function, got " .. type(action))
    end
    return self.trigger:Subscribe(action)
end

function State:Unsubscribe(action)
    if action == nil then
        return
    end
    if type(action) ~= "function" then
        error("Unsubscribe requires a function, got " .. type(action))
    end
    self.trigger:Unsubscribe(action)
end

function State:Set(value)
    -- Optimization: Skip trigger invocation if value hasn't changed
    -- This prevents unnecessary reactive updates
    -- Note: Uses Lua's == operator which performs shallow comparison
    -- For deep equality of tables, override this method or wrap with custom logic
    if self.value == value then
        return
    end
    self.value = value
    self.trigger:Invoke(value)
end

function State:Update(setter)
    if setter == nil then
        return
    end
    if type(setter) ~= "function" then
        error("Update requires a function, got " .. type(setter))
    end
    self:Set(setter(self:Now()))
end

return State
