local M = {}

local _registry = {}

function M.register(kind, fn)
  assert(type(kind) == "string" and kind ~= "", "invalid kind")
  assert(type(fn) == "function", "invalid fallback fn")
  _registry[kind] = fn
end

function M.unregister(kind)
  if type(kind) ~= "string" then
    return false
  end
  if _registry[kind] == nil then
    return false
  end
  _registry[kind] = nil
  return true
end

function M.resolve(kind, game, choice)
  if type(kind) ~= "string" then
    return nil
  end
  local fn = _registry[kind]
  if type(fn) ~= "function" then
    return nil
  end
  local ok, action = pcall(fn, game, choice)
  if not ok then
    return nil
  end
  return action
end

function M.has(kind)
  return type(kind) == "string" and type(_registry[kind]) == "function"
end

function M.snapshot()
  local kinds = {}
  for kind in pairs(_registry) do
    kinds[#kinds + 1] = kind
  end
  table.sort(kinds)
  return kinds
end

function M.reset()
  _registry = {}
end

return M
