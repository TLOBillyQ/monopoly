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
  return (idx % #path) + 1
end

local bottom_intersection = find_index(45)
local inner_entry = find_index(42)
local shanghai_idx = find_index(34)
local right_exit = find_index(43)

local map = {
  path = path,
  -- 交叉路口按奇偶转向：奇数走默认路径，偶数转向内圈/外圈
  branches = {
    -- 底部道具格（45）往上进入内圈，否则继续外圈
    [bottom_intersection] = { odd = next_index(bottom_intersection), even = inner_entry },
    -- 上海路（34）偶数右转接回外圈的右侧机会格（43），奇数继续内圈
    [shanghai_idx] = { odd = next_index(shanghai_idx), even = right_exit },
  },
}

return map
