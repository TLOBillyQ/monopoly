-- Ticker.lua
-- Tickers are epochs that act as execution gateways

local Epoch = require("spoke.epoch")
local Heap = require("spoke.heap")
local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime

local Ticker = {}
Ticker.__index = Ticker
setmetatable(Ticker, {__index = Epoch})

function Ticker.new()
    local self = Epoch.new()
    setmetatable(self, Ticker)
    
    self.pending = Heap.new(function(a, b) return a:CompareTo(b) end)
    self.onTick = {}
    self.requestTick = nil
    self.isPaused = false
    self.isManual = false
    self.didContinue = false
    self.AutoArmTickAfterInit = false
    
    return self
end

function Ticker:IsTicking()
    local handle = self:GetControlHandle()
    return handle and handle:IsAlive() and handle:GetFrame() and handle:GetFrame().Type == SpokeRuntime.FrameKind.Tick
end

function Ticker:Init(builder)
    -- Subclasses should override Bootstrap
    if not self.isManual then
        self.requestTick = function()
            builder:GetPorts().RequestTick()
        end
        builder:OnCleanup(function()
            self.requestTick = nil
        end)
    end
    
    -- Bootstrap returns the root epoch
    local root = self:Bootstrap(builder)
    builder:Call(root)
    
    -- Return tick block
    return function(s)
        if self.isPaused or not self:HasPending() then
            return
        end
        
        self.didContinue = false
        for _, fn in ipairs(self.onTick) do
            if not self.isPaused then
                fn(s, self)
            end
        end
        
        if not self.didContinue and not self.isPaused then
            error("Ticker must TickNext() or Pause() during OnTick")
        end
        
        if self:HasPending() and not self.isPaused then
            if self.requestTick then
                self.requestTick()
            end
        end
    end
end

function Ticker:Bootstrap(builder)
    error("Bootstrap must be overridden")
end

function Ticker:TickNext()
    if not self:IsTicking() then
        error("TickNext() must be called from within an OnTick block")
    end
    
    self.didContinue = true
    local ticked = self.pending:RemoveMin()
    ticked:TickEpoch()
    return ticked
end

function Ticker:Schedule(epoch)
    if epoch == nil then
        error("Cannot schedule nil epoch")
    end
    if epoch.IsDetached then
        return  -- Silently ignore detached epochs
    end
    local prevHasPending = self:HasPending()
    self.pending:Insert(epoch)
    if not self:IsTicking() and not prevHasPending and self:HasPending() and not self.isPaused then
        if self.requestTick then
            self.requestTick()
        end
    end
end

function Ticker:SetIsPaused(value)
    if self.isPaused == value then
        return
    end
    self.isPaused = value
    if not value and self:HasPending() and not self:IsTicking() then
        if self.requestTick then
            self.requestTick()
        end
    end
end

function Ticker:SetToManual()
    self.isManual = true
end

function Ticker:HasPending()
    local pending = self.pending
    -- Clean up detached epochs efficiently
    while pending:Count() > 0 do
        local top = pending:PeekMin()
        if not top.IsDetached then
            return true
        end
        pending:RemoveMin()
    end
    return false
end

function Ticker:Pause()
    self:SetIsPaused(true)
end

function Ticker:Resume()
    self:SetIsPaused(false)
end

return Ticker
