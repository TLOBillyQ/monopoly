-- SpokeIntrospect.lua
-- Introspection utilities for Spoke Epoch trees

local SpokeIntrospect = {}

local SpokePool = require("spoke.spokepool")
local elPool = SpokePool.Create(function(l) 
    for k in pairs(l) do l[k] = nil end
end)

function SpokeIntrospect.GetChildren(epoch, storeIn)
    storeIn = storeIn or {}
    if epoch.GetChildren then
        return epoch:GetChildren(storeIn)
    end
    return storeIn
end

function SpokeIntrospect.GetParent(epoch)
    if epoch.GetParent then
        return epoch:GetParent()
    end
    return nil
end

function SpokeIntrospect.TreeTrace(frames)
    if #frames == 0 then return "(empty)" end
    
    local result = {}
    local es = {}
    for i = 1, #frames do
        table.insert(es, frames[i].Epoch)
    end
    
    local roots = {}
    for _, e in ipairs(es) do
        local hasRoot = false
        for _, r in ipairs(roots) do
            if r == e then hasRoot = true; break end
        end
        if not hasRoot and SpokeIntrospect.GetParent(e) == nil then
            table.insert(roots, e)
        end
    end
    
    table.insert(result, "<------------ Spoke Frame Trace ------------>")
    table.insert(result, SpokeIntrospect.StackTrace(frames))
    table.insert(result, "<------------ Spoke Tree Trace ------------>")
    
    for _, root in ipairs(roots) do
        table.insert(result, SpokeIntrospect.DumpTree(root, function(e)
            local label = tostring(e)
            for i, epoch in ipairs(es) do
                if epoch == e then
                    label = string.format("(%d)-%s", i-1, label)
                    break
                end
            end
            if e.Fault then
                label = string.format("%s [Faulted]", label)
            end
            return label
        end))
    end
    
    return table.concat(result, "\n")
end

function SpokeIntrospect.StackTrace(frames)
    if #frames == 0 then return "(empty)" end
    local result = {}
    for i = 1, #frames do
        table.insert(result, string.format("%d: %s", i-1, tostring(frames[i])))
    end
    return table.concat(result, "\n")
end

function SpokeIntrospect.DumpTree(root, eLabel)
    local result = {}
    local function traverse(depth, epoch)
        local indent = string.rep("    ", depth)
        local label = eLabel and eLabel(epoch) or tostring(epoch)
        table.insert(result, string.format("%s|-- %s", indent, label))
        
        local children = SpokeIntrospect.GetChildren(epoch, elPool:Now())
        for _, c in ipairs(children) do
            traverse(depth + 1, c)
        end
        elPool:Return(children)
    end
    traverse(0, root)
    return table.concat(result, "\n")
end

return SpokeIntrospect
