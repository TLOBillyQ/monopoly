---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_bootstrap.lua") end

require("test.bootstrap").install_package_paths()

local check = require("luassert")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local tool_lockfile = require("foundation.tool_lockfile")
local test_source = debug.getinfo(1, "S").source:gsub("^@", "")
local test_dir = test_source:match("^(.*)/[^/]+$") or "tools/foundation/test"
local runtime_paths = dofile(test_dir .. "/../runtime_paths.lua")
local bootstrap_path = test_dir .. "/../bootstrap.lua"
local bootstrap = require("foundation.bootstrap")

local function _with_stubs(stubs, fn)
  local saved_lua54 = package.loaded["foundation.lua54"]
  package.loaded["foundation.lua54"] = nil
  local originals = {}
  for index, stub in ipairs(stubs) do
    originals[index] = stub.target[stub.key]
    stub.target[stub.key] = stub.value
  end
  local ok, err = pcall(fn)
  for index = #stubs, 1, -1 do
    local stub = stubs[index]
    stub.target[stub.key] = originals[index]
  end
  package.loaded["foundation.lua54"] = saved_lua54
  if not ok then
    error(err, 0)
  end
end

-- 原生子进程替身:`where.exe <解释器>` 形如真实机器——首行是用户 shell 的
-- lua.cmd 垫片,真解释器在第二行;安装前缀必须由后者导出。
local function _native_probe(command)
  if command[1] == "where.exe" then
    if command[2] == "luarocks.exe" then
      return { ok = false, output = "" }
    end
    return { ok = true, output = "C:\\tools\\shim\\lua.cmd\r\n"
      .. os.getenv("LOCALAPPDATA") .. "\\Programs\\Lua\\bin\\lua.exe\r\n" }
  end
  if command[2] == "-v" then return { ok = true, output = "Lua 5.4.6" } end
end

local _LUAROCKS_PREFIX = os.getenv("LOCALAPPDATA"):gsub("\\", "/") .. "/Programs/Lua"

describe("bootstrap", function()

it("parses the repo url lockfile format", function()
  local lock, err = tool_lockfile.parse_contents(table.concat({
    "# comment",
    "acceptance4lua http://example.invalid/eggy/acceptance4lua",
    "dry4lua http://example.invalid/eggy/dry4lua.git",
    "",
  }, "\n"))

  check.is_nil(err)
  check.is_not_nil(lock)
  check.equal("http://example.invalid/eggy/acceptance4lua", lock.tools.acceptance4lua.url)
  check.equal("http://example.invalid/eggy/dry4lua.git", lock.tools.dry4lua.url)
  check.same({ "acceptance4lua", "dry4lua" }, lock.ordered)
end)

it("rejects unknown tools", function()
  local lock, err = tool_lockfile.parse_contents(
    "unknown http://example.invalid/eggy/unknown\n"
  )

  check.is_nil(lock)
  check.truthy(tostring(err):find("unknown tool", 1, true) ~= nil)
end)

-- #94:旧 CRAP/变异/架构工具退场后,锁文件白名单不再接受它们。
it("rejects retired quality tools", function()
  for _, name in ipairs({ "arch_view", "crap4lua", "mutate4lua" }) do
    local lock, err = tool_lockfile.parse_contents(name .. " http://example.invalid/eggy/" .. name .. "\n")
    check.is_nil(lock)
    check.truthy(tostring(err):find("unknown tool", 1, true) ~= nil, name)
  end
end)

it("install appends luarocks tree paths", function()
  local root = env_lib.make_temp_path("bootstrap_spec", "")
  fs_lib.remove_path(root)
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "src")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "test")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "tools/foundation")))
  check.is_true(fs_lib.copy_file(
    "tools/foundation/package_path_helper.lua",
    path_lib.join_path(root, "tools/foundation/package_path_helper.lua")
  ))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "tools")))
  check.is_true(fs_lib.write_file(path_lib.join_path(root, "tools/tools.lock"), ""))

  local original = package.path
  package.path = "/sentinel/?.lua"
  local fresh_bootstrap = dofile(bootstrap_path)
  fresh_bootstrap.install(nil, { cwd = root })
  local path = package.path
  package.path = original
  fs_lib.remove_path(root)

  check.truthy(path:find("/.toolcache/luarocks/share/lua/5.4/?.lua", 1, true) ~= nil)
  check.truthy(path:find("/.toolcache/luarocks/share/lua/5.4/?/init.lua", 1, true) ~= nil)
end)

it("install appends luarocks tree cpath", function()
  local root = env_lib.make_temp_path("bootstrap_cpath_spec", "")
  fs_lib.remove_path(root)
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "src")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "test")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "tools/foundation")))
  check.is_true(fs_lib.copy_file(
    "tools/foundation/package_path_helper.lua",
    path_lib.join_path(root, "tools/foundation/package_path_helper.lua")
  ))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "tools")))
  check.is_true(fs_lib.write_file(path_lib.join_path(root, "tools/tools.lock"), ""))

  local original = package.cpath
  package.cpath = "/sentinel/?.so"
  local fresh_bootstrap = dofile(bootstrap_path)
  fresh_bootstrap.install(nil, { cwd = root })
  local cpath = package.cpath
  package.cpath = original
  fs_lib.remove_path(root)

  check.truthy(cpath:find("/.toolcache/luarocks/lib/lua/5.4/?.so", 1, true) ~= nil)
end)

it("resolves a repo root from the lockfile based tool layout", function()
  local root = path_lib.join_path(
    "tmp",
    "runtime_paths_spec_$__monopoly_runtime_paths_unset__ path"
  )
  fs_lib.remove_path(root)

  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "src")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "test")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "tools/foundation")))
  check.is_true(fs_lib.ensure_dir(path_lib.join_path(root, "tools")))
  check.is_true(fs_lib.write_file(path_lib.join_path(root, "tools/tools.lock"), ""))

  local env = runtime_paths.resolve({
    cwd = root,
    source_path = "tools/foundation/bootstrap.lua",
  })

  fs_lib.remove_path(root)

  check.equal(path_lib.normalize_path(root), env.repo_root)
  check.equal(path_lib.join_path(path_lib.normalize_path(root), ".toolcache"), env.tool_cache_dir)
end)

it("ensure busted tree skips install when marker exists", function()
  local ensure_calls = 0
  local command_calls = 0
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path)
      check.equal("/repo/.toolcache/luarocks/share/lua/5.4/busted/runner.lua", path)
      return true
    end },
    { target = fs_lib, key = "ensure_dir", value = function()
      ensure_calls = ensure_calls + 1
      return true
    end },
    { target = proc_lib, key = "run_command", value = function()
      command_calls = command_calls + 1
      return { ok = true }
    end },
  }, function()
    check.is_true(bootstrap.ensure_busted_tree("/repo"))
  end)
  check.equal(0, ensure_calls)
  check.equal(0, command_calls)
end)

it("ensure busted tree installs pinned rock and checks marker", function()
  local marker_checks = 0
  local captured_command
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path)
      if path:match("luarocks%.exe$") then return true end
      -- 解释器候选路径(/opt/homebrew/bin/lua5.4 之类)不参与 marker 计数。
      if path:match("%.lua$") == nil then return false end
      marker_checks = marker_checks + 1
      check.equal("/repo/.toolcache/luarocks/share/lua/5.4/busted/runner.lua", path)
      return marker_checks > 1
    end },
    { target = fs_lib, key = "ensure_dir", value = function(path)
      check.equal("/repo/.toolcache/luarocks", path)
      return true
    end },
    { target = proc_lib, key = "command_exists", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function(command)
      local probe = _native_probe(command)
      if probe then return probe end
      captured_command = command
      return { ok = true, output = "" }
    end },
  }, function()
    check.is_true(bootstrap.ensure_busted_tree("/repo"))
  end)
  check.same({ "--tree", "/repo/.toolcache/luarocks", "--lua-version", "5.4" },
    { table.unpack(captured_command, 2, 5) })
  check.same({ "install", "busted", "2.3.0-1", "--deps-mode", "one" },
    { table.unpack(captured_command, 8) })
  check.equal("--lua-dir", captured_command[6])
  -- --lua-dir 取真实解释器(lua.exe)所在前缀,而不是 where.exe 首行的
  -- lua.cmd / lua.bat 垫片目录。
  check.equal(_LUAROCKS_PREFIX, captured_command[7])
  check.equal(2, marker_checks)
end)

it("ensure busted tree propagates tree creation failure", function()
  local command_calls = 0
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path) return path:match("luarocks.exe$") ~= nil end },
    { target = fs_lib, key = "ensure_dir", value = function()
      return nil, "mkdir failed"
    end },
    { target = proc_lib, key = "run_command", value = function()
      command_calls = command_calls + 1
      return { ok = true }
    end },
  }, function()
    local ok, err = bootstrap.ensure_busted_tree("/repo")
    check.is_nil(ok)
    check.equal("mkdir failed", err)
  end)
  check.equal(0, command_calls)
end)

it("ensure luacov tree reports install failure", function()
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path) return path:match("luarocks.exe$") ~= nil end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "command_exists", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function(command)
      local probe = _native_probe(command)
      if probe then return probe end
      check.equal("luacov", command[#command - 3])
      check.equal("0.17.0-1", command[#command - 2])
      return { ok = false, output = "offline" }
    end },
  }, function()
    local ok, err = bootstrap.ensure_luacov_tree("/repo")
    check.is_nil(ok)
    check.equal("luarocks install failed for luacov: offline", err)
  end)
end)

it("ensure luacov tree reports missing post install marker", function()
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path) return path:match("luarocks.exe$") ~= nil end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "command_exists", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function(command)
      return _native_probe(command) or { ok = true, output = "" }
    end },
  }, function()
    local ok, err = bootstrap.ensure_luacov_tree("/repo")
    check.is_nil(ok)
    check.equal("luacov not found in luarocks tree after install", err)
  end)
end)

-- #93:crapper 的 Lua 覆盖率走 luacov.reporter.lcov;只能装进项目 tree,不能借全局 tree。
it("ensure luacov lcov reporter tree stops when luacov dependency fails", function()
  local command_calls = 0
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path)
      check.equal("/repo/.toolcache/luarocks/share/lua/5.4/luacov/reporter/lcov.lua", path)
      return false
    end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function()
      command_calls = command_calls + 1
      return { ok = true }
    end },
    { target = bootstrap, key = "ensure_luacov_tree", value = function(repo_root)
      check.equal("/repo", repo_root)
      return nil, "luacov failed"
    end },
  }, function()
    local ok, err = bootstrap.ensure_luacov_reporter_lcov_tree("/repo")
    check.is_nil(ok)
    check.equal("luacov failed", err)
  end)
  check.equal(0, command_calls)
end)

it("ensure luacov lcov reporter tree installs the pinned rock", function()
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path) return path:match("luarocks.exe$") ~= nil end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "command_exists", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function(command)
      local probe = _native_probe(command)
      if probe then return probe end
      check.equal("luacov-reporter-lcov", command[#command - 3])
      check.equal("0.2-0", command[#command - 2])
      return { ok = false, output = "offline" }
    end },
    { target = bootstrap, key = "ensure_luacov_tree", value = function() return true end },
  }, function()
    local ok, err = bootstrap.ensure_luacov_reporter_lcov_tree("/repo")
    check.is_nil(ok)
    check.equal("luarocks install failed for luacov-reporter-lcov: offline", err)
  end)
end)

end)
