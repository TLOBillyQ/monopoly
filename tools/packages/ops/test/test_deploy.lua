---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/ops/test/test_deploy.lua") end
require("test.bootstrap").install_package_paths()

-- deploy.lua(story1 deploy_core)的聚焦单测:纯字符串演算 + 沙箱文件系统行为 +
-- CLI 命令面。行为真源是 deploy.lua(历史来源 deploy.ps1,已随 #384 删除,ADR 0030)。
local check = require("luassert")
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
  local root = env_lib.make_temp_path("deploy_core_spec_中文 空格_", "")
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

describe("deploy public sandbox contracts", function()

it("get text formats bilingual", function()
  check.equal(deploy.get_text("部署", "Deploy"), "部署 / Deploy")
end)

it("normalize path replaces all backslashes", function()
  check.equal(deploy.normalize_path_text("C:\\Users\\foo"), "C:/Users/foo")
  check.equal(deploy.normalize_path_text("/mnt/c"), "/mnt/c")
  check.equal(deploy.normalize_path_text(""), "")
end)

it("Lua source directory name is retained", function()
  -- "大富翁" = U+5927 U+5BCC U+7FC1(UTF-8)。
  check.equal(deploy.join_lua_source_dir_name(), "LuaSource_大富翁")
end)

it("blank path returns empty", function()
  check.equal(deploy.resolve_normalized_path(""), "")
  check.equal(deploy.resolve_normalized_path(nil), "")
  check.equal(deploy.resolve_normalized_path("   "), "")
end)

it("keeps absolute path and trims trailing slashes", function()
  check.equal(deploy.resolve_normalized_path("/home/alice/"), "/home/alice")
  check.equal(deploy.resolve_normalized_path("/home/alice"), "/home/alice")
  -- Windows 盘符绝对路径语义仅在真实 Windows 上成立(POSIX 上 IsPathRooted 只认 "/")。
  if package.config:sub(1, 1) == "\\" then
    check.equal(deploy.resolve_normalized_path("C:/Users/foo/"), "C:/Users/foo")
  end
end)

it("relative path is joined to cwd", function()
  local cwd = env_lib.current_dir()
  check.equal(deploy.resolve_normalized_path("src"), cwd .. "/src")
end)

it("tilde expands against home", function()
  _with_stubbed("resolve_home_dir", function()
    return "/home/alice"
  end, function()
    check.equal(deploy.resolve_normalized_path("~/Desktop"), "/home/alice/Desktop")
  end)
end)

it("folds dot and dotdot segments", function()
  check.equal(deploy.resolve_normalized_path("/home/alice/sub/../bob"), "/home/alice/bob")
  check.equal(deploy.resolve_normalized_path("/home/alice/sub/./bob"), "/home/alice/sub/bob")
  check.equal(deploy.resolve_normalized_path("/home/alice/../../bob"), "/bob")
end)

it("Windows drive path folds on Windows", function()
  -- Windows 盘符绝对路径语义仅在真实 Windows 上成立(POSIX 上 IsPathRooted 只认 "/")。
  if package.config:sub(1, 1) == "\\" then
    check.equal(deploy.resolve_normalized_path("C:/Users/foo/../bar/"), "C:/Users/bar")
  end
end)

it("expands percent environment variables", function()
  local home = os.getenv("HOME")
  if home == nil or tostring(home):gsub("^%s+", ""):gsub("%s+$", "") == "" then
    return
  end
  check.equal(deploy.resolve_normalized_path("%HOME%/x"), deploy.normalize_path_text(home) .. "/x")
end)

it("Windows host matches OS or separator", function()
  local expected = os.getenv("OS") == "Windows_NT" or package.config:sub(1, 1) == "\\"
  check.equal(deploy.test_is_windows_host(), expected)
end)

it("platform name returns win on Windows host", function()
  _with_stubbed("test_is_windows_host", function()
    return true
  end, function()
    check.equal(deploy.resolve_platform_name(), "win")
  end)
end)

it("platform name errors on other platforms", function()
  local captured = nil
  _with_stubbed("test_is_windows_host", function()
    return false
  end, function()
    _with_stubbed("exit_with_error", function(message)
      captured = message
    end, function()
      deploy.resolve_platform_name()
    end)
  end)
  check.truthy(tostring(captured):find("Windows only", 1, true),
    "non-win/non-wsl platforms must report the Windows-only deploy target")
end)

it("project root is true for full project shape", function()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    check.is_true(deploy.test_project_root(proj))
  end)
end)

it("project root is false when marker missing", function()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    check.is_false(deploy.test_project_root(proj .. "/tools"))
    check.is_false(deploy.test_project_root(root))
  end)
end)

it("line count skips blank and full line comments", function()
  _with_sandbox(function(root)
    local sample = root .. "/sample.lua"
    _write_file(sample, "-- a\nlocal x = 1\n\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 1)
    _write_file(sample, "-- only comment\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 0)
    _write_file(sample, "")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 0)
  end)
end)

-- #527:块注释内部行(典型:每文件尾部的 mutate4lua manifest)不得计为有效代码。
it("line count skips block comment interior", function()
  _with_sandbox(function(root)
    local sample = root .. "/sample.lua"
    _write_file(sample, "local a = 1\n--[[ mutate4lua-manifest\nscope.1.id=function:x\nscope.1.startLine=1\n]]\nlocal b = 2\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 2)
    -- 长括号等级形式 --[==[ ... ]==]
    _write_file(sample, "--[==[\ninterior line\n]==]\nlocal c = 3\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 1)
  end)
end)

it("line count handles inline block close and trailing code", function()
  _with_sandbox(function(root)
    local sample = root .. "/sample.lua"
    -- 同行闭合的行首块注释,余下代码仍计
    _write_file(sample, "--[[@meta]] local x = 1\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 1)
    -- 块注释闭合行尾部带代码仍计
    _write_file(sample, "--[[\ninterior\n]] local y = 2\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 1)
    -- 行内注释(--[[@as T]] 在行尾,行首为代码)行为不变
    _write_file(sample, "local z = f() --[[@as T]]\n")
    check.equal(deploy.get_effective_lua_line_count_for_file(sample), 1)
  end)
end)

it("line count for missing file is zero", function()
  check.equal(deploy.get_effective_lua_line_count_for_file("/nonexistent/deploy_core_spec.lua"), 0)
end)

it("line count for directory includes hidden files", function()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    check.equal(deploy.get_effective_lua_line_count_for_dir(proj .. "/src"), 6)
    check.equal(deploy.get_effective_lua_line_count_for_dir(proj .. "/nonexistent"), 0)
  end)
end)

it("Lua file count includes recursive Lua files only", function()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    check.equal(deploy.get_lua_file_count(proj .. "/src"), 4)
    check.equal(deploy.get_lua_file_count(proj .. "/main.lua"), 1)
    check.equal(deploy.get_lua_file_count(proj .. "/nonexistent"), 0)
  end)
end)

it("copy file creates parent and overwrites", function()
  _with_sandbox(function(root)
    local source = root .. "/src.txt"
    _write_file(source, "hello")
    local target = root .. "/nested/dir/dst.txt"
    check.is_true(deploy.copy_file_with_parent_dir(source, target))
    check.equal(fs_lib.read_raw(target), "hello")
    _write_file(source, "updated")
    check.is_true(deploy.copy_file_with_parent_dir(source, target))
    check.equal(fs_lib.read_raw(target), "updated")
  end)
end)

it("copy file errors on missing source", function()
  _with_sandbox(function(root)
    check.has_error(function()
      deploy.copy_file_with_parent_dir(root .. "/missing.lua", root .. "/out/dst.lua")
    end)
  end)
end)

it("copy file errors when target is directory", function()
  _with_sandbox(function(root)
    local source = root .. "/src.txt"
    _write_file(source, "hello")
    local target_dir = root .. "/outdir"
    fs_lib.ensure_dir(target_dir)
    check.has_error(function()
      deploy.copy_file_with_parent_dir(source, target_dir)
    end)
  end)
end)

it("reset directory clears and recreates", function()
  _with_sandbox(function(root)
    local dir = root .. "/reset"
    fs_lib.ensure_dir(dir .. "/sub")
    _write_file(dir .. "/sub/stale.lua", "stale")
    deploy.reset_directory(dir)
    check.is_true(fs_lib.path_exists(dir))
    check.is_false(fs_lib.path_exists(dir .. "/sub/stale.lua"))
  end)
end)

it("copy tree mirrors hidden and non Lua files", function()
  _with_sandbox(function(root)
    local proj = _make_project(root)
    local target = root .. "/target/src"
    deploy.copy_directory_tree(proj .. "/src", target)
    for _, relative in ipairs({
      "a.lua", "sub/b.lua", ".hidden.lua", ".hiddendir/x.lua", "notes.txt", ".keep",
    }) do
      check.equal(fs_lib.read_raw(target .. "/" .. relative), fs_lib.read_raw(proj .. "/src/" .. relative),
        "mirror must include " .. relative)
    end
  end)
end)

it("copy tree errors on missing source", function()
  _with_sandbox(function(root)
    check.has_error(function()
      deploy.copy_directory_tree(root .. "/missing", root .. "/target")
    end)
  end)
end)

it("remove nested paths removes existing targets", function()
  _with_sandbox(function(root)
    local dir = root .. "/nested"
    fs_lib.ensure_dir(dir .. "/a/b")
    _write_file(dir .. "/a/b/c.txt", "x")
    deploy.remove_nested_paths(dir, { "a/b", "missing" })
    check.is_false(fs_lib.path_exists(dir .. "/a/b"))
  end)
end)

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

it("script rejects extra positional arguments", function()
  local result = _run_deploy_lua({ "extra1", "extra2" })
  check.is_false(result.ok)
  check.truthy(result.output:find("ERROR:", 1, true),
    "extra args must fail with ERROR on stderr: " .. result.output)
end)

it("script rejects help without usage text", function()
  local result = _run_deploy_lua({ "--help" })
  check.is_false(result.ok)
  check.truthy(result.output:find("ERROR:", 1, true),
    "--help must fail with ERROR on stderr: " .. result.output)
  check.is_nil(result.output:find("Usage", 1, true),
    "--help must not print usage text: " .. result.output)
  check.is_nil(result.output:find("用法", 1, true),
    "--help must not print Chinese usage text: " .. result.output)
end)

it("CLI subcommand help shows usage", function()
  local result = _run_cli_deploy({ "--help" })
  check.is_true(result.ok, "deploy --help via cli.lua must exit 0: " .. result.output)
  check.truthy(result.output:find("用法", 1, true) ~= nil,
    "deploy --help via cli.lua must show Chinese usage: " .. result.output)
end)

it("CLI forwards extra arguments to script", function()
  local result = _run_cli_deploy({ "额外 参数" })
  check.is_false(result.ok)
  check.truthy(result.output:find("ERROR:", 1, true),
    "extra args via cli.lua must reach deploy.lua and fail with ERROR: " .. result.output)
end)
end)
