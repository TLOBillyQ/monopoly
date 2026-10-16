-- dry 已知重复样例(#122):与 ledger_b.lua 的函数结构相同、命名不同。
-- 固定夹具,不依赖 src/ 业务代码里碰巧存在的重复。
local M = {}

function M.sum_positive(entries, limit)
  local total = 0
  for index = 1, #entries do
    local amount = entries[index].amount
    if amount > 0 and total + amount <= limit then
      total = total + amount
    end
  end
  return total
end

return M
