
local path = {
  
  35, 1, 2, 3, 45, 4, 5, 6, 36,
  7, 8, 9, 40, 10, 11, 12, 37,
  13, 14, 15, 44, 16, 17, 18, 38,
  19, 20, 21, 43, 22, 23, 24,
  
  42, 31, 32, 39, 41, 33, 34,
  28, 29, 30, 27, 26, 25,
}

local function find_index(tile_id)
  for i, id in ipairs(path) do
    if id == tile_id then
      return i
    end
  end
  error("tile id " .. tile_id .. " not found in path")
end

local function next_index(idx)
  
  if idx == 24 then
    return 35
  end

  return (idx % #path) + 1
end

local bottom_intersection = find_index(45)
local bottom_entry = find_index(42)
local left_intersection = find_index(40)
local left_entry = find_index(25)
local up_intersection = find_index(40)
local up_entry = find_index(25)
local right_intersection = find_index(40)
local right_entry = find_index(25)

local market = find_index(39)

local map = {
  path = path,
  
  branches = {
    [bottom_intersection] = { odd = next_index(bottom_intersection), even = bottom_entry },
    [left_intersection] = { odd = next_index(left_intersection), even = left_entry },
    [up_intersection] = { odd = next_index(up_intersection), even = up_entry },
    [right_intersection] = { odd = next_index(right_intersection), even = right_entry },
  },
}

return map
