-- Effect.lua
-- An Effect runs an EffectBlock, and re-runs whenever any of its triggers fire

local BaseEffect = require("spoke.baseeffect").BaseEffect
local State = require("spoke.state")
local LambdaEpoch = require("spoke.lambdaepoch")

local Effect = {}
Effect.__index = Effect
setmetatable(Effect, {__index = BaseEffect})

function Effect.new(name, block, triggers)
    if type(block) ~= "function" then
        error("Effect requires a block function, got " .. type(block))
    end
    local self = BaseEffect.new(name, triggers or {})
    setmetatable(self, Effect)
    
    self.block = block
    
    return self
end

-- Effect with return value (Effect<T>)
local EffectT = {}
EffectT.__index = EffectT
setmetatable(EffectT, {__index = BaseEffect})

function EffectT.new(name, block, triggers)
    if block ~= nil and type(block) ~= "function" then
        error("EffectT.new: parameter 2 (block) must be function or nil, got " .. type(block))
    end
    local self = BaseEffect.new(name, triggers or {})
    setmetatable(self, EffectT)
    
    self.state = State.Create()
    self.block = function(s)
        if not block then
            return
        end
        
        local result = block(s)
        
        -- If result is a signal, subscribe to it
        if result and type(result) == "table" and result.Now and result.Subscribe then
            s:Subscribe(result, function(x)
                self.state:Set(x)
            end)
        end
        
        -- Deferred initializer to set initial value
        s:Call(LambdaEpoch.new("Deferred Initializer", function(s)
            return function(s)
                if result and result.Now then
                    self.state:Set(result:Now())
                end
            end
        end))
    end
    
    return self
end

function EffectT:Now()
    return self.state:Now()
end

function EffectT:Subscribe(action)
    return self.state:Subscribe(action)
end

function EffectT:Unsubscribe(action)
    self.state:Unsubscribe(action)
end

return {
    Effect = Effect,
    EffectT = EffectT
}
