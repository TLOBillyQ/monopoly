local bootstrap = require("test.bootstrap")
local arch_tool = assert(bootstrap.ensure_tool("arch_view"))
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local text_lib = require("foundation.text")
local arch_common = require("arch_view.runtime.common")
local arch_cli = require("packages.arch_view.runner")

bootstrap.install_package_paths()

local project_root = path_lib.normalize_path(env_lib.current_dir())

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if fs_lib.path_exists(path) == true then
      return path
    end
  end
  return paths and paths[1] or nil
end

local function _make_tmp_root(tag)
  return env_lib.make_temp_path("script_tools_contract_" .. tostring(tag or "tmp"), "") .. "_中文 English"
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
  local ok, err = fs_lib.remove_path(tmp_root)
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
  local tmp_root = env_lib.make_temp_path("script_tools_contract_" .. tostring(tag or "tmp"), "")
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
  local out_path = path_lib.join_path(tmp_root, "arch_view_input/architecture.json")
  local default_config_path = _first_existing({
    path_lib.join_path(project_root, "tools/packages/arch_view/config.json"),
  })
  local ok, err = xpcall(function()
    return arch_cli.run({
      "scan",
      "--out",
      out_path,
    }, {
      cwd = project_root,
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
  return proc_lib.run_command(command, {
    cwd = project_root,
  })
end


local function _write_fixture_file(path, content)
  local ok, err = fs_lib.write_file(path, content)
  if not ok then
    error(err)
  end
end

local function _test_encoding_check_accepts_utf8_chinese_strings()
  _with_ascii_tmp("encoding_chinese_strings", function(tmp_root)
    local src_dir = path_lib.join_path(tmp_root, "src")
    local fixture_path = path_lib.join_path(src_dir, "ui/prompt.lua")
    _write_fixture_file(fixture_path, table.concat({
      'local prompt = "中文提示…继续"',
      "return prompt",
      "",
    }, "\n"))

    local result = _run_lua({
      "tools/packages/encoding/encoding.lua",
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
    local src_dir = path_lib.join_path(tmp_root, "src")
    local fixture_path = path_lib.join_path(src_dir, "ui/anim.lua")
    _write_fixture_file(fixture_path, table.concat({
      "-- Fallback: no scheduler — preserve original call order",
      "return true",
      "",
    }, "\n"))

    local result = _run_lua({
      "tools/packages/encoding/encoding.lua",
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
    local src_dir = path_lib.join_path(tmp_root, "src")
    local fixture_path = path_lib.join_path(src_dir, "broken.lua")
    _write_fixture_file(fixture_path, "local broken = '" .. string.char(0xFF) .. "'\n")

    local result = _run_lua({
      "tools/packages/encoding/encoding.lua",
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

local function _test_foundation_handles_unicode_paths_for_file_ops()
  _with_clean_tmp("common_file_ops", function(tmp_root)
    local base = path_lib.join_path(tmp_root, "common_子目录/更多目录")
    local file_path = path_lib.join_path(base, "测试_文件.lua")
    local copy_source = path_lib.join_path(tmp_root, "copy_source")
    local copy_target = path_lib.join_path(tmp_root, "copy_target_中文/复制目录")

    local ok, err = fs_lib.ensure_dir(base)
    if not ok then
      error(err)
    end

    ok, err = fs_lib.write_file(file_path, 'return { value = "中文 English" }\n')
    if not ok then
      error(err)
    end

    ok, err = fs_lib.append_file(file_path, "-- appended\n")
    if not ok then
      error(err)
    end

    assert(fs_lib.path_exists(file_path) == true, "unicode file path should exist after write")

    local content, read_err = fs_lib.read_file(file_path)
    if content == nil then
      error(read_err)
    end
    _assert_contains(content, "中文 English", "unicode file content should round-trip through file io")
    _assert_contains(content, "-- appended", "append_file should preserve appended content")

    local files, list_err = proc_lib.collect_lua_files(tmp_root)
    if files == nil then
      error(list_err)
    end
    assert(#files == 1, "collect_lua_files should find the unicode fixture file")
    _assert_contains(files[1], "测试_文件.lua", "collect_lua_files should preserve unicode file names")

    ok, err = fs_lib.ensure_dir(path_lib.join_path(copy_source, "nested"))
    if not ok then
      error(err)
    end
    ok, err = fs_lib.write_file(path_lib.join_path(copy_source, "nested/sample.lua"), "return 1\n")
    if not ok then
      error(err)
    end

    ok, err = fs_lib.copy_tree(copy_source, copy_target)
    if not ok then
      error(err)
    end
    assert(fs_lib.path_exists(path_lib.join_path(copy_target, "nested/sample.lua")) == true,
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
  assert(proc_lib.command_exists("lua") == true, "lua should exist in the test environment")
  assert(proc_lib.command_exists("monopoly_command_that_should_not_exist_12345") == false,
    "command_exists should return false for missing commands")
end

-- arity 是这条契约的重点,不是顺手加的。tools/ 下先前有三处 _trim 写成
--   return tostring(v):gsub("^%s+",""):gsub("%s+$","")
-- gsub 返回 (结果, 替换次数),于是 `return _trim(x)` 的函数悄悄多吐一个数字:
-- 某返回 repo_root 的契约本是 (path) / (nil, err),成功时实际返回 (path, 1)。
-- 调用方恰好按 `if root == nil` 判断才没炸——改成 `if root_err` 就炸。
-- 所以这里钉死:trim 只返回一个值。
local function _test_trim_strips_whitespace_and_returns_one_value()
  assert(text_lib.trim("  padded  ") == "padded", "trim should strip leading and trailing whitespace")
  assert(text_lib.trim("") == "", "trim should map empty string to empty string")
  assert(text_lib.trim(nil) == "", "trim should map nil to empty string")
  assert(text_lib.trim("\n\tmixed \r\n") == "mixed", "trim should strip mixed whitespace")
  assert(text_lib.trim("in  ner") == "in  ner", "trim should not touch interior whitespace")

  assert(select("#", text_lib.trim("  x  ")) == 1,
    "trim must return exactly one value; returning gsub's replacement count corrupts (value)/(nil, err) contracts")
end

-- 同一缺陷类的第三、四例(前两例见 trim 那条契约)。path_exists / is_dir 先前直接
-- `return _os_execute_success(...)`,而它返回 (成功, 退出码),于是这两个谓词实际返回
-- (true, 0)。verify_full 与 packages/luaunit_runner/lua54.lua 的
-- _path_or_command_available 又原样 `return fs_lib.path_exists(text)` 把这对值
-- 继续上传。谓词只该答"是/否"。
local function _test_path_predicates_return_one_boolean()
  assert(fs_lib.path_exists("tools") == true, "path_exists should find an existing directory")
  assert(fs_lib.path_exists("tools/foundation/fs.lua") == true, "path_exists should find an existing file")
  assert(fs_lib.path_exists("monopoly_missing_path_12345") == false, "path_exists should reject a missing path")

  assert(fs_lib.is_dir("tools") == true, "is_dir should accept a directory")
  assert(fs_lib.is_dir("tools/foundation/fs.lua") == false, "is_dir should reject a regular file")
  assert(fs_lib.is_dir("monopoly_missing_path_12345") == false, "is_dir should reject a missing path")

  assert(select("#", fs_lib.path_exists("tools")) == 1,
    "path_exists must return exactly one value; leaking os.execute's exit code corrupts predicate contracts")
  assert(select("#", fs_lib.is_dir("tools")) == 1,
    "is_dir must return exactly one value; leaking os.execute's exit code corrupts predicate contracts")
end


local function _test_cli_help_text_is_bilingual()
  local help_commands = {
    { "tools/packages/arch_view/runner.lua", "--help" },
    { "tools/packages/crap/runner.lua", "--help" },
    { "tools/packages/encoding/encoding.lua", "--help" },
    { "tools/packages/mutate/runner.lua", "--help" },
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

-- 部署目标只有 Windows 侧 Eggy 宿主:原生 win 或 WSL(经 cmd.exe + wslpath 互操作,
-- #128 / #127 平台约束)。mac / native Linux 落点已删除,脚本在这些平台直接报错。
-- WSL 落点无法用 fake_home 沙箱化(读的是 Windows 侧 %USERPROFILE%),
-- 故部署行为由文本断言 + 非目标平台的报错断言钉住。
local function _test_deploy_lua_matches_simplified_cli()
  local script_text = assert(fs_lib.read_file(path_lib.join_path(project_root, "tools/packages/ops/deploy.lua")))

  -- 零参数 CLI:任何参数都 ERROR + exit 1。
  _assert_contains(
    script_text,
    "Unexpected argument",
    "deploy.lua should reject any CLI argument (zero-parameter interface)"
  )

  -- cli.lua 顶层路由:deploy 子命令挂载到 ops 包(命令集 ↔ packages/ 一致性由
  -- cli_command_table_guard 结构保证,这里钉行为面:入口必须经 cli.lua 可达)。
  local cli_source = assert(fs_lib.read_file(path_lib.join_path(project_root, "tools/cli.lua")))
  _assert_contains(cli_source, 'name = "deploy"', "cli.lua should route the deploy subcommand")
  _assert_contains(cli_source, 'pkg = "ops"', "cli.lua deploy should route to packages.ops")

  -- 退役全局/参数:不再注入 build-mode / deploy-target / startup-test-profile。
  _assert_not_contains(
    script_text,
    "MONOPOLY_BUILD_MODE",
    "deploy.lua should no longer inject any build-mode global"
  )
  _assert_not_contains(
    script_text,
    "MONOPOLY_DEPLOY_TARGET",
    "deploy.lua should no longer read MONOPOLY_DEPLOY_TARGET fallback"
  )
  _assert_not_contains(
    script_text,
    "STARTUP_TEST_PROFILE",
    "deploy.lua should no longer inject the retired STARTUP_TEST_PROFILE global"
  )

  -- LuaSource 目录名集中构造。
  _assert_contains(
    script_text,
    "function M.join_lua_source_dir_name",
    "deploy.lua should centralize the LuaSource directory name construction"
  )

  -- 原生 Windows 落点:~/Desktop/dev/eggy/LuaSource_大富翁。
  _assert_contains(
    script_text,
    '_join_path(_join_path(_join_path(_join_path(home_dir, "Desktop"), "dev"), "eggy"), M.join_lua_source_dir_name())',
    "deploy.lua should keep the windows default deploy path semantics"
  )

  -- WSL 分支(#128 / #127 平台约束):落点解析到 Windows 用户 Desktop/dev/eggy,不是 WSL 内部 $HOME。
  _assert_contains(
    script_text,
    "function M.test_is_wsl_host",
    "deploy.lua should detect WSL separately from native Linux"
  )
  _assert_contains(
    script_text,
    "function M.resolve_wsl_windows_home",
    "deploy.lua should resolve the Windows host home when deploying from WSL"
  )
  _assert_contains(
    script_text,
    '_join_path(_join_path(_join_path(_join_path(win_home, "Desktop"), "dev"), "eggy"), M.join_lua_source_dir_name())',
    "deploy.lua WSL branch should target the Windows-side Desktop/dev/eggy path"
  )

  -- 非目标平台落点与检测已删除。
  _assert_not_contains(
    script_text,
    "function M.test_is_macos_host",
    "deploy.lua should no longer detect macOS (Windows-only deploy target)"
  )
  _assert_not_contains(
    script_text,
    "function M.test_is_linux_host",
    "deploy.lua should no longer detect native Linux (Windows-only deploy target)"
  )
  _assert_not_contains(
    script_text,
    '"Documents"',
    "deploy.lua should no longer keep mac/native-linux deploy targets (Windows-only)"
  )

  -- 不再使用发布/备份后缀路径。
  _assert_not_contains(
    script_text,
    "LuaSource_大富翁-发布",
    "deploy.lua should no longer keep suffix-based default deploy paths"
  )
  _assert_not_contains(
    script_text,
    "LuaSource_大富翁-备份",
    "deploy.lua should no longer keep suffix-based backup deploy paths"
  )
end

local function _running_under_wsl()
  if os.getenv("WSL_DISTRO_NAME") ~= nil then
    return true
  end
  local handle = io.open("/proc/version", "r")
  if handle == nil then
    return false
  end
  local version_text = handle:read("*a") or ""
  handle:close()
  return version_text:lower():find("microsoft", 1, true) ~= nil
end

local function _test_deploy_comprehensive()
  _test_deploy_lua_matches_simplified_cli()

  if _running_under_wsl() then
    return
  end

  -- 非 win/WSL 平台(mac / native Linux)不再是部署目标,脚本必须直接报错退出。
  local result = _run_lua({ "tools/packages/ops/deploy.lua" })
  assert(result.ok == false,
    "deploy should fail on non-Windows/non-WSL platforms (Windows-only deploy target)")
  _assert_contains(result.output, "Windows only",
    "deploy failure should state the Windows-only deploy target")
end

local function _test_run_command_preserves_bilingual_stderr_and_utf8_stdin()
  _with_clean_tmp("run_command_stderr_capture", function(tmp_root)
    local script_path = path_lib.join_path(tmp_root, "capture_output.lua")
    local stdin_path = path_lib.join_path(tmp_root, "stdin.txt")
    local ok, err = fs_lib.write_file(script_path, table.concat({
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

    ok, err = fs_lib.write_file(stdin_path, "stdin 中文 / utf8 stdin")
    if not ok then
      error(err)
    end

    local result = proc_lib.run_command({ "lua", script_path }, {
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
    local out_dir = path_lib.join_path(tmp_root, "arch_view_目标/中文 English")
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
    assert(fs_lib.path_exists(path_lib.join_path(out_dir, "index.html")) == true, "arch viewer should write index.html")
    assert(fs_lib.path_exists(path_lib.join_path(out_dir, "architecture.json")) == true, "arch viewer should write architecture.json")
  end)
end

local function _test_mutate_wrapper_scan_output()
  local result = _run_lua({
    "tools/packages/mutate/runner.lua",
    "src/foundation/identity.lua",
    "--scan",
  })

  assert(result.ok == true, "mutate wrapper scan should succeed")
  _assert_contains(result.output, "file: src/foundation/identity.lua",
    "mutate scan should report the normalized target path")
  _assert_contains(result.output, "sites: ",
    "mutate scan should emit discovered mutation site count")
end

local function _test_reference_tools_do_not_expose_bin_entrypoints()
  -- tree 形态下 root 即 luarocks tree,bin/ 住着其它工具的入口(dry4lua 等);
  -- arch_view 自身的契约改为检查 rock 安装清单不含 bin 条目。
  local version = arch_tool.url:match("arch_view%-(%d+%.%d+%.%d+%-%d+)%.rockspec$")
  assert(version ~= nil, "cannot parse arch_view version from pin url: " .. tostring(arch_tool.url))
  local manifest_path = path_lib.join_path(arch_tool.root,
    "lib/luarocks/rocks-5.4/arch_view/" .. version .. "/rock_manifest")
  local manifest = assert(fs_lib.read_file(manifest_path))
  assert(manifest:find("bin =", 1, true) == nil,
    "reference 4lua tools should not expose bin entrypoints: " .. manifest_path)
end

local function _test_bootstrap_resolves_repo_root_from_non_repo_cwd()
  _with_ascii_tmp("bootstrap_non_repo_cwd", function(tmp_root)
    local outside_dir = path_lib.join_path(tmp_root, "outside")
    local ok, err = fs_lib.ensure_dir(outside_dir)
    if not ok then
      error(err)
    end

    local bootstrap_path = path_lib.join_path(project_root, "tools/foundation/bootstrap.lua")
    local script_path = path_lib.join_path(project_root, "tools/packages/crap/runner.lua")
    local expected_root = path_lib.normalize_path(project_root)
    local lua_snippet = table.concat({
      "local bootstrap = dofile(" .. string.format("%q", bootstrap_path) .. ")",
      "local env = bootstrap.install(" .. string.format("%q", script_path) .. ")",
      "assert(env.repo_root == " .. string.format("%q", expected_root) .. ", 'repo root mismatch')",
      "io.write(env.repo_root)",
    }, "\n")

    local bootstrap_result = proc_lib.run_command({ "lua", "-e", lua_snippet }, {
      cwd = outside_dir,
    })
    assert(bootstrap_result.ok == true, "bootstrap helper should resolve repo_root outside the repo cwd")
    _assert_contains(bootstrap_result.output, expected_root,
      "bootstrap helper should report the normalized repo root")

    local help_result = proc_lib.run_command({ "lua", script_path, "--help" }, {
      cwd = outside_dir,
    })
    assert(help_result.ok == true, "tool entrypoint should resolve bootstrap dependencies outside the repo cwd")
    _assert_contains(help_result.output, "Usage",
      "tool help should still render when launched outside the repo cwd")
  end)
end

local contract_tests = {
  { group = "shared", owner = "foundation", name = "command_exists_reports_present_and_missing_commands", run = _test_command_exists_reports_present_and_missing_commands },
  { group = "shared", owner = "foundation", name = "trim_strips_whitespace_and_returns_one_value", run = _test_trim_strips_whitespace_and_returns_one_value },
  { group = "shared", owner = "foundation", name = "path_predicates_return_one_boolean", run = _test_path_predicates_return_one_boolean },
  { group = "shared", owner = "foundation", name = "foundation_handles_unicode_paths_for_file_ops", run = _test_foundation_handles_unicode_paths_for_file_ops },
  { group = "shared", owner = "arch", name = "arch_common_reuses_unicode_safe_file_ops", run = _test_arch_common_reuses_unicode_safe_file_ops },
  { group = "shared", owner = "tooling_policy", name = "cli_help_text_is_bilingual", run = _test_cli_help_text_is_bilingual },
  { group = "quality", owner = "arch", name = "arch_view_viewer_supports_unicode_output_path", run = _test_arch_view_viewer_supports_unicode_output_path },
  { group = "quality", owner = "tooling_policy", name = "reference_tools_do_not_expose_bin_entrypoints", run = _test_reference_tools_do_not_expose_bin_entrypoints },
  { group = "shared", owner = "bootstrap", name = "bootstrap_resolves_repo_root_from_non_repo_cwd", run = _test_bootstrap_resolves_repo_root_from_non_repo_cwd },
  { group = "ops", owner = "deploy", name = "deploy_lua_matches_simplified_cli", run = _test_deploy_lua_matches_simplified_cli },
}

local tooling_tests = {
  { group = "quality", owner = "encoding", name = "encoding_check_accepts_utf8_chinese_strings", run = _test_encoding_check_accepts_utf8_chinese_strings },
  { group = "quality", owner = "encoding", name = "encoding_check_reports_suspicious_english_comment", run = _test_encoding_check_reports_suspicious_english_comment },
  { group = "quality", owner = "encoding", name = "encoding_check_reports_invalid_utf8_bytes", run = _test_encoding_check_reports_invalid_utf8_bytes },
  { group = "quality", owner = "mutate", name = "mutate_wrapper_scan_output", run = _test_mutate_wrapper_scan_output },
  { group = "ops", owner = "deploy", name = "deploy_comprehensive", run = _test_deploy_comprehensive },
  { group = "shared", owner = "foundation", name = "run_command_preserves_bilingual_stderr_and_utf8_stdin", run = _test_run_command_preserves_bilingual_stderr_and_utf8_stdin },
}

local valid_groups = {
  ops = true,
  quality = true,
  shared = true,
}

local valid_owners = {
  arch = true,
  bootstrap = true,
  foundation = true,
  deploy = true,
  encoding = true,
  mutate = true,
  tooling_policy = true,
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

--[[ mutate4lua-manifest
version=4
projectHash=9c63fe154b5e3d51
scope.0.id=chunk:test/support/tooling_suites/architecture/script_tools_contract.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=700
scope.0.semanticHash=4e6546132414cec7
scope.1.id=function:_first_existing
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=22
scope.1.semanticHash=49a62996f44e3261
scope.2.id=function:_make_tmp_root
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=26
scope.2.semanticHash=5ca59ebf20728f69
scope.3.id=function:_assert_contains
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=32
scope.3.semanticHash=9fde07c4dd671be7
scope.4.id=function:_assert_not_contains
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=38
scope.4.semanticHash=175dacfbe2bc5492
scope.5.id=function:_cleanup_tmp
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=45
scope.5.semanticHash=471994ee634a8162
scope.6.id=function:_with_clean_tmp
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=57
scope.6.semanticHash=6cd8268e4092c9b1
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=52
scope.7.semanticHash=600a75ce96a391b3
scope.8.id=function:_with_ascii_tmp
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=69
scope.8.semanticHash=4c6776d3df6e51a2
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=62
scope.9.endLine=64
scope.9.semanticHash=600a75ce96a391b3
scope.10.id=function:_generate_arch_view_input_json
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=90
scope.10.semanticHash=7b7214ce0bb6dea1
scope.11.id=function:<anonymous>#3
scope.11.kind=function
scope.11.startLine=76
scope.11.endLine=85
scope.11.semanticHash=c8d899e95cd7b1ca
scope.12.id=function:_run_lua
scope.12.kind=function
scope.12.startLine=92
scope.12.endLine=100
scope.12.semanticHash=08533f908e150c7b
scope.13.id=function:_write_fixture_file
scope.13.kind=function
scope.13.startLine=103
scope.13.endLine=108
scope.13.semanticHash=91399cc86dab88bf
scope.14.id=function:_test_encoding_check_accepts_utf8_chinese_strings
scope.14.kind=function
scope.14.startLine=110
scope.14.endLine=131
scope.14.semanticHash=44275e1b556e1799
scope.15.id=function:<anonymous>#4
scope.15.kind=function
scope.15.startLine=111
scope.15.endLine=130
scope.15.semanticHash=f1c1d819c73a4726
scope.16.id=function:_test_encoding_check_reports_suspicious_english_comment
scope.16.kind=function
scope.16.startLine=133
scope.16.endLine=158
scope.16.semanticHash=b75c8db97792eb11
scope.17.id=function:<anonymous>#5
scope.17.kind=function
scope.17.startLine=134
scope.17.endLine=157
scope.17.semanticHash=89541a43c8812b06
scope.18.id=function:_test_encoding_check_reports_invalid_utf8_bytes
scope.18.kind=function
scope.18.startLine=160
scope.18.endLine=179
scope.18.semanticHash=6e4634ec0d445246
scope.19.id=function:<anonymous>#6
scope.19.kind=function
scope.19.startLine=161
scope.19.endLine=178
scope.19.semanticHash=77a8733689e1db53
scope.20.id=function:_test_foundation_handles_unicode_paths_for_file_ops
scope.20.kind=function
scope.20.startLine=181
scope.20.endLine=235
scope.20.semanticHash=282bceff65093e80
scope.21.id=function:<anonymous>#7
scope.21.kind=function
scope.21.startLine=182
scope.21.endLine=234
scope.21.semanticHash=ed0cd57eb409532d
scope.22.id=function:_test_arch_common_reuses_unicode_safe_file_ops
scope.22.kind=function
scope.22.startLine=237
scope.22.endLine=262
scope.22.semanticHash=e38e38025a292280
scope.23.id=function:<anonymous>#8
scope.23.kind=function
scope.23.startLine=238
scope.23.endLine=261
scope.23.semanticHash=61444d6eb53c83ed
scope.24.id=function:_test_command_exists_reports_present_and_missing_commands
scope.24.kind=function
scope.24.startLine=264
scope.24.endLine=268
scope.24.semanticHash=78dea18ecb234598
scope.25.id=function:_test_trim_strips_whitespace_and_returns_one_value
scope.25.kind=function
scope.25.startLine=276
scope.25.endLine=285
scope.25.semanticHash=d0de1e1ff4711dd4
scope.26.id=function:_test_path_predicates_return_one_boolean
scope.26.kind=function
scope.26.startLine=292
scope.26.endLine=305
scope.26.semanticHash=a2813f4363b2e284
scope.27.id=function:_test_cli_help_text_is_bilingual
scope.27.kind=function
scope.27.startLine=308
scope.27.endLine=349
scope.27.semanticHash=13feedd3917f0073
scope.28.id=function:<anonymous>#9
scope.28.kind=function
scope.28.startLine=321
scope.28.endLine=326
scope.28.semanticHash=3074f792b48c2395
scope.29.id=function:_test_deploy_lua_matches_simplified_cli
scope.29.kind=function
scope.29.startLine=355
scope.29.endLine=441
scope.29.semanticHash=a3a02fd998e1b3ca
scope.30.id=function:_running_under_wsl
scope.30.kind=function
scope.30.startLine=443
scope.30.endLine=454
scope.30.semanticHash=0e8beea7353a95b9
scope.31.id=function:_test_deploy_comprehensive
scope.31.kind=function
scope.31.startLine=456
scope.31.endLine=469
scope.31.semanticHash=6b80f2bd79ee971c
scope.32.id=function:_test_run_command_preserves_bilingual_stderr_and_utf8_stdin
scope.32.kind=function
scope.32.startLine=471
scope.32.endLine=509
scope.32.semanticHash=5ba3d38d886df164
scope.33.id=function:<anonymous>#10
scope.33.kind=function
scope.33.startLine=472
scope.33.endLine=508
scope.33.semanticHash=493ba5c948796f21
scope.34.id=function:_test_arch_view_viewer_supports_unicode_output_path
scope.34.kind=function
scope.34.startLine=511
scope.34.endLine=549
scope.34.semanticHash=4fa56e6038de2cdf
scope.35.id=function:<anonymous>#11
scope.35.kind=function
scope.35.startLine=512
scope.35.endLine=548
scope.35.semanticHash=8c1f82a96ae31984
scope.36.id=function:print
scope.36.kind=function
scope.36.startLine=517
scope.36.endLine=523
scope.36.semanticHash=b1b58017d3100017
scope.37.id=function:<anonymous>#12
scope.37.kind=function
scope.37.startLine=525
scope.37.endLine=536
scope.37.semanticHash=07912723b9232bc5
scope.38.id=function:_test_mutate_wrapper_scan_output
scope.38.kind=function
scope.38.startLine=551
scope.38.endLine=563
scope.38.semanticHash=76ff622eb13a3380
scope.39.id=function:_test_reference_tools_do_not_expose_bin_entrypoints
scope.39.kind=function
scope.39.startLine=565
scope.39.endLine=575
scope.39.semanticHash=706467edae647c04
scope.40.id=function:_test_bootstrap_resolves_repo_root_from_non_repo_cwd
scope.40.kind=function
scope.40.startLine=577
scope.40.endLine=609
scope.40.semanticHash=d66afebf5833a6a6
scope.41.id=function:<anonymous>#13
scope.41.kind=function
scope.41.startLine=578
scope.41.endLine=608
scope.41.semanticHash=7340f906bd82aa1b
scope.42.id=function:_validate_cases
scope.42.kind=function
scope.42.startLine=649
scope.42.endLine=668
scope.42.semanticHash=a6b9df082bf53600
scope.43.id=function:_cases_for_group
scope.43.kind=function
scope.43.startLine=670
scope.43.endLine=678
scope.43.semanticHash=19c6dbdeb19f47d2
scope.44.id=function:_cases_for_owner
scope.44.kind=function
scope.44.startLine=680
scope.44.endLine=688
scope.44.semanticHash=19c6dbdeb19f47d2
]]
