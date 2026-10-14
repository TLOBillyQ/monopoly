---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/uml_quality/test/test_uml_quality_busted.lua") end
require("test.bootstrap").install_package_paths()

-- 仓根 .busted + test/busted_helper.lua(#99):crapper / mutator 直接调原版
-- busted.runner。子进程按 uml 钉死环境装 package.path(仅仓根 + 项目缓存),
-- 只跑 test/fixtures/stock_busted 下的样本,不跑整套。
local check = require("luassert")
local proc = require("foundation.proc")
local lua54 = require("foundation.lua54")
local root = require("foundation.bootstrap").resolve(debug.getinfo(1, "S").source).repo_root:gsub("\\", "/")

local function _stock_busted(spec)
  local share = root .. "/.toolcache/luarocks/share/lua/5.4"
  local pinned = "package.path = " .. string.format("%q", table.concat({ root .. "/?.lua", root .. "/?/init.lua",
    share .. "/?.lua", share .. "/?/init.lua" }, ";"))
    .. "; package.cpath = " .. string.format("%q", root .. "/.toolcache/luarocks/lib/lua/5.4/?.dll")
  return proc.run_command({ lua54.lua54_bin(), "-e",
    pinned .. "; require('busted.runner')({ standalone = false }); os.exit(0)",
    "--", "busted", "--ignore-lua", spec }, { cwd = root })
end

describe("uml quality stock busted adapter", function()

it("runs specs through test/helper.lua with project events and relative chunk names", function()
  local result = _stock_busted("test/fixtures/stock_busted/test_adapter.lua")
  check.equal(0, result.code, result.output)
  check.truthy(result.output:find("1..2", 1, true), result.output)
end)

it("keeps a failing assertion failing", function()
  local result = _stock_busted("test/fixtures/stock_busted/test_failing.lua")
  check.equal(1, result.code, result.output)
  check.truthy(result.output:find("not ok 1", 1, true), result.output)
end)

end)
