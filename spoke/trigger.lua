-- Trigger.lua
-- A simple event emitter integrated into Spoke's reactive system

local SpokeHandle = require("spoke.spokehandle")
local SpokePool = require("spoke.spokepool")
local SpokeLogger = require("spoke.spokelogger")
local SpokeRuntime = require("spoke.spokeruntime")

local Trigger = {}
Trigger.__index = Trigger

local NIL = {}
local REBUILD_THRESHOLD = 1000

function Trigger.Create()
    return Trigger.new()
end

function Trigger.new()
    local self = setmetatable({}, Trigger)
    self.subs = {}
    self.events = {}
    self.eventHead = 1
    self.idCount = 0
    self.isFlushing = false
    self.subListPool = SpokePool.Create(function(l) for k in pairs(l) do l[k] = nil end end)
    
    self._unsub = function(id) self:Unsub(id) end
    self._flush = function() self:Flush() end
    
    return self
end

function Trigger:Subscribe(action)
    if type(action) ~= "function" then
        error("Subscribe requires a function, got " .. type(action))
    end
    local sub = {
        Id = self.idCount,
        Action = action
    }
    self.idCount = self.idCount + 1
    table.insert(self.subs, sub)
    return SpokeHandle.Of(sub.Id, self._unsub)
end

function Trigger:Invoke(param)
    if param == nil then
        table.insert(self.events, NIL)
    else
        table.insert(self.events, param)
    end
    SpokeRuntime.SpokeRuntime.Batch(self._flush)
end

function Trigger:Unsubscribe(action)
    if action == nil then
        return
    end
    if type(action) ~= "function" then
        error("Unsubscribe requires a function, got " .. type(action))
    end
    local toRemove = {}
    for i, sub in ipairs(self.subs) do
        if sub.Action == action then
            table.insert(toRemove, sub.Id)
        end
    end
    for _, id in ipairs(toRemove) do
        self:Unsub(id)
    end
end

function Trigger:Flush()
    if self.isFlushing then
        return
    end
    
    self.isFlushing = true
    while self.eventHead <= #self.events do
        local evt = self.events[self.eventHead]
        self.eventHead = self.eventHead + 1
        
        -- Copy subscribers
        local subList = self.subListPool:Now()
        for i, sub in ipairs(self.subs) do
            table.insert(subList, sub)
        end
        
        for _, sub in ipairs(subList) do
            local success, err = pcall(function()
                if sub and sub.Action and type(sub.Action) == "function" then
                    if evt == NIL then
                        sub.Action()
                    else
                        sub.Action(evt)
                    end
                end
            end)
            if not success then
                SpokeLogger.SpokeError.Log("Trigger subscriber error", err)
            end
        end
        
        self.subListPool:Return(subList)
    end

    if self.eventHead > #self.events then
        self.events = {}
        self.eventHead = 1
    elseif self.eventHead > REBUILD_THRESHOLD then
        local newEvents = {}
        for i = self.eventHead, #self.events do
            newEvents[#newEvents + 1] = self.events[i]
        end
        self.events = newEvents
        self.eventHead = 1
    end
    self.isFlushing = false
end

function Trigger:Unsub(id)
    for i = #self.subs, 1, -1 do
        if self.subs[i].Id == id then
            table.remove(self.subs, i)
            return
        end
    end
end

return Trigger
