---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/lint/test/test_lint_runner.lua") end
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local bootstrap = require("foundation.bootstrap")
local proc_lib = require("foundation.proc")
local availability = require("foundation.tool_availability")
local runner = require("packages.lint.runner")

-- 替换 luacheck 自举与 stderr,跑一次 runner.run,返回退出码与 stderr 文本。
local function _run_with_luacheck_bootstrap(ensure)
  local saved_ensure, saved_run, saved_stderr = bootstrap.ensure_luacheck_tree, proc_lib.run_command, io.stderr
  local written = {}
  bootstrap.ensure_luacheck_tree = ensure
  proc_lib.run_command = function() error("luacheck must not run when its bootstrap failed") end
  rawset(io, "stderr", { write = function(_, ...)
    for _, part in ipairs({ ... }) do written[#written + 1] = tostring(part) end
  end })
  local ok, code = pcall(runner.run, { "tools/packages/lint" })
  bootstrap.ensure_luacheck_tree, proc_lib.run_command = saved_ensure, saved_run
  rawset(io, "stderr", saved_stderr)
  if not ok then error(code, 0) end
  return code, table.concat(written)
end

describe("lint runner bootstrap", function()

-- #112:luacheck 装不上(网络)是不可用,不是 lint 失败——退 3,诊断点名工具与步骤。
it("luacheck install network failure reports unavailable", function()
  local code, stderr = _run_with_luacheck_bootstrap(function()
    local detail = "luarocks install failed for luacheck: Error: Failed downloading luacheck"
    return nil, detail, availability.unavailable("luacheck", "install", detail)
  end)
  check.equal(3, code)
  check.matches("[lint] status=unavailable tool=luacheck step=install", stderr, 1, true)
  check.matches("未运行", stderr, 1, true)
  check.matches("Failed downloading luacheck", stderr, 1, true)
end)

it("non network bootstrap failure stays a real failure", function()
  local code, stderr = _run_with_luacheck_bootstrap(function() return nil, "mkdir failed" end)
  check.equal(1, code)
  check.equal("mkdir failed\n", stderr)
end)

end)
