require("test.bootstrap").install_package_paths()

local fs_lib = require("foundation.fs")
local git_query = require("test.guards.lib.git_query")

local M = {}

-- 验收步骤绑定行数预算门禁(测试极简化决策 / issue #194)。
--
-- 病灶:旧 steps 库膨胀到 12.3K 行(churn 全仓第一、超变异上限),验收主场化后
-- 绑定层是长期承重墙,必须防复胖。DSL 重写落地基线 4,050 行(2026-07-20,#192)。
-- 超限时先想参数化合并与句面收敛,预算只准提案调升——在 ADR 里留痕,不准静默
-- 改数。5000 → 5500 见 ADR 0062(#594:存量 29 域已占 4,993 行,余量耗尽)。
M.BUDGET_LINES = 5500

local function _count_lines(content)
  local count = 0
  for _ in tostring(content):gmatch("\n") do
    count = count + 1
  end
  return count
end

-- 纯策略核:路径表 + read(path) -> content|nil,返回违规列表。
function M.check(paths, read, budget)
  local total = 0
  local unreadable = {}
  for _, path in ipairs(paths) do
    if path:sub(-4) == ".lua" then
      local content = read(path)
      if content == nil then
        unreadable[#unreadable + 1] = "steps_budget_guard: 读不到 " .. path
      else
        total = total + _count_lines(content)
      end
    end
  end
  if #unreadable > 0 then
    return unreadable, total
  end
  if total > budget then
    return {
      "steps_budget_guard: features/steps/ 合计 " .. tostring(total)
        .. " 行,超出预算 " .. tostring(budget)
        .. " —— 先做参数化合并/句面收敛;确需调升预算须走 ADR 留痕(测试极简化决策)",
    }, total
  end
  return {}, total
end

-- IO 壳:取 tracked 绑定路径,交给纯核。
function M.run()
  return git_query.run_tracked_guard("steps_budget_guard", "features/steps", function(lines)
    return M.check(lines, fs_lib.read_file, M.BUDGET_LINES)
  end)
end

return M
