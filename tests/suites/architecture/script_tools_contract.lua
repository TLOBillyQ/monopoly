local bootstrap = require("tests.bootstrap")
local common = require("shared.lib.common")
local arch_common = require("arch_view.runtime.common")
local arch_cli = require("quality.arch")
local deploy_defaults = require("ops.deploy_defaults")

bootstrap.install_package_paths()

local project_root = common.normalize_path(common.current_dir())

local function _make_tmp_root(tag)
  return common.make_temp_path("script_tools_contract_" .. tostring(tag or "tmp"), "") .. "_中文 English"
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

local function _cleanup_tmp(tmp_root)
  local ok, err = common.remove_path(tmp_root)
  if ok == nil then
    error(err)
  end
end

local function _with_clean_tmp(tag, fn)
  local tmp_root = _make_tmp_root(tag)
  _cleanup_tmp(tmp_root)
  local ok, err = xpcall(function()
    fn(tmp_root)
  end, debug.traceback)
  _cleanup_tmp(tmp_root)
  if not ok then
    error(err)
  end
end

local function _with_ascii_tmp(tag, fn)
  local tmp_root = common.make_temp_path("script_tools_contract_" .. tostring(tag or "tmp"), "")
  _cleanup_tmp(tmp_root)
  local ok, err = xpcall(function()
    fn(tmp_root)
  end, debug.traceback)
  _cleanup_tmp(tmp_root)
  if not ok then
    error(err)
  end
end

local function _run_lua(args)
  local command = { "lua" }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return common.run_command(command, {
    cwd = project_root,
  })
end

local function _test_common_handles_unicode_paths_for_file_ops()
  _with_clean_tmp("common_file_ops", function(tmp_root)
    local base = common.join_path(tmp_root, "common_子目录/更多目录")
    local file_path = common.join_path(base, "测试_文件.lua")
    local copy_source = common.join_path(tmp_root, "copy_source")
    local copy_target = common.join_path(tmp_root, "copy_target_中文/复制目录")

    local ok, err = common.ensure_dir(base)
    if not ok then
      error(err)
    end

    ok, err = common.write_file(file_path, 'return { value = "中文 English" }\n')
    if not ok then
      error(err)
    end

    ok, err = common.append_file(file_path, "-- appended\n")
    if not ok then
      error(err)
    end

    assert(common.path_exists(file_path) == true, "unicode file path should exist after write")

    local content, read_err = common.read_file(file_path)
    if content == nil then
      error(read_err)
    end
    _assert_contains(content, "中文 English", "unicode file content should round-trip through file io")
    _assert_contains(content, "-- appended", "append_file should preserve appended content")

    local files, list_err = common.collect_lua_files(tmp_root)
    if files == nil then
      error(list_err)
    end
    assert(#files == 1, "collect_lua_files should find the unicode fixture file")
    _assert_contains(files[1], "测试_文件.lua", "collect_lua_files should preserve unicode file names")

    ok, err = common.ensure_dir(common.join_path(copy_source, "nested"))
    if not ok then
      error(err)
    end
    ok, err = common.write_file(common.join_path(copy_source, "nested/sample.lua"), "return 1\n")
    if not ok then
      error(err)
    end

    ok, err = common.copy_tree(copy_source, copy_target)
    if not ok then
      error(err)
    end
    assert(common.path_exists(common.join_path(copy_target, "nested/sample.lua")) == true,
      "copy_tree should support unicode target directories")
  end)
end

local function _test_arch_common_reuses_unicode_safe_file_ops()
  _with_clean_tmp("arch_common_file_ops", function(tmp_root)
    local out_dir = arch_common.join_path(tmp_root, "arch_view_输出/子目录")
    local ok, err = arch_common.ensure_dir(out_dir)
    if not ok then
      error(err)
    end

    ok, err = arch_common.write_file(arch_common.join_path(out_dir, "demo.lua"), "return {}\n")
    if not ok then
      error(err)
    end

    local content, read_err = arch_common.read_file(arch_common.join_path(out_dir, "demo.lua"))
    if content == nil then
      error(read_err)
    end
    _assert_contains(content, "return {}", "arch_common should reuse shared file io")

    local files, list_err = arch_common.collect_lua_files(tmp_root)
    if files == nil then
      error(list_err)
    end
    assert(#files == 1, "arch_common should collect unicode lua files through shared utility")
  end)
end

local function _test_command_exists_reports_present_and_missing_commands()
  assert(common.command_exists("lua") == true, "lua should exist in the test environment")
  assert(common.command_exists("monopoly_command_that_should_not_exist_12345") == false,
    "command_exists should return false for missing commands")
end

local function _test_cli_help_text_is_bilingual()
  local help_commands = {
    { "scripts/ops/deploy.lua", "--help" },
    { "scripts/data/export_xlsx.lua", "--help" },
    { "scripts/ops/update_api.lua", "--help" },
    { "scripts/quality/arch.lua", "--help" },
    { "scripts/quality/crap.lua", "--help" },
    { "scripts/quality/mutate.lua", "--help" },
    { "scripts/quality/scrap.lua", "--help" },
  }

  for _, args in ipairs(help_commands) do
    local result = _run_lua(args)
    assert(result.ok == true, "help command should exit successfully for " .. table.concat(args, " "))
    _assert_contains(result.output, "用法", "help output should include Chinese usage text")
    _assert_contains(result.output, "Usage", "help output should include English usage text")
  end
end

local function _test_deploy_unknown_flag_is_bilingual()
  local result = _run_lua({ "scripts/ops/deploy.lua", "--bad-flag" })
  assert(result.ok == false, "deploy should fail on unknown flags")
  _assert_contains(result.output, "未知参数", "unknown flag output should include Chinese text")
  _assert_contains(result.output, "Unknown flag", "unknown flag output should include English text")
end

local function _test_deploy_defaults_match_windows_history()
  local resolved = deploy_defaults.resolve({
    home_dir = "C:/Users/example",
    is_windows = true,
    is_macos = false,
    publish = false,
  })
  local publish_resolved = deploy_defaults.resolve({
    home_dir = "C:/Users/example",
    is_windows = true,
    is_macos = false,
    publish = true,
  })

  assert(resolved == "C:/Users/example/Desktop/dev/LuaSource_大富翁-开发",
    "windows dev deploy default should match the historical Desktop/dev path")
  assert(publish_resolved == "C:/Users/example/Desktop/dev/LuaSource_大富翁-发布",
    "windows release deploy default should match the historical Desktop/dev path")
end

local function _test_deploy_defaults_match_macos_history()
  local resolved = deploy_defaults.resolve({
    home_dir = "/Users/example",
    is_windows = false,
    is_macos = true,
    publish = false,
  })
  local publish_resolved = deploy_defaults.resolve({
    home_dir = "/Users/example",
    is_windows = false,
    is_macos = true,
    publish = true,
  })
  local candidates = deploy_defaults.candidates({
    home_dir = "/Users/example",
    is_windows = false,
    is_macos = true,
    publish = false,
  })

  assert(resolved == "/Users/example/Documents/eggy/LuaSource_大富翁-开发",
    "macOS dev deploy default should match the historical Documents/eggy path")
  assert(publish_resolved == "/Users/example/Documents/eggy/LuaSource_大富翁-发布",
    "macOS release deploy default should match the historical Documents/eggy path")
  assert(candidates[2] == "/Users/example/Documents/eggy/LuaSource_monopoly",
    "macOS should preserve the legacy LuaSource_monopoly fallback from git history")
end

local function _test_publish_deploy_allows_publish_path()
  _with_ascii_tmp("publish_deploy_allows_publish_path", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "release_deploy")
    local result = _run_lua({
      "scripts/ops/deploy.lua",
      "--publish",
      "--target-path",
      publish_target,
    })

    assert(result.ok == true, "publish deploy should allow target paths that include 发布")
    _assert_contains(result.output, "部署模式: 发布部署", "publish deploy should log the release mode in Chinese")
    _assert_contains(result.output, "Deploy mode: release deploy", "publish deploy should log the release mode in English")
    assert(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "publish deploy should copy main.lua into the target path")
  end)
end

local function _test_publish_deploy_rejects_startup_profile()
  _with_ascii_tmp("publish_deploy_rejects_startup_profile", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "release_deploy")
    local result = _run_lua({
      "scripts/ops/deploy.lua",
      "--publish",
      "--target-path",
      publish_target,
      "--startup-profile",
      "smoke_test",
    })

    assert(result.ok == false, "publish deploy should reject startup profile injection")
    _assert_contains(result.output, "禁止注入 STARTUP_TEST_PROFILE", "publish deploy should explain the release restriction in Chinese")
    _assert_contains(result.output, "does not allow STARTUP_TEST_PROFILE", "publish deploy should explain the release restriction in English")
  end)
end

local function _test_run_command_preserves_bilingual_stderr_and_utf8_stdin()
  _with_clean_tmp("run_command_stderr_capture", function(tmp_root)
    local script_path = common.join_path(tmp_root, "capture_output.lua")
    local stdin_path = common.join_path(tmp_root, "stdin.txt")
    local ok, err = common.write_file(script_path, table.concat({
      "local input = io.read('*a') or ''",
      "if input ~= '' then",
      "  io.write(input)",
      "  if input:sub(-1) ~= '\\n' then",
      "    io.write('\\n')",
      "  end",
      "end",
      "io.stderr:write('未知参数 / Unknown flag: --bad-flag\\n')",
      "os.exit(7)",
      "",
    }, "\n"))
    if not ok then
      error(err)
    end

    ok, err = common.write_file(stdin_path, "stdin 中文 / utf8 stdin")
    if not ok then
      error(err)
    end

    local result = common.run_command({ "lua", script_path }, {
      cwd = project_root,
      stdin_path = stdin_path,
    })

    assert(result.ok == false, "run_command should surface non-zero exit codes")
    assert(result.code ~= 0, "run_command should preserve the child exit code")
    _assert_contains(result.output, "stdin 中文 / utf8 stdin", "run_command should preserve utf8 stdin content")
    _assert_contains(result.output, "未知参数", "run_command should preserve Chinese stderr text")
    _assert_contains(result.output, "Unknown flag", "run_command should preserve English stderr text")
    _assert_not_contains(result.output, "System.Management.Automation.RemoteException",
      "run_command should not wrap native stderr as a PowerShell exception")
  end)
end

local function _test_arch_view_viewer_supports_unicode_output_path()
  _with_clean_tmp("arch_view_unicode_output", function(tmp_root)
    local out_dir = common.join_path(tmp_root, "arch_view_目标/中文 English")
    local messages = {}
    local original_print = print
    print = function(...)
      local parts = {}
      for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
      end
      messages[#messages + 1] = table.concat(parts, "\t")
    end

    local ok, err = xpcall(function()
      return arch_cli.run({
      "viewer",
      "--out-dir",
      out_dir,
      "--in-json",
      "scripts/quality/arch/viewer/architecture.json",
      }, {
        cwd = project_root,
        asset_root = common.join_path(project_root, "vendor/arch_view/viewer"),
        default_config_path = common.join_path(project_root, "scripts/quality/arch/config.json"),
      })
    end, debug.traceback)
    print = original_print

    if not ok then
      error(err)
    end

    local output = table.concat(messages, "\n")
    _assert_contains(output, "arch_view 视图已生成", "arch viewer logs should include Chinese text")
    _assert_contains(output, "arch_view viewer ok", "arch viewer logs should include English text")
    assert(common.path_exists(common.join_path(out_dir, "index.html")) == true, "arch viewer should write index.html")
    assert(common.path_exists(common.join_path(out_dir, "architecture.json")) == true, "arch viewer should write architecture.json")
  end)
end

local function _test_scrap_viewer_supports_unicode_output_path()
  _with_clean_tmp("scrap_viewer_unicode_output", function(tmp_root)
    local out_dir = common.join_path(tmp_root, "scrap_目标/中文 English")
    local result = _run_lua({
      "scripts/quality/scrap.lua",
      "viewer",
      "--out-dir",
      out_dir,
    })

    assert(result.ok == true, "scrap viewer should support unicode output paths")
    _assert_contains(result.output, "scrap4lua viewer ok", "scrap viewer output should include English success text")
    _assert_contains(result.output, "视图已生成", "scrap viewer output should include Chinese success text")
    assert(common.path_exists(common.join_path(out_dir, "index.html")) == true, "scrap viewer should write index.html")
    assert(common.path_exists(common.join_path(out_dir, "scrap_data.js")) == true, "scrap viewer should write scrap_data.js")
  end)
end

local function _test_mutate_wrapper_scan_json_output()
  local result = _run_lua({
    "scripts/quality/mutate.lua",
    "src/core/utils/role_id.lua",
    "--scan",
    "--json",
  })

  assert(result.ok == true, "mutate wrapper scan should succeed")
  _assert_contains(result.output, "\"relative_file\":\"src/core/utils/role_id.lua\"",
    "mutate scan should report the normalized target path")
  _assert_contains(result.output, "\"sites\":[",
    "mutate scan should emit discovered mutation sites in json output")
end

local function _test_mutate_wrapper_indexes_behavior_suites_as_json()
  local result = _run_lua({
    "scripts/quality/mutate.lua",
    "--index-suites",
    "--lane",
    "behavior",
    "--json",
  })

  assert(result.ok == true, "mutate wrapper suite indexing should succeed")
  _assert_contains(result.output, "\"ok\":true",
    "suite indexing should report success in json output")
  _assert_contains(result.output, "\"suite_count\":",
    "suite indexing should report indexed suite count")
end

local contract_tests = {
  { name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
  { name = "deploy_defaults_match_windows_history", run = _test_deploy_defaults_match_windows_history },
  { name = "deploy_defaults_match_macos_history", run = _test_deploy_defaults_match_macos_history },
  { name = "deploy_unknown_flag_is_bilingual", run = _test_deploy_unknown_flag_is_bilingual },
  { name = "publish_deploy_allows_publish_path", run = _test_publish_deploy_allows_publish_path },
  { name = "publish_deploy_rejects_startup_profile", run = _test_publish_deploy_rejects_startup_profile },
  { name = "run_command_preserves_bilingual_stderr_and_utf8_stdin", run = _test_run_command_preserves_bilingual_stderr_and_utf8_stdin },
}

local tooling_tests = {
  { name = "common_handles_unicode_paths_for_file_ops", run = _test_common_handles_unicode_paths_for_file_ops },
  { name = "arch_common_reuses_unicode_safe_file_ops", run = _test_arch_common_reuses_unicode_safe_file_ops },
  { name = "cli_help_text_is_bilingual", run = _test_cli_help_text_is_bilingual },
  { name = "arch_view_viewer_supports_unicode_output_path", run = _test_arch_view_viewer_supports_unicode_output_path },
  { name = "scrap_viewer_supports_unicode_output_path", run = _test_scrap_viewer_supports_unicode_output_path },
  { name = "mutate_wrapper_scan_json_output", run = _test_mutate_wrapper_scan_json_output },
  { name = "mutate_wrapper_indexes_behavior_suites_as_json", run = _test_mutate_wrapper_indexes_behavior_suites_as_json },
}

return {
  name = "script_tools_contract",
  tests = contract_tests,
  tooling_tests = tooling_tests,
}
