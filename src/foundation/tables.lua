local M = {}

function M.copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, child in pairs(value) do
    out[key] = M.copy(child)
  end
  return out
end

function M.copy_table(value)
  if type(value) ~= "table" then
    return {}
  end
  local out = {}
  for key, child in pairs(value) do
    out[key] = child
  end
  return out
end

function M.contains(list, value)
  if type(list) ~= "table" then
    return false
  end
  for _, current in ipairs(list) do
    if current == value then
      return true
    end
  end
  return false
end

function M.join_or_default(list, separator, default_value)
  if type(list) ~= "table" or #list == 0 then
    return default_value
  end
  return table.concat(list, separator)
end

function M.ensure_table_field(t, key)
  if type(t[key]) ~= "table" then
    t[key] = {}
  end
  return t[key]
end

-- 字段为 nil 时填入任意默认值并返回现值;已有值(含 false)原样保留。
function M.ensure_field(t, key, fallback)
  if t[key] == nil then
    t[key] = fallback
  end
  return t[key]
end

-- 只在字段缺席(nil)时补空表,已有的非表值保持原样交回调用方。与
-- ensure_table_field 不同:那个会把非表值悄悄换成空表,这里不会掩盖类型错误。
function M.ensure_absent_field(t, key)
  local value = t[key]
  if value == nil then
    value = {}
    t[key] = value
  end
  return value
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=1ed22a8cdded6393
scope.0.id=chunk:src/foundation/tables.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=8bd5b8b06f35cf6a
scope.1.id=function:M.copy
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=12
scope.1.semanticHash=2c1f91e24dc2ce7b
scope.2.id=function:M.copy_table
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=23
scope.2.semanticHash=4ff13cd143dd853f
scope.3.id=function:M.contains
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=35
scope.3.semanticHash=c53dedb777e19cbf
scope.4.id=function:M.join_or_default
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=42
scope.4.semanticHash=f9c9ca21ab2e0ea6
scope.5.id=function:M.ensure_table_field
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=49
scope.5.semanticHash=8a11646bf5a31cdf
scope.6.id=function:M.ensure_field
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=57
scope.6.semanticHash=11c0e329b673d65b
scope.7.id=function:M.ensure_absent_field
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=68
scope.7.semanticHash=2ce4c7d9acf699a9
]]
