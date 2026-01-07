-- SpokeTree.lua
-- Root ticker for a Spoke tree

local Ticker = require("spoke.ticker")
local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime
local SpokeLogger = require("spoke.spokelogger")

local FlushMode = {
    Auto = 1,
    Manual = 2
}

local SpokeTree = {}
SpokeTree.__index = SpokeTree
setmetatable(SpokeTree, {__index = Ticker})

function SpokeTree.new(name, main, flushMode, flushLayer, services)
    if name == nil or name == "" then
        name = "SpokeTree"
    end
    if main == nil then
        error("SpokeTree requires a main epoch")
    end
    
    local self = Ticker.new()
    setmetatable(self, SpokeTree)
    
    self.Name = name
    self.Main = main
    self.FlushMode = flushMode or FlushMode.Auto
    self.FlushLayer = flushLayer or 0
    self.command = nil
    self.ports = nil
    self.TimeStamp = -1
    self.isLayerBoosted = false
    self.IsTree = true
    self._internalTick = false
    
    if self.FlushMode == FlushMode.Manual then
        self:SetToManual()
    else
        self.command = "Flush"
        self.isLayerBoosted = true
        SpokeRuntime.Local:TryScopedLayerBoost(self, function()
            self.isLayerBoosted = false
        end)
    end
    
    -- Push bootstrap frame
    local Frame = require("spoke.spokeruntime").Frame
    SpokeRuntime.Local:Push(Frame.new(SpokeRuntime.FrameKind.Bootstrap, self))
    self.TimeStamp = SpokeRuntime.Local.TimeStamp
    
    local success, err = pcall(function()
        self:Attach(nil, require("spoke.treecoords").new(), nil, services)
    end)
    
    if not success then
        SpokeLogger.SpokeError.Log("[SpokeTree] uncaught error in Bootstrap", err)
    end
    
    SpokeRuntime.Local:Pop()
    
    return self
end

function SpokeTree:Bootstrap(builder)
    -- Get logger
    local found, logger = builder:TryImport("ISpokeLogger")
    if not found then
        logger = SpokeLogger.SpokeError.DefaultLogger
    end
    
    -- Store ports for later use
    self.ports = {
        HasPending = function() return self:HasPending() end,
        PeekNext = function() return self.pending:Count() > 0 and self.pending:PeekMin() or nil end,
        Pause = function() self:Pause() end,
        Resume = function() self:Resume() end
    }
    
    -- Set up OnTick handler
    local onTickHandler = function(s, ticker)
        local maxPasses = 1000
        if not self.command or self.command == "None" then
            return
        end
        
        local passCount = 0
        local prev = nil
        
        while self.ports.HasPending() do
            if passCount > maxPasses then
                error("Exceed oscillation limit - possible infinite loop")
            end
            
            local success, result = pcall(function()
                local next = self.ports.PeekNext()
                if prev and prev:CompareTo(next) > 0 then
                    passCount = passCount + 1
                end
                prev = next
                
                ticker:TickNext()
            end)
            
            if not success then
                self:SetFault(result)
                if logger then
                    logger:Error(string.format("FLUSH ERROR\n->A fault occurred during flush.\n\n%s", tostring(result)))
                end
                break
            end
            
            if self.command == "Tick" then
                break
            end
        end
    end
    
    -- Register OnTick
    table.insert(self.onTick, onTickHandler)
    
    return self.Main
end

function SpokeTree:CompareTo(other)
    if self.FlushLayer ~= other.FlushLayer then
        return self.FlushLayer < other.FlushLayer and -1 or 1
    end
    if self.isLayerBoosted == other.isLayerBoosted then
        return self.TimeStamp < other.TimeStamp and -1 or (self.TimeStamp > other.TimeStamp and 1 or 0)
    end
    return self.isLayerBoosted and -1 or 1
end

function SpokeTree:IsLayerBoosted()
    return self.isLayerBoosted
end

function SpokeTree:Flush()
    if self.FlushMode ~= FlushMode.Manual then
        error("Only trees with Manual flush mode can be explicitly flushed. Current mode: " .. tostring(self.FlushMode))
    end
    if self:IsTicking() then
        error("Re-entrant flush detected - cannot flush while already flushing")
    end
    if self.IsDetached then
        error("Cannot flush detached tree")
    end

    self.command = "Flush"
    self._internalTick = true
    SpokeRuntime.Local:Schedule(self)
end

function SpokeTree:Tick()
    -- When called externally on a manual tree, schedule a single tick
    if self.FlushMode == FlushMode.Manual and not self._internalTick then
        if self:IsTicking() then
            error("Re-entrant flush detected - cannot tick while already ticking")
        end
        if self.IsDetached then
            return  -- Silently ignore ticks on detached trees
        end
        self.command = "Tick"
        self._internalTick = true
        SpokeRuntime.Local:Schedule(self)
        return
    end

    -- Internal tick path (called by SpokeRuntime)
    self._internalTick = false
    self:TickEpoch()
end

function SpokeTree:Dispose()
    local handle = self:GetControlHandle()
    handle:OnPopSelf(function()
        self:Detach()
    end)
end

-- Static factory methods
function SpokeTree.Spawn(name, root, services)
    if type(name) ~= "string" then
        -- If first arg is not string, it's the root
        services = root
        root = name
        name = "SpokeTree"
    end
    return SpokeTree.new(name, root, FlushMode.Auto, 0, services)
end

function SpokeTree.SpawnEager(name, root, services)
    if type(name) ~= "string" then
        services = root
        root = name
        name = "SpokeTree (Eager)"
    end
    return SpokeTree.new(name, root, FlushMode.Auto, -1, services)
end

function SpokeTree.SpawnManual(name, root, services)
    if type(name) ~= "string" then
        services = root
        root = name
        name = "SpokeTree (Manual)"
    end
    return SpokeTree.new(name, root, FlushMode.Manual, math.mininteger or -2^31, services)
end

return {
    SpokeTree = SpokeTree,
    FlushMode = FlushMode
}
