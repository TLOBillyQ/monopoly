-- TreeCoords.lua
-- Determines the imperative ordering for a node in the call-tree

local TreeCoords = {}
TreeCoords.__index = TreeCoords

function TreeCoords.new()
    local self = setmetatable({}, TreeCoords)
    self.coords = {}
    self.packed = nil
    return self
end

function TreeCoords:Tail()
    return self.coords[#self.coords]
end

function TreeCoords:Extend(idx)
    if idx == nil then
        error("Cannot extend with nil index")
    end
    if type(idx) ~= "number" then
        error("Index must be a number, got " .. type(idx))
    end
    local next = TreeCoords.new()
    for i = 1, #self.coords do
        table.insert(next.coords, self.coords[i])
    end
    table.insert(next.coords, idx)
    return next
end

function TreeCoords:CompareTo(other)
    if other == nil then
        error("Cannot compare with nil")
    end
    if not other.coords then
        error("Cannot compare with invalid TreeCoords object")
    end
    local myDepth = #self.coords
    local otherDepth = #other.coords
    local minDepth = math.min(myDepth, otherDepth)
    
    for i = 1, minDepth do
        if self.coords[i] < other.coords[i] then
            return -1
        elseif self.coords[i] > other.coords[i] then
            return 1
        end
    end
    
    if myDepth < otherDepth then
        return -1
    elseif myDepth > otherDepth then
        return 1
    else
        return 0
    end
end

return TreeCoords
