-- foundation.class 最小类系统:Class(name) 造类,:new(...) 造实例并调用 init 构造。
-- 仅支持单一类 + 实例方法;不带多父继承、__get_*/__set_* 魔法、__custom_index、
-- 大写 Init 构造（全仓使用面盘点确认零使用，#48）。

---@class Class
---@field __name string 类名
---@field new fun(self: Class, ...): any 创建类的实例
---@field init fun(self: table, ...) 可选构造函数;:new 调用时若存在则以实例为 self 执行

---@param class_name string 类名(仅作标识,写入实例元表 __name)
---@return Class class_table 类表;在其上定义实例方法,用 class_table:new(...) 造实例
local function Class(class_name)
  local class_table = {
    __name = class_name,
  }
  class_table.__index = class_table

  function class_table:new(...)
    local instance = setmetatable({}, class_table)
    if self.init then
      self.init(instance, ...)
    end
    return instance
  end

  return class_table
end

return Class

--[[ mutate4lua-manifest
version=4
projectHash=c5ce283d75d85231
scope.0.id=chunk:src/foundation/class.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=7c135e5bb7e56c21
scope.1.id=function:Class
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=27
scope.1.semanticHash=2f8b314e7b27b92b
scope.2.id=function:class_table:new
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=24
scope.2.semanticHash=548a5ea5dd307a8a
]]
