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

local function _test_wrapper_defaults_to_behavior_lane_driver()
  local out = _buffer()
  local err = _buffer()
  local captured_driver_command = nil
  local captured_args = nil
  local captured_project_hash = nil
  local original_default_test_command = function()
    return { "original" }
  end
  local original_project_hash = function()
    return "original_hash"
  end
  local project_module = {
    default_test_command = original_default_test_command,
    project_hash = original_project_hash,
  }
  local main_module = {
    usage = function()
      return "upstream usage"
    end,
    run = function(args)
      captured_args = args
      captured_driver_command = project_module.default_test_command(nil, {
        target_file = "src/core/utils/role_id.lua",
        project_hash = "project_hash_123",
      })
      captured_project_hash = project_module.project_hash("/repo", "/repo/src/core/utils/role_id.lua", "return false\n")
      return 0
    end,
  }

  local exit_code = mutate.run({
    "src/core/utils/role_id.lua",
  }, {
    stdout = out,
    stderr = err,
    workspace_root = "/repo",
    main_module = main_module,
    project_module = project_module,
    project_hash_env = {
      list_project_files = function()
        return { "src/core/utils/role_id.lua", "tests/probe.lua" }
      end,
      read_file = function(path)
        if path == "/repo/tests/probe.lua" then
          return "assert(true)\n"
        end
        return nil
      end,
      normalize_newlines = function(text)
        return text
      end,
      hash_text = function(text)
        return text
      end,
    },
  })

  assert(exit_code == 0, "wrapper should return upstream exit code")
  assert(captured_args[1] == "src/core/utils/role_id.lua", "target file should pass through unchanged")
  assert(captured_driver_command[1] == "lua", "wrapper should inject lua command")
  assert(captured_driver_command[2] == "scripts/quality/mutate_monopoly_driver.lua",
    "wrapper should inject Monopoly mutation driver")
  assert(captured_driver_command[4] == "behavior", "wrapper should default to behavior lane")
  _assert_contains(table.concat(captured_driver_command, " "), "--target-file src/core/utils/role_id.lua",
    "wrapper should pass mutation target to default driver")
  _assert_contains(table.concat(captured_driver_command, " "), "--project-hash project_hash_123",
    "wrapper should pass project hash to default driver")
  _assert_contains(captured_project_hash, "src/core/utils/role_id.lua\nreturn false\n",
    "wrapper should replace target content when building project hash")
  _assert_contains(captured_project_hash, "tests/probe.lua\nassert(true)\n",
    "wrapper should include additional repo files in project hash")
  assert(project_module.default_test_command == original_default_test_command,
    "wrapper should restore original project default_test_command")
  assert(project_module.project_hash == original_project_hash,
    "wrapper should restore original project_hash")
  assert(out:text() == "", "wrapper should not write help output on normal runs")
  assert(err:text() == "", "wrapper should not write stderr on normal runs")
end

local function _test_wrapper_bypasses_default_driver_when_test_command_is_explicit()
  local captured_driver_command = nil
  local project_module = {
    default_test_command = function()
      return { "original" }
    end,
  }
  local main_module = {
    usage = function()
      return "upstream usage"
    end,
    run = function(args)
      captured_driver_command = project_module.default_test_command()
      assert(args[2] == "--test-command", "explicit test command should be preserved")
      return 0
    end,
  }

  local exit_code = mutate.run({
    "src/core/utils/role_id.lua",
    "--test-command",
    "lua tests/behavior.lua",
  }, {
    main_module = main_module,
    project_module = project_module,
    workspace_root = "/repo",
  })

  assert(exit_code == 0, "wrapper should still return upstream exit code")
  assert(captured_driver_command[1] == "original", "wrapper should not override explicit test commands")
end

local function _test_wrapper_help_is_bilingual()
  local out = _buffer()
  local err = _buffer()
  local main_module = {
    usage = function()
      return "mutate4lua <file.lua>"
    end,
  }

  local exit_code = mutate.run({
    "--help",
  }, {
    stdout = out,
    stderr = err,
    main_module = main_module,
    project_module = { default_test_command = function() return {} end },
  })

  assert(exit_code == 0, "help should succeed")
  _assert_contains(out:text(), "用法", "wrapper help should include Chinese usage text")
  _assert_contains(out:text(), "Usage", "wrapper help should include English usage text")
  _assert_contains(out:text(), "--lane behavior|contract", "wrapper help should document Monopoly lane option")
  _assert_contains(out:text(), "mutate4lua <file.lua>", "wrapper help should append upstream usage")
  assert(err:text() == "", "help should not write stderr")
end

local function _test_list_project_hash_files_ignores_mutate_cache()
  local files = mutate.list_project_hash_files("/repo", {
    list_project_files = function()
      return {
        "src/core/utils/role_id.lua",
        ".mutate4lua/cache/baseline/a.meta.lua",
        ".mutate4lua/cache/baseline/a.coverage",
        "tests/probe.lua",
      }
    end,
  })

  assert(#files == 2, "mutate cache files should be ignored")
  assert(files[1] == "src/core/utils/role_id.lua", "source file should stay in project hash input")
  assert(files[2] == "tests/probe.lua", "test file should stay in project hash input")
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
      return { { name = "fake", tests = { { name = "probe", run = function() dofile(source_path)() end } } } }, mode
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

local function _test_driver_select_suites_for_target_uses_cached_index()
  local suites = {
    { name = "suite_a", module_name = "suite.a", tests = {} },
    { name = "suite_b", module_name = "suite.b", tests = {} },
  }
  local selected = driver.select_suites_for_target("/repo", "behavior", "dev", "src/demo/target.lua", "abc", suites, {
    load_suite_index = function()
      return {
        ["suite.a"] = { ["src/demo/other.lua"] = true },
        ["suite.b"] = { ["src/demo/target.lua"] = true },
      }
    end,
  })

  assert(#selected == 1, "driver should keep only suites covering target file")
  assert(selected[1].module_name == "suite.b", "driver should select matching suite by module_name")
end

local function _test_driver_select_suites_for_target_falls_back_for_contract_lane()
  local suites = {
    { name = "suite_a", module_name = "suite.a", tests = {} },
    { name = "suite_b", module_name = "suite.b", tests = {} },
  }
  local selected = driver.select_suites_for_target("/repo", "contract", "dev", "src/demo/target.lua", "abc", suites, {})
  assert(#selected == 2, "contract lane should skip suite slicing")
end

return {
  name = "architecture.mutate4lua_contract",
  tests = {
    { name = "wrapper_defaults_to_behavior_lane_driver", run = _test_wrapper_defaults_to_behavior_lane_driver },
    { name = "wrapper_bypasses_default_driver_when_test_command_is_explicit", run = _test_wrapper_bypasses_default_driver_when_test_command_is_explicit },
    { name = "wrapper_help_is_bilingual", run = _test_wrapper_help_is_bilingual },
    { name = "list_project_hash_files_ignores_mutate_cache", run = _test_list_project_hash_files_ignores_mutate_cache },
    { name = "driver_select_suites_for_target_uses_cached_index", run = _test_driver_select_suites_for_target_uses_cached_index },
    { name = "driver_select_suites_for_target_falls_back_for_contract_lane", run = _test_driver_select_suites_for_target_falls_back_for_contract_lane },
    { name = "driver_behavior_mode_writes_repo_relative_coverage", run = _test_driver_behavior_mode_writes_repo_relative_coverage },
    { name = "driver_contract_forces_dev_mode", run = _test_driver_contract_forces_dev_mode },
  },
}
