---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/uml_quality/test/test_uml_quality_cli.lua") end
require("test.bootstrap").install_package_paths()

-- uml 子命令(#93)的退出码契约。真跑 crapper/mutator 不在本套件内;
-- 预检失败面用一个不含 .uml-viewer 检出、项目缓存装不上的临时仓根驱动。
local check = require("luassert")
local cli = require("packages.uml_quality.cli")
local bootstrap = require("foundation.bootstrap")
local env_lib = require("foundation.env")
local fs = require("foundation.fs")

local function _quiet(fn)
  local captured = {}
  local sink = { write = function(_, ...) for _, part in ipairs({ ... }) do captured[#captured + 1] = tostring(part) end end }
  local original_write, original_stderr = io.write, io.stderr
  rawset(io, "write", function(...) return sink:write(...) end)
  rawset(io, "stderr", sink)
  local ok, result = pcall(fn)
  rawset(io, "write", original_write)
  rawset(io, "stderr", original_stderr)
  if not ok then error(result, 0) end
  return result, table.concat(captured)
end

local function _with_offline_rocks(fn)
  local saved = {}
  for _, key in ipairs({ "ensure_busted_tree", "ensure_luassert_tree", "ensure_luacov_tree",
    "ensure_luacov_reporter_lcov_tree" }) do
    saved[key] = bootstrap[key]
    bootstrap[key] = function() return nil, "offline" end
  end
  local ok, err = pcall(fn)
  for key, value in pairs(saved) do bootstrap[key] = value end
  if not ok then error(err, 0) end
end

describe("uml quality cli", function()

it("prints usage on --help", function()
  local code, output = _quiet(function() return cli.main({ "--help" }, {}) end)
  check.equal(0, code)
  check.truthy(output:find("check|crap|mutate", 1, true))
end)

it("rejects a missing or unknown operation as usage error", function()
  check.equal(2, (_quiet(function() return cli.main({}, {}) end)))
  check.equal(2, (_quiet(function() return cli.main({ "ir" }, {}) end)))
  check.equal(2, (_quiet(function() return cli.main({ "check", "--extra" }, {}) end)))
end)

-- 反例:依赖缺失必须大声失败(非零,不是 3——3 是 mutate 的有效结果),
-- 且不能留下上一轮的 quality-result.json 让消费方读成本轮结果。
it("fails preflight loudly and clears a stale quality result", function()
  local root = env_lib.make_temp_path("uml_quality_cli", "")
  local stale = root .. "/.uml-viewer/quality-result.json"
  fs.ensure_parent_dir(stale)
  fs.write_file(stale, '{"version":1,"exitCode":0,"validResult":true}')
  local code, output
  _with_offline_rocks(function()
    code, output = _quiet(function() return cli.main({ "crap" }, { repo_root = root }) end)
  end)
  local stale_left = fs.path_exists(stale)
  fs.remove_path(root)
  check.equal(1, code)
  check.is_false(stale_left)
  check.truthy(output:find("FAIL project cache rock luacov-reporter-lcov: offline", 1, true))
  check.truthy(output:find("uml-command.ps1 missing", 1, true))
  check.truthy(output:find("crapper: ", 1, true))
  check.truthy(output:find("crap was not started", 1, true))
end)

end)
