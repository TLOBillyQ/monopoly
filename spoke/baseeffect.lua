-- BaseEffect.lua
-- Abstract base class for Effect, Phase and Reaction

local Computation = require("spoke.computation")

local BaseEffect = {}
BaseEffect.__index = BaseEffect
setmetatable(BaseEffect, {__index = Computation})

-- EffectBuilder
local EffectBuilder = {}
EffectBuilder.__index = EffectBuilder

function EffectBuilder.new(addDynamicTrigger, epochBuilder)
    local self = setmetatable({}, EffectBuilder)
    self.addDynamicTrigger = addDynamicTrigger
    self.s = epochBuilder
    return self
end

function EffectBuilder:D(signal)
    self.addDynamicTrigger(signal)
    return signal:Now()
end

function EffectBuilder:Use(trigger)
    return self.s:Use(trigger)
end

function EffectBuilder:Call(epoch)
    return self.s:Call(epoch)
end

function EffectBuilder:Export(obj)
    return self.s:Export(obj)
end

function EffectBuilder:TryImport(typeOrPredicate)
    return self.s:TryImport(typeOrPredicate)
end

function EffectBuilder:Import(typeOrPredicate)
    return self.s:Import(typeOrPredicate)
end

function EffectBuilder:OnCleanup(fn)
    self.s:OnCleanup(fn)
end

function EffectBuilder:Log(msg)
    self.s:Log(msg)
end

function EffectBuilder:Subscribe(trigger, action)
    if trigger then
        self:Use(trigger:Subscribe(action))
    end
end

function EffectBuilder:Memo(name, selector, triggers)
    if type(name) == "function" then
        -- name is actually the selector
        triggers = selector
        selector = name
        name = "Memo"
    end
    local Memo = require("spoke.memo")
    return self:Call(Memo.new(name, selector, triggers))
end

function EffectBuilder:Effect(name, block, triggers)
    if type(name) == "function" then
        triggers = block
        block = name
        name = "Effect"
    end
    local Effect = require("spoke.effect")
    return self:Call(Effect.new(name, block, triggers))
end

function EffectBuilder:Reaction(name, block, triggers)
    if type(name) == "function" then
        triggers = block
        block = name
        name = "Reaction"
    end
    local Reaction = require("spoke.reaction")
    return self:Call(Reaction.new(name, block, triggers))
end

function EffectBuilder:Phase(name, mountWhen, block, triggers)
    if type(name) ~= "string" then
        triggers = block
        block = mountWhen
        mountWhen = name
        name = "Phase"
    end
    local Phase = require("spoke.phase")
    return self:Call(Phase.new(name, mountWhen, block, triggers))
end

function EffectBuilder:Dock(name)
    local Dock = require("spoke.dock")
    return self:Call(Dock.new(name))
end

-- Main BaseEffect class
function BaseEffect.new(name, triggers)
    local self = Computation.new(name, triggers or {})
    setmetatable(self, BaseEffect)
    
    self.block = nil
    self._addDynamicTrigger = function(trigger)
        self:AddDynamicTrigger(trigger)
    end
    
    return self
end

function BaseEffect:OnRun(epochBuilder)
    if self.block then
        local builder = EffectBuilder.new(self._addDynamicTrigger, epochBuilder)
        self.block(builder)
    end
end

return {
    BaseEffect = BaseEffect,
    EffectBuilder = EffectBuilder
}
