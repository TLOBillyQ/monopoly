local M = {}

--- Deep-copies a table. Non-table values are returned as-is.
-- Recursively copies all nested tables.
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

return M
