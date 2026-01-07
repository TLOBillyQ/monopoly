-- Computation.lua
-- Abstract base class for all reactive objects

local Epoch = require("spoke.epoch")

local Computation = {}
Computation.__index = Computation
setmetatable(Computation, {__index = Epoch})

-- DependencyTracker for managing dynamic trigger subscriptions
local DependencyTracker = {}
DependencyTracker.__index = DependencyTracker

local function validateTrigger(trigger, source)
    local triggerType = type(trigger)
    if triggerType ~= "table" and triggerType ~= "userdata" then
        error("Invalid trigger type (" .. triggerType .. ") at " .. source)
    end
    local subscribe = trigger.Subscribe
    if type(subscribe) ~= "function" then
        error("Invalid trigger type (" .. triggerType .. ") missing Subscribe at " .. source)
    end
end

function DependencyTracker.new(schedule)
    if type(schedule) ~= "function" then
        error("DependencyTracker requires a schedule function, got " .. type(schedule))
    end
    local self = setmetatable({}, DependencyTracker)
    self.schedule = schedule
    self.seen = {}
    self.staticHandles = {}
    self.dynamicHandles = {}
    self.depIndex = 0
    return self
end

function DependencyTracker:AddStatic(trigger)
    validateTrigger(trigger, "DependencyTracker:AddStatic")
    if self.seen[trigger] then
        return
    end
    self.seen[trigger] = true
    local handle = trigger:Subscribe(self:ScheduleFromIndex(-1))
    table.insert(self.staticHandles, {t = trigger, h = handle})
end

function DependencyTracker:BeginDynamic()
    self.depIndex = 0
    self.seen = {}
    for _, dep in ipairs(self.staticHandles) do
        self.seen[dep.t] = true
    end
end

function DependencyTracker:AddDynamic(trigger)
    validateTrigger(trigger, "DependencyTracker:AddDynamic")
    if self.seen[trigger] then
        return
    end
    self.seen[trigger] = true
    
    if self.depIndex >= #self.dynamicHandles then
        local handle = trigger:Subscribe(self:ScheduleFromIndex(self.depIndex))
        table.insert(self.dynamicHandles, {t = trigger, h = handle})
    elseif self.dynamicHandles[self.depIndex + 1].t ~= trigger then
        self.dynamicHandles[self.depIndex + 1].h:Dispose()
        local handle = trigger:Subscribe(self:ScheduleFromIndex(self.depIndex))
        self.dynamicHandles[self.depIndex + 1] = {t = trigger, h = handle}
    end
    self.depIndex = self.depIndex + 1
end

function DependencyTracker:EndDynamic()
    while #self.dynamicHandles > self.depIndex do
        self.dynamicHandles[#self.dynamicHandles].h:Dispose()
        table.remove(self.dynamicHandles)
    end
end

function DependencyTracker:Dispose()
    self.seen = {}
    for _, handle in ipairs(self.staticHandles) do
        handle.h:Dispose()
    end
    for _, handle in ipairs(self.dynamicHandles) do
        handle.h:Dispose()
    end
    self.staticHandles = {}
    self.dynamicHandles = {}
end

function DependencyTracker:ScheduleFromIndex(index)
    return function()
        if index < self.depIndex then
            self.schedule()
        end
    end
end

-- Main Computation class
function Computation.new(name, triggers)
    local self = Epoch.new()
    setmetatable(self, Computation)
    
    self.Name = name
    self.triggers = triggers or {}
    self.tracker = nil
    
    return self
end

function Computation:Init(builder)
    self.tracker = DependencyTracker.new(function()
        builder:GetPorts().RequestTick()
    end)
    
    builder:OnCleanup(function()
        self.tracker:Dispose()
    end)
    
    for index, trigger in ipairs(self.triggers) do
        validateTrigger(trigger, ("Computation.Init triggers[%d]"):format(index))
    end

    for _, trigger in ipairs(self.triggers) do
        self.tracker:AddStatic(trigger)
    end
    
    return function(s)
        self.tracker:BeginDynamic()
        local success, err = pcall(function()
            self:OnRun(s)
        end)
        self.tracker:EndDynamic()
        if not success then
            error(err)
        end
    end
end

function Computation:OnRun(builder)
    -- Override in subclasses
    error("OnRun must be overridden")
end

function Computation:AddStaticTrigger(trigger)
    if self.tracker then
        self.tracker:AddStatic(trigger)
    end
end

function Computation:AddDynamicTrigger(trigger)
    if self.tracker then
        self.tracker:AddDynamic(trigger)
    end
end

return Computation
