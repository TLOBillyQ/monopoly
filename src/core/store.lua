local Store = {}
Store.__index = Store

local Tables = require("src.util.tables")
local deep_copy = Tables.deep_copy

function Store.new(init)
  local self = {
    state = deep_copy(init or {}),
  }
  return setmetatable(self, Store)
end

function Store:get(path)
  local node = self.state
  for _, key in ipairs(path) do
    if type(node) ~= "table" then
      return nil
    end
    node = node[key]
  end
  return node
end

function Store:set(path, value)
  local node = self.state
  for i = 1, #path - 1 do
    local key = path[i]
    if node[key] == nil or type(node[key]) ~= "table" then
      node[key] = {}
    end
    node = node[key]
  end
  node[path[#path]] = value
end

return Store
