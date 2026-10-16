-- dry 已知重复样例(#122):与 ledger_a.lua 的函数结构相同、命名不同。
-- 固定夹具,不依赖 src/ 业务代码里碰巧存在的重复。
local M = {}

function M.collect_credits(rows, cap)
  local acc = 0
  for i = 1, #rows do
    local value = rows[i].amount
    if value > 0 and acc + value <= cap then
      acc = acc + value
    end
  end
  return acc
end

return M
