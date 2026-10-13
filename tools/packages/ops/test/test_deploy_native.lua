if arg then rawset(arg, 0, "tools/packages/ops/test/test_deploy_native.lua") end
require("test.bootstrap").install_package_paths()
local check = require("luassert")
local env = require("foundation.env")
local fs = require("foundation.fs")
local deploy = require("tools.packages.ops.deploy")

describe("native deploy copy sandbox", function()

local function sandbox(fn)
  local root = env.make_temp_path("deploy_native_中文 空格_", "")
  fs.ensure_dir(root)
  local ok, err = xpcall(function() fn(root) end, debug.traceback)
  fs.remove_path(root)
  if not ok then error(err) end
end

it("missing source preserves existing target", function()
  sandbox(function(root)
    assert(fs.write_file(root .. "/target/保留.txt", "keep"))
    check.has_error(function()
      deploy.copy_directory_tree(root .. "/missing", root .. "/target")
    end)
    check.same(fs.read_raw(root .. "/target/保留.txt"), "keep")
  end)
end)

it("real mirror preserves bytes and removes stale files", function()
  sandbox(function(root)
    assert(fs.write_file(root .. "/source/子 目录/中文.lua", "return '中文'\n"))
    assert(fs.write_file(root .. "/source/.hidden", "\0binary\255"))
    fs.ensure_dir(root .. "/source/空目录")
    assert(fs.write_file(root .. "/target/stale.txt", "stale"))
    deploy.copy_directory_tree(root .. "/source", root .. "/target")
    check.same(fs.read_raw(root .. "/target/子 目录/中文.lua"), "return '中文'\n")
    check.same(fs.read_raw(root .. "/target/.hidden"), "\0binary\255")
    check.is_true(fs.is_dir(root .. "/target/空目录"))
    check.is_false(fs.path_exists(root .. "/target/stale.txt"))
    deploy.copy_directory_tree(root .. "/source", root .. "/target")
    check.same(fs.read_raw(root .. "/target/.hidden"), "\0binary\255")
  end)
end)

-- 仅在子进程 PATH 的隔离目录放置受控 robocopy.cmd;真实 cmd 退出,
-- 真正的逐文件复制仍由公共 copy_directory_tree 完成。
local function controlled_copy(root, code)
  local proc = require("foundation.proc")
  local executable = assert(proc.run_command({ "where.exe", "lua.exe" }).output:match("([^\r\n]+)"))
  assert(fs.write_file(root .. "/bin/robocopy.cmd", "@echo off\r\necho invoked>\"" .. root .. "/invoked.txt\"\r\nexit /b " .. code .. "\r\n"))
  assert(fs.write_file(root .. "/driver.lua", "local d=require('tools.packages.ops.deploy'); d.copy_directory_tree(arg[1],arg[2])"))
  local command = 'set "PATH=' .. root:gsub("/", "\\") .. '\\bin;' .. os.getenv("SystemRoot")
    .. '\\System32" & "' .. executable .. '" "' .. root .. '/driver.lua" "' .. root .. '/source" "' .. root .. '/target"'
  local result = proc.run_command(command)
  check.is_true(result.ok, result.output)
  check.is_true(fs.path_exists(root .. "/invoked.txt"))
end

for code = 0, 7 do
  it("robocopy exit " .. code .. " is success", function()
    sandbox(function(root)
      assert(fs.write_file(root .. "/source/中文.lua", "source"))
      assert(fs.write_file(root .. "/target/保留.txt", "keep"))
      controlled_copy(root, code)
      check.same(fs.read_raw(root .. "/target/保留.txt"), "keep")
      check.is_false(fs.path_exists(root .. "/target/中文.lua"))
    end)
  end)
end

for _, code in ipairs({ 8, 16 }) do
  it("robocopy exit " .. code .. " copies real files", function()
    sandbox(function(root)
      assert(fs.write_file(root .. "/source/子 目录/中文.lua", "fallback\0bytes"))
      assert(fs.write_file(root .. "/source/.hidden", "hidden"))
      fs.ensure_dir(root .. "/source/空目录")
      assert(fs.write_file(root .. "/target/stale.txt", "stale"))
      controlled_copy(root, code)
      check.same(fs.read_raw(root .. "/target/子 目录/中文.lua"), "fallback\0bytes")
      check.same(fs.read_raw(root .. "/target/.hidden"), "hidden")
      check.is_true(fs.is_dir(root .. "/target/空目录"))
      check.is_false(fs.path_exists(root .. "/target/stale.txt"))
    end)
  end)
end

it("project root resolves current repository", function()
  check.same(deploy.resolve_project_root(), env.current_dir())
end)

it("default target retains native location", function()
  local home = deploy.resolve_home_dir():gsub("/$", "")
  check.same(deploy.resolve_default_target_path("win"), home .. "/Desktop/dev/eggy/LuaSource_大富翁")
end)

it("unavailable robocopy copies real files", function()
  sandbox(function(root)
    local proc = require("foundation.proc")
    local executable = assert(proc.run_command({ "where.exe", "lua.exe" }).output:match("([^\r\n]+)"))
    assert(fs.write_file(root .. "/source/中文.lua", "real fallback"))
    assert(fs.write_file(root .. "/target/stale.txt", "stale"))
    assert(fs.write_file(root .. "/driver.lua", "local d=require('tools.packages.ops.deploy'); d.copy_directory_tree(arg[1],arg[2])"))
    -- where 是真实系统程序;PATH 中有它而没有 robocopy。
    local input = assert(io.open(os.getenv("SystemRoot") .. "/System32/where.exe", "rb"))
    local bytes = input:read("*a")
    input:close()
    assert(fs.write_file(root .. "/bin/where.exe", bytes))
    local result = proc.run_command('set "PATH=' .. root:gsub("/", "\\") .. '\\bin" & "' .. executable
      .. '" "' .. root .. '/driver.lua" "' .. root .. '/source" "' .. root .. '/target"')
    check.is_true(result.ok, result.output)
    check.same(fs.read_raw(root .. "/target/中文.lua"), "real fallback")
    check.is_false(fs.path_exists(root .. "/target/stale.txt"))
  end)
end)

it("project root resolves from other working directory", function()
  sandbox(function(root)
    local proc = require("foundation.proc")
    local repo = env.current_dir()
    local script = "package.path=" .. string.format("%q", repo .. "/?.lua;")
      .. "..package.path; io.write(require('tools.packages.ops.deploy').resolve_project_root())"
    assert(fs.write_file(root .. "/root_driver.lua", script))
    local result = proc.run_command({ "lua", root .. "/root_driver.lua" }, { cwd = root })
    check.is_true(result.ok, result.output)
    check.same(result.output, repo)
  end)
end)

end)
