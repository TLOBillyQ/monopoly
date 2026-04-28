local common = require("shared.lib.common")
local arch_common = require("arch_view.runtime.common")
local loc_counter = require("shared.lib.loc_counter")
local loc_scan = require("shared.lib.loc_scan")
local runtime_paths = dofile("tools/shared/runtime_paths.lua")

local project_root = runtime_paths.resolve({
  source_path = debug.getinfo(1, "S").source,
  cwd = runtime_paths.current_dir(),
}).repo_root

-- 缓存 PowerShell 命令检测结果，避免每次调用都执行 command_exists
local _cached_powershell_cmd = nil
local _cached_powershell_checked = false
local _run_lua

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
  local result = _run_lua({
    "tools/quality/arch.lua",
    "scan",
    "--out",
    out_path,
  })
  assert.is_true(result.ok == true, result.output)
  return out_path
end

_run_lua = function(args)
  local command = { "lua" }
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
  assert.is_true(result.ok == true, result.output)
  return result
end

local function _write_fixture_file(path, content)
  local ok, err = common.write_file(path, content)
  assert.is_true(ok == true, err)
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

    assert.is_true(result.ok == true, "encoding check should allow utf-8 Chinese business strings")
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

    assert.is_true(result.ok == false, "encoding check should fail on suspicious punctuation in English comments")
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

    assert.is_true(result.ok == false, "encoding check should fail on invalid utf-8 bytes")
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
    assert.is_true(ok == true, err)

    ok, err = common.write_file(file_path, 'return { value = "中文 English" }\n')
    assert.is_true(ok == true, err)

    ok, err = common.append_file(file_path, "-- appended\n")
    assert.is_true(ok == true, err)

    assert.is_true(common.path_exists(file_path) == true, "unicode file path should exist after write")

    local content, read_err = common.read_file(file_path)
    assert.is_not_nil(content, read_err)
    _assert_contains(content, "中文 English", "unicode file content should round-trip through file io")
    _assert_contains(content, "-- appended", "append_file should preserve appended content")

    local files, list_err = common.collect_lua_files(tmp_root)
    assert.is_not_nil(files, list_err)
    assert.equals(1, #files, "collect_lua_files should find the unicode fixture file")
    _assert_contains(files[1], "测试_文件.lua", "collect_lua_files should preserve unicode file names")

    ok, err = common.ensure_dir(common.join_path(copy_source, "nested"))
    assert.is_true(ok == true, err)
    ok, err = common.write_file(common.join_path(copy_source, "nested/sample.lua"), "return 1\n")
    assert.is_true(ok == true, err)

    ok, err = common.copy_tree(copy_source, copy_target)
    assert.is_true(ok == true, err)
    assert.is_true(common.path_exists(common.join_path(copy_target, "nested/sample.lua")) == true,
      "copy_tree should support unicode target directories")
  end)
end

local function _test_arch_common_reuses_unicode_safe_file_ops()
  _with_clean_tmp("arch_common_file_ops", function(tmp_root)
    local out_dir = arch_common.join_path(tmp_root, "arch_view_输出/子目录")
    local ok, err = arch_common.ensure_dir(out_dir)
    assert.is_true(ok == true, err)

    ok, err = arch_common.write_file(arch_common.join_path(out_dir, "demo.lua"), "return {}\n")
    assert.is_true(ok == true, err)

    local content, read_err = arch_common.read_file(arch_common.join_path(out_dir, "demo.lua"))
    assert.is_not_nil(content, read_err)
    _assert_contains(content, "return {}", "arch_common should reuse shared file io")

    local files, list_err = arch_common.collect_lua_files(tmp_root)
    assert.is_not_nil(files, list_err)
    assert.equals(1, #files, "arch_common should collect unicode lua files through shared utility")
  end)
end

local function _test_command_exists_reports_present_and_missing_commands()
  assert.is_true(common.command_exists("lua") == true, "lua should exist in the test environment")
  assert.is_true(common.command_exists("monopoly_command_that_should_not_exist_12345") == false,
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

    assert.is_true(switched == true, "console helper should switch to utf8 on non-utf8 windows consoles")
    assert.is_true(first_state.changed == true, "console helper should report a code page change")
    assert.equals("65001", first_state.code_page, "console helper should report utf8 after switching")

    local cached, cached_state = common.ensure_windows_utf8_console({
      get_code_page = function()
        error("cached call should not query code page again")
      end,
      set_code_page_utf8 = function()
        error("cached call should not switch code page again")
      end,
    })

    assert.is_true(cached == true, "cached console helper result should stay successful")
    assert.is_true(cached_state.changed == true, "cached console helper state should preserve the first switch result")
    assert.equals(1, get_calls, "console helper should query the code page only once per process")
    assert.equals(1, set_calls, "console helper should switch the code page only once per process")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  assert.is_true(ok == true, err)
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

    assert.is_true(switched == true, "console helper should succeed on utf8 consoles")
    assert.is_true(state.changed == false, "console helper should not change an already utf8 console")
    assert.equals("already_utf8", state.reason, "console helper should report the already utf8 fast path")
    assert.equals(1, get_calls, "console helper should still inspect the current code page")
    assert.equals(0, set_calls, "console helper should not switch code page when already utf8")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  assert.is_true(ok == true, err)
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

    assert.is_true(passed == true, "console helper should no-op successfully off windows")
    assert.is_true(state.changed == false, "console helper should not report changes off windows")
    assert.equals("not_windows", state.reason, "console helper should explain the off-windows fast path")
    assert.equals(0, get_calls, "console helper should not query code pages off windows")
    assert.equals(0, set_calls, "console helper should not switch code pages off windows")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  assert.is_true(ok == true, err)
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

    assert.is_true(switched == false, "console helper should surface switching failures without throwing")
    assert.is_true(state.changed == false, "console helper should not report a change on failure")
    assert.equals("switch_failed", state.reason, "console helper should preserve the switching failure reason")
  end, debug.traceback)

  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  assert.is_true(ok == true, err)
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

  local running = #threads
  while running > 0 do
    running = 0
    for _, thread in ipairs(threads) do
      if coroutine.status(thread) ~= "dead" then
        coroutine.resume(thread)
        if coroutine.status(thread) ~= "dead" then
          running = running + 1
        end
      end
    end
  end

  for _, item in ipairs(results) do
    assert.is_true(item.result.ok == true, "help command should exit successfully for " .. table.concat(item.args, " "))
    _assert_contains(item.result.output, "用法", "help output should include Chinese usage text")
    _assert_contains(item.result.output, "Usage", "help output should include English usage text")
  end
end

local function _test_update_api_writes_changelog_into_docs_eggy_api_dir()
  local script_text, read_err = common.read_file(common.join_path(project_root, "tools/ops/update_api.lua"))
  assert.is_not_nil(script_text, read_err)
  _assert_contains(
    script_text,
    "docs/eggy/api/changelog.md",
    "update_api should keep the changelog under docs/eggy/api"
  )
  _assert_not_contains(
    script_text,
    "docs/eggy/api_changelog.md",
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

local function _run_update_api_git(new_path, doc_dir, changelog_path)
  return _run_lua({
    "tools/ops/update_api.lua",
    "--new", new_path,
    "--doc-dir", doc_dir,
    "--changelog", changelog_path,
    "--skip-meta",
  })
end

local function _test_update_api_updates_docs_and_changelog_when_api_changes()
  _with_ascii_tmp("update_api_api_changes", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_api_changes")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "legacy_call")
    _commit_all(fixture_root, "init")
    _write_update_api_fixture(new_path, "current_call")

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert.is_true(result.ok == false, "update_api should exit non-zero when API diff exists")
    assert.is_true(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == true,
      "update_api should generate split docs")
    assert.is_true(common.path_exists(changelog_path) == true,
      "update_api should write changelog")
    _assert_contains(result.output, "新增 / Added: 1",
      "update_api should report the added API")
    _assert_contains(result.output, "删除 / Removed: 1",
      "update_api should report the removed API")
    _assert_contains(result.output, "缺失项 / Missing: 0",
      "update_api should keep doc entries aligned with source entries")
    _assert_contains(result.output, "多余项 / Extra: 0",
      "update_api should keep doc entries aligned with source entries")
  end)
end

local function _test_update_api_reports_extra_doc_entries_when_check_fails()
  _with_ascii_tmp("update_api_extra_doc", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_extra_doc")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")
    local extra_doc_path = common.join_path(doc_dir, "zz_extra.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "old_call")
    _commit_all(fixture_root, "init")
    _write_update_api_fixture(new_path, "new_call")
    _write_fixture_file(extra_doc_path, table.concat({
      "# extra",
      "",
      "GhostAPI|ghost_call",
      "",
    }, "\n"))

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert.is_true(result.ok == false,
      "update_api should exit non-zero when doc check finds extra entries")
    _assert_contains(result.output, "多余项 / Extra: 1",
      "update_api should surface the extra doc entry count")
    _assert_contains(result.output, "多余示例 / Extra sample: [GhostAPI|ghost_call]",
      "update_api should surface the offending extra doc entry")
  end)
end

local function _test_update_api_skips_all_writes_when_api_unchanged()
  _with_ascii_tmp("update_api_no_change", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_no_change")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "stable_call")
    _commit_all(fixture_root, "init")

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert.is_true(result.ok == true, "update_api should exit 0 when API unchanged")
    assert.is_true(common.path_exists(changelog_path) == false,
      "update_api should not write changelog when API unchanged")
    assert.is_true(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == false,
      "update_api should not generate docs when API unchanged")
    _assert_contains(result.output, "无 API 变化",
      "update_api should report no-op reason when API unchanged")
  end)
end

local function _expected_default_deploy_target(fake_home)
  if common.is_windows() then
    return common.join_path(fake_home, "Desktop/dev/LuaSource_大富翁")
  end
  if common.is_macos() then
    return common.join_path(fake_home, "Documents/eggy/LuaSource_大富翁")
  end
  return nil
end

local function _test_deploy_script_matches_simplified_cli()
  local script_text, read_err = common.read_file(common.join_path(project_root, "tools/ops/deploy.ps1"))
  assert.is_not_nil(script_text, read_err)
  local param_block = script_text:match("param%((.-)%)%s*%$ErrorActionPreference")
  assert.is_not_nil(param_block, "deploy.ps1 should keep a top-level param block")
  _assert_contains(
    param_block,
    "[string]$Profile",
    "deploy.ps1 should expose the simplified profile parameter"
  )
  _assert_contains(
    script_text,
    "function Join-LuaSourceDirName",
    "deploy.ps1 should centralize the LuaSource directory name construction"
  )
  _assert_contains(
    script_text,
    "Join-Path (Join-Path (Join-Path $home_dir \"Desktop\") \"dev\") (Join-LuaSourceDirName)",
    "deploy.ps1 should keep the windows default deploy path semantics"
  )
  _assert_contains(
    script_text,
    "Join-Path (Join-Path (Join-Path $home_dir \"Documents\") \"eggy\") (Join-LuaSourceDirName)",
    "deploy.ps1 should keep the macOS default deploy path semantics"
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
  _assert_not_contains(
    param_block,
    "$TargetPath",
    "deploy.ps1 should no longer expose explicit target path override"
  )
  _assert_not_contains(
    param_block,
    "$StartupProfile",
    "deploy.ps1 should no longer expose the retired startup profile parameter"
  )
  _assert_not_contains(
    param_block,
    "$Platform",
    "deploy.ps1 should no longer expose explicit platform override"
  )
  _assert_not_contains(
    param_block,
    "$KeepTestStartup",
    "deploy.ps1 should no longer expose KeepTestStartup"
  )
  _assert_not_contains(
    param_block,
    "$Help",
    "deploy.ps1 should no longer expose help switch handling"
  )
  _assert_not_contains(
    script_text,
    "MONOPOLY_DEPLOY_TARGET",
    "deploy.ps1 should no longer read MONOPOLY_DEPLOY_TARGET fallback"
  )
end

local function _test_deploy_comprehensive()
  _test_deploy_script_matches_simplified_cli()

  _with_ascii_tmp("deploy_comprehensive", function(tmp_root)
    local fake_home = common.join_path(tmp_root, "fake_home")
    local publish_target = _expected_default_deploy_target(fake_home)
    local command = table.concat({
      "$env:HOME = " .. _powershell_single_quote(fake_home),
      "$env:USERPROFILE = " .. _powershell_single_quote(fake_home),
      "& " .. _powershell_single_quote("./tools/ops/deploy.ps1") .. " -BuildMode debug -Profile missile",
    }, "; ")
    local result = _run_powershell_command(command)

    if result.skipped == true then
      return
    end
    if publish_target == nil then
      return
    end

    assert.is_true(result.ok == true, "deploy should succeed with debug profile under the simplified CLI")
    assert.is_true(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "deploy should write main.lua into the default target path")
    assert.is_true(common.path_exists(common.join_path(publish_target, "src/config")) == true,
      "deploy should copy src into the default target path")
    assert.is_true(common.path_exists(common.join_path(publish_target, "Data/UIManagerNodes.lua")) == true,
      "deploy should copy UIManagerNodes into the default target path")
    assert.is_true(common.path_exists(common.join_path(publish_target, "Data/Prefab.lua")) == true,
      "deploy should copy Prefab into the default target path")

    local deployed_main, main_err = common.read_file(common.join_path(publish_target, "main.lua"))
    assert.is_not_nil(deployed_main, main_err)
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "debug"',
      "deploy should inject debug build mode into main.lua")
    _assert_contains(deployed_main, 'STARTUP_TEST_PROFILE = "missile"',
      "deploy should inject Profile into main.lua in debug mode")
    _assert_contains(result.output, "Build mode: debug",
      "deploy output should report debug mode")
    _assert_contains(result.output, common.normalize_path(publish_target),
      "deploy output should report the resolved default target path")
    _assert_contains(result.output, "Lua Files:",
      "deploy output should keep total lua file count")
    _assert_contains(result.output, "Effective LOC:",
      "deploy output should keep total effective loc")
  end)

  _with_ascii_tmp("deploy_release_default", function(tmp_root)
    local fake_home = common.join_path(tmp_root, "fake_home")
    local publish_target = _expected_default_deploy_target(fake_home)
    local command = table.concat({
      "$env:HOME = " .. _powershell_single_quote(fake_home),
      "$env:USERPROFILE = " .. _powershell_single_quote(fake_home),
      "& " .. _powershell_single_quote("./tools/ops/deploy.ps1") .. " -BuildMode release",
    }, "; ")
    local result = _run_powershell_command(command)

    if result.skipped == true then
      return
    end
    if publish_target == nil then
      return
    end

    assert.is_true(result.ok == true, "deploy should succeed without startup profile")
    local deployed_main, main_err = common.read_file(common.join_path(publish_target, "main.lua"))
    assert.is_not_nil(deployed_main, main_err)
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "release"',
      "deploy without startup profile should inject release build mode")
    _assert_not_contains(deployed_main, 'STARTUP_TEST_PROFILE = ',
      "deploy without startup profile should not inject STARTUP_TEST_PROFILE")
    _assert_contains(result.output, "Build mode: release",
      "deploy output should show release mode when no startup profile is present")
    assert.is_true(common.path_exists(common.join_path(publish_target, "src/config/testing")) == false,
      "release deploy should strip src/config/testing")
    assert.is_true(common.path_exists(common.join_path(publish_target, "src/app/testing")) == false,
      "release deploy should strip src/app/testing")
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
    assert.is_true(ok == true, err)

    ok, err = common.write_file(stdin_path, "stdin 中文 / utf8 stdin")
    assert.is_true(ok == true, err)

    local result = common.run_command({ "lua", script_path }, {
      cwd = project_root,
      stdin_path = stdin_path,
    })

    assert.is_true(result.ok == false, "run_command should surface non-zero exit codes")
    assert.is_true(result.code ~= 0, "run_command should preserve the child exit code")
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
    local input_json = _generate_arch_view_input_json(tmp_root)
    local result = _run_lua({
      "tools/quality/arch.lua",
      "viewer",
      "--out-dir",
      out_dir,
      "--in-json",
      input_json,
    })

    assert.is_true(result.ok == true, result.output)
    _assert_contains(result.output, "arch_view 视图已生成", "arch viewer logs should include Chinese text")
    _assert_contains(result.output, "arch_view viewer ok", "arch viewer logs should include English success text")
    assert.is_true(common.path_exists(common.join_path(out_dir, "index.html")) == true,
      "arch viewer should write index.html")
    assert.is_true(common.path_exists(common.join_path(out_dir, "architecture.json")) == true,
      "arch viewer should write architecture.json")
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

    assert.is_true(result.ok == true, "scrap viewer should support unicode output paths")
    _assert_contains(result.output, "scrap4lua viewer ok", "scrap viewer output should include English success text")
    _assert_contains(result.output, "视图已生成", "scrap viewer output should include Chinese success text")
    assert.is_true(common.path_exists(common.join_path(out_dir, "index.html")) == true,
      "scrap viewer should write index.html")
    assert.is_true(common.path_exists(common.join_path(out_dir, "scrap_data.js")) == true,
      "scrap viewer should write scrap_data.js")
  end)
end

local function _test_mutate_wrapper_scan_json_output()
  local result = _run_lua({
    "tools/quality/mutate.lua",
    "src/core/utils/role_id.lua",
    "--scan",
    "--json",
  })

  assert.is_true(result.ok == true, "mutate wrapper scan should succeed")
  _assert_contains(result.output, '"relative_file":"src/core/utils/role_id.lua"',
    "mutate scan should report the normalized target path")
  _assert_contains(result.output, '"sites":[',
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

  assert.is_true(result.ok == true, "mutate wrapper suite indexing should succeed")
  _assert_contains(result.output, '"ok":true',
    "suite indexing should report success in json output")
  _assert_contains(result.output, '"suite_count":',
    "suite indexing should report indexed suite count")
end

local function _test_bootstrap_resolves_repo_root_from_non_repo_cwd()
  _with_ascii_tmp("bootstrap_non_repo_cwd", function(tmp_root)
    local outside_dir = common.join_path(tmp_root, "outside")
    local ok, err = common.ensure_dir(outside_dir)
    assert.is_true(ok == true, err)

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
    assert.is_true(bootstrap_result.ok == true, "bootstrap helper should resolve repo_root outside the repo cwd")
    _assert_contains(bootstrap_result.output, expected_root,
      "bootstrap helper should report the normalized repo root")

    local help_result = common.run_command({ "lua", script_path, "--help" }, {
      cwd = outside_dir,
    })
    assert.is_true(help_result.ok == true, "tool entrypoint should resolve bootstrap dependencies outside the repo cwd")
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
    assert.is_true(ok == true, err)
    ok, err = common.ensure_dir(vendor_dir)
    assert.is_true(ok == true, err)
    ok, err = common.ensure_dir(data_dir)
    assert.is_true(ok == true, err)

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
    assert.is_not_nil(result, count_err)

    local by_name = {}
    for _, entry in ipairs(result.breakdown or {}) do
      by_name[entry.name] = entry.effective_lua_line_count
    end

    assert.equals(_line_count(src_content), by_name["src"], "worktree scanner should count src directory LOC")
    assert.equals(_line_count(vendor_content), by_name["vendor/third_party"],
      "worktree scanner should count vendor directory LOC")
    assert.equals(_line_count(main_content) + 1, by_name["main.lua"],
      "worktree scanner should add the startup profile line only when the file exists")
    assert.equals(_line_count(ui_nodes_content), by_name["Data/UIManagerNodes.lua"],
      "worktree scanner should count UIManagerNodes.lua LOC")
    assert.equals(_line_count(prefab_content), by_name["Data/Prefab.lua"],
      "worktree scanner should count Prefab.lua LOC")
    assert.equals(by_name["src"] + by_name["vendor/third_party"]
      + by_name["main.lua"] + by_name["Data/UIManagerNodes.lua"] + by_name["Data/Prefab.lua"], result.total_effective_line_count,
      "worktree scanner should keep total_effective_line_count aligned with the breakdown")
  end)
end

local function _test_loc_scan_counts_history_across_git_diff_shapes()
  _with_ascii_tmp("loc_scan_history", function(tmp_root)
    local repo_root = common.join_path(tmp_root, "history_repo")
    local src_dir = common.join_path(repo_root, "src")
    local tests_dir = common.join_path(repo_root, "tests")
    local ok, err = common.ensure_dir(src_dir)
    assert.is_true(ok == true, err)
    ok, err = common.ensure_dir(tests_dir)
    assert.is_true(ok == true, err)

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

    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v1)
    _write_fixture_file(common.join_path(tests_dir, "spec.lua"), test_v1)
    _commit_all(repo_root, "initial loc fixtures")

    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v2)
    _write_fixture_file(common.join_path(tests_dir, "extra.lua"), test_v2)
    _write_fixture_file(common.join_path(tests_dir, "empty.lua"), "")
    _run_in_dir(repo_root, { "git", "mv", "tests/spec.lua", "tests/spec_renamed.lua" })
    _commit_all(repo_root, "modify add rename")

    loc_scan.reset_caches()
    local result, history_err = loc_scan.count_history({
      git_root = repo_root,
      since = "1 day ago",
    })
    assert.is_not_nil(result, history_err)

    local rows = result.rows or {}
    assert.equals(2, #rows, "history scanner should return one row per commit in the time window")

    assert.equals(_line_count(src_v1), rows[1].src_loc, "first history row should use the initial src LOC")
    assert.equals(1, rows[1].src_files, "first history row should count the initial src file")
    assert.equals(_line_count(test_v1), rows[1].tests_loc, "first history row should use the initial tests LOC")
    assert.equals(1, rows[1].tests_files, "first history row should count the initial tests file")

    assert.equals(_line_count(src_v2), rows[2].src_loc, "second history row should reflect the modified src LOC")
    assert.equals(_line_count(test_v1) + _line_count(test_v2), rows[2].tests_loc,
      "second history row should accumulate renamed and added tests LOC")
    assert.equals(2, rows[2].tests_files, "second history row should count renamed and new files")
  end)
end

local contract_tests = {
  { name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
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
  { name = "bootstrap_resolves_repo_root_from_non_repo_cwd", run = _test_bootstrap_resolves_repo_root_from_non_repo_cwd },
  { name = "loc_scan_counts_worktree_with_go_engine", run = _test_loc_scan_counts_worktree_with_go_engine },
  { name = "loc_scan_counts_history_across_git_diff_shapes", run = _test_loc_scan_counts_history_across_git_diff_shapes },
  { name = "deploy_script_matches_simplified_cli", run = _test_deploy_script_matches_simplified_cli },
  { name = "update_api_writes_changelog_into_docs_eggy_api_dir", run = _test_update_api_writes_changelog_into_docs_eggy_api_dir },
  { name = "update_api_updates_docs_and_changelog_when_api_changes", run = _test_update_api_updates_docs_and_changelog_when_api_changes },
  { name = "update_api_reports_extra_doc_entries_when_check_fails", run = _test_update_api_reports_extra_doc_entries_when_check_fails },
  { name = "update_api_skips_all_writes_when_api_unchanged", run = _test_update_api_skips_all_writes_when_api_unchanged },
}

local tooling_tests = {
  { name = "encoding_check_accepts_utf8_chinese_strings", run = _test_encoding_check_accepts_utf8_chinese_strings },
  { name = "encoding_check_reports_suspicious_english_comment", run = _test_encoding_check_reports_suspicious_english_comment },
  { name = "encoding_check_reports_invalid_utf8_bytes", run = _test_encoding_check_reports_invalid_utf8_bytes },
  { name = "mutate_wrapper_indexes_behavior_suites_as_json", run = _test_mutate_wrapper_indexes_behavior_suites_as_json },
  { name = "deploy_comprehensive", run = _test_deploy_comprehensive },
  { name = "run_command_preserves_bilingual_stderr_and_utf8_stdin", run = _test_run_command_preserves_bilingual_stderr_and_utf8_stdin },
}

describe("script_tools_contract", function()
  for _, case in ipairs(contract_tests) do
    it(case.name, case.run)
  end
end)
