---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/uml_quality/test/test_uml_quality_runtime.lua") end
require("test.bootstrap").install_package_paths()

-- uml 质量入口的纯演算面(#93):子进程钉死的 Lua 装载环境、项目缓存来源判定与
-- Python 工具环境判定。真跑 crapper/mutator 不在本套件内。
local check = require("luassert")
local runtime = require("packages.uml_quality.runtime")

local ROOT = "/repo"
local CACHE = "/repo/.toolcache/luarocks"

local function _env_map(list)
  local map = {}
  for _, entry in ipairs(list) do map[entry[1]] = entry[2] end
  return map
end

describe("uml quality runtime", function()

-- 全局 %APPDATA%\luarocks tree 里也有 busted/luacov/lcov reporter;子进程若继承
-- 用户 LUA_PATH,就会从全局 tree 解析出「能跑」的假绿。装载面必须只剩仓根与项目缓存。
it("pins child lua module paths to the repo root and project cache only", function()
  local env = _env_map(runtime.pinned_env(ROOT, "/lua/bin", "/sys"))
  local expected_path = "/repo/?.lua;/repo/?/init.lua;"
    .. CACHE .. "/share/lua/5.4/?.lua;" .. CACHE .. "/share/lua/5.4/?/init.lua"
  check.equal(expected_path, env.LUA_PATH_5_4)
  check.equal(expected_path, env.LUA_PATH)
  check.equal(CACHE .. "/lib/lua/5.4/?.dll", env.LUA_CPATH_5_4)
  check.equal(CACHE .. "/lib/lua/5.4/?.dll", env.LUA_CPATH)
  check.equal("", env.LUA_INIT)
  check.equal("", env.LUA_INIT_5_4)
end)

-- crapper/mutator 用 PATH 上的 lua 解析解释器;选定的 Lua 5.4 目录排第一。
it("puts the selected lua 5.4 directory first on PATH", function()
  local env = _env_map(runtime.pinned_env(ROOT, "/lua/bin", "/sys;/tools"))
  check.equal("/lua/bin;/sys;/tools", env.PATH)
end)

-- uml view(#99 / ADR 0070):上游从 PATH 选 herdr X.Y.Z >= 0.9.3 的最高版;
-- 预检同口径逐段数值比较,不认非 X.Y.Z 的版本行。
it("accepts herdr X.Y.Z versions at or above 0.9.3", function()
  for _, line in ipairs({ "herdr 0.9.3\r\n", "herdr 0.9.4\n", "herdr 0.9.31", "herdr 0.10.0", "herdr 1.0.0" }) do
    check.is_true(runtime.herdr_verdict(line).ok, line)
  end
  for _, line in ipairs({ "herdr 0.9.2", "herdr 0.8.9", "herdr 0.9", "herdr 0.9.4-rc1", "herdr x" }) do
    check.is_false(runtime.herdr_verdict(line).ok, line)
  end
  check.is_false(runtime.herdr_verdict(nil).ok)
  check.equal("herdr 0.9.4", runtime.herdr_verdict("herdr 0.9.4\n").message)
end)

it("accepts a module resolved inside the project cache", function()
  local verdict = runtime.module_verdict("luacov.reporter.lcov",
    CACHE .. "/share/lua/5.4/luacov/reporter/lcov.lua", ROOT)
  check.is_true(verdict.ok)
end)

-- 反例:解析到全局 tree 或缺失都必须判失败,不能因为「能 require」就放行。
it("rejects a module resolved outside the project cache", function()
  local verdict = runtime.module_verdict("busted.runner",
    "/home/AppData/Roaming/luarocks/share/lua/5.4/busted/runner.lua", ROOT)
  check.is_false(verdict.ok)
  check.truthy(verdict.message:find("outside project cache", 1, true))
end)

it("rejects a module resolved from the repo root instead of the cache", function()
  local verdict = runtime.module_verdict("busted.runner", "/repo/busted/runner.lua", ROOT)
  check.is_false(verdict.ok)
end)

it("rejects a missing module", function()
  local verdict = runtime.module_verdict("luacov.reporter.lcov", nil, ROOT)
  check.is_false(verdict.ok)
  check.truthy(verdict.message:find("not found", 1, true))
end)

-- luarocks.loader 若可解析,会按用户 luarocks 配置把全局 tree 接回来;它必须不可见。
it("requires the luarocks loader to stay unresolvable", function()
  check.is_true(runtime.loader_verdict(nil).ok)
  check.is_false(runtime.loader_verdict("/luarocks/bin/lua/luarocks/loader.lua").ok)
end)

it("accepts a python tool from its own checkout with python 3.11 or newer", function()
  local verdict = runtime.python_verdict("crapper",
    "3.12.10\r\n\\REPO\\.uml-viewer\\crapper\\src\\crapper\\__init__.py\r\n", ROOT)
  check.is_true(verdict.ok)
end)

it("rejects python older than 3.11", function()
  local verdict = runtime.python_verdict("crapper",
    "3.10.4\n/repo/.uml-viewer/crapper/src/crapper/__init__.py\n", ROOT)
  check.is_false(verdict.ok)
  check.truthy(verdict.message:find("3.11", 1, true))
end)

it("rejects a python tool imported from outside its checkout", function()
  local verdict = runtime.python_verdict("mutator", "3.12.10\n/site-packages/mutator/__init__.py\n", ROOT)
  check.is_false(verdict.ok)
end)

-- 探针输出:resolve 行 = 必需模块的解析结果,load 行 = require 时实际装载的每个文件
-- (含传递依赖),error 行 = require 失败;loader 行 = luarocks.loader 是否可解析。
it("passes a probe whose every module and loaded file lives in the project cache", function()
  local output = table.concat({
    "resolve\tbusted.runner\t" .. CACHE .. "/share/lua/5.4/busted/runner.lua",
    "load\tsystem.core\t" .. CACHE .. "/lib/lua/5.4/system/core.dll",
    "loader\t",
  }, "\n")
  local ok, verdicts = runtime.probe_verdicts(output, ROOT)
  check.is_true(ok)
  check.equal(3, #verdicts)
end)

it("fails a probe when a transitively loaded file comes from the global tree", function()
  local output = table.concat({
    "resolve\tbusted.runner\t" .. CACHE .. "/share/lua/5.4/busted/runner.lua",
    "load\tsay\t/home/AppData/Roaming/luarocks/share/lua/5.4/say/init.lua",
    "loader\t",
  }, "\n")
  local ok, verdicts = runtime.probe_verdicts(output, ROOT)
  check.is_false(ok)
  check.is_false(verdicts[2].ok)
end)

it("fails a probe that reports a require error or nothing at all", function()
  local ok, verdicts = runtime.probe_verdicts("error\tluacov.reporter.lcov\tmodule not found\nloader\t", ROOT)
  check.is_false(ok)
  check.truthy(verdicts[1].message:find("module not found", 1, true))
  check.is_false((runtime.probe_verdicts("", ROOT)))
end)

-- 批处理里 % 会被 cmd 展开;环境值必须原样到达子进程。
it("writes env values into the batch without cmd expansion", function()
  local text = runtime.batch_text(ROOT, { { "LUA_PATH", "a%b" } }, { "lua.exe", "-v" })
  check.truthy(text:find('set "LUA_PATH=a%%b"', 1, true))
  check.truthy(text:find('cd /d "\\repo"', 1, true))
  check.truthy(text:find("exit /b %errorlevel%", 1, true))
end)

end)
