-- 路径顺序与 9x9 网格对应，按 grid_coords 逐格行走
local path = {
  35, 1, 2, 3, 44, 4, 5, 6, 36,
  7, 40, 24, 23, 31, 8, 9, 32, 22,
  41, 34, 33, 42, 39, 27, 26, 25, 43,
  10, 28, 21, 20, 29, 11, 12, 30, 19,
  38, 18, 17, 16, 45, 15, 14, 13, 37,
}

local map = {
  path = path,
  branches = {}, -- 分支点可在此扩展： {index = {odd = targetIndex, even = targetIndex}}
}

return map
