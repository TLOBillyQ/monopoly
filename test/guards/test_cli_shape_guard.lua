require("test.bootstrap").install_package_paths()

local luassert = assert
local guard = require("test.guards.lib.cli_shape_guard")

-- 包内 cli.lua 形态契约 guard(#316 / #300 Q4):每个 packages.<pkg>.cli 必须
-- 返回 table 且 main 为 function。下面用注入的 loader 喂合成模块,断言它
-- 真的会红/会绿——门禁的价值全在能变红。

describe("TestCliShapeGuard", function()
  -- 合规形态(return table + main function)不违规。
  it("test_table_with_main_function_is_allowed", function()
    local violation = guard.check_module("verify", { main = function() end, usage = function() end })
    luassert.is_nil(violation)
  end)

  -- 返回非 table 必须被拦。
  it("test_non_table_return_is_blocked", function()
    local violation = guard.check_module("broken", "not a table")
    luassert.truthy(violation:find("broken", 1, true) ~= nil)
    luassert.truthy(violation:find("table", 1, true) ~= nil)
  end)

  -- table 缺 main / main 非 function 必须被拦。
  it("test_missing_or_non_function_main_is_blocked", function()
    local missing = guard.check_module("broken", {})
    luassert.truthy(missing:find("main", 1, true) ~= nil)
    local non_function = guard.check_module("broken", { main = 42 })
    luassert.truthy(non_function:find("main", 1, true) ~= nil)
  end)

  -- check 走注入 loader:加载失败与形态违规都进违规清单。
  it("test_check_collects_load_failure_and_shape_violation", function()
    local modules = {
      ["packages.good.cli"] = { main = function() end },
      ["packages.bad.cli"] = { main = nil },
    }
    local loader = function(module_name)
      if module_name == "packages.explode.cli" then
        return false, "boom"
      end
      return true, modules[module_name]
    end
    local violations = guard.check({ "good", "bad", "explode" }, loader)
    luassert.is.equal(2, #violations, table.concat(violations, "\n"))
    local joined = table.concat(violations, "\n")
    luassert.truthy(joined:find("bad", 1, true) ~= nil)
    luassert.truthy(joined:find("explode", 1, true) ~= nil)
    luassert.truthy(joined:find("boom", 1, true) ~= nil)
  end)

  -- 全合规语料必须全绿。
  it("test_check_all_compliant_is_green", function()
    local loader = function()
      return true, { main = function() end }
    end
    local violations = guard.check({ "verify", "lint" }, loader)
    luassert.is.equal(0, #violations, table.concat(violations, "\n"))
  end)
end)
