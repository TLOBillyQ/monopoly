local M = {}

function M.with_sub_length(x, y, z)
  local vector_mt = {}
  vector_mt.__sub = function(a, b)
    return M.with_sub_length(a.x - b.x, a.y - b.y, a.z - b.z)
  end
  local vector = setmetatable({ x = x, y = y, z = z }, vector_mt)
  function vector:length()
    local sum = self.x * self.x + self.y * self.y + self.z * self.z
    return math.sqrt(sum)
  end
  return vector
end

function M.with_add(x, y, z)
  local vector_mt = {}
  vector_mt.__add = function(a, b)
    return M.with_add(a.x + b.x, a.y + b.y, a.z + b.z)
  end
  return setmetatable({ x = x, y = y, z = z }, vector_mt)
end

return M
