-- ReadOnlyList.lua
-- A read-only wrapper around a list

local ReadOnlyList = {}
ReadOnlyList.__index = ReadOnlyList

function ReadOnlyList.new(list)
    if list == nil then
        error("ReadOnlyList requires a list")
    end
    if type(list) ~= "table" then
        error("ReadOnlyList requires a table, got " .. type(list))
    end
    local self = setmetatable({}, ReadOnlyList)
    self.list = list
    return self
end

function ReadOnlyList:Count()
    return #self.list
end

function ReadOnlyList:Get(index)
    if type(index) ~= "number" then
        error("Index must be a number, got " .. type(index))
    end
    if index < 1 or index > #self.list then
        error("Index out of bounds: " .. tostring(index))
    end
    return self.list[index]
end

function ReadOnlyList:__index(key)
    if type(key) == "number" then
        return self.list[key]
    end
    return ReadOnlyList[key]
end

return ReadOnlyList
