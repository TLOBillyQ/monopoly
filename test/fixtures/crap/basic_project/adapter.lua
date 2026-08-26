-- #361 P1 fixture adapter:crap 契约用例的覆盖输入不再真跑 contract 车道
-- (单测 26-27s),run 直接把一罐固定 luacov 报告落盘——报告内容与 src/ 下
-- 3 个源文件逐行对齐(luacov 报告每个源行占一行,行号按序隐式推进):
--   alpha.lua 全命中;beta.lua 的 `return a` 分支 *0(部分覆盖);
--   gamma.lua 全 *0(零覆盖,crap = cx^2 + cx 路径)。
-- 契约形状同上游 tests/fixtures/basic_project/adapter.lua:
--   resolve_suites(lane, mode) -> suites;run(suites, opts) -> { total, failed, ... }

local _RULE = string.rep("=", 80)

-- 每行:<命中数或 *0 或空><空格><源行原文>;空命中列 = 非可执行行,仍推进计数。
local _REPORT = table.concat({
  _RULE,
  "src/alpha.lua",
  _RULE,
  "1      local M = {}",
  "",
  "1      function M.add(a, b)",
  "1        return a + b",
  "       end",
  "",
  "1      return M",
  _RULE,
  "src/beta.lua",
  _RULE,
  "1      local M = {}",
  "",
  "1      function M.max_value(a, b)",
  "1        if a > b then",
  "*0       return a",
  "       end",
  "1        return b",
  "       end",
  "",
  "1      return M",
  _RULE,
  "src/gamma.lua",
  _RULE,
  "*0     local M = {}",
  "",
  "*0     function M.identity(x)",
  "*0       return x",
  "       end",
  "",
  "*0     return M",
  _RULE,
  "",
}, "\n")

local adapter = {}

function adapter.resolve_suites(_lane, _mode)
  return {}
end

function adapter.run(_suites, opts)
  local handle, open_err = io.open(opts.report_path, "wb")
  if handle == nil then
    error("fixture adapter cannot write report: " .. tostring(open_err), 0)
  end
  handle:write(_REPORT)
  handle:close()
  return { total = 0, failed = false, failures = {} }
end

return adapter
