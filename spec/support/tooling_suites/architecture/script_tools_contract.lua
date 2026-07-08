local bootstrap = require("spec.bootstrap")
local arch_tool = assert(bootstrap.ensure_tool("arch_view"))
local common = require("shared.lib.common")
local arch_common = require("arch_view.runtime.common")
local arch_cli = require("quality.arch")
local loc_counter = require("spec.support.lib.loc_counter")
local loc_history = require("shared.lib.loc_history")

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
      asset_root = common.join_path(arch_tool.root, "viewer"),
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

local function _with_is_windows(is_windows_value, body)
  local original_is_windows = common.is_windows
  common.is_windows = function() return is_windows_value end
  local ok, err = xpcall(body, debug.traceback)
  common.is_windows = original_is_windows
  common.ensure_windows_utf8_console({ reset = true, force = true })
  if not ok then
    error(err)
  end
end

local function _test_windows_utf8_console_switches_once_per_process()
  _with_is_windows(true, function()
    local get_calls = 0
    local set_calls = 0
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
  end)
end

local function _test_windows_utf8_console_dispatch()
  local cases = {
    {
      name = "skips when already utf8",
      is_windows = true,
      get_code_page = function() return "65001" end,
      set_code_page_utf8 = function() return true end,
      expected_switched = true,
      expected_changed = false,
      expected_reason = "already_utf8",
      expected_get_calls = 1,
      expected_set_calls = 0,
    },
    {
      name = "noop off windows",
      is_windows = false,
      get_code_page = function() return "936" end,
      set_code_page_utf8 = function() return true end,
      expected_switched = true,
      expected_changed = false,
      expected_reason = "not_windows",
      expected_get_calls = 0,
      expected_set_calls = 0,
    },
    {
      name = "failure is non-throwing",
      is_windows = true,
      get_code_page = function() return nil, "failed_to_read_code_page" end,
      set_code_page_utf8 = function() return false, "switch_failed" end,
      expected_switched = false,
      expected_changed = false,
      expected_reason = "switch_failed",
    },
  }
  for _, case in ipairs(cases) do
    _with_is_windows(case.is_windows, function()
      local get_calls = 0
      local set_calls = 0
      local switched, state = common.ensure_windows_utf8_console({
        reset = true,
        force = true,
        get_code_page = function()
          get_calls = get_calls + 1
          return case.get_code_page()
        end,
        set_code_page_utf8 = function()
          set_calls = set_calls + 1
          return case.set_code_page_utf8()
        end,
      })

      assert(switched == case.expected_switched,
        "[" .. case.name .. "] switched=" .. tostring(switched))
      assert(state.changed == case.expected_changed,
        "[" .. case.name .. "] changed=" .. tostring(state.changed))
      assert(state.reason == case.expected_reason,
        "[" .. case.name .. "] reason=" .. tostring(state.reason))
      if case.expected_get_calls then
        assert(get_calls == case.expected_get_calls,
          "[" .. case.name .. "] get_calls=" .. get_calls)
      end
      if case.expected_set_calls then
        assert(set_calls == case.expected_set_calls,
          "[" .. case.name .. "] set_calls=" .. set_calls)
      end
    end)
  end
end

local function _test_cli_help_text_is_bilingual()
  local help_commands = {
    { "tools/ops/update_api.lua", "--help" },
    { "tools/quality/arch.lua", "--help" },
    { "tools/quality/crap.lua", "--help" },
    { "tools/quality/encoding.lua", "--help" },
    { "tools/quality/mutate.lua", "--help" },
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
        coroutine.resume(thread)
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
    'docs/reference/eggy/api/changelog.md',
    "update_api should keep the changelog under docs/reference/eggy/api"
  )
  _assert_not_contains(
    script_text,
    'docs/reference/eggy/api_changelog.md',
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
    local doc_dir = common.join_path(fixture_root, "docs/reference/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "legacy_call")
    _commit_all(fixture_root, "init")
    _write_update_api_fixture(new_path, "current_call")

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert(result.ok == false, "update_api should exit non-zero when API diff exists")
    assert(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == true,
      "update_api should generate split docs")
    assert(common.path_exists(changelog_path) == true,
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
    local doc_dir = common.join_path(fixture_root, "docs/reference/eggy/api")
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

    assert(result.ok == false,
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
    local doc_dir = common.join_path(fixture_root, "docs/reference/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "stable_call")
    _commit_all(fixture_root, "init")
    -- 不覆盖文件，内容与 git HEAD 相同

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert(result.ok == true, "update_api should exit 0 when API unchanged")
    assert(common.path_exists(changelog_path) == false,
      "update_api should not write changelog when API unchanged")
    assert(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == false,
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
  return common.join_path(fake_home, "Documents/eggy/LuaSource_大富翁")
end

local function _test_deploy_script_matches_simplified_cli()
  local script_text = assert(common.read_file(common.join_path(project_root, "tools/ops/deploy.ps1")))
  local param_block = assert(script_text:match("param%((.-)%)%s*%$ErrorActionPreference"),
    "deploy.ps1 should keep a top-level param block")
  _assert_contains(
    param_block,
    "[string]$Autotest",
    "deploy.ps1 should expose the autotest selector parameter"
  )
  _assert_not_contains(
    param_block,
    "$Profile",
    "deploy.ps1 should no longer expose the retired single-profile parameter (ADR 0026)"
  )
  _assert_not_contains(
    script_text,
    "STARTUP_TEST_PROFILE",
    "deploy.ps1 should no longer inject the retired STARTUP_TEST_PROFILE global (ADR 0026)"
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
      "& " .. _powershell_single_quote("./tools/ops/deploy.ps1") .. " -BuildMode debug",
    }, "; ")
    local result = _run_powershell_command(command)

    if result.skipped == true then
      return
    end
    if publish_target == nil then
      return
    end

    assert(result.ok == true, "deploy should succeed with debug profile under the simplified CLI")
    assert(common.path_exists(common.join_path(publish_target, "main.lua")) == true,
      "deploy should write main.lua into the default target path")
    assert(common.path_exists(common.join_path(publish_target, "src/config")) == true,
      "deploy should copy src into the default target path")
    assert(common.path_exists(common.join_path(publish_target, "Data/UIManagerNodes.lua")) == true,
      "deploy should copy UIManagerNodes into the default target path")
    assert(common.path_exists(common.join_path(publish_target, "Data/Prefab.lua")) == true,
      "deploy should copy Prefab into the default target path")

    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "debug"',
      "deploy should inject debug build mode into main.lua")
    _assert_not_contains(deployed_main, 'STARTUP_TEST_PROFILE = ',
      "debug deploy should no longer inject the retired startup profile global")
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

    assert(result.ok == true, "deploy should succeed without startup profile")
    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "release"',
      "deploy without startup profile should inject release build mode")
    _assert_not_contains(deployed_main, 'STARTUP_TEST_PROFILE = ',
      "deploy without startup profile should not inject STARTUP_TEST_PROFILE")
    _assert_not_contains(deployed_main, 'STARTUP_AUTOTEST = ',
      "release deploy should never inject STARTUP_AUTOTEST")
    _assert_contains(result.output, "Build mode: release",
      "deploy output should show release mode when no startup profile is present")
    assert(common.path_exists(common.join_path(publish_target, "src/config/testing")) == false,
      "release deploy should strip src/config/testing")
    assert(common.path_exists(common.join_path(publish_target, "src/app/testing")) == false,
      "release deploy should strip src/app/testing")
  end)

  _with_ascii_tmp("deploy_autotest", function(tmp_root)
    local fake_home = common.join_path(tmp_root, "fake_home")
    local publish_target = _expected_default_deploy_target(fake_home)
    local command = table.concat({
      "$env:HOME = " .. _powershell_single_quote(fake_home),
      "$env:USERPROFILE = " .. _powershell_single_quote(fake_home),
      "& " .. _powershell_single_quote("./tools/ops/deploy.ps1") .. " -Autotest all",
    }, "; ")
    local result = _run_powershell_command(command)

    if result.skipped == true then
      return
    end
    if publish_target == nil then
      return
    end

    assert(result.ok == true, "deploy -Autotest should succeed and imply debug build mode")
    local deployed_main = assert(common.read_file(common.join_path(publish_target, "main.lua")))
    _assert_contains(deployed_main, 'MONOPOLY_BUILD_MODE = "debug"',
      "autotest deploy should inject debug build mode")
    _assert_contains(deployed_main, 'STARTUP_AUTOTEST = "all"',
      "autotest deploy should inject the autotest selector")
    _assert_not_contains(deployed_main, 'STARTUP_TEST_PROFILE = ',
      "autotest deploy should not inject the retired startup profile global")
    _assert_contains(result.output, "Autotest: all",
      "deploy output should report the autotest selector")
    assert(common.path_exists(common.join_path(publish_target, "src/app/testing")) == true,
      "autotest deploy must keep src/app/testing (runner lives there)")

    local conflict_command = table.concat({
      "$env:HOME = " .. _powershell_single_quote(fake_home),
      "$env:USERPROFILE = " .. _powershell_single_quote(fake_home),
      "& " .. _powershell_single_quote("./tools/ops/deploy.ps1") .. " -BuildMode release -Autotest all",
    }, "; ")
    local conflict_result = _run_powershell_command(conflict_command)
    if conflict_result.skipped ~= true then
      assert(conflict_result.ok == false,
        "deploy must reject -BuildMode release together with -Autotest")
    end
  end)
end

local function _test_autotest_report_script_matches_cli()
  local script_text = assert(common.read_file(common.join_path(project_root, "tools/ops/autotest_report.ps1")))
  local param_block = assert(script_text:match("param%((.-)%)"),
    "autotest_report.ps1 should keep a top-level param block")
  _assert_contains(param_block, "[string]$LogPath",
    "autotest_report.ps1 should accept an explicit log path")
  _assert_contains(param_block, "[string]$TargetPath",
    "autotest_report.ps1 should accept a deploy target path")
  _assert_contains(param_block, "[switch]$Wait",
    "autotest_report.ps1 should support waiting for a running batch")
  _assert_contains(script_text, "function Join-LuaSourceDirName",
    "autotest_report.ps1 should resolve the same default deploy dir as deploy.ps1")
  _assert_contains(script_text, "[autotest]",
    "autotest_report.ps1 should parse the [autotest] line contract")
end

local function _write_autotest_log(path, lines)
  _write_fixture_file(path, table.concat(lines, "\n") .. "\n")
end

local function _run_autotest_report(log_path)
  local command = "& " .. _powershell_single_quote("./tools/ops/autotest_report.ps1")
    .. " -LogPath " .. _powershell_single_quote(log_path)
  return _run_powershell_command(command)
end

local function _test_autotest_report_parses_results()
  _with_ascii_tmp("autotest_report", function(tmp_root)
    local pass_log = common.join_path(tmp_root, "pass_log.txt")
    _write_autotest_log(pass_log, {
      "12:00:00 [info] [autotest] begin selector=all total=2",
      "12:00:01 [info] [autotest] profile=solo_mine index=1 result=pass reason=budget_turns turns=6 seconds=3.0 warns=0",
      "12:00:02 [info] [autotest] profile=solo_missile index=2 result=pass reason=expect_met turns=2 seconds=1.0 warns=0",
      "12:00:03 [info] [autotest] summary total=2 pass=2 fail=0 seconds=4.0",
    })
    local pass_result = _run_autotest_report(pass_log)
    if pass_result.skipped == true then
      return
    end
    assert(pass_result.ok == true, "all-pass log should exit zero: " .. tostring(pass_result.output))
    _assert_contains(pass_result.output, "All profiles passed",
      "report should announce the all-pass verdict")
    _assert_contains(pass_result.output, "summary total=2 pass=2 fail=0",
      "report should echo the summary line")

    local fail_log = common.join_path(tmp_root, "fail_log.txt")
    _write_autotest_log(fail_log, {
      "12:00:00 [info] [autotest] begin selector=all total=2",
      "12:00:01 [info] [autotest] profile=solo_mine index=1 result=fail reason=tick_error turns=1 seconds=2.0 warns=0 message=\"boom\"",
      "12:00:02 [info] [autotest] profile=solo_missile index=2 result=pass reason=expect_met turns=2 seconds=1.0 warns=0",
      "12:00:03 [info] [autotest] summary total=2 pass=1 fail=1 seconds=3.0",
    })
    local fail_result = _run_autotest_report(fail_log)
    assert(fail_result.ok == false, "failing profiles should exit non-zero")
    _assert_contains(fail_result.output, "1 profile(s) failed",
      "report should count failing profiles")

    local unfinished_log = common.join_path(tmp_root, "unfinished_log.txt")
    _write_autotest_log(unfinished_log, {
      "12:00:00 [info] [autotest] begin selector=all total=2",
      "12:00:01 [info] [autotest] profile=solo_mine index=1 result=pass reason=budget_turns turns=6 seconds=3.0 warns=0",
    })
    local unfinished_result = _run_autotest_report(unfinished_log)
    assert(unfinished_result.ok == false, "missing summary should exit non-zero without -Wait")
    _assert_contains(unfinished_result.output, "no summary",
      "report should explain the run has not finished")

    local empty_log = common.join_path(tmp_root, "empty_log.txt")
    _write_autotest_log(empty_log, {
      "12:00:00 [info] [Eggy] startup policy: build_mode=debug autotest=nil",
    })
    local empty_result = _run_autotest_report(empty_log)
    assert(empty_result.ok == false, "log without autotest markers should exit non-zero")
    _assert_contains(empty_result.output, "no [autotest] output",
      "report should explain missing autotest output")

    local error_log = common.join_path(tmp_root, "error_log.txt")
    _write_autotest_log(error_log, {
      "12:00:00 [info] [autotest] error message=\"unknown autotest profile: nope\"",
    })
    local error_result = _run_autotest_report(error_log)
    assert(error_result.ok == false, "startup error line should exit non-zero")
    _assert_contains(error_result.output, "startup error",
      "report should surface the startup error verdict")
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
        asset_root = common.join_path(arch_tool.root, "viewer"),
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

local function _test_mutate_wrapper_scan_json_output()
  local result = _run_lua({
    "tools/quality/mutate.lua",
    "src/foundation/identity.lua",
    "--scan",
    "--json",
  })

  assert(result.ok == true, "mutate wrapper scan should succeed")
  _assert_contains(result.output, "\"relative_file\":\"src/foundation/identity.lua\"",
    "mutate scan should report the normalized target path")
  _assert_contains(result.output, "\"sites\":[",
    "mutate scan should emit discovered mutation sites in json output")
end

local function _test_reference_tools_do_not_expose_bin_entrypoints()
  local removed_paths = {
    common.join_path(arch_tool.root, "bin"),
  }

  for _, path in ipairs(removed_paths) do
    assert(common.path_exists(path) ~= true,
      "reference 4lua tools should not expose bin entrypoints: " .. path)
  end
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

-- daily granularity 契约：同一天多次 commit 合并成 1 个 daily snapshot（end-of-day state）
local function _test_loc_history_returns_daily_snapshots()
  _with_ascii_tmp("loc_history_daily", function(tmp_root)
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

    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v1)
    _write_fixture_file(common.join_path(tests_dir, "spec.lua"), test_v1)
    _commit_all(repo_root, "initial loc fixtures")

    _write_fixture_file(common.join_path(src_dir, "a.lua"), src_v2)
    _write_fixture_file(common.join_path(tests_dir, "extra.lua"), test_v2)
    _write_fixture_file(common.join_path(tests_dir, "empty.lua"), "")
    _run_in_dir(repo_root, { "git", "mv", "tests/spec.lua", "tests/spec_renamed.lua" })
    _commit_all(repo_root, "modify add rename")

    loc_history.reset_caches()
    local result, history_err = loc_history.count_history({
      git_root = repo_root,
      days = 1,
    })
    if result == nil then
      error(history_err)
    end

    local rows = result.rows or {}
    assert(#rows == 1,
      "daily mode should collapse same-day commits into one row, got " .. tostring(#rows))

    local today = os.date("%Y-%m-%d")
    assert(rows[1].date == today,
      "daily row date should equal today (YYYY-MM-DD), got: " .. tostring(rows[1].date))

    assert(rows[1].src_loc == _line_count(src_v2),
      "daily snapshot should reflect final src state (v2)")
    assert(rows[1].tests_loc == _line_count(test_v1) + _line_count(test_v2),
      "daily snapshot should accumulate renamed and new tests LOC")
    assert(rows[1].tests_files == 2,
      "daily snapshot should count renamed and new tests files")
    assert(not rows[1].carried_forward,
      "actual-commit day should not be marked as carried forward")
  end)
end

local contract_tests = {
  { group = "shared", owner = "common", name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
  { group = "shared", owner = "common", name = "common_handles_unicode_paths_for_file_ops", run = _test_common_handles_unicode_paths_for_file_ops },
  { group = "shared", owner = "arch", name = "arch_common_reuses_unicode_safe_file_ops", run = _test_arch_common_reuses_unicode_safe_file_ops },
  { group = "shared", owner = "common", name = "windows_utf8_console_switches_once_per_process", run = _test_windows_utf8_console_switches_once_per_process },
  { group = "shared", owner = "common", name = "windows_utf8_console_dispatch", run = _test_windows_utf8_console_dispatch },
  { group = "shared", owner = "tooling_policy", name = "cli_help_text_is_bilingual", run = _test_cli_help_text_is_bilingual },
  { group = "quality", owner = "arch", name = "arch_view_viewer_supports_unicode_output_path", run = _test_arch_view_viewer_supports_unicode_output_path },
  { group = "quality", owner = "mutate", name = "mutate_wrapper_scan_json_output", run = _test_mutate_wrapper_scan_json_output },
  { group = "quality", owner = "tooling_policy", name = "reference_tools_do_not_expose_bin_entrypoints", run = _test_reference_tools_do_not_expose_bin_entrypoints },
  { group = "shared", owner = "bootstrap", name = "bootstrap_resolves_repo_root_from_non_repo_cwd", run = _test_bootstrap_resolves_repo_root_from_non_repo_cwd },
  { group = "shared", owner = "loc_history", name = "loc_history_returns_daily_snapshots", run = _test_loc_history_returns_daily_snapshots },
  { group = "ops", owner = "deploy", name = "deploy_script_matches_simplified_cli", run = _test_deploy_script_matches_simplified_cli },
  { group = "ops", owner = "autotest_report", name = "autotest_report_script_matches_cli", run = _test_autotest_report_script_matches_cli },
  { group = "ops", owner = "update_api", name = "update_api_writes_changelog_into_docs_eggy_api_dir", run = _test_update_api_writes_changelog_into_docs_eggy_api_dir },
  { group = "ops", owner = "update_api", name = "update_api_updates_docs_and_changelog_when_api_changes", run = _test_update_api_updates_docs_and_changelog_when_api_changes },
  { group = "ops", owner = "update_api", name = "update_api_reports_extra_doc_entries_when_check_fails", run = _test_update_api_reports_extra_doc_entries_when_check_fails },
  { group = "ops", owner = "update_api", name = "update_api_skips_all_writes_when_api_unchanged", run = _test_update_api_skips_all_writes_when_api_unchanged },
}

local tooling_tests = {
  { group = "quality", owner = "encoding", name = "encoding_check_accepts_utf8_chinese_strings", run = _test_encoding_check_accepts_utf8_chinese_strings },
  { group = "quality", owner = "encoding", name = "encoding_check_reports_suspicious_english_comment", run = _test_encoding_check_reports_suspicious_english_comment },
  { group = "quality", owner = "encoding", name = "encoding_check_reports_invalid_utf8_bytes", run = _test_encoding_check_reports_invalid_utf8_bytes },
  { group = "quality", owner = "mutate", name = "mutate_wrapper_indexes_behavior_suites_as_json", run = _test_mutate_wrapper_indexes_behavior_suites_as_json },
  { group = "ops", owner = "deploy", name = "deploy_comprehensive", run = _test_deploy_comprehensive },
  { group = "ops", owner = "autotest_report", name = "autotest_report_parses_results", run = _test_autotest_report_parses_results },
  { group = "shared", owner = "common", name = "run_command_preserves_bilingual_stderr_and_utf8_stdin", run = _test_run_command_preserves_bilingual_stderr_and_utf8_stdin },
}

local valid_groups = {
  ops = true,
  quality = true,
  shared = true,
}

local valid_owners = {
  arch = true,
  autotest_report = true,
  bootstrap = true,
  common = true,
  deploy = true,
  encoding = true,
  loc_history = true,
  mutate = true,
  tooling_policy = true,
  update_api = true,
}

local function _validate_cases(cases, label)
  for _, case in ipairs(cases or {}) do
    if valid_groups[case.group] ~= true then
      error(string.format(
        "%s case %s has invalid tooling group: %s",
        label,
        tostring(case.name),
        tostring(case.group)
      ))
    end
    if valid_owners[case.owner] ~= true then
      error(string.format(
        "%s case %s has invalid tooling owner: %s",
        label,
        tostring(case.name),
        tostring(case.owner)
      ))
    end
  end
end

local function _cases_for_group(cases, group)
  local selected = {}
  for _, case in ipairs(cases or {}) do
    if case.group == group then
      selected[#selected + 1] = case
    end
  end
  return selected
end

local function _cases_for_owner(cases, owner)
  local selected = {}
  for _, case in ipairs(cases or {}) do
    if case.owner == owner then
      selected[#selected + 1] = case
    end
  end
  return selected
end

_validate_cases(contract_tests, "contract")
_validate_cases(tooling_tests, "tooling")

return {
  name = "script_tools_contract",
  tests = contract_tests,
  tooling_tests = tooling_tests,
  cases_for_group = _cases_for_group,
  cases_for_owner = _cases_for_owner,
}
