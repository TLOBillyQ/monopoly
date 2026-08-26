local bootstrap = require("test.bootstrap")
local catalog = require("test.support.catalog")
local fs_lib = require("foundation.fs")
local mutate = require("packages.mutate.runner")

bootstrap.install_package_paths()

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function _assert_not_contains(text, unexpected, message)
  if tostring(text or ""):find(unexpected, 1, true) ~= nil then
    error((message or "unexpected text found") .. "\nunexpected: " .. tostring(unexpected) .. "\nactual: " .. tostring(text))
  end
end

local function _buffer()
  local parts = {}
  return {
    write = function(_, ...)
      local count = select("#", ...)
      for index = 1, count do
        parts[#parts + 1] = tostring(select(index, ...))
      end
    end,
    text = function()
      return table.concat(parts)
    end,
  }
end

-- 引擎行为 case 一律注入 proceed guard(#325):真实 guard 在 PATH lua≠5.4 的
-- 宿主上会 re-exec(输出落子进程终端,进不了 buffer)——那正是门禁的正确行为,
-- 由 packages.mutate.lua54_guard 单测与下方 require_guard_* 接入 case 覆盖。
-- 此处注入 proceed 只为把引擎行为从宿主环境里解耦出来稳定断言。
local _PROCEED_GUARD = {
  ensure = function()
    return "proceed"
  end,
}

local function _test_wrapper_delegates_to_lua_cli()
  local out = _buffer()
  local err = _buffer()
  local exit_code = mutate._run_guarded(_PROCEED_GUARD, {
    "src/foundation/identity.lua",
    "--scan",
  }, {
    stdout = out,
    stderr = err,
  })

  _assert_eq(type(exit_code), "number", "wrapper should return numeric exit code")
  local output = out:text() .. err:text()
  assert(output ~= "", "scan should produce output")
end

local function _test_wrapper_routes_scan_command()
  local out = _buffer()
  local err = _buffer()
  local exit_code = mutate._run_guarded(_PROCEED_GUARD, {
    "src/foundation/identity.lua",
    "--scan",
  }, {
    stdout = out,
    stderr = err,
  })

  local output = out:text()
  local has_sites = output:find("sites:", 1, true) ~= nil
    or output:find('"sites"', 1, true) ~= nil
  assert(has_sites or exit_code == 0, "scan should produce sites output or succeed")
end

local function _test_wrapper_help_is_bilingual_and_lists_new_cli_options()
  local out = _buffer()
  local err = _buffer()

  local exit_code = mutate._run_guarded(_PROCEED_GUARD, {"--help"}, {
    stdout = out,
    stderr = err,
  })

  assert(exit_code == 0, "help should succeed")
  _assert_contains(out:text(), "用法", "wrapper help should include Chinese usage text")
  _assert_contains(out:text(), "Usage", "wrapper help should include English usage text")
  -- mutate4lua v0.1.0：driver 契约选项已删，差分/覆盖率选项纳入。
  _assert_contains(out:text(), "--since-last-run", "wrapper help should document since-last-run")
  _assert_contains(out:text(), "--reuse-coverage", "wrapper help should document reuse-coverage")
  _assert_contains(out:text(), "--mutate-all", "wrapper help should document mutate-all")
  _assert_not_contains(out:text(), "--index-suites", "wrapper help must not document removed suite preheat")
  _assert_not_contains(out:text(), "--lane", "wrapper help must not document removed lane option")
  assert(err:text() == "", "help should not write stderr")
end

local function _test_no_go_binary_references_in_wrapper()
  local wrapper_path = mutate.env.cwd .. "/tools/packages/mutate/runner.lua"
  local content = fs_lib.read_file(wrapper_path)
  _assert_not_contains(content, "ensure_" .. "binary", "wrapper should not reference removed binary resolver")
  _assert_not_contains(content, "mutate4lua-" .. "engine", "wrapper should not reference removed engine binary name")
  _assert_not_contains(content, "go " .. "build", "wrapper should not reference removed build command")
  _assert_not_contains(content, "engine_bridge", "wrapper should not reference engine_bridge")
  _assert_not_contains(content, "busted_adapter", "wrapper should not reference the removed driver adapter")
  _assert_not_contains(content, "default_driver", "wrapper should not reference the removed driver contract")
end

local function _test_wrapper_uses_luarocks_tree_layout()
  local wrapper_path = mutate.env.cwd .. "/tools/packages/mutate/runner.lua"
  local wrapper = fs_lib.read_file(wrapper_path)
  _assert_contains(wrapper, "packages.mutate.mutate4lua_paths", "wrapper should delegate reference path setup to package helper")
  _assert_not_contains(wrapper, "/mutate4lua/lua/?.lua", "wrapper should not use removed lua module layout")

  local helper_path = mutate.env.cwd .. "/tools/packages/mutate/mutate4lua_paths.lua"
  local helper = fs_lib.read_file(helper_path)
  _assert_contains(helper, "/share/lua/5.4", "shared helper should load mutate4lua from luarocks tree")
  _assert_not_contains(helper, "/lib", "shared helper should not retain removed lib layout fallback")
  _assert_contains(helper, "/?.lua", "shared helper should load plain lua module pattern")
  _assert_contains(helper, "/?/init.lua", "shared helper should load init module pattern")
end

-- #361 P8:no_go_binary_references_in_reference_cli 已删——扫描对象是
-- .toolcache/luarocks tree 里的第三方 rock 源码是钉定装载面，文本不受
-- 本仓控制、升级即假红(此前已因撞上游注释收窄过一次断言);「go binary 不回潮」
-- 的正确护栏是 tools.lock 钉版 + 下方本仓 wrapper 文本扫描(保留)。

-- issue #325：require 形态由 cli.lua → tool_cli 进程内委托
-- 必须与脚本形态走同一 Lua 5.4 门禁——否则 PATH 上 lua=5.5 的机器上 cli.lua
-- 直跑引擎,shim PATH 注入从不生效,沙箱基线以 5.5 语义跑全量 suite 假红。
-- guard 判定/幂等由 packages.mutate.lua54_guard 单测保证;此处钉 runner 接入
-- 点:注入 guard 实现,断言 run 按其裁定分支(失败→1+诊断 / reexec→退出码透传
-- 且不跑引擎 / proceed→照常跑引擎)。

local function _test_require_guard_fails_fast_with_diagnostic()
  local out = _buffer()
  local err = _buffer()
  local code = mutate._run_guarded({
    ensure = function()
      return nil,
        "mutate lane aborted: no Lua 5.4 interpreter found (set LUA54_BIN to override)."
    end,
  }, { "src/foundation/identity.lua" }, { stdout = out, stderr = err })

  _assert_eq(code, 1, "guard failure should exit 1 without running the engine")
  _assert_contains(err:text(), "Lua 5.4", "diagnostic should reach the caller's stderr channel")
  _assert_eq(out:text(), "", "guard failure should not write stdout")
end

local function _test_require_guard_reexec_passthroughs_exit_code_without_running_engine()
  local out = _buffer()
  local err = _buffer()
  local code = mutate._run_guarded({
    ensure = function()
      return "reexec", 42
    end,
  }, { "x.lua" }, { stdout = out, stderr = err })

  _assert_eq(code, 42, "reexec exit code should pass through; a real engine run would not return 42")
  _assert_eq(out:text(), "", "reexec should not write stdout")
  _assert_eq(err:text(), "", "reexec should not write stderr")
end

-- proceed 分支(guard 通过 → 跑真实引擎)由上方注入 _PROCEED_GUARD 的
-- wrapper_* case 覆盖,不重复钉。

local function _test_contract_lane_excludes_tooling_smoke_cases()
  local suites = catalog.load_contract_suites()
  local cases_by_suite = {}
  for _, suite in ipairs(suites) do
    local names = {}
    for _, test in ipairs(suite.tests or {}) do
      names[#names + 1] = test.name
    end
    cases_by_suite[suite.name] = table.concat(names, ",")
  end

  assert((cases_by_suite["script_tools_contract"] or ""):find("mutate_wrapper_scan_output", 1, true) == nil,
    "contract lane should exclude mutate scanning tooling smoke")
  assert((cases_by_suite["script_tools_contract"] or ""):find("deploy_comprehensive", 1, true) == nil,
    "contract lane should exclude deploy powershell smoke")
  assert((cases_by_suite["script_tools_contract"] or ""):find("run_command_preserves_bilingual_stderr_and_utf8_stdin", 1, true) == nil,
    "contract lane should exclude subprocess stderr smoke")
  assert((cases_by_suite["architecture.arch_view_contract"] or ""):find("cli_scan_writes_metadata", 1, true) == nil,
    "contract lane should exclude arch_view scan tooling smoke")
  assert((cases_by_suite["architecture.arch_view_contract"] or ""):find("viewer_command_writes_static_bundle", 1, true) == nil,
    "contract lane should exclude arch_view viewer tooling smoke")
end

return {
  name = "mutate4lua_tooling_contract",
  tests = {
    { name = "wrapper_delegates_to_lua_cli", run = _test_wrapper_delegates_to_lua_cli },
    { name = "wrapper_routes_scan_command", run = _test_wrapper_routes_scan_command },
    { name = "wrapper_help_is_bilingual_and_lists_new_cli_options", run = _test_wrapper_help_is_bilingual_and_lists_new_cli_options },
    { name = "no_go_binary_references_in_wrapper", run = _test_no_go_binary_references_in_wrapper },
    { name = "wrapper_uses_luarocks_tree_layout", run = _test_wrapper_uses_luarocks_tree_layout },
    { name = "require_guard_fails_fast_with_diagnostic", run = _test_require_guard_fails_fast_with_diagnostic },
    { name = "require_guard_reexec_passthroughs_exit_code_without_running_engine", run = _test_require_guard_reexec_passthroughs_exit_code_without_running_engine },
    { name = "contract_lane_excludes_tooling_smoke_cases", run = _test_contract_lane_excludes_tooling_smoke_cases },
  },
}
