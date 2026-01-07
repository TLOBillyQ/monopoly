-- Phase.lua
-- A specialized Effect which only runs its block when mountWhen is true

local BaseEffect = require("spoke.baseeffect").BaseEffect

local Phase = {}
Phase.__index = Phase
setmetatable(Phase, {__index = BaseEffect})

function Phase.new(name, mountWhen, block, triggers)
    if type(mountWhen) ~= "table" then
        error("Phase.new: parameter 2 (mountWhen) must be a table with Now/Subscribe, got " .. type(mountWhen))
    end
    if type(mountWhen.Now) ~= "function" then
        error("Phase.new: parameter 2 (mountWhen) must provide Now(), got " .. type(mountWhen.Now))
    end
    if mountWhen.Subscribe ~= nil and type(mountWhen.Subscribe) ~= "function" then
        error("Phase.new: parameter 2 (mountWhen) Subscribe must be a function if provided, got " .. type(mountWhen.Subscribe))
    end
    local self = BaseEffect.new(name, triggers or {})
    setmetatable(self, Phase)
    
    self.mountWhen = mountWhen
    self.block = function(s)
        if mountWhen:Now() then
            if block then
                block(s)
            end
        end
    end
    
    return self
end

function Phase:Init(builder)
    local mountBlock = BaseEffect.Init(self, builder)
    self:AddStaticTrigger(self.mountWhen)
    return mountBlock
end

return Phase
