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

function M.normalize_currency(currency)
  assert(currency ~= nil and currency ~= "", "missing currency")
  return currency
end

return M
