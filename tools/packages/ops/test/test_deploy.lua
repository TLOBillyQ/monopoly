---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/ops/test/test_deploy.lua") end
require("test.bootstrap").install_package_paths()

-- deploy.lua(story1 deploy_core)的聚焦单测:纯字符串演算 + 沙箱文件系统行为 +
-- CLI 命令面。行为真源是 deploy.lua(历史来源 deploy.ps1,已随 #384 删除,ADR 0030)。
local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")
local deploy = require("tools.packages.ops.deploy")

local function _with_stubbed(field, value, fn)
  local original = deploy[field]
  deploy[field] = value
  local ok, err = xpcall(function()
    fn()
  end, debug.traceback)
  deploy[field] = original
  if not ok then
    error(err)
  end
end

local function _with_sandbox(fn)
  local root = env_lib.make_temp_path("deploy_core_spec_", "")
  fs_lib.remove_path(root)
  local ok, err = xpcall(function()
    fn(root)
  end, debug.traceback)
  fs_lib.remove_path(root)
  if not ok then
    error(err)
  end
end

local function _write_file(path, content)
  local ok, err = fs_lib.write_file(path, content)
  if not ok then
    error(err)
  end
end

-- 沙箱项目:含隐藏 Lua、隐藏目录、非 Lua、
-- 缩进注释、行内注释、空行。源侧统计期望:Lua Files 7 / Effective LOC 9。
local function _make_project(root)
  local proj = root .. "/project"
  fs_lib.ensure_dir(proj .. "/src/sub")
  fs_lib.ensure_dir(proj .. "/src/.hiddendir")
  fs_lib.ensure_dir(proj .. "/Data")
  fs_lib.ensure_dir(proj .. "/tools")
  _write_file(proj .. "/main.lua", "-- main\nprint(\"hello\")\n")
  _write_file(proj .. "/src/a.lua", "-- header\nlocal a = 1\n\n  -- indented\nlocal b = 2 -- trailing\n")
  _write_file(proj .. "/src/sub/b.lua", "-- b\nlocal x = 1\nlocal y = 2\n")
  _write_file(proj .. "/src/.hidden.lua", "-- hidden\nlocal h = 1\n")
  _write_file(proj .. "/src/.hiddendir/x.lua", "-- x\nlocal xv = 1\n")
  _write_file(proj .. "/src/notes.txt", "not lua\n")
  _write_file(proj .. "/src/.keep", "keep\n")
  _write_file(proj .. "/Data/UIManagerNodes.lua", "-- nodes\nreturn {}\n")
  _write_file(proj .. "/Data/Prefab.lua", "-- prefab\nreturn {}\n")
  _write_file(proj .. "/tools/placeholder.txt", "placeholder\n")
  return proj
end

local function _is_wsl()
  local distro = os.getenv("WSL_DISTRO_NAME")
  if distro ~= nil and tostring(distro):gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
    return true
  end
  local handle = io.open("/proc/version", "r")
  if handle == nil then
    return false
  end
  local text = handle:read("*a") or ""
  handle:close()
  return text:lower():find("microsoft", 1, true) ~= nil
end

TestDeployTextAndNames = {}

function TestDeployTextAndNames:test_get_text_formats_bilingual()
  lu.assertIs(deploy.get_text("部署", "Deploy"), "部署 / Deploy")
end

function TestDeployTextAndNames:test_normalize_path_text_replaces_all_backslashes()
  lu.assertIs(deploy.normalize_path_text("C:\\Users\\foo"), "C:/Users/foo")
  lu.assertIs(deploy.normalize_path_text("/mnt/c"), "/mnt/c")
  lu.assertIs(deploy.normalize_path_text(""), "")
end

function TestDeployTextAndNames:test_join_lua_source_dir_name_is_lua_source_monopoly()
  -- "大富翁" = U+5927 U+5BCC U+7FC1(UTF-8)。
  lu.assertIs(deploy.join_lua_source_dir_name(), "LuaSource_大富翁")
end

TestDeployResolveNormalizedPath = {}

function TestDeployResolveNormalizedPath:test_blank_returns_empty()
  lu.assertIs(deploy.resolve_normalized_path(""), "")
  lu.assertIs(deploy.resolve_normalized_path(nil), "")
  lu.assertIs(deploy.resolve_normalized_path("   "), "")
end

function TestDeployResolveNormalizedPath:test_keeps_absolute_path_and_trims_trailing_slashes()
  lu.assertIs(deploy.resolve_normalized_path("/home/alice/"), "/home/alice")
  lu.assertIs(deploy.resolve_normalized_path("/home/alice"), "/home/alice")
  -- Windows 盘符绝对路径语义仅在真实 Windows 上成立(POSIX 上 IsPathRooted 只认 "/")。
  if package.config:sub(1, 1) == "\\" then
    lu.assertIs(deploy.resolve_normalized_path("C:/Users/foo/"), "C:/Users/foo")
  end
end

function TestDeployResolveNormalizedPath:test_relative_path_is_joined_to_cwd()
  local cwd = env_lib.current_dir()
  lu.assertIs(deploy.resolve_normalized_path("src"), cwd .. "/src")
end

function TestDeployResolveNormalizedPath:test_tilde_expands_against_home()
  _with_stubbed("resolve_home_dir", function()
    return "/home/alice"
  end, function()
    lu.assertIs(deploy.resolve_normalized_path("~/Desktop"), "/home/alice/Desktop")
  end)
end

function TestDeployResolveNormalizedPath:test_folds_dot_and_dotdot_segments()
  lu.assertIs(deploy.resolve_normalized_path("/home/alice/sub/../bob"), "/home/alice/bob")
  lu.assertIs(deploy.resolve_normalized_path("/home/alice/sub/./bob"), "/home/alice/sub/bob")
  lu.assertIs(deploy.resolve_normalized_path("/home/alice/../../bob"), "/bob")
end

function TestDeployResolveNormalizedPath:test_windows_drive_path_folds_only_on_windows()
  -- Windows 盘符绝对路径语义仅在真实 Windows 上成立(POSIX 上 IsPathRooted 只认 "/")。
  if package.config:sub(1, 1) == "\\" then
    lu.assertIs(deploy.resolve_normalized_path("C:/Users/foo/../bar/"), "C:/Users/bar")
  end
end

function TestDeployResolveNormalizedPath:test_expands_percent_environment_variables()
  local home = os.getenv("HOME")
  if home == nil or tostring(home):gsub("^%s+", ""):gsub("%s+$", "") == "" then
    return
  end
  lu.assertIs(deploy.resolve_normalized_path("%HOME%/x"), deploy.normalize_path_text(home) .. "/x")
end

TestDeployPlatformDetection = {}

function TestDeployPlatformDetection:test_windows_host_matches_os_or_separator()
  local expected = os.getenv("OS") == "Windows_NT" or package.config:sub(1, 1) == "\\"
  lu.assertIs(deploy.test_is_windows_host(), expected)
end

function TestDeployPlatformDetection:test_platform_name_returns_win_when_windows_host()
  _with_stubbed("test_is_windows_host", function()
    return true
  end, function()
    lu.assertIs(deploy.resolve_platform_name(), "win")
  end)
end

function TestDeployPlatformDetection:test_platform_name_returns_wsl_when_wsl_host()
  _with_stubbed("test_is_windows_host", function()
    return false
  end, function()
    _with_stubbed("test_is_wsl_host", function()
      return true
    end, function()
      lu.assertIs(deploy.resolve_platform_name(), "wsl")
    end)
  end)
end

function TestDeployPlatformDetection:test_platform_name_errors_on_other_platforms()
  local captured = nil
  _with_stubbed("test_is_windows_host", function()
    return false
  end, function()
    _with_stubbed("test_is_wsl_host", function()
      return false
    end, function()
      _with_stubbed("exit_with_error", function(message)
        captured = message
      end, function()
        deploy.resolve_platform_name()
      end)
    end)
  end)
  lu.assertEvalToTrue(tostring(captured):find("Windows only", 1, true),
    "non-win/non-wsl platforms must report the Windows-only deploy target")
end

TestDeployProjectRoot = {}

function TestDeployProjectRoot:test_project_root_true_for_full_project_shape()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    lu.assertTrue(deploy.test_project_root(proj))
  end)
end

function TestDeployProjectRoot:test_project_root_false_when_marker_missing()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    lu.assertFalse(deploy.test_project_root(proj .. "/tools"))
    lu.assertFalse(deploy.test_project_root(root))
  end)
end

TestDeployStats = {}

function TestDeployStats:test_effective_line_count_for_file_skips_blank_and_full_line_comments()
  _with_sandbox(function(root)
    local sample = root .. "/sample.lua"
    _write_file(sample, "-- a\nlocal x = 1\n\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 1)
    _write_file(sample, "-- only comment\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 0)
    _write_file(sample, "")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 0)
  end)
end

-- #527:块注释内部行(典型:每文件尾部的 mutate4lua manifest)不得计为有效代码。
function TestDeployStats:test_effective_line_count_skips_block_comment_interior()
  _with_sandbox(function(root)
    local sample = root .. "/sample.lua"
    _write_file(sample, "local a = 1\n--[[ mutate4lua-manifest\nscope.1.id=function:x\nscope.1.startLine=1\n]]\nlocal b = 2\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 2)
    -- 长括号等级形式 --[==[ ... ]==]
    _write_file(sample, "--[==[\ninterior line\n]==]\nlocal c = 3\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 1)
  end)
end

function TestDeployStats:test_effective_line_count_inline_block_close_and_trailing_code()
  _with_sandbox(function(root)
    local sample = root .. "/sample.lua"
    -- 同行闭合的行首块注释,余下代码仍计
    _write_file(sample, "--[[@meta]] local x = 1\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 1)
    -- 块注释闭合行尾部带代码仍计
    _write_file(sample, "--[[\ninterior\n]] local y = 2\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 1)
    -- 行内注释(--[[@as T]] 在行尾,行首为代码)行为不变
    _write_file(sample, "local z = f() --[[@as T]]\n")
    lu.assertIs(deploy.get_effective_lua_line_count_for_file(sample), 1)
  end)
end

function TestDeployStats:test_effective_line_count_for_file_missing_is_zero()
  lu.assertIs(deploy.get_effective_lua_line_count_for_file("/nonexistent/deploy_core_spec.lua"), 0)
end

function TestDeployStats:test_effective_line_count_for_dir_sums_files_including_hidden()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    lu.assertIs(deploy.get_effective_lua_line_count_for_dir(proj .. "/src"), 6)
    lu.assertIs(deploy.get_effective_lua_line_count_for_dir(proj .. "/nonexistent"), 0)
  end)
end

function TestDeployStats:test_lua_file_count_counts_recursive_lua_only()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    lu.assertIs(deploy.get_lua_file_count(proj .. "/src"), 4)
    lu.assertIs(deploy.get_lua_file_count(proj .. "/main.lua"), 1)
    lu.assertIs(deploy.get_lua_file_count(proj .. "/nonexistent"), 0)
  end)
end

TestDeployCopy = {}

function TestDeployCopy:test_copy_file_with_parent_dir_creates_parent_and_overwrites()
  _with_sandbox(function(root)
    local source = root .. "/src.txt"
    _write_file(source, "hello")
    local target = root .. "/nested/dir/dst.txt"
    lu.assertTrue(deploy.copy_file_with_parent_dir(source, target))
    lu.assertIs(fs_lib.read_raw(target), "hello")
    _write_file(source, "updated")
    lu.assertTrue(deploy.copy_file_with_parent_dir(source, target))
    lu.assertIs(fs_lib.read_raw(target), "updated")
  end)
end

function TestDeployCopy:test_copy_file_with_parent_dir_errors_on_missing_source()
  _with_sandbox(function(root)
    lu.assertError(function()
      deploy.copy_file_with_parent_dir(root .. "/missing.lua", root .. "/out/dst.lua")
    end)
  end)
end

function TestDeployCopy:test_copy_file_with_parent_dir_errors_when_target_is_directory()
  _with_sandbox(function(root)
    local source = root .. "/src.txt"
    _write_file(source, "hello")
    local target_dir = root .. "/outdir"
    fs_lib.ensure_dir(target_dir)
    lu.assertError(function()
      deploy.copy_file_with_parent_dir(source, target_dir)
    end)
  end)
end

function TestDeployCopy:test_reset_directory_clears_and_recreates()
  _with_sandbox(function(root)
    local dir = root .. "/reset"
    fs_lib.ensure_dir(dir .. "/sub")
    _write_file(dir .. "/sub/stale.lua", "stale")
    deploy.reset_directory(dir)
    lu.assertTrue(fs_lib.path_exists(dir))
    lu.assertFalse(fs_lib.path_exists(dir .. "/sub/stale.lua"))
  end)
end

function TestDeployCopy:test_copy_directory_tree_fallback_mirrors_including_hidden_and_non_lua()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    local target = root .. "/target/src"
    _with_stubbed("test_is_windows_host", function()
      return false
    end, function()
      _with_stubbed("test_is_wsl_host", function()
        return false
      end, function()
        deploy.copy_directory_tree(proj .. "/src", target)
      end)
    end)
    for _, relative in ipairs({
      "a.lua", "sub/b.lua", ".hidden.lua", ".hiddendir/x.lua", "notes.txt", ".keep",
    }) do
      lu.assertIs(fs_lib.read_raw(target .. "/" .. relative), fs_lib.read_raw(proj .. "/src/" .. relative),
        "mirror must include " .. relative)
    end
  end)
end

function TestDeployCopy:test_copy_directory_tree_fallback_errors_on_missing_source()
  _with_sandbox(function(root)
    _with_stubbed("test_is_windows_host", function()
      return false
    end, function()
      _with_stubbed("test_is_wsl_host", function()
        return false
      end, function()
        lu.assertError(function()
          deploy.copy_directory_tree(root .. "/missing", root .. "/target")
        end)
      end)
    end)
  end)
end

function TestDeployCopy:test_remove_nested_paths_removes_existing_targets()
  _with_sandbox(function(root)
    local dir = root .. "/nested"
    fs_lib.ensure_dir(dir .. "/a/b")
    _write_file(dir .. "/a/b/c.txt", "x")
    deploy.remove_nested_paths(dir, { "a/b", "missing" })
    lu.assertFalse(fs_lib.path_exists(dir .. "/a/b"))
  end)
end

TestDeployCliSurface = {}

local function _run_deploy_lua(extra_args)
  local args = { "lua", "tools/packages/ops/deploy.lua" }
  for _, value in ipairs(extra_args or {}) do
    args[#args + 1] = value
  end
  return proc_lib.run_command(args, {
    cwd = env_lib.current_dir(),
  })
end

-- 经 tools/cli.lua 的子命令入口(壳 tools/packages/ops/cli.lua 转发)。
-- 只测 --help 与多余参数:两者都在部署动作前结束,不会真拷部署目录。
local function _run_cli_deploy(extra_args)
  local args = { "lua", "tools/cli.lua", "deploy" }
  for _, value in ipairs(extra_args or {}) do
    args[#args + 1] = value
  end
  return proc_lib.run_command(args, {
    cwd = env_lib.current_dir(),
  })
end

function TestDeployCliSurface:test_rejects_extra_positional_arguments()
  local result = _run_deploy_lua({ "extra1", "extra2" })
  lu.assertFalse(result.ok)
  lu.assertEvalToTrue(result.output:find("ERROR:", 1, true),
    "extra args must fail with ERROR on stderr: " .. result.output)
end

function TestDeployCliSurface:test_rejects_help_switch_without_usage_text()
  local result = _run_deploy_lua({ "--help" })
  lu.assertFalse(result.ok)
  lu.assertEvalToTrue(result.output:find("ERROR:", 1, true),
    "--help must fail with ERROR on stderr: " .. result.output)
  lu.assertNil(result.output:find("Usage", 1, true),
    "--help must not print usage text: " .. result.output)
  lu.assertNil(result.output:find("用法", 1, true),
    "--help must not print Chinese usage text: " .. result.output)
end

function TestDeployCliSurface:test_windows_only_error_on_other_platforms()
  if _is_wsl() then
    return
  end
  local result = _run_deploy_lua({})
  lu.assertFalse(result.ok)
  lu.assertEvalToTrue(result.output:find("Windows only", 1, true),
    "non-win/non-wsl run must state the Windows-only target: " .. result.output)
end

function TestDeployCliSurface:test_cli_subcommand_help_shows_usage()
  local result = _run_cli_deploy({ "--help" })
  lu.assertTrue(result.ok, "deploy --help via cli.lua must exit 0: " .. result.output)
  lu.assertEvalToTrue(result.output:find("用法", 1, true) ~= nil,
    "deploy --help via cli.lua must show Chinese usage: " .. result.output)
end

function TestDeployCliSurface:test_cli_subcommand_forwards_extra_args_to_script()
  local result = _run_cli_deploy({ "extra1" })
  lu.assertFalse(result.ok)
  lu.assertEvalToTrue(result.output:find("ERROR:", 1, true),
    "extra args via cli.lua must reach deploy.lua and fail with ERROR: " .. result.output)
end

return TestDeployTextAndNames
