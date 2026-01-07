-- Epoch.lua
-- The most primitive object in Spoke

local TreeCoords = require("spoke.treecoords")
local SpokeException = require("spoke.spokeexception")
local SpokeRuntime = require("spoke.spokeruntime").SpokeRuntime
local SpokeHandle = require("spoke.spokehandle")
local SpokeLogger = require("spoke.spokelogger")

local Epoch = {}
Epoch.__index = Epoch

-- Attachment record kinds
local AttachRecordKind = {
    Cleanup = 1,
    Handle = 2,
    Use = 3,
    Call = 4,
    Export = 5
}

-- Attachment record structure
local AttachRecord = {}
AttachRecord.__index = AttachRecord

function AttachRecord.newHandle(handle)
    local self = setmetatable({}, AttachRecord)
    self.Type = AttachRecordKind.Handle
    self.Handle = handle
    return self
end

function AttachRecord.new(recordType, asObj)
    local self = setmetatable({}, AttachRecord)
    self.Type = recordType
    self.AsObj = asObj
    return self
end

local function wrapDetachException(msg, err)
    if type(err) == "table" and err.ToString then
        return err
    end
    return SpokeException.new(msg, err, SpokeRuntime.Local:GetFrames())
end

local function handleDetachFailure(epoch, operation, err)
    local message = string.format("Detach failed in '%s' during %s", tostring(epoch), operation)
    local wrapped = wrapDetachException(message, err)
    SpokeLogger.SpokeError.Log(message, wrapped)
    if SpokeRuntime.StrictCleanup then
        error(wrapped)
    end
end

function AttachRecord:Detach(epoch)
    if self.Type == AttachRecordKind.Cleanup then
        local success, err = pcall(function() self.AsObj() end)
        if not success then
            handleDetachFailure(epoch, "Cleanup", err)
        end
    elseif self.Type == AttachRecordKind.Handle then
        self.Handle:Dispose()
    elseif self.Type == AttachRecordKind.Use then
        local success, err = pcall(function() self.AsObj:Dispose() end)
        if not success then
            handleDetachFailure(epoch, "Use", err)
        end
    elseif self.Type == AttachRecordKind.Call then
        local success, err = pcall(function() self.AsObj:Detach() end)
        if not success then
            handleDetachFailure(epoch, "Call", err)
        end
    end
end

-- Epoch Mutations
local EpochMutations = {}
EpochMutations.__index = EpochMutations

function EpochMutations.new(owner)
    local self = setmetatable({}, EpochMutations)
    self.owner = owner
    return self
end

function EpochMutations:NoMischief()
    if not self.owner.controlHandle:IsTop() then
        error("Tried to mutate an Epoch that's been sealed for further changes.")
    end
end

function EpochMutations:Use(handleOrDisposable)
    self:NoMischief()
    if handleOrDisposable.Dispose then
        if handleOrDisposable.id then -- It's a SpokeHandle
            table.insert(self.owner.attachEvents, AttachRecord.newHandle(handleOrDisposable))
        else -- It's a disposable
            table.insert(self.owner.attachEvents, AttachRecord.new(AttachRecordKind.Use, handleOrDisposable))
        end
    end
    return handleOrDisposable
end

function EpochMutations:Call(epoch)
    self:NoMischief()
    if epoch == nil then
        error("Cannot attach nil epoch")
    end
    if epoch.parent then
        error("Tried to attach an epoch which was already attached")
    end
    table.insert(self.owner.attachEvents, AttachRecord.new(AttachRecordKind.Call, epoch))
    local childCoords = self.owner.Coords:Extend(#self.owner.attachEvents - 1)
    local childTicker = self.owner.ticker or self.owner
    epoch:Attach(self.owner, childCoords, childTicker, nil)
    return epoch
end

function EpochMutations:Export(obj)
    self:NoMischief()
    table.insert(self.owner.attachEvents, AttachRecord.new(AttachRecordKind.Export, obj))
    return obj
end

function EpochMutations:TryImport(typeOrPredicate)
    local startIndex = #self.owner.attachEvents
    local anc = self.owner
    
    while anc do
        for i = startIndex, 1, -1 do
            local evt = anc.attachEvents[i]
            if evt.Type == AttachRecordKind.Export then
                -- Simple type matching for Lua
                if type(typeOrPredicate) == "function" then
                    if typeOrPredicate(evt.AsObj) then
                        return true, evt.AsObj
                    end
                elseif type(typeOrPredicate) == "string" then
                    if type(evt.AsObj) == typeOrPredicate then
                        return true, evt.AsObj
                    end
                end
            end
        end
        startIndex = anc.attachIndex or 0
        anc = anc.parent
    end
    
    return false, nil
end

function EpochMutations:Import(typeOrPredicate)
    local found, obj = self:TryImport(typeOrPredicate)
    if found then
        return obj
    end
    error(string.format("Failed to import: %s", tostring(typeOrPredicate)))
end

function EpochMutations:OnCleanup(fn)
    self:NoMischief()
    if fn == nil then
        return
    end
    if type(fn) ~= "function" then
        error("OnCleanup requires a function, got " .. type(fn))
    end
    table.insert(self.owner.attachEvents, AttachRecord.new(AttachRecordKind.Cleanup, fn))
end

function EpochMutations:RequestTick()
    self.owner.controlHandle:OnPopSelf(self.owner._requestTick)
end

-- EpochBuilder
local EpochBuilder = {}
EpochBuilder.__index = EpochBuilder

function EpochBuilder.new(mutations)
    local self = setmetatable({}, EpochBuilder)
    self.s = mutations
    return self
end

function EpochBuilder:Use(handle) return self.s:Use(handle) end
function EpochBuilder:Call(epoch) return self.s:Call(epoch) end
function EpochBuilder:Export(obj) return self.s:Export(obj) end
function EpochBuilder:TryImport(t) return self.s:TryImport(t) end
function EpochBuilder:Import(t) return self.s:Import(t) end
function EpochBuilder:OnCleanup(fn) self.s:OnCleanup(fn) end

function EpochBuilder:Log(msg)
    self:Call(require("spoke.lambdaepoch").new("Log: " .. msg, function(s)
        local found, logger = s:TryImport("ISpokeLogger")
        if not found then
            logger = require("spoke.spokelogger").SpokeError.DefaultLogger
        end
        if logger then
            logger:Log(msg)
        end
        return nil
    end))
end

function EpochBuilder:GetPorts()
    return {
        RequestTick = function() self.s:RequestTick() end
    }
end

-- Main Epoch class
function Epoch.new()
    local self = setmetatable({}, Epoch)
    self.Coords = TreeCoords.new()
    self.IsDetached = false
    self.Fault = nil
    self.Name = nil
    self.AutoArmTickAfterInit = true
    self.attachEvents = {}
    self.tickCursor = TreeCoords.new()
    self.parent = nil
    self.attachIndex = -1
    self.ticker = nil
    self.tickBlock = nil
    self.controlHandle = nil
    self._requestTick = nil
    self.isPending = false
    return self
end

function Epoch:__tostring()
    return self.Name or "Epoch"
end

function Epoch:CompareTo(other)
    return self.tickCursor:CompareTo(other.tickCursor)
end

function Epoch:DetachFrom(i)
    while #self.attachEvents > math.max(i, 0) do
        self.attachEvents[#self.attachEvents]:Detach(self)
        table.remove(self.attachEvents)
    end
end

function Epoch:Detach()
    self:DetachFrom(0)
    self.IsDetached = true
end

function Epoch:Attach(parent, coords, ticker, services)
    if coords == nil then
        error("Cannot attach with nil coords")
    end
    self.parent = parent
    self.attachIndex = parent and #parent.attachEvents - 1 or -1
    self.Coords = coords
    self.tickCursor = coords
    self.ticker = ticker
    
    -- Route tick requests
    self._requestTick = function()
        if self.Fault or self.IsDetached or self.isPending then
            return
        end
        self.isPending = true
        if self.ticker then
            self.ticker:Schedule(self)
        elseif self.IsTree then
            SpokeRuntime.Local:Schedule(self)
        end
    end
    
    self:InitEpoch(services)
end

function Epoch:InitEpoch(services)
    self.controlHandle = SpokeRuntime.Local:Push(require("spoke.spokeruntime").Frame.new(SpokeRuntime.FrameKind.Init, self))
    
    local success, result = pcall(function()
        -- Pre-export services
        if services then
            for _, x in ipairs(services) do
                table.insert(self.attachEvents, AttachRecord.new(AttachRecordKind.Export, x))
            end
        end
        
        -- User-defined Init
        local builder = EpochBuilder.new(EpochMutations.new(self))
        local tickBlock = self:Init(builder)
        self.tickBlock = tickBlock
        
        -- Tick attachments start after Init
        self.tickCursor = self.Coords:Extend(#self.attachEvents)
        
        return true
    end)
    
    if not success then
        if type(result) == "table" and result.SkipMarkFaulted then
            self.Fault = result
            result.SkipMarkFaulted = false
        else
            self.Fault = SpokeException.new("Uncaught Exception in Init", result, SpokeRuntime.Local:GetFrames())
        end
    end
    
    SpokeRuntime.Local:Pop()
    
    -- Request first tick
    if self.AutoArmTickAfterInit then
        self.controlHandle:OnPopSelf(self._requestTick)
    end
end

function Epoch:Init(builder)
    -- Override in subclasses
    error("Init must be overridden")
end

function Epoch:TickEpoch()
    if self.IsDetached then
        return
    end
    
    self.isPending = false
    self.controlHandle = SpokeRuntime.Local:Push(require("spoke.spokeruntime").Frame.new(SpokeRuntime.FrameKind.Tick, self))
    self:DetachFrom(self.tickCursor:Tail() or 0)
    
    local success, result = pcall(function()
        if self.tickBlock then
            local builder = EpochBuilder.new(EpochMutations.new(self))
            self.tickBlock(builder)
        end
    end)
    
    if not success then
        if type(result) == "table" and result.SkipMarkFaulted then
            self.Fault = result
            result.SkipMarkFaulted = false
        else
            self.Fault = SpokeException.new("Uncaught Exception in Tick", result, SpokeRuntime.Local:GetFrames())
        end
    end
    
    SpokeRuntime.Local:Pop()
end

function Epoch:GetChildren(storeIn)
    storeIn = storeIn or {}
    for _, evt in ipairs(self.attachEvents) do
        if evt.Type == AttachRecordKind.Call then
            table.insert(storeIn, evt.AsObj)
        end
    end
    return storeIn
end

function Epoch:GetParent()
    return self.parent
end

function Epoch:GetControlHandle()
    return self.controlHandle
end

function Epoch:GetTicker()
    return self.ticker
end

function Epoch:SetFault(fault)
    self.Fault = fault
end

return Epoch
