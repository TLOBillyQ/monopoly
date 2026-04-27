local M = {}

M.slot = {
  "常驻_道具槽位1",
  "常驻_道具槽位2",
  "常驻_道具槽位3",
  "常驻_道具槽位4",
  "常驻_道具槽位5",
}

M.outline = {
  "常驻_可出牌外框1",
  "常驻_可出牌外框2",
  "常驻_可出牌外框3",
  "常驻_可出牌外框4",
  "常驻_可出牌外框5",
}

function M.slots(n)
  local t = {}
  for i = 1, n do t[i] = M.slot[i] end
  return t
end

function M.outlines(n)
  local t = {}
  for i = 1, n do t[i] = M.outline[i] end
  return t
end

return M
