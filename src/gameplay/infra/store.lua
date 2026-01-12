local Store = {}
Store.__index = Store

local Tables = require("src.util.tables")
local deep_copy = Tables.deep_copy

local DEFAULT_VERSION = 1

function Store.new(init)
  local self = {
    version = DEFAULT_VERSION,
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
    node[key] = node[key] or {}
    node = node[key]
  end
  node[path[#path]] = value
end

function Store:snapshot()
  return {
    version = self.version,
    state = deep_copy(self.state),
  }
end

function Store:restore(snapshot)
  assert(snapshot and snapshot.state, "invalid snapshot")
  self.version = snapshot.version or self.version
  self.state = deep_copy(snapshot.state)
end

return Store
