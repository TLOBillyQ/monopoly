-- SpokeLogger.lua
-- Logging interfaces and default logger

local SpokeLogger = {}

-- Default console logger
local ConsoleSpokeLogger = {}
ConsoleSpokeLogger.__index = ConsoleSpokeLogger

function ConsoleSpokeLogger.new()
    local self = setmetatable({}, ConsoleSpokeLogger)
    return self
end

function ConsoleSpokeLogger:Log(msg)
    print(msg)
end

function ConsoleSpokeLogger:Error(msg)
    print("[ERROR] " .. msg)
end

-- Static SpokeError module
local SpokeError = {
    Log = function(msg, ex)
        local exMsg = ex and tostring(ex) or ""
        print(string.format("[Spoke] %s\n%s", msg, exMsg))
    end,
    DefaultLogger = ConsoleSpokeLogger.new()
}

return {
    ConsoleSpokeLogger = ConsoleSpokeLogger,
    SpokeError = SpokeError
}
