local M = {}

function M.max_value(a, b)
  if a > b then
    return a
  end
  return b
end

return M
