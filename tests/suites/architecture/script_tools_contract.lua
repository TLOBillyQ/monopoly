local bootstrap = require("tests.bootstrap")
local common = require("lib.common")
local arch_common = require("arch_view.common")

bootstrap.install_package_paths()

local project_root = common.normalize_path(common.current_dir())
local tmp_root = common.join_path(common.system_tmp_dir(), "monopoly_script_tools_contract_中文 English")

local function _assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function _cleanup_tmp()
  local ok, err = common.remove_path(tmp_root)
  if ok == nil then
    error(err)
  end
end

local function _with_clean_tmp(fn)
  _cleanup_tmp()
  local ok, err = xpcall(fn, debug.traceback)
  _cleanup_tmp()
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
  _with_clean_tmp(function()
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
  _with_clean_tmp(function()
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
    { "scripts/deploy.lua", "--help" },
    { "scripts/export_xlsx.lua", "--help" },
    { "scripts/update_api.lua", "--help" },
    { "scripts/arch.lua", "--help" },
    { "scripts/airl.lua", "--help" },
    { "scripts/crap.lua", "--help" },
    { "scripts/mutate.lua", "--help" },
  }

  for _, args in ipairs(help_commands) do
    local result = _run_lua(args)
    assert(result.ok == true, "help command should exit successfully for " .. table.concat(args, " "))
    _assert_contains(result.output, "用法", "help output should include Chinese usage text")
    _assert_contains(result.output, "Usage", "help output should include English usage text")
  end
end

local function _test_deploy_unknown_flag_is_bilingual()
  local result = _run_lua({ "scripts/deploy.lua", "--bad-flag" })
  assert(result.ok == false, "deploy should fail on unknown flags")
  _assert_contains(result.output, "未知参数", "unknown flag output should include Chinese text")
  _assert_contains(result.output, "Unknown flag", "unknown flag output should include English text")
end

local function _test_arch_view_viewer_supports_unicode_output_path()
  _with_clean_tmp(function()
    local out_dir = common.join_path(tmp_root, "arch_view_目标/中文 English")
    local result = _run_lua({
      "scripts/arch.lua",
      "viewer",
      "--out-dir",
      out_dir,
      "--in-json",
      "scripts/arch/viewer/architecture.json",
    })

    assert(result.ok == true, "arch viewer should succeed for unicode output paths")
    _assert_contains(result.output, "arch_view 视图已生成", "arch viewer logs should include Chinese text")
    _assert_contains(result.output, "arch_view viewer ok", "arch viewer logs should include English text")
    assert(common.path_exists(common.join_path(out_dir, "index.html")) == true, "arch viewer should write index.html")
    assert(common.path_exists(common.join_path(out_dir, "architecture.json")) == true, "arch viewer should write architecture.json")
  end)
end

local function _test_airl_generate_verify_succeeds()
  local result = _run_lua({ "scripts/airl.lua", "generate", "--verify" })
  assert(result.ok == true, "airl generate --verify should succeed")
  _assert_contains(result.output, "air_l generate verify ok", "airl verify output should include success text")
end

local function _test_airl_generate_supports_unicode_output_path()
  _with_clean_tmp(function()
    local out_dir = common.join_path(tmp_root, "airl_输出/中文 English")
    local result = _run_lua({
      "scripts/airl.lua",
      "generate",
      "--out-dir",
      out_dir,
    })

    assert(result.ok == true, "airl generate should succeed for unicode output paths")
    _assert_contains(result.output, "air_l generate ok", "airl generate output should include success text")
    assert(common.path_exists(common.join_path(out_dir, "main.lua")) == true, "airl generate should write main.lua")
    assert(common.path_exists(common.join_path(out_dir, "src/entry/init.lua")) == true,
      "airl generate should write src/entry/init.lua")
  end)
end

return {
  name = "script_tools_contract",
  tests = {
    { name = "common_handles_unicode_paths_for_file_ops", run = _test_common_handles_unicode_paths_for_file_ops },
    { name = "arch_common_reuses_unicode_safe_file_ops", run = _test_arch_common_reuses_unicode_safe_file_ops },
    { name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
    { name = "cli_help_text_is_bilingual", run = _test_cli_help_text_is_bilingual },
    { name = "airl_generate_verify_succeeds", run = _test_airl_generate_verify_succeeds },
    { name = "airl_generate_supports_unicode_output_path", run = _test_airl_generate_supports_unicode_output_path },
    { name = "deploy_unknown_flag_is_bilingual", run = _test_deploy_unknown_flag_is_bilingual },
    { name = "arch_view_viewer_supports_unicode_output_path", run = _test_arch_view_viewer_supports_unicode_output_path },
  },
}
