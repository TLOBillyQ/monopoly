-- SpokeHandle.lua
-- A zero-gc handle for disposing a managed resource

local SpokeLogger = require("spoke.spokelogger")

local SpokeHandle = {}
SpokeHandle.__index = SpokeHandle

function SpokeHandle.Of(id, onDispose)
    if onDispose ~= nil and type(onDispose) ~= "function" then
        error("onDispose must be a function or nil, got " .. type(onDispose))
    end
    local self = setmetatable({}, SpokeHandle)
    self.id = id
    self.onDispose = onDispose
    return self
end

function SpokeHandle:Dispose()
    if self.onDispose then
        local success, err = pcall(function()
            self.onDispose(self.id)
        end)
        if not success then
            SpokeLogger.SpokeError.Log("Handle disposal failed", err)
        end
    end
    -- Clear the onDispose handler to prevent double disposal
    self.onDispose = nil
end

function SpokeHandle:Equals(other)
    if other == nil or type(other) ~= "table" then
        return false
    end
    -- Compare id only - after disposal, handles with same id are still considered equal
    -- This allows tracking of handle identity even after disposal
    if not other.id then
        return false
    end
    return self.id == other.id
end

return SpokeHandle
