-- Dock.lua
-- An Epoch that has a dynamic collection of keyed attachments

local Epoch = require("spoke.epoch")
local SpokeRuntime = require("spoke.spokeruntime")

local Dock = {}
Dock.__index = Dock
setmetatable(Dock, {__index = Epoch})

function Dock.new(name)
    local self = Epoch.new()
    setmetatable(self, Dock)
    
    self.Name = name or "Dock"
    self.dynamicChildren = {}
    self.isDetaching = false
    self.childIndex = 0
    
    return self
end

function Dock:Call(key, epoch)
    if key == nil then
        error("Cannot Call with nil key")
    end
    if epoch == nil then
        error("Cannot Call with nil epoch")
    end
    if self.isDetaching then
        error("Cannot Call while detaching")
    end
    
    -- Push a stack frame
    SpokeRuntime.SpokeRuntime.Local:Push(SpokeRuntime.Frame.new(SpokeRuntime.SpokeRuntime.FrameKind.Dock, self))
    
    -- Drop existing epoch at key
    self:Drop(key)
    
    -- Add new epoch
    self.dynamicChildren[key] = epoch
    local childCoords = self.Coords:Extend(self.childIndex)
    self.childIndex = self.childIndex + 1
    local childTicker = self:GetTicker()
    epoch:Attach(self, childCoords, childTicker, nil)
    
    SpokeRuntime.SpokeRuntime.Local:Pop()
    return epoch
end

function Dock:Drop(key)
    local child = self.dynamicChildren[key]
    if not child then
        return
    end
    child:Detach()
    self.dynamicChildren[key] = nil
end

function Dock:Init(builder)
    builder:OnCleanup(function()
        self.isDetaching = true
        local children = self:GetChildren()
        for i = #children, 1, -1 do
            children[i]:Detach()
        end
        self.dynamicChildren = {}
    end)
    return nil
end

function Dock:GetChildren(storeIn)
    storeIn = storeIn or {}
    for _, child in pairs(self.dynamicChildren) do
        table.insert(storeIn, child)
    end
    table.sort(storeIn, function(a, b)
        return a.Coords:CompareTo(b.Coords) < 0
    end)
    return storeIn
end

return Dock
