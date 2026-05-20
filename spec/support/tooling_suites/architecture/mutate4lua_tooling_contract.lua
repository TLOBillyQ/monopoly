local bootstrap = require("spec.bootstrap")
local catalog = require("tools.quality.shared.test_catalog")
local common = require("shared.lib.common")
local mutate = require("quality.mutate")
local driver = require("quality.mutate.driver")

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

local function _temp_dir(name)
  local path = common.make_temp_path(name, "")
  local ok, err = common.ensure_dir(path)
  if not ok then
    error(err)
  end
  return path
end

local function _cleanup(path)
  if path ~= nil and path ~= "" then
    common.remove_path(path)
  end
end

local function _test_wrapper_delegates_to_lua_cli()
  local out = _buffer()
  local err = _buffer()
  local exit_code = mutate.run({
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

local function _test_wrapper_routes_scan_and_index_commands()
  local out = _buffer()
  local err = _buffer()
  local exit_code = mutate.run({
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

local function _test_wrapper_help_is_bilingual()
  local out = _buffer()
  local err = _buffer()

  local exit_code = mutate.run({"--help"}, {
    stdout = out,
    stderr = err,
  })

  assert(exit_code == 0, "help should succeed")
  _assert_contains(out:text(), "用法", "wrapper help should include Chinese usage text")
  _assert_contains(out:text(), "Usage", "wrapper help should include English usage text")
  _assert_contains(out:text(), "--index-suites", "wrapper help should document suite preheat")
  assert(err:text() == "", "help should not write stderr")
end

local function _test_no_go_binary_references_in_wrapper()
  local wrapper_path = mutate.env.cwd .. "/tools/quality/mutate.lua"
  local content = common.read_file(wrapper_path)
  _assert_not_contains(content, "ensure_" .. "binary", "wrapper should not reference removed binary resolver")
  _assert_not_contains(content, "mutate4lua-" .. "engine", "wrapper should not reference removed engine binary name")
  _assert_not_contains(content, "go " .. "build", "wrapper should not reference removed build command")
  _assert_not_contains(content, "engine_bridge", "wrapper should not reference engine_bridge")
end

local function _test_wrapper_uses_vendor_lib_layout()
  local wrapper_path = mutate.env.cwd .. "/tools/quality/mutate.lua"
  local content = common.read_file(wrapper_path)
  _assert_contains(content, "/mutate4lua/lib", "wrapper should load mutate4lua lib module layout")
  _assert_contains(content, "/?.lua", "wrapper should load plain lua module pattern")
  _assert_contains(content, "/?/init.lua", "wrapper should load init module pattern")
  _assert_not_contains(content, "/mutate4lua/lua/?.lua", "wrapper should not use removed lua module layout")
end

local function _test_no_go_binary_references_in_vendor_cli()
  local cli_path = mutate.env.cwd .. "/vendor/mutate4lua/lib/mutate4lua/cli.lua"
  local content = common.read_file(cli_path)
  assert(content ~= nil, "vendor cli should exist at lib layout")
  _assert_not_contains(content, "ensure_" .. "binary", "vendor cli should not reference removed binary resolver")
  _assert_not_contains(content, "engine_bridge", "vendor cli should not reference engine_bridge")
  _assert_not_contains(content, "go " .. "build", "vendor cli should not reference removed build command")
end

local function _test_driver_lists_suite_modules_as_json()
  local suites = {
    {name = "suite_a", module_name = "suite.a", tests = {}},
    {name = "suite_b", module_name = "suite.b", tests = {}},
  }
  local out = _buffer()
  local exit_code = driver.run({
    "--lane", "behavior",
    "--list-suites",
    "--json",
  }, {
    stdout = out,
    resolve_lane_suites = function()
      return suites
    end,
  })

  assert(exit_code == 0, "list-suites should succeed")
  _assert_contains(out:text(), "suite.a", "json output should include suite.a")
  _assert_contains(out:text(), "suite.b", "json output should include suite.b")
end

local function _test_driver_emits_suite_file_map_json_without_line_granularity()
  local root = _temp_dir("mutate_driver_index_map")
  local source_a = common.join_path(root, "src/probe_a.lua")
  local source_b = common.join_path(root, "src/probe_b.lua")
  local ok, err = common.ensure_dir(common.join_path(root, "src"))
  if not ok then
    _cleanup(root)
    error(err)
  end
  ok, err = common.write_file(source_a, "local M = {}\nfunction M.run()\n  return 'a'\nend\nreturn M\n")
  if not ok then
    _cleanup(root)
    error(err)
  end
  ok, err = common.write_file(source_b, "local M = {}\nfunction M.run()\n  return 'b'\nend\nreturn M\n")
  if not ok then
    _cleanup(root)
    error(err)
  end

  local original_package_loaded = package.loaded
  package.loaded = setmetatable({}, {__index = original_package_loaded})

  local out = _buffer()
  local exit_code = driver.run({
    "--lane", "behavior",
    "--emit-suite-file-map-json",
  }, {
    stdout = out,
    stderr = _buffer(),
    project_root = root,
    resolve_lane_suites = function()
      return {
        {
          name = "suite_a",
          module_name = "suite.a",
          tests = {
            {name = "probe_a", run = function() assert(dofile(source_a).run() == "a") end},
          },
        },
        {
          name = "suite_b",
          module_name = "suite.b",
          tests = {
            {name = "probe_b", run = function() assert(dofile(source_b).run() == "b") end},
          },
        },
      }
    end,
  })

  package.loaded = original_package_loaded
  _cleanup(root)

  assert(exit_code == 0, "emit-suite-file-map-json should succeed")
  _assert_contains(out:text(), '"suite.a"', "suite file map should include suite.a key")
  _assert_contains(out:text(), '"suite.b"', "suite file map should include suite.b key")
  _assert_contains(out:text(), '"src/probe_a.lua"', "suite file map should use repo-relative file paths")
  _assert_contains(out:text(), '"src/probe_b.lua"', "suite file map should use repo-relative file paths")
  assert(out:text():find("src/probe_a.lua:") == nil, "suite file map should not include line-level coverage entries")
end

local function _test_driver_writes_repo_relative_coverage()
  local root = _temp_dir("mutate_driver_behavior")
  local source_path = common.join_path(root, "src/probe.lua")
  local coverage_file = common.join_path(root, "coverage.txt")
  local captured_lane = nil

  local ok, err = common.ensure_dir(common.join_path(root, "src"))
  if not ok then
    _cleanup(root)
    error(err)
  end
  ok, err = common.write_file(source_path, "local value = 1\nreturn function()\n  return value\nend\n")
  if not ok then
    _cleanup(root)
    error(err)
  end

  local exit_code = driver.run({
    "--lane", "behavior",
    "--coverage-file", coverage_file,
  }, {
    project_root = root,
    resolve_lane_suites = function(lane)
      captured_lane = lane
      return {{name = "fake", module_name = "suite.fake", tests = {{name = "probe", run = function() dofile(source_path)() end}}}}
    end,
  })

  local coverage = common.read_file(coverage_file)
  _cleanup(root)

  assert(exit_code == 0, "driver should succeed when suites pass")
  assert(captured_lane == "behavior", "driver should resolve requested lane")
  _assert_contains(coverage, "src/probe.lua:1", "coverage output should use repo-relative lua paths")
end

local function _test_driver_suite_list_file_filters_suites()
  local root = _temp_dir("mutate_driver_suite_list")
  local coverage_file = common.join_path(root, "coverage.txt")
  local suite_list_file = common.join_path(root, "suites.txt")
  local ok, err = common.write_file(suite_list_file, "suite.b\n")
  if not ok then
    _cleanup(root)
    error(err)
  end

  local executed = {}
  local exit_code = driver.run({
    "--lane", "behavior",
    "--coverage-file", coverage_file,
    "--suite-list-file", suite_list_file,
    "--quiet",
  }, {
    project_root = root,
    resolve_lane_suites = function()
      return {
        {name = "suite_a", module_name = "suite.a", tests = {{name = "a", run = function() executed[#executed + 1] = "a" end}}},
        {name = "suite_b", module_name = "suite.b", tests = {{name = "b", run = function() executed[#executed + 1] = "b" end}}},
      }
    end,
    run_all = function(suites, opts)
      return require("tools.quality.shared.test_harness").run_all(suites, opts)
    end,
  })

  _cleanup(root)
  assert(exit_code == 0, "suite-list-file execution should succeed")
  assert(#executed == 1 and executed[1] == "b", "driver should only run suites from suite list file")
end

local function _test_driver_contract_lane_runs_without_mode_switching()
  local captured_mode = "__unset__"
  local exit_code = driver.run({
    "--lane", "contract",
    "--coverage-file", common.make_temp_path("mutate_contract", ".coverage"),
  }, {
    project_root = "/repo",
    resolve_lane_suites = function()
      return {{name = "fake", tests = {}}}
    end,
    run_all = function(_, opts)
      captured_mode = opts.mode
      return {failed = false}
    end,
  })

  assert(exit_code == 0, "contract lane should succeed for passing suites")
  assert(captured_mode == nil, "driver should not pass a mode flag into harness")
end

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

  assert((cases_by_suite["script_tools_contract"] or ""):find("mutate_wrapper_indexes_behavior_suites_as_json", 1, true) == nil,
    "contract lane should exclude mutate indexing tooling smoke")
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
    {name = "wrapper_delegates_to_lua_cli", run = _test_wrapper_delegates_to_lua_cli},
    {name = "wrapper_routes_scan_and_index_commands", run = _test_wrapper_routes_scan_and_index_commands},
    {name = "wrapper_help_is_bilingual", run = _test_wrapper_help_is_bilingual},
    {name = "no_go_binary_references_in_wrapper", run = _test_no_go_binary_references_in_wrapper},
    {name = "wrapper_uses_vendor_lib_layout", run = _test_wrapper_uses_vendor_lib_layout},
    {name = "no_go_binary_references_in_vendor_cli", run = _test_no_go_binary_references_in_vendor_cli},
    {name = "driver_lists_suite_modules_as_json", run = _test_driver_lists_suite_modules_as_json},
    {name = "driver_emits_suite_file_map_json_without_line_granularity", run = _test_driver_emits_suite_file_map_json_without_line_granularity},
    {name = "driver_writes_repo_relative_coverage", run = _test_driver_writes_repo_relative_coverage},
    {name = "driver_suite_list_file_filters_suites", run = _test_driver_suite_list_file_filters_suites},
    {name = "driver_contract_lane_runs_without_mode_switching", run = _test_driver_contract_lane_runs_without_mode_switching},
    {name = "contract_lane_excludes_tooling_smoke_cases", run = _test_contract_lane_excludes_tooling_smoke_cases},
  },
}
