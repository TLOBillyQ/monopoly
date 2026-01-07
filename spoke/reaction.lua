-- Reaction.lua
-- An Effect that skips its first invocation

local BaseEffect = require("spoke.baseeffect").BaseEffect

local Reaction = {}
Reaction.__index = Reaction
setmetatable(Reaction, {__index = BaseEffect})

function Reaction.new(name, block, triggers)
    local self = BaseEffect.new(name, triggers or {})
    setmetatable(self, Reaction)
    
    local isFirst = true
    self.block = function(s)
        if not isFirst then
            if block then
                block(s)
            end
        else
            isFirst = false
        end
    end
    
    return self
end

return Reaction
