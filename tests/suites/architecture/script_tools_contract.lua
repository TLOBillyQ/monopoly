local bootstrap = require("tests.bootstrap")
local common = require("shared.lib.common")
local arch_common = require("arch_view.runtime.common")
local arch_cli = require("quality.arch")
local deploy_defaults = require("ops.deploy_defaults")
local loc_counter = require("shared.lib.loc_counter")
local loc_scan = require("shared.lib.loc_scan")

bootstrap.install_package_paths()

local project_root = common.normalize_path(common.current_dir())

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if common.path_exists(path) == true then
      return path
    end
  end
  return paths and paths[1] or nil
end

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

local function _run_powershell_file(script_path, args)
  local command = nil
  if common.command_exists("pwsh") then
    command = { "pwsh", "-File", script_path }
  elseif common.command_exists("powershell") then
    command = { "powershell", "-File", script_path }
  else
    return {
      skipped = true,
      output = "powershell not available",
    }
  end

  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end

  return common.run_command(command, {
    cwd = project_root,
  })
end

local function _run_in_dir(cwd, command)
  local result = common.run_command(command, {
    cwd = cwd,
  })
  if result.ok ~= true then
    error(result.output)
  end
  return result
end

local function _write_fixture_file(path, content)
  local ok, err = common.write_file(path, content)
  if not ok then
    error(err)
  end
end

local function _init_git_repo(repo_root)
  _run_in_dir(project_root, { "git", "init", repo_root })
  _run_in_dir(repo_root, { "git", "config", "user.email", "codex@example.com" })
  _run_in_dir(repo_root, { "git", "config", "user.name", "Codex" })
end

local function _commit_all(repo_root, message)
  _run_in_dir(repo_root, { "git", "add", "-A" })
  _run_in_dir(repo_root, { "git", "commit", "-m", message })
end

local function _line_count(text)
  return loc_counter.count_effective_lines(text)
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

local function _test_windows_utf8_console_switches_once_per_process()
  local original_is_windows = common.is_windows
  local get_calls = 0
  local set_calls = 0

  common.is_windows = function()
    return true
  end

  local ok, err = xpcall(function()
    local switched, first_state = common.ensure_windows_utf8_console({
      reset = true,
      get_code_page = function()
        get_calls = get_calls + 1
        return "936"
      end,
      set_code_page_utf8 = function()
        set_calls = set_calls + 1
        return true
      end,
    })

    assert(switched == true, "console helper should switch to utf8 on non-utf8 windows consoles")
    assert(first_state.changed == true, "console helper should report a code page change")
    assert(first_state.code_page == "65001", "console helper should report utf8 after switching")

    local cached, cached_state = common.ensure_windows_utf8_console({
      get_code_page = function()
        error("cached call should not query code page again")
      end,
      set_code_page_utf8 = function()
        error("cached call should not switch code page again")
      end,
    })

    assert(cached == true, "cached console helper result should stay successful")
    assert(cached_state.changed == true, "cached console helper state should preserve the first switch result")
    assert(get_calls == 1, "console helper should query the code page only once per process")
    assert(set_calls == 1, "console helper should switch the code page only once per process")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  if not ok then
    error(err)
  end
end

local function _test_windows_utf8_console_skips_when_already_utf8()
  local original_is_windows = common.is_windows
  local get_calls = 0
  local set_calls = 0

  common.is_windows = function()
    return true
  end

  local ok, err = xpcall(function()
    local switched, state = common.ensure_windows_utf8_console({
      reset = true,
      force = true,
      get_code_page = function()
        get_calls = get_calls + 1
        return "65001"
      end,
      set_code_page_utf8 = function()
        set_calls = set_calls + 1
        return true
      end,
    })

    assert(switched == true, "console helper should succeed on utf8 consoles")
    assert(state.changed == false, "console helper should not change an already utf8 console")
    assert(state.reason == "already_utf8", "console helper should report the already utf8 fast path")
    assert(get_calls == 1, "console helper should still inspect the current code page")
    assert(set_calls == 0, "console helper should not switch code page when already utf8")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  if not ok then
    error(err)
  end
end

local function _test_windows_utf8_console_is_noop_off_windows()
  local original_is_windows = common.is_windows
  local get_calls = 0
  local set_calls = 0

  common.is_windows = function()
    return false
  end

  local ok, err = xpcall(function()
    local passed, state = common.ensure_windows_utf8_console({
      reset = true,
      force = true,
      get_code_page = function()
        get_calls = get_calls + 1
        return "936"
      end,
      set_code_page_utf8 = function()
        set_calls = set_calls + 1
        return true
      end,
    })

    assert(passed == true, "console helper should no-op successfully off windows")
    assert(state.changed == false, "console helper should not report changes off windows")
    assert(state.reason == "not_windows", "console helper should explain the off-windows fast path")
    assert(get_calls == 0, "console helper should not query code pages off windows")
    assert(set_calls == 0, "console helper should not switch code pages off windows")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  if not ok then
    error(err)
  end
end

local function _test_windows_utf8_console_failure_is_non_throwing()
  local original_is_windows = common.is_windows

  common.is_windows = function()
    return true
  end

  local ok, err = xpcall(function()
    local switched, state = common.ensure_windows_utf8_console({
      reset = true,
      force = true,
      get_code_page = function()
        return nil, "failed_to_read_code_page"
      end,
      set_code_page_utf8 = function()
        return false, "switch_failed"
      end,
    })

    assert(switched == false, "console helper should surface switching failures without throwing")
    assert(state.changed == false, "console helper should not report a change on failure")
    assert(state.reason == "switch_failed", "console helper should preserve the switching failure reason")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  if not ok then
    error(err)
  end
end

local function _test_cli_help_text_is_bilingual()
  local help_commands = {
    { "tools/data/export_xlsx.lua", "--help" },
    { "tools/ops/update_api.lua", "--help" },
    { "tools/quality/arch.lua", "--help" },
    { "tools/quality/crap.lua", "--help" },
    { "tools/quality/mutate.lua", "--help" },
    { "tools/quality/scrap.lua", "--help" },
  }

  for _, args in ipairs(help_commands) do
    local result = _run_lua(args)
    assert(result.ok == true, "help command should exit successfully for " .. table.concat(args, " "))
    _assert_contains(result.output, "用法", "help output should include Chinese usage text")
    _assert_contains(result.output, "Usage", "help output should include English usage text")
  end
end

local function _test_deploy_unknown_flag_is_bilingual()
  local result = _run_powershell_file("tools/ops/deploy.ps1", { "--bad-flag" })
  if result.skipped == true then
    return
  end
  assert(result.ok == false, "deploy should fail on unknown flags")
  _assert_contains(result.output, "未知参数", "unknown flag output should include Chinese text")
  _assert_contains(result.output, "Unknown flag", "unknown flag output should include English text")
end

local function _test_deploy_defaults_match_windows_history()
  local resolved = deploy_defaults.resolve({
    home_dir = "C:/Users/example",
    is_windows = true,
    is_macos = false,
  })

  assert(resolved == "C:/Users/example/Desktop/dev/LuaSource_大富翁-发布",
    "windows deploy default should converge to the release path")
end

local function _test_deploy_defaults_match_macos_history()
  local resolved = deploy_defaults.resolve({
    home_dir = "/Users/example",
    is_windows = false,
    is_macos = true,
  })
  local candidates = deploy_defaults.candidates({
    home_dir = "/Users/example",
    is_windows = false,
    is_macos = true,
  })

  assert(resolved == "/Users/example/Documents/eggy/LuaSource_大富翁-发布",
    "macOS deploy default should converge to the release path")
  assert(#candidates == 1 and candidates[1] == "/Users/example/Documents/eggy/LuaSource_大富翁-发布",
    "macOS deploy candidates should only keep the release path")
end

local function _test_deploy_allows_explicit_target_path()
  _with_ascii_tmp("deploy_allows_explicit_target_path", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "--target-path",
      publish_target,
    })
    if result.skipped == true then
      return
    end

    assert(result.ok == true, "deploy should allow explicit target paths")
    assert(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "deploy should copy main.lua into the target path")
  end)
end

local function _test_deploy_aligns_with_current_repo_layout()
  _with_ascii_tmp("deploy_aligns_with_current_repo_layout", function(tmp_root)
    local target = common.join_path(tmp_root, "dev_deploy")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "--target-path",
      target,
    })
    if result.skipped == true then
      return
    end

    assert(result.ok == true, "deploy should succeed for the current repo layout")
    assert(common.path_exists(common.join_path(target, "main.lua")) == true,
      "deploy should copy main.lua into the target path")
    assert(common.path_exists(common.join_path(target, "src/config")) == true,
      "deploy should include src/config through the src directory copy")
    assert(common.path_exists(common.join_path(target, "Data/UIManagerNodes.lua")) == true,
      "deploy should copy Data/UIManagerNodes.lua into the target path")
    assert(common.path_exists(common.join_path(target, "Data/Prefab.lua")) == true,
      "deploy should copy Data/Prefab.lua into the target path")
    _assert_not_contains(result.output, "/Config",
      "deploy output should not mention the retired Config directory")
    _assert_not_contains(result.output, "Config: 0",
      "deploy LOC breakdown should not include the retired Config directory")
  end)
end

local function _test_deploy_injects_startup_profile_when_requested()
  _with_ascii_tmp("deploy_injects_startup_profile_when_requested", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "--target-path",
      publish_target,
      "--startup-profile",
      "smoke_test",
    })
    if result.skipped == true then
      return
    end

    assert(result.ok == true, "deploy should allow startup profile injection")
    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'STARTUP_TEST_PROFILE = "smoke_test"',
      "deploy should inject startup profile into main.lua when requested")
  end)
end

local function _test_deploy_powershell_entrypoint_runs()
  _with_ascii_tmp("deploy_powershell_entrypoint_runs", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath",
      publish_target,
      "-StartupProfile",
      "smoke_test",
    })

    if result.skipped == true then
      return
    end

    assert(result.ok == true, "deploy PowerShell wrapper should succeed")
    assert(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "deploy PowerShell wrapper should copy main.lua into the target path")
    assert(common.path_exists(common.join_path(publish_target, "src/config")) == true,
      "deploy PowerShell wrapper should include src/config through the src directory copy")
    assert(common.path_exists(common.join_path(publish_target, "Data/UIManagerNodes.lua")) == true,
      "deploy PowerShell wrapper should copy Data/UIManagerNodes.lua into the target path")
    assert(common.path_exists(common.join_path(publish_target, "Data/Prefab.lua")) == true,
      "deploy PowerShell wrapper should copy Data/Prefab.lua into the target path")

    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'STARTUP_TEST_PROFILE = "smoke_test"',
      "deploy PowerShell wrapper should forward startup profile injection")
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
    local input_json = _first_existing({
      "tools/quality/arch/viewer/architecture.json",
    })
    local default_config_path = _first_existing({
      common.join_path(project_root, "tools/quality/arch/config.json"),
    })
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
      input_json,
      }, {
        cwd = project_root,
        asset_root = common.join_path(project_root, "vendor/arch_view/viewer"),
        default_config_path = default_config_path,
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
      "tools/quality/scrap.lua",
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
    "tools/quality/mutate.lua",
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
    "tools/quality/mutate.lua",
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

local function _test_bootstrap_resolves_repo_root_from_non_repo_cwd()
  _with_ascii_tmp("bootstrap_non_repo_cwd", function(tmp_root)
    local outside_dir = common.join_path(tmp_root, "outside")
    local ok, err = common.ensure_dir(outside_dir)
    if not ok then
      error(err)
    end

    local bootstrap_path = common.join_path(project_root, "tools/shared/bootstrap.lua")
    local script_path = common.join_path(project_root, "tools/quality/crap.lua")
    local expected_root = common.normalize_path(project_root)
    local lua_snippet = table.concat({
      "local bootstrap = dofile(" .. string.format("%q", bootstrap_path) .. ")",
      "local env = bootstrap.install(" .. string.format("%q", script_path) .. ")",
      "assert(env.repo_root == " .. string.format("%q", expected_root) .. ", 'repo root mismatch')",
      "io.write(env.repo_root)",
    }, "\n")

    local bootstrap_result = common.run_command({ "lua", "-e", lua_snippet }, {
      cwd = outside_dir,
    })
    assert(bootstrap_result.ok == true, "bootstrap helper should resolve repo_root outside the repo cwd")
    _assert_contains(bootstrap_result.output, expected_root,
      "bootstrap helper should report the normalized repo root")

    local help_result = common.run_command({ "lua", script_path, "--help" }, {
      cwd = outside_dir,
    })
    assert(help_result.ok == true, "tool entrypoint should resolve bootstrap dependencies outside the repo cwd")
    _assert_contains(help_result.output, "Usage",
      "tool help should still render when launched outside the repo cwd")
  end)
end

local function _test_loc_scan_counts_worktree_with_go_engine()
  _with_ascii_tmp("loc_scan_worktree", function(tmp_root)
    local repo_root = common.join_path(tmp_root, "loc_repo")
    local src_dir = common.join_path(repo_root, "src")
    local vendor_dir = common.join_path(repo_root, "vendor/third_party")
    local data_dir = common.join_path(repo_root, "Data")
    local ok, err = common.ensure_dir(src_dir)
    if not ok then
      error(err)
    end
    ok, err = common.ensure_dir(vendor_dir)
    if not ok then
      error(err)
    end
    ok, err = common.ensure_dir(data_dir)
    if not ok then
      error(err)
    end

    local src_content = table.concat({
      "local value = 1",
      "",
      "-- comment",
      "return value",
      "",
    }, "\n")
    local vendor_content = "return { enabled = true }\n"
    local main_content = "return require('src.sample')\n"
    local ui_nodes_content = "return { ui = true }\n"
    local prefab_content = "return { prefab = true }\n"

    _write_fixture_file(common.join_path(src_dir, "sample.lua"), src_content)
    _write_fixture_file(common.join_path(vendor_dir, "feature.lua"), vendor_content)
    _write_fixture_file(common.join_path(repo_root, "main.lua"), main_content)
    _write_fixture_file(common.join_path(data_dir, "UIManagerNodes.lua"), ui_nodes_content)
    _write_fixture_file(common.join_path(data_dir, "Prefab.lua"), prefab_content)

    loc_scan.reset_caches()
    local result, count_err = loc_scan.count_worktree({
      project_root = repo_root,
      directories = {
        { name = "src", path = "src" },
        { name = "vendor/third_party", path = "vendor/third_party" },
      },
      files = {
        { name = "main.lua", path = "main.lua", extra_lines_if_exists = 1 },
        { name = "Data/UIManagerNodes.lua", path = "Data/UIManagerNodes.lua", extra_lines_if_exists = 0 },
        { name = "Data/Prefab.lua", path = "Data/Prefab.lua", extra_lines_if_exists = 0 },
      },
    })
    if result == nil then
      error(count_err)
    end

    local by_name = {}
    for _, entry in ipairs(result.breakdown or {}) do
      by_name[entry.name] = entry.effective_lua_line_count
    end

    assert(by_name["src"] == _line_count(src_content), "worktree scanner should count src directory LOC")
    assert(by_name["vendor/third_party"] == _line_count(vendor_content),
      "worktree scanner should count vendor directory LOC")
    assert(by_name["main.lua"] == _line_count(main_content) + 1,
      "worktree scanner should add the startup profile line only when the file exists")
    assert(by_name["Data/UIManagerNodes.lua"] == _line_count(ui_nodes_content),
      "worktree scanner should count UIManagerNodes.lua LOC")
    assert(by_name["Data/Prefab.lua"] == _line_count(prefab_content),
      "worktree scanner should count Prefab.lua LOC")
    assert(result.total_effective_line_count == by_name["src"] + by_name["vendor/third_party"]
      + by_name["main.lua"] + by_name["Data/UIManagerNodes.lua"] + by_name["Data/Prefab.lua"],
      "worktree scanner should keep total_effective_line_count aligned with the breakdown")
  end)
end

local function _test_loc_scan_counts_history_across_git_diff_shapes()
  _with_ascii_tmp("loc_scan_history", function(tmp_root)
    local repo_root = common.join_path(tmp_root, "history_repo")
    local src_dir = common.join_path(repo_root, "src")
    local tests_dir = common.join_path(repo_root, "tests")
    local ok, err = common.ensure_dir(src_dir)
    if not ok then
      error(err)
    end
    ok, err = common.ensure_dir(tests_dir)
    if not ok then
      error(err)
    end

    _init_git_repo(repo_root)

    local src_v1 = table.concat({
      "local value = 1",
      "-- comment",
      "return value",
      "",
    }, "\n")
    local src_v2 = table.concat({
      "local value = 2",
      "local bonus = 3",
      "return value + bonus",
      "",
    }, "\n")
    local src_v3 = table.concat({
      "local next_value = 9",
      "return next_value",
      "",
    }, "\n")
    local test_v1 = table.concat({
      "return { ok = true }",
      "",
    }, "\n")
    local test_v2 = table.concat({
      "return { more = true }",
      "local value = 1",
      "",
    }, "\n")

    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v1)
    _write_fixture_file(common.join_path(tests_dir, "spec.lua"), test_v1)
    _commit_all(repo_root, "initial loc fixtures")

    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v2)
    _write_fixture_file(common.join_path(tests_dir, "extra.lua"), test_v2)
    _write_fixture_file(common.join_path(tests_dir, "empty.lua"), "")
    _commit_all(repo_root, "modify add empty")

    _run_in_dir(repo_root, { "git", "mv", "tests/spec.lua", "tests/spec_renamed.lua" })
    local remove_ok, remove_err = common.remove_path(common.join_path(tests_dir, "extra.lua"))
    if remove_ok == nil then
      error(remove_err)
    end
    _run_in_dir(repo_root, { "git", "mv", "src/a.lua", "src/a.txt" })
    _write_fixture_file(common.join_path(src_dir, "b.lua"), src_v3)
    _commit_all(repo_root, "rename delete and replace")

    loc_scan.reset_caches()
    local result, history_err = loc_scan.count_history({
      git_root = repo_root,
      since = "10 days ago",
    })
    if result == nil then
      error(history_err)
    end

    local rows = result.rows or {}
    assert(#rows == 3, "history scanner should return one row per commit in the time window")

    assert(rows[1].src_loc == _line_count(src_v1), "first history row should use the initial src LOC")
    assert(rows[1].src_files == 1, "first history row should count the initial src file")
    assert(rows[1].tests_loc == _line_count(test_v1), "first history row should use the initial tests LOC")
    assert(rows[1].tests_files == 1, "first history row should count the initial tests file")

    assert(rows[2].src_loc == _line_count(src_v2), "second history row should reflect the modified src LOC")
    assert(rows[2].src_files == 1, "second history row should keep one counted src file")
    assert(rows[2].tests_loc == _line_count(test_v1) + _line_count(test_v2),
      "second history row should include added test LOC and ignore the empty file")
    assert(rows[2].tests_files == 2, "second history row should ignore empty lua files in file totals")

    assert(rows[3].src_loc == _line_count(src_v3), "third history row should drop the renamed non-lua src file")
    assert(rows[3].src_files == 1, "third history row should count the replacement src lua file")
    assert(rows[3].tests_loc == _line_count(test_v1), "third history row should keep renamed lua files in tests totals")
    assert(rows[3].tests_files == 1, "third history row should reflect the deleted extra test file")
  end)
end

local contract_tests = {
  { name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
  { name = "deploy_defaults_match_windows_history", run = _test_deploy_defaults_match_windows_history },
  { name = "deploy_defaults_match_macos_history", run = _test_deploy_defaults_match_macos_history },
  { name = "deploy_unknown_flag_is_bilingual", run = _test_deploy_unknown_flag_is_bilingual },
  { name = "deploy_aligns_with_current_repo_layout", run = _test_deploy_aligns_with_current_repo_layout },
  { name = "deploy_allows_explicit_target_path", run = _test_deploy_allows_explicit_target_path },
  { name = "deploy_injects_startup_profile_when_requested", run = _test_deploy_injects_startup_profile_when_requested },
  { name = "deploy_powershell_entrypoint_runs", run = _test_deploy_powershell_entrypoint_runs },
  { name = "run_command_preserves_bilingual_stderr_and_utf8_stdin", run = _test_run_command_preserves_bilingual_stderr_and_utf8_stdin },
}

local tooling_tests = {
  { name = "common_handles_unicode_paths_for_file_ops", run = _test_common_handles_unicode_paths_for_file_ops },
  { name = "arch_common_reuses_unicode_safe_file_ops", run = _test_arch_common_reuses_unicode_safe_file_ops },
  { name = "windows_utf8_console_switches_once_per_process", run = _test_windows_utf8_console_switches_once_per_process },
  { name = "windows_utf8_console_skips_when_already_utf8", run = _test_windows_utf8_console_skips_when_already_utf8 },
  { name = "windows_utf8_console_is_noop_off_windows", run = _test_windows_utf8_console_is_noop_off_windows },
  { name = "windows_utf8_console_failure_is_non_throwing", run = _test_windows_utf8_console_failure_is_non_throwing },
  { name = "cli_help_text_is_bilingual", run = _test_cli_help_text_is_bilingual },
  { name = "arch_view_viewer_supports_unicode_output_path", run = _test_arch_view_viewer_supports_unicode_output_path },
  { name = "scrap_viewer_supports_unicode_output_path", run = _test_scrap_viewer_supports_unicode_output_path },
  { name = "mutate_wrapper_scan_json_output", run = _test_mutate_wrapper_scan_json_output },
  { name = "mutate_wrapper_indexes_behavior_suites_as_json", run = _test_mutate_wrapper_indexes_behavior_suites_as_json },
  { name = "bootstrap_resolves_repo_root_from_non_repo_cwd", run = _test_bootstrap_resolves_repo_root_from_non_repo_cwd },
  { name = "loc_scan_counts_worktree_with_go_engine", run = _test_loc_scan_counts_worktree_with_go_engine },
  { name = "loc_scan_counts_history_across_git_diff_shapes", run = _test_loc_scan_counts_history_across_git_diff_shapes },
}

return {
  name = "script_tools_contract",
  tests = contract_tests,
  tooling_tests = tooling_tests,
}
