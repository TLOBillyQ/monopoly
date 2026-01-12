-- 按照地图外圈逆时针，再进入内圈逆时针
local path = {
  -- 外圈（32 格）
  35, 1, 2, 3, 45, 4, 5, 6, 36,
  7, 8, 9, 40, 10, 11, 12, 37,
  13, 14, 15, 44, 16, 17, 18, 38,
  19, 20, 21, 43, 22, 23, 24,
  -- 内圈（13 格）
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
  -- 杭州路后面是起点
  if idx == 24 then
    return 35
  end

  return (idx % #path) + 1
end

local bottom_intersection = find_index(45)
local bottom_entry = find_index(42)

local left_intersection = find_index(40)
local left_entry = find_index(25)


local map = {
  path = path,
  -- 交叉路口按奇偶转向：奇数走默认路径，偶数转向内圈/外圈
  branches = {
    [bottom_intersection] = { odd = next_index(bottom_intersection), even = bottom_entry },
    [left_intersection] = { odd = next_index(left_intersection), even = left_entry },
  
  },
}

return map
