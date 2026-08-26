---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/crap/test/test_crap_cli_lua54_guard.lua") end
require("test.bootstrap").install_package_paths()

-- #453:lua tools/cli.lua crap 直调在 PATH 上 lua 非 5.4 时须 re-exec 到钉定
-- lua5.4(否则 luacov_adapter 进程内 require 5.4 ABI 的 cluacov C hook
-- Segfault)。本文件钉纯函数判定;main 的 re-exec 走 tool_cli.forward_subprocess
-- (其 lua_bin 参数契约见 tools/foundation/test/test_tool_cli.lua)。
local lu = require("luaunit")
local crap_cli = require("packages.crap.cli")

TestCrapCliLua54Guard = {}

function TestCrapCliLua54Guard:test_needs_reexec_when_not_lua54()
  lu.assertTrue(crap_cli.needs_lua54_reexec("Lua 5.5"))
  lu.assertTrue(crap_cli.needs_lua54_reexec("Lua 5.3"))
end

function TestCrapCliLua54Guard:test_no_reexec_under_lua54()
  lu.assertFalse(crap_cli.needs_lua54_reexec("Lua 5.4"))
end

-- main 的 --help 路由必须在 re-exec 判定之前(非 5.4 下 --help 也要能出 usage)。
function TestCrapCliLua54Guard:test_help_routed_before_reexec_guard()
  local ok, err = pcall(crap_cli.main, { "--help" }, nil)
  lu.assertTrue(ok, tostring(err))
end


return TestCrapCliLua54Guard
