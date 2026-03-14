local bootstrap = require("tests.bootstrap")
local common = require("lib.common")
local mutate = require("mutate")
local driver = require("quality.mutate_monopoly_driver")

bootstrap.install_package_paths()

local function _assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function _buffer()
  local parts = {}
  return {
    write = function(_, text)
      parts[#parts + 1] = text
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

local function _test_wrapper_invokes_go_binary_for_mutate()
  local out = _buffer()
  local err = _buffer()
  local captured_command = nil
  local exit_code = mutate.run({
    "src/core/utils/role_id.lua",
    "--lane",
    "behavior",
    "--mode",
    "release_trimmed",
    "--since-last-run",
    "--json",
  }, {
    stdout = out,
    stderr = err,
    workspace_root = "/repo",
    ensure_binary = function(path)
      return path, nil
    end,
    run_command = function(command)
      captured_command = command
      return { ok = true, code = 0, output = "ok\n" }
    end,
  })

  assert(exit_code == 0, "wrapper should return command exit code")
  assert(captured_command[2] == "mutate", "wrapper should default to mutate subcommand")
  assert(captured_command[4] == "src/core/utils/role_id.lua", "wrapper should pass target via --target")
  _assert_contains(table.concat(captured_command, " "), "--lane behavior", "wrapper should keep lane option")
  _assert_contains(table.concat(captured_command, " "), "--mode release_trimmed", "wrapper should keep mode option")
  _assert_contains(table.concat(captured_command, " "), "--since-last-run", "wrapper should keep mutation selection flags")
  _assert_contains(table.concat(captured_command, " "), "--json", "wrapper should pass json flag through")
  assert(out:text() == "ok\n", "wrapper should write stdout for successful command")
  assert(err:text() == "", "wrapper should not write stderr for successful command")
end

local function _test_wrapper_routes_scan_update_and_index_commands()
  local captured = {}
  local function _capture(args)
    mutate.run(args, {
      workspace_root = "/repo",
      ensure_binary = function(path)
        return path, nil
      end,
      run_command = function(command)
        captured[#captured + 1] = table.concat(command, " ")
        return { ok = true, code = 0, output = "" }
      end,
    })
  end

  _capture({ "src/demo.lua", "--scan" })
  _capture({ "src/demo.lua", "--update-manifest" })
  _capture({ "--index-suites", "--lane", "behavior" })

  _assert_contains(captured[1], " scan ", "--scan should map to scan subcommand")
  _assert_contains(captured[2], " migrate-manifest ", "--update-manifest should map to migrate-manifest subcommand")
  _assert_contains(captured[3], " index-suites ", "--index-suites should map to index-suites subcommand")
end

local function _test_wrapper_help_is_bilingual()
  local out = _buffer()
  local err = _buffer()

  local exit_code = mutate.run({ "--help" }, {
    stdout = out,
    stderr = err,
  })

  assert(exit_code == 0, "help should succeed")
  _assert_contains(out:text(), "用法", "wrapper help should include Chinese usage text")
  _assert_contains(out:text(), "Usage", "wrapper help should include English usage text")
  _assert_contains(out:text(), "--index-suites", "wrapper help should document suite preheat")
  assert(err:text() == "", "help should not write stderr")
end

local function _test_driver_lists_suite_modules_as_json()
  local suites = {
    { name = "suite_a", module_name = "suite.a", tests = {} },
    { name = "suite_b", module_name = "suite.b", tests = {} },
  }
  local out = _buffer()
  local exit_code = driver.run({
    "--lane", "behavior",
    "--list-suites",
    "--json",
  }, {
    stdout = out,
    resolve_lane_suites = function()
      return suites, "dev"
    end,
  })

  assert(exit_code == 0, "list-suites should succeed")
  _assert_contains(out:text(), "suite.a", "json output should include suite.a")
  _assert_contains(out:text(), "suite.b", "json output should include suite.b")
end

local function _test_driver_behavior_mode_writes_repo_relative_coverage()
  local root = _temp_dir("mutate_driver_behavior")
  local source_path = common.join_path(root, "src/probe.lua")
  local coverage_file = common.join_path(root, "coverage.txt")
  local captured_mode = nil
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
    "--mode", "release_trimmed",
    "--coverage-file", coverage_file,
  }, {
    project_root = root,
    resolve_lane_suites = function(lane, mode)
      captured_lane = lane
      return { { name = "fake", module_name = "suite.fake", tests = { { name = "probe", run = function() dofile(source_path)() end } } } }, mode
    end,
    run_all = function(suites, opts)
      captured_mode = opts.mode
      return require("TestHarness").run_all(suites, opts)
    end,
  })

  local coverage = common.read_file(coverage_file)
  _cleanup(root)

  assert(exit_code == 0, "driver should succeed when suites pass")
  assert(captured_lane == "behavior", "driver should resolve requested lane")
  assert(captured_mode == "release_trimmed", "behavior lane should preserve requested mode")
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
    resolve_lane_suites = function(_, mode)
      return {
        { name = "suite_a", module_name = "suite.a", tests = { { name = "a", run = function() executed[#executed + 1] = "a" end } } },
        { name = "suite_b", module_name = "suite.b", tests = { { name = "b", run = function() executed[#executed + 1] = "b" end } } },
      }, mode
    end,
    run_all = function(suites, opts)
      return require("TestHarness").run_all(suites, opts)
    end,
  })

  _cleanup(root)
  assert(exit_code == 0, "suite-list-file execution should succeed")
  assert(#executed == 1 and executed[1] == "b", "driver should only run suites from suite list file")
end

local function _test_driver_contract_forces_dev_mode()
  local captured_mode = nil
  local exit_code = driver.run({
    "--lane", "contract",
    "--mode", "release_trimmed",
    "--coverage-file", common.make_temp_path("mutate_contract", ".coverage"),
  }, {
    project_root = "/repo",
    resolve_lane_suites = function()
      return { { name = "fake", tests = {} } }, "dev"
    end,
    run_all = function(_, opts)
      captured_mode = opts.mode
      return { failed = false }
    end,
  })

  assert(exit_code == 0, "contract lane should succeed for passing suites")
  assert(captured_mode == "dev", "contract lane should always run in dev mode")
end

return {
  name = "architecture.mutate4lua_contract",
  tests = {
    { name = "wrapper_invokes_go_binary_for_mutate", run = _test_wrapper_invokes_go_binary_for_mutate },
    { name = "wrapper_routes_scan_update_and_index_commands", run = _test_wrapper_routes_scan_update_and_index_commands },
    { name = "wrapper_help_is_bilingual", run = _test_wrapper_help_is_bilingual },
    { name = "driver_lists_suite_modules_as_json", run = _test_driver_lists_suite_modules_as_json },
    { name = "driver_behavior_mode_writes_repo_relative_coverage", run = _test_driver_behavior_mode_writes_repo_relative_coverage },
    { name = "driver_suite_list_file_filters_suites", run = _test_driver_suite_list_file_filters_suites },
    { name = "driver_contract_forces_dev_mode", run = _test_driver_contract_forces_dev_mode },
  },
}
