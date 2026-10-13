---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_tool_cli.lua") end

require("test.bootstrap").install_package_paths()

local check = require("luassert")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local tool_cli = require("foundation.tool_cli")


-- 每个用例一间临时 fixture 仓:package.path 挂上临时目录,teardown 时还原并
-- 清掉 require 缓存,避免用例间串扰。
local function _with_fixture_root(body)
  local root = env_lib.make_temp_path("tool_cli_spec", "")
  fs_lib.remove_path(root)
  check.is_true(fs_lib.ensure_dir(root))
  local original_path = package.path
  package.path = package.path .. ";" .. root .. "/?.lua"
  local ok, err = pcall(body, root)
  package.path = original_path
  package.loaded["fixture_runner"] = nil
  fs_lib.remove_path(root)
  if not ok then
    error(err, 2)
  end
end

describe("tool cli", function()
it("normalize exit code passes numbers through", function()
  check.equal(tool_cli.normalize_exit_code(0), 0)
  check.equal(tool_cli.normalize_exit_code(1), 1)
  check.equal(tool_cli.normalize_exit_code(2), 2)
end)

it("normalize exit code maps truthy and falsy", function()
  check.equal(tool_cli.normalize_exit_code(true), 0)
  check.equal(tool_cli.normalize_exit_code(false), 1)
  check.equal(tool_cli.normalize_exit_code(nil), 1)
end)

it("merge env overlays overrides on base", function()
  local merged = tool_cli.merge_env({ from_base = "base", shared = "base-default" }, { shared = "override" })

  check.equal(merged.from_base, "base")
  check.equal(merged.shared, "override")
end)

it("merge env tolerates nil sides and does not mutate inputs", function()
  local base = { key = "base" }
  local overrides = { key = "override" }

  check.same(tool_cli.merge_env(nil, nil), {})
  check.same(tool_cli.merge_env(base, nil), { key = "base" })
  check.same(tool_cli.merge_env(nil, overrides), { key = "override" })
  check.same(base, { key = "base" })
  check.same(overrides, { key = "override" })
end)

it("run passes caller env through untouched", function()
  _with_fixture_root(function(root)
    -- fixture 故意带 env 字段:断言 adapter 对它视而不见(不替 runner 合并)
    check.is_true(fs_lib.write_file(path_lib.join_path(root, "fixture_runner.lua"), table.concat({
      "local M = { env = { from_runner = 'runner', shared = 'runner-default' } }",
      "function M.run(args, env)",
      "  M.captured = { args = args, env = env }",
      "  return 3",
      "end",
      "return M",
      "",
    }, "\n")))

    local caller_env = { shared = "caller", from_caller = "yes" }
    local code = tool_cli.run(
      { runner_module = "fixture_runner", runner_script = "missing/runner.lua" },
      { "a", "b" },
      caller_env
    )

    check.equal(code, 3)
    local captured = require("fixture_runner").captured
    check.same(captured.args, { "a", "b" })
    -- merge 职责在 runner 侧(#323):cli adapter 原样透传,不替 runner 合并
    check.equal(captured.env, caller_env)
  end)
end)

it("run normalizes boolean runner results", function()
  _with_fixture_root(function(root)
    check.is_true(fs_lib.write_file(path_lib.join_path(root, "fixture_runner.lua"), table.concat({
      "local M = {}",
      "function M.run() return M.result end",
      "return M",
      "",
    }, "\n")))
    local runner = require("fixture_runner")

    runner.result = true
    check.equal(tool_cli.run({ runner_module = "fixture_runner", runner_script = "missing" }, {}, nil), 0)
    runner.result = false
    check.equal(tool_cli.run({ runner_module = "fixture_runner", runner_script = "missing" }, {}, nil), 1)
  end)
end)

it("run falls back to subprocess when module missing", function()
  _with_fixture_root(function(root)
    local script = path_lib.join_path(root, "fixture_script.lua")
    check.is_true(fs_lib.write_file(script, "os.exit(tonumber(arg[1]))\n"))

    local code = tool_cli.run(
      { runner_module = "no_such_module_xyz", runner_script = script },
      { "7" },
      nil
    )

    check.equal(code, 7)
  end)
end)

it("forward subprocess passes args and exit code", function()
  _with_fixture_root(function(root)
    local script = path_lib.join_path(root, "fixture_script.lua")
    check.is_true(fs_lib.write_file(script, "assert(arg[1] == 'has space')\nos.exit(5)\n"))

    check.equal(tool_cli.forward_subprocess(script, { "has space" }), 5)
  end)
end)

-- lua_bin 显式钉定(#453):crap 在非 5.4 解释器下 re-exec 到 lua5.4,
-- 子进程由钉定解释器执行而非 PATH 上的 lua。fixture 断言解释器身份。
it("forward subprocess honors explicit lua bin", function()
  _with_fixture_root(function(root)
    local script = path_lib.join_path(root, "fixture_lua54.lua")
    check.is_true(fs_lib.write_file(script,
      "assert(_VERSION == 'Lua 5.4', 'must run under Lua 5.4, got ' .. _VERSION)\nos.exit(5)\n"))
    local lua54 = require("packages.luaunit_runner.lua54")

    check.equal(tool_cli.forward_subprocess(script, {}, lua54.detect_lua54()), 5)
  end)
end)

end)
