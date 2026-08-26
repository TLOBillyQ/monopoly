local M = {}

M.slot = {
  "常驻_道具槽位1",
  "常驻_道具槽位2",
  "常驻_道具槽位3",
  "常驻_道具槽位4",
  "常驻_道具槽位5",
}

function M.slots(n)
  local t = {}
  for i = 1, n do t[i] = M.slot[i] end
  return t
end

return M
