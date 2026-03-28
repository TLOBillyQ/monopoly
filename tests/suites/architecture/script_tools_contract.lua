local bootstrap = require("tests.bootstrap")
local common = require("shared.lib.common")
local arch_common = require("arch_view.runtime.common")
local arch_cli = require("quality.arch")
local loc_counter = require("shared.lib.loc_counter")
local loc_scan = require("shared.lib.loc_scan")

bootstrap.install_package_paths()

local project_root = common.normalize_path(common.current_dir())

-- 缓存 PowerShell 命令检测结果，避免每次调用都执行 command_exists
local _cached_powershell_cmd = nil
local _cached_powershell_checked = false

local function _get_powershell_cmd()
  if _cached_powershell_checked then
    return _cached_powershell_cmd
  end
  _cached_powershell_checked = true
  if common.command_exists("pwsh") then
    _cached_powershell_cmd = "pwsh"
  elseif common.command_exists("powershell") then
    _cached_powershell_cmd = "powershell"
  end
  return _cached_powershell_cmd
end

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

local function _generate_arch_view_input_json(tmp_root)
  local out_path = common.join_path(tmp_root, "arch_view_input/architecture.json")
  local default_config_path = _first_existing({
    common.join_path(project_root, "tools/quality/arch/config.json"),
  })
  local ok, err = xpcall(function()
    return arch_cli.run({
      "scan",
      "--out",
      out_path,
    }, {
      cwd = project_root,
      asset_root = common.join_path(project_root, "vendor/arch_view/viewer"),
      default_config_path = default_config_path,
    })
  end, debug.traceback)
  if not ok then
    error(err)
  end
  return out_path, default_config_path
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
  local cmd = _get_powershell_cmd()
  if cmd == nil then
    return {
      skipped = true,
      output = "powershell not available",
    }
  end

  local command = { cmd, "-File", script_path }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end

  return common.run_command(command, {
    cwd = project_root,
  })
end

local function _powershell_single_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function _run_powershell_command(command_text)
  local cmd = _get_powershell_cmd()
  if cmd == nil then
    return {
      skipped = true,
      output = "powershell not available",
    }
  end

  return common.run_command({ cmd, "-Command", command_text }, {
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

local function _test_encoding_check_accepts_utf8_chinese_strings()
  _with_ascii_tmp("encoding_chinese_strings", function(tmp_root)
    local src_dir = common.join_path(tmp_root, "src")
    local fixture_path = common.join_path(src_dir, "ui/prompt.lua")
    _write_fixture_file(fixture_path, table.concat({
      'local prompt = "中文提示…继续"',
      "return prompt",
      "",
    }, "\n"))

    local result = _run_lua({
      "tools/quality/encoding.lua",
      "check",
      "--root",
      src_dir,
    })

    assert(result.ok == true, "encoding check should allow utf-8 Chinese business strings")
    _assert_contains(result.output, "encoding check ok",
      "encoding check should report success for Chinese business strings")
  end)
end

local function _test_encoding_check_reports_suspicious_english_comment()
  _with_ascii_tmp("encoding_english_comment", function(tmp_root)
    local src_dir = common.join_path(tmp_root, "src")
    local fixture_path = common.join_path(src_dir, "ui/anim.lua")
    _write_fixture_file(fixture_path, table.concat({
      "-- Fallback: no scheduler — preserve original call order",
      "return true",
      "",
    }, "\n"))

    local result = _run_lua({
      "tools/quality/encoding.lua",
      "check",
      "--root",
      src_dir,
    })

    assert(result.ok == false, "encoding check should fail on suspicious punctuation in English comments")
    _assert_contains(result.output, "U+2014",
      "encoding check should report the em dash codepoint")
    _assert_contains(result.output, 'replace with "-"',
      "encoding check should suggest the ASCII replacement")
    _assert_contains(result.output, "comment",
      "encoding check should classify the violation as a comment issue")
  end)
end

local function _test_encoding_check_reports_invalid_utf8_bytes()
  _with_ascii_tmp("encoding_invalid_utf8", function(tmp_root)
    local src_dir = common.join_path(tmp_root, "src")
    local fixture_path = common.join_path(src_dir, "broken.lua")
    _write_fixture_file(fixture_path, "local broken = '" .. string.char(0xFF) .. "'\n")

    local result = _run_lua({
      "tools/quality/encoding.lua",
      "check",
      "--root",
      src_dir,
    })

    assert(result.ok == false, "encoding check should fail on invalid utf-8 bytes")
    _assert_contains(result.output, "invalid UTF-8 byte sequence",
      "encoding check should report invalid utf-8 bytes")
    _assert_contains(result.output, "broken.lua:1:",
      "encoding check should include the file and line location")
  end)
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
    { "tools/quality/encoding.lua", "--help" },
    { "tools/quality/mutate.lua", "--help" },
    { "tools/quality/scrap.lua", "--help" },
  }

  -- 并行执行所有 help 命令以减少总耗时
  local results = {}
  local threads = {}
  
  for i, args in ipairs(help_commands) do
    threads[i] = coroutine.create(function()
      results[i] = {
        args = args,
        result = _run_lua(args),
      }
    end)
  end
  
  -- 轮询执行所有协程直到完成
  local running = #threads
  while running > 0 do
    running = 0
    for _, thread in ipairs(threads) do
      if coroutine.status(thread) ~= "dead" then
        local ok = coroutine.resume(thread)
        if coroutine.status(thread) ~= "dead" then
          running = running + 1
        end
      end
    end
  end
  
  -- 验证所有结果
  for _, item in ipairs(results) do
    assert(item.result.ok == true, "help command should exit successfully for " .. table.concat(item.args, " "))
    _assert_contains(item.result.output, "用法", "help output should include Chinese usage text")
    _assert_contains(item.result.output, "Usage", "help output should include English usage text")
  end
end

local function _test_update_api_writes_changelog_into_docs_eggy_api_dir()
  local script_text = assert(common.read_file(common.join_path(project_root, "tools/ops/update_api.lua")))
  _assert_contains(
    script_text,
    'docs/eggy/api/changelog.md',
    "update_api should keep the changelog under docs/eggy/api"
  )
  _assert_not_contains(
    script_text,
    'docs/eggy/api_changelog.md',
    "update_api should not write changelog beside the api directory"
  )
end

local function _write_update_api_fixture(path, function_name)
  _write_fixture_file(path, table.concat({
    "---@meta EggyAPI",
    "",
    "---@class GlobalAPI",
    "GlobalAPI = {}",
    "",
    "function GlobalAPI." .. tostring(function_name) .. "() end",
    "",
  }, "\n"))
end

local function _run_update_api_with_paths(old_path, new_path, doc_dir, changelog_path)
  return _run_lua({
    "tools/ops/update_api.lua",
    "--old", old_path,
    "--new", new_path,
    "--doc-dir", doc_dir,
    "--changelog", changelog_path,
  })
end

local function _test_update_api_deletes_old_baseline_when_only_diff_fails()
  _with_ascii_tmp("update_api_delete_old_on_diff", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_delete_old_on_diff")
    local old_path = common.join_path(fixture_root, "EggyAPI copy.lua")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _write_update_api_fixture(old_path, "legacy_call")
    _write_update_api_fixture(new_path, "current_call")

    local result = _run_update_api_with_paths(old_path, new_path, doc_dir, changelog_path)

    assert(result.ok == false, "update_api should still exit non-zero when API diff exists")
    assert(common.path_exists(old_path) == false, "update_api should delete old baseline after docs/check succeed")
    assert(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == true,
      "update_api should generate split docs before deleting the old baseline")
    assert(common.path_exists(changelog_path) == true, "update_api should write changelog into the requested path")
    _assert_contains(result.output, "新增 / Added: 1", "update_api should report the added API in diff output")
    _assert_contains(result.output, "删除 / Removed: 1", "update_api should report the removed API in diff output")
    _assert_contains(result.output, "缺失项 / Missing: 0", "update_api should keep doc entries aligned with source entries")
    _assert_contains(result.output, "多余项 / Extra: 0", "update_api should keep doc entries aligned with source entries")
  end)
end

local function _test_update_api_keeps_old_baseline_when_check_fails()
  _with_ascii_tmp("update_api_keep_old_on_check_failure", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_keep_old_on_check_failure")
    local old_path = common.join_path(fixture_root, "EggyAPI copy.lua")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")
    local extra_doc_path = common.join_path(doc_dir, "zz_extra.md")

    _write_update_api_fixture(old_path, "shared_call")
    _write_update_api_fixture(new_path, "shared_call")
    _write_fixture_file(extra_doc_path, table.concat({
      "# extra",
      "",
      "GhostAPI|ghost_call",
      "",
    }, "\n"))

    local result = _run_update_api_with_paths(old_path, new_path, doc_dir, changelog_path)

    assert(result.ok == false, "update_api should exit non-zero when doc check finds extra entries")
    assert(common.path_exists(old_path) == true, "update_api should keep old baseline when check fails")
    _assert_contains(result.output, "多余项 / Extra: 1", "update_api should surface the extra doc entry count")
    _assert_contains(result.output, "多余示例 / Extra sample: [GhostAPI|ghost_call]",
      "update_api should surface the offending extra doc entry")
  end)
end

local function _test_deploy_script_keeps_default_paths()
  local script_text = assert(common.read_file(common.join_path(project_root, "tools/ops/deploy.ps1")))
  _assert_contains(
    script_text,
    "$home_dir/Desktop/dev/LuaSource_大富翁",
    "deploy.ps1 should keep the windows default deploy path"
  )
  _assert_contains(
    script_text,
    "$home_dir/Documents/eggy/LuaSource_大富翁",
    "deploy.ps1 should keep the macOS default deploy path"
  )
  _assert_not_contains(
    script_text,
    "LuaSource_大富翁-发布",
    "deploy.ps1 should no longer keep suffix-based default deploy paths"
  )
  _assert_not_contains(
    script_text,
    "LuaSource_大富翁-备份",
    "deploy.ps1 should no longer keep suffix-based backup deploy paths"
  )
  _assert_not_contains(
    script_text,
    "vehicle-runtime",
    "deploy.ps1 should not expose the retired vehicle runtime flag"
  )
end

local function _test_deploy_script_removes_vehicle_runtime_legacy_support()
  local script_text = assert(common.read_file(common.join_path(project_root, "tools/ops/deploy.ps1")))
  _assert_not_contains(script_text, "--vehicle-runtime", "deploy.ps1 should no longer advertise the vehicle runtime flag")
  _assert_not_contains(script_text, "VehicleRuntime", "deploy.ps1 should not keep the legacy vehicle runtime parameter")
  _assert_not_contains(script_text, "vehicle_runtime_legacy", "deploy.ps1 should not reference the retired legacy runtime module")
  _assert_not_contains(script_text, "legacy 载具运行时", "deploy.ps1 should not mention the retired legacy runtime mode")
  _assert_not_contains(script_text, "legacy vehicle runtime", "deploy.ps1 should not mention the retired legacy runtime mode")
end

local function _test_deploy_comprehensive()
  _test_deploy_script_keeps_default_paths()

  _with_ascii_tmp("deploy_comprehensive", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")

    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-BuildMode", "debug",
      "-TargetPath", publish_target,
      "-StartupProfile", "missile",
    })
    
    if result.skipped == true then
      return
    end

    -- 验证成功执行
    assert(result.ok == true, "deploy should succeed with explicit target and startup profile")
    
    -- 验证文件复制正确
    assert(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "deploy should copy main.lua into the target path")
    assert(common.path_exists(common.join_path(publish_target, "src/config")) == true,
      "deploy should include src/config through the src directory copy")
    assert(common.path_exists(common.join_path(publish_target, "Data/UIManagerNodes.lua")) == true,
      "deploy should copy Data/UIManagerNodes.lua into the target path")
    assert(common.path_exists(common.join_path(publish_target, "Data/Prefab.lua")) == true,
      "deploy should copy Data/Prefab.lua into the target path")
    
    -- 验证启动配置注入
    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "debug"',
      "deploy should inject debug build mode into main.lua")
    _assert_contains(deployed_main, 'STARTUP_TEST_PROFILE = "missile"',
      "deploy should inject startup profile into main.lua when requested")
    _assert_contains(result.output, "Build mode: debug",
      "deploy output should show debug mode when startup profile is present")
    _assert_contains(result.output, "Lua Files:",
      "deploy output should keep total lua file count")
    _assert_contains(result.output, "Effective LOC:",
      "deploy output should keep total effective loc")
    
    local invalid_profile_result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath", publish_target,
      "-StartupProfile", "test_quick_3_rounds",
    })
    assert(invalid_profile_result.ok == false, "deploy should fail on unknown startup profiles")
    _assert_contains(invalid_profile_result.output, "unknown test profile: test_quick_3_rounds",
      "invalid startup profile output should keep the requested profile name")
    _assert_contains(invalid_profile_result.output, "available profiles:",
      "invalid startup profile output should list available startup profiles")
    _assert_contains(invalid_profile_result.output, "missile",
      "invalid startup profile output should include a valid startup profile example")
  end)

  _with_ascii_tmp("deploy_release_default", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath", publish_target,
    })

    if result.skipped == true then
      return
    end

    assert(result.ok == true, "deploy should succeed without startup profile")
    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "release"',
      "deploy without startup profile should inject release build mode")
    _assert_not_contains(deployed_main, 'STARTUP_TEST_PROFILE = ',
      "deploy without startup profile should not inject STARTUP_TEST_PROFILE")
    _assert_contains(result.output, "Build mode: release",
      "deploy output should show release mode when no startup profile is present")
  end)

  _with_ascii_tmp("deploy_profile_forces_debug", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath", publish_target,
      "-StartupProfile", "missile",
      "-BuildMode", "release",
    })

    if result.skipped == true then
      return
    end

    assert(result.ok == true, "deploy should force debug instead of failing when startup profile is present")
    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "debug"',
      "deploy should force debug build mode when startup profile is present")
    _assert_contains(deployed_main, 'STARTUP_TEST_PROFILE = "missile"',
      "deploy should keep startup profile injection when forcing debug")
    _assert_contains(result.output, "自动切换为 debug 模式",
      "deploy output should explain the automatic debug override in Chinese")
    _assert_contains(result.output, "forcing debug build mode",
      "deploy output should explain the automatic debug override in English")
  end)

  _with_ascii_tmp("deploy_powershell_style", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath", publish_target,
      "-StartupProfile", "missile",
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
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "debug"',
      "deploy PowerShell wrapper should auto-select debug mode for startup profiles")
    _assert_contains(deployed_main, 'STARTUP_TEST_PROFILE = "missile"',
      "deploy PowerShell wrapper should forward startup profile injection")
  end)

  _with_ascii_tmp("deploy_direct_invocation", function(tmp_root)
    local publish_target = common.join_path(tmp_root, "deploy_target")
    local command = table.concat({
      "$env:MONOPOLY_DEPLOY_TARGET = " .. _powershell_single_quote(publish_target),
      "& " .. _powershell_single_quote("./tools/ops/deploy.ps1") .. " -StartupProfile clear_obstacles",
    }, "; ")
    local result = _run_powershell_command(command)

    if result.skipped == true then
      return
    end

    assert(result.ok == true, "direct script invocation should succeed with StartupProfile only")
    assert(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "direct script invocation should deploy to MONOPOLY_DEPLOY_TARGET instead of misbinding StartupProfile")
    _assert_contains(result.output, common.normalize_path(publish_target),
      "direct script invocation should report the resolved deploy target")
  end)

  _with_ascii_tmp("deploy_keep_test_startup", function(tmp_root)
    local keep_target = common.join_path(tmp_root, "keep_target")
    local keep_result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath", keep_target,
      "-StartupProfile", "missile",
      "-KeepTestStartup",
    })

    if keep_result.skipped == true then
      return
    end

    assert(keep_result.ok == true, "deploy should allow KeepTestStartup in debug mode")
    assert(common.path_exists(common.join_path(keep_target, "src/config/testing")) == true,
      "KeepTestStartup should preserve src/config/testing when StartupProfile forces debug mode")
    assert(common.path_exists(common.join_path(keep_target, "src/app/testing")) == true,
      "KeepTestStartup should preserve src/app/testing when StartupProfile forces debug mode")

    local release_target = common.join_path(tmp_root, "release_target")
    local release_result = _run_powershell_file("tools/ops/deploy.ps1", {
      "-TargetPath", release_target,
      "-BuildMode", "release",
      "-KeepTestStartup",
    })
    assert(release_result.ok == true, "deploy release should still succeed with KeepTestStartup present")
    assert(common.path_exists(common.join_path(release_target, "src/config/testing")) == false,
      "release deploy should strip src/config/testing even when KeepTestStartup is set")
    assert(common.path_exists(common.join_path(release_target, "src/app/testing")) == false,
      "release deploy should strip src/app/testing even when KeepTestStartup is set")
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
    local input_json, default_config_path = _generate_arch_view_input_json(tmp_root)
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

-- 轻量版 git 历史测试，使用 2 次提交而非 3 次，减少执行时间
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

    -- 第一次提交：初始文件
    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v1)
    _write_fixture_file(common.join_path(tests_dir, "spec.lua"), test_v1)
    _commit_all(repo_root, "initial loc fixtures")

    -- 第二次提交：合并修改、添加、重命名、删除操作（减少一次提交）
    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v2)
    _write_fixture_file(common.join_path(tests_dir, "extra.lua"), test_v2)
    _write_fixture_file(common.join_path(tests_dir, "empty.lua"), "")
    _run_in_dir(repo_root, { "git", "mv", "tests/spec.lua", "tests/spec_renamed.lua" })
    _commit_all(repo_root, "modify add rename")

    loc_scan.reset_caches()
    local result, history_err = loc_scan.count_history({
      git_root = repo_root,
      since = "1 day ago",  -- 缩短时间范围加快查询
    })
    if result == nil then
      error(history_err)
    end

    local rows = result.rows or {}
    assert(#rows == 2, "history scanner should return one row per commit in the time window")

    -- 验证第一次提交
    assert(rows[1].src_loc == _line_count(src_v1), "first history row should use the initial src LOC")
    assert(rows[1].src_files == 1, "first history row should count the initial src file")
    assert(rows[1].tests_loc == _line_count(test_v1), "first history row should use the initial tests LOC")
    assert(rows[1].tests_files == 1, "first history row should count the initial tests file")

    -- 验证第二次提交：包含修改、添加、重命名
    assert(rows[2].src_loc == _line_count(src_v2), "second history row should reflect the modified src LOC")
    assert(rows[2].tests_loc == _line_count(test_v2),
      "second history row should include added test LOC")
    assert(rows[2].tests_files == 2, "second history row should count renamed and new files")
  end)
end

local contract_tests = {
  { name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
  { name = "deploy_script_keeps_default_paths", run = _test_deploy_script_keeps_default_paths },
  { name = "deploy_script_removes_vehicle_runtime_legacy_support", run = _test_deploy_script_removes_vehicle_runtime_legacy_support },
  { name = "update_api_writes_changelog_into_docs_eggy_api_dir", run = _test_update_api_writes_changelog_into_docs_eggy_api_dir },
  { name = "update_api_deletes_old_baseline_when_only_diff_fails", run = _test_update_api_deletes_old_baseline_when_only_diff_fails },
  { name = "update_api_keeps_old_baseline_when_check_fails", run = _test_update_api_keeps_old_baseline_when_check_fails },
}

local tooling_tests = {
  { name = "encoding_check_accepts_utf8_chinese_strings", run = _test_encoding_check_accepts_utf8_chinese_strings },
  { name = "encoding_check_reports_suspicious_english_comment", run = _test_encoding_check_reports_suspicious_english_comment },
  { name = "encoding_check_reports_invalid_utf8_bytes", run = _test_encoding_check_reports_invalid_utf8_bytes },
  { name = "deploy_comprehensive", run = _test_deploy_comprehensive },
  { name = "run_command_preserves_bilingual_stderr_and_utf8_stdin", run = _test_run_command_preserves_bilingual_stderr_and_utf8_stdin },
}

return {
  name = "script_tools_contract",
  tests = contract_tests,
  tooling_tests = tooling_tests,
}
