-- SpokePool.lua
-- A pool of reusable objects for avoiding GC

local SpokeLogger = require("spoke.spokelogger")

local SpokePool = {}
SpokePool.__index = SpokePool

function SpokePool.Create(reset)
    if reset ~= nil and type(reset) ~= "function" then
        error("Reset must be a function or nil, got " .. type(reset))
    end
    local self = setmetatable({}, SpokePool)
    self.pool = {}
    self.reset = reset
    self.constructor = nil
    return self
end

function SpokePool:SetConstructor(constructor)
    if constructor ~= nil and type(constructor) ~= "function" then
        error("Constructor must be a function or nil, got " .. type(constructor))
    end
    self.constructor = constructor
end

function SpokePool:Now()
    if #self.pool > 0 then
        return table.remove(self.pool)
    end
    if self.constructor then
        return self.constructor()
    end
    return {}  -- Default to empty table
end

function SpokePool:Return(obj)
    if obj == nil then
        return  -- Silently ignore nil returns
    end
    if self.reset then
        local success, err = pcall(function()
            self.reset(obj)
        end)
        if not success then
            -- Log but don't fail - reset is best-effort
            SpokeLogger.SpokeError.Log("Pool reset function failed", err)
        end
    end
    table.insert(self.pool, obj)
end

return SpokePool
