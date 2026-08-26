---@generic T
---@class Array<T>: Class
---@field [integer] T 数组元素
---@field length integer 数组长度
---@field protected __protected_data T[] 数组数据
---@field protected __protected_length integer 数组长度
---@field new fun(self: Array): Array<T>
local Class = require("src.ui.manager.class")
local Array = Class("Array")

function Array:__custom_index(key)
    return self.__protected_data[key]
end

function Array:init()
    self.__protected_data = {}
    self.__protected_length = 0
end

---@param callback fun(e: T)
function Array:forEach(callback)
    for i = 1, self.__protected_length do
        callback(self.__protected_data[i])
    end
end

function Array:append(value)
    self.__protected_length = self.__protected_length + 1
    self.__protected_data[self.__protected_length] = value
end

function Array:pop()
    local value = self.__protected_data[self.__protected_length]
    self.__protected_data[self.__protected_length] = nil
    self.__protected_length = self.__protected_length - 1
    return value
end

function Array:__get_length()
    return self.__protected_length
end

function Array:__set_length(value)
    error("Array length is read-only")
end

return Array

--[[ mutate4lua-manifest
version=4
projectHash=4e665ff77cf8fe39
scope.0.id=chunk:src/ui/manager/array.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=4abee5844700d118
scope.1.id=function:Array:__custom_index
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=70ade069282003e1
scope.2.id=function:Array:init
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=18
scope.2.semanticHash=ff1c69d04b047d58
scope.3.id=function:Array:forEach
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=25
scope.3.semanticHash=c006a31be74da5ca
scope.4.id=function:Array:append
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=30
scope.4.semanticHash=4b4e19acfcab4720
scope.5.id=function:Array:pop
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=37
scope.5.semanticHash=a88d8b9e6fe402f9
scope.6.id=function:Array:__get_length
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=41
scope.6.semanticHash=c0484ae42c9068b0
scope.7.id=function:Array:__set_length
scope.7.kind=function
scope.7.startLine=43
scope.7.endLine=45
scope.7.semanticHash=57f430cdc8cb12a4
]]
