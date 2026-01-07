-- Memo.lua
-- A computed reactive value which updates when any of its triggers fire

local Computation = require("spoke.computation")
local State = require("spoke.state")

local Memo = {}
Memo.__index = Memo
setmetatable(Memo, {__index = Computation})

-- MemoBuilder
local MemoBuilder = {}
MemoBuilder.__index = MemoBuilder

function MemoBuilder.new(addDynamicTrigger, epochBuilder)
    local self = setmetatable({}, MemoBuilder)
    self.addDynamicTrigger = addDynamicTrigger
    self.s = epochBuilder
    return self
end

function MemoBuilder:D(signal)
    self.addDynamicTrigger(signal)
    return signal:Now()
end

function MemoBuilder:OnCleanup(fn)
    self.s:OnCleanup(fn)
end

-- Main Memo class
function Memo.new(name, selector, triggers)
    if type(selector) ~= "function" then
        error("Memo requires a selector function, got " .. type(selector))
    end
    local self = Computation.new(name, triggers or {})
    setmetatable(self, Memo)
    
    self.state = State.Create()
    self.selector = selector
    self._addDynamicTrigger = function(trigger)
        self:AddDynamicTrigger(trigger)
    end
    
    return self
end

function Memo:Now()
    return self.state:Now()
end

function Memo:Subscribe(action)
    return self.state:Subscribe(action)
end

function Memo:Unsubscribe(action)
    self.state:Unsubscribe(action)
end

function Memo:OnRun(epochBuilder)
    local builder = MemoBuilder.new(self._addDynamicTrigger, epochBuilder)
    if self.selector then
        self.state:Set(self.selector(builder))
    end
end

return Memo
