-- SpokeRuntime.lua
-- The Spoke runtime providing VM-like capabilities

local Heap = require("spoke.heap")
local SpokePool = require("spoke.spokepool")
local ReadOnlyList = require("spoke.readonlylist")
local SpokeException = require("spoke.spokeexception")
local SpokeLogger = require("spoke.spokelogger")

local SpokeRuntime = {}
SpokeRuntime.__index = SpokeRuntime
SpokeRuntime.StrictCleanup = false

do
    local strictEnv = os.getenv("SPOKE_STRICT_CLEANUP")
    if strictEnv then
        strictEnv = strictEnv:lower()
        SpokeRuntime.StrictCleanup = strictEnv == "1" or strictEnv == "true" or strictEnv == "yes"
    end
end

-- Frame kinds enum
SpokeRuntime.FrameKind = {
    None = 0,
    Init = 1,
    Tick = 2,
    Dock = 3,
    Bootstrap = 4
}

-- Frame structure
local Frame = {}
Frame.__index = Frame

function Frame.new(frameType, epoch)
    local self = setmetatable({}, Frame)
    self.Type = frameType
    self.Epoch = epoch
    return self
end

function Frame:__tostring()
    if self.Type == SpokeRuntime.FrameKind.None then
        return "<null>"
    end
    local typeName = self.Epoch.Name or "Unknown"
    local faultInfo = self.Epoch.Fault and "[Faulted]" or ""
    local frameNames = {"None", "Init", "Tick", "Dock", "Bootstrap"}
    return string.format("%s %s <%s>%s", frameNames[self.Type + 1] or "Unknown", tostring(self.Epoch), typeName, faultInfo)
end

-- Handle structure
local Handle = {}
Handle.__index = Handle

function Handle.new(stack, index, version)
    local self = setmetatable({}, Handle)
    self.Stack = stack
    self.Index = index
    self.version = version
    return self
end

function Handle:IsAlive()
    return self.Stack and self.Index <= #self.Stack.frames and self.version == self.Stack.versions[self.Index]
end

function Handle:IsTop()
    return self:IsAlive() and self.Index == #self.Stack.frames
end

function Handle:GetFrame()
    return self:IsAlive() and self.Stack.frames[self.Index] or nil
end

function Handle:OnPopSelf(fn)
    if not self:IsAlive() then
        if fn then fn() end
    else
        table.insert(self.Stack.onPopSelfFrames[self.Index], fn)
    end
end

-- Main SpokeRuntime class
function SpokeRuntime.new()
    local self = setmetatable({}, SpokeRuntime)
    self.TimeStamp = 0
    self.scheduledTrees = Heap.new(function(a, b) return a:CompareTo(b) end)
    self.fnlPool = SpokePool.Create(function(l) for k in pairs(l) do l[k] = nil end end)
    self.frames = {}
    self.versions = {}
    self.onPopSelfFrames = {}
    self.layer = math.maxinteger or 2^31 - 1
    self.holdCount = 0
    return self
end

-- Static Local instance
SpokeRuntime.Local = SpokeRuntime.new()

function SpokeRuntime:GetFrames()
    return ReadOnlyList.new(self.frames)
end

function SpokeRuntime.Batch(fn)
    if type(fn) ~= "function" then
        error("Batch requires a function, got " .. type(fn))
    end
    SpokeRuntime.Local:Hold()
    local success, err = pcall(fn)
    SpokeRuntime.Local:Release()
    if not success then
        local exception = SpokeException.new("Uncaught Exception in Batch", err, SpokeRuntime.Local:GetFrames())
        SpokeLogger.SpokeError.Log("Uncaught Spoke error", exception)
        error(exception)
    end
end

function SpokeRuntime:Push(frame)
    if frame == nil then
        error("Cannot push nil frame")
    end
    table.insert(self.frames, frame)
    table.insert(self.versions, self.TimeStamp)
    self.TimeStamp = self.TimeStamp + 1
    table.insert(self.onPopSelfFrames, self.fnlPool:Now())
    return Handle.new(self, #self.frames, self.versions[#self.versions])
end

function SpokeRuntime:Pop()
    if #self.frames == 0 then
        error("Cannot pop from empty stack")
    end
    local lastIndex = #self.frames
    table.remove(self.frames, lastIndex)
    table.remove(self.versions, lastIndex)
    local onPopSelf = self.onPopSelfFrames[lastIndex]
    table.remove(self.onPopSelfFrames, lastIndex)
    
    for _, fn in ipairs(onPopSelf) do
        if fn then
            local success, err = pcall(fn)
            if not success then
                SpokeLogger.SpokeError.Log("Error in OnPopSelf callback", err)
            end
        end
    end
    self.fnlPool:Return(onPopSelf)
end

function SpokeRuntime:Hold()
    self.holdCount = self.holdCount + 1
end

function SpokeRuntime:Release()
    if self.holdCount <= 0 then
        error("Release called without matching Hold")
    end
    self.holdCount = self.holdCount - 1
    if self.holdCount == 0 then
        self:TryFlush()
    end
end

function SpokeRuntime:Schedule(tree)
    if tree == nil then
        error("Cannot schedule nil tree")
    end
    self.scheduledTrees:Insert(tree)
    self:TryFlush()
end

function SpokeRuntime:TryFlush()
    local maxPasses = 100
    if self.holdCount > 0 or not self:HasPending() then
        return
    end
    
    local passCount = 0
    local prev = nil
    
    repeat
        if passCount >= maxPasses then
            SpokeLogger.SpokeError.Log("SpokeRuntime exceeded oscillation limit", nil)
            while self.scheduledTrees:Count() > 0 do
                self.scheduledTrees:RemoveMin()
            end
            break
        end
        
        local top = self.scheduledTrees:PeekMin()
        local isLayerBoosted = top:IsLayerBoosted()
        
        if isLayerBoosted and top.FlushLayer > self.layer then
            return
        elseif not isLayerBoosted and top.FlushLayer >= self.layer then
            return
        end
        
        if prev and prev:CompareTo(top) > 0 then
            passCount = passCount + 1
        end
        
        prev = top
        self:TickTree(self.scheduledTrees:RemoveMin())
    until not self:HasPending()
end

function SpokeRuntime:TickTree(tree)
    local storeLayer = self.layer
    self.layer = math.min(tree.FlushLayer, self.layer)
    
    local success, err = pcall(function() tree:Tick() end)
    if not success then
        SpokeLogger.SpokeError.Log("Uncaught Spoke error", err)
    end
    
    self.layer = storeLayer
    if #self.frames == 0 then
        self:TryFlush()
    end
end

function SpokeRuntime:TryScopedLayerBoost(tree, onPopped)
    local isPossible = #self.frames > 0 and tree.FlushLayer <= self.layer
    if not isPossible then
        onPopped()
        return
    end
    
    local topHandle = Handle.new(self, #self.frames, self.versions[#self.versions])
    topHandle:OnPopSelf(onPopped)
end

function SpokeRuntime:HasPending()
    local trees = self.scheduledTrees
    -- Clean up detached trees efficiently
    while trees:Count() > 0 do
        local top = trees:PeekMin()
        if not top.IsDetached then
            return true
        end
        trees:RemoveMin()
    end
    return false
end

return {
    SpokeRuntime = SpokeRuntime,
    Frame = Frame,
    Handle = Handle
}
