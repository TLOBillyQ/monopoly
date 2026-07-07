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

return M

--[[ mutate4lua-manifest
version=2
projectHash=f88d0504cfc9d0d1
scope.0.id=chunk:src/foundation/tables.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=fc8d3b507ce8babb
scope.1.id=function:M.join_or_default:37
scope.1.kind=function
scope.1.startLine=37
scope.1.endLine=42
scope.1.semanticHash=3b3116f0df11b0d8
]]
