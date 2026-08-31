---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_bootstrap.lua") end

require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
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
  if not ok then
    error(err, 0)
  end
end

TestBootstrap = {}

function TestBootstrap:test_parses_the_repo_url_lockfile_format()
  local lock, err = tool_lockfile.parse_contents(table.concat({
    "# comment",
    "mutate4lua http://example.invalid/eggy/mutate4lua",
    "dry4lua http://example.invalid/eggy/dry4lua.git",
    "",
  }, "\n"))

  lu.assertNil(err)
  lu.assertNotNil(lock)
  lu.assertIs(lock.tools.mutate4lua.url, "http://example.invalid/eggy/mutate4lua")
  lu.assertIs(lock.tools.dry4lua.url, "http://example.invalid/eggy/dry4lua.git")
  lu.assertEquals(lock.ordered, { "mutate4lua", "dry4lua" })
end

function TestBootstrap:test_rejects_unknown_tools()
  local lock, err = tool_lockfile.parse_contents(
    "unknown http://example.invalid/eggy/unknown\n"
  )

  lu.assertNil(lock)
  lu.assertEvalToTrue(tostring(err):find("unknown tool", 1, true) ~= nil)
end

function TestBootstrap:test_install_appends_luarocks_tree_paths()
  local root = env_lib.make_temp_path("bootstrap_spec", "")
  fs_lib.remove_path(root)
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "src")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "test")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "tools/foundation")))
  lu.assertTrue(fs_lib.copy_file(
    "tools/foundation/package_path_helper.lua",
    path_lib.join_path(root, "tools/foundation/package_path_helper.lua")
  ))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "tools")))
  lu.assertTrue(fs_lib.write_file(path_lib.join_path(root, "tools/tools.lock"), ""))

  local original = package.path
  package.path = "/sentinel/?.lua"
  local fresh_bootstrap = dofile(bootstrap_path)
  fresh_bootstrap.install(nil, { cwd = root })
  local path = package.path
  package.path = original
  fs_lib.remove_path(root)

  lu.assertEvalToTrue(path:find("/.toolcache/luarocks/share/lua/5.4/?.lua", 1, true) ~= nil)
  lu.assertEvalToTrue(path:find("/.toolcache/luarocks/share/lua/5.4/?/init.lua", 1, true) ~= nil)
end

function TestBootstrap:test_install_appends_luarocks_tree_cpath()
  local root = env_lib.make_temp_path("bootstrap_cpath_spec", "")
  fs_lib.remove_path(root)
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "src")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "test")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "tools/foundation")))
  lu.assertTrue(fs_lib.copy_file(
    "tools/foundation/package_path_helper.lua",
    path_lib.join_path(root, "tools/foundation/package_path_helper.lua")
  ))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "tools")))
  lu.assertTrue(fs_lib.write_file(path_lib.join_path(root, "tools/tools.lock"), ""))

  local original = package.cpath
  package.cpath = "/sentinel/?.so"
  local fresh_bootstrap = dofile(bootstrap_path)
  fresh_bootstrap.install(nil, { cwd = root })
  local cpath = package.cpath
  package.cpath = original
  fs_lib.remove_path(root)

  lu.assertEvalToTrue(cpath:find("/.toolcache/luarocks/lib/lua/5.4/?.so", 1, true) ~= nil)
end

function TestBootstrap:test_resolves_a_repo_root_from_the_lockfile_based_tool_layout()
  local root = path_lib.join_path(
    "tmp",
    "runtime_paths_spec_$__monopoly_runtime_paths_unset__ path"
  )
  fs_lib.remove_path(root)

  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "src")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "test")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "tools/foundation")))
  lu.assertTrue(fs_lib.ensure_dir(path_lib.join_path(root, "tools")))
  lu.assertTrue(fs_lib.write_file(path_lib.join_path(root, "tools/tools.lock"), ""))

  local env = runtime_paths.resolve({
    cwd = root,
    source_path = "tools/foundation/bootstrap.lua",
  })

  fs_lib.remove_path(root)

  lu.assertIs(env.repo_root, path_lib.normalize_path(root))
  lu.assertIs(env.tool_cache_dir, path_lib.join_path(path_lib.normalize_path(root), ".toolcache"))
end

function TestBootstrap:test_ensure_luaunit_tree_skips_install_when_marker_exists()
  local ensure_calls = 0
  local command_calls = 0
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path)
      lu.assertIs(path, "/repo/.toolcache/luarocks/share/lua/5.4/luaunit.lua")
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
    lu.assertTrue(bootstrap.ensure_luaunit_tree("/repo"))
  end)
  lu.assertIs(ensure_calls, 0)
  lu.assertIs(command_calls, 0)
end

function TestBootstrap:test_ensure_luaunit_tree_installs_pinned_rock_and_checks_marker()
  local marker_checks = 0
  local captured_command
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path)
      marker_checks = marker_checks + 1
      lu.assertIs(path, "/repo/.toolcache/luarocks/share/lua/5.4/luaunit.lua")
      return marker_checks > 1
    end },
    { target = fs_lib, key = "ensure_dir", value = function(path)
      lu.assertIs(path, "/repo/.toolcache/luarocks")
      return true
    end },
    { target = proc_lib, key = "run_command", value = function(command)
      captured_command = command
      return { ok = true, output = "" }
    end },
  }, function()
    lu.assertTrue(bootstrap.ensure_luaunit_tree("/repo"))
  end)
  lu.assertEquals(captured_command, {
    "luarocks", "--tree", "/repo/.toolcache/luarocks", "--lua-version", "5.4",
    "install", "luaunit", "3.5-1",
  })
  lu.assertIs(marker_checks, 2)
end

function TestBootstrap:test_ensure_luaunit_tree_propagates_tree_creation_failure()
  local command_calls = 0
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function() return false end },
    { target = fs_lib, key = "ensure_dir", value = function()
      return nil, "mkdir failed"
    end },
    { target = proc_lib, key = "run_command", value = function()
      command_calls = command_calls + 1
      return { ok = true }
    end },
  }, function()
    local ok, err = bootstrap.ensure_luaunit_tree("/repo")
    lu.assertNil(ok)
    lu.assertIs(err, "mkdir failed")
  end)
  lu.assertIs(command_calls, 0)
end

function TestBootstrap:test_ensure_luacov_tree_reports_install_failure()
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function() return false end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function(command)
      lu.assertIs(command[#command - 1], "luacov")
      lu.assertIs(command[#command], "0.17.0-1")
      return { ok = false, output = "offline" }
    end },
  }, function()
    local ok, err = bootstrap.ensure_luacov_tree("/repo")
    lu.assertNil(ok)
    lu.assertIs(err, "luarocks install failed for luacov: offline")
  end)
end

function TestBootstrap:test_ensure_luacov_tree_reports_missing_post_install_marker()
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function() return false end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function()
      return { ok = true, output = "" }
    end },
  }, function()
    local ok, err = bootstrap.ensure_luacov_tree("/repo")
    lu.assertNil(ok)
    lu.assertIs(err, "luacov not found in luarocks tree after install")
  end)
end

function TestBootstrap:test_ensure_cluacov_tree_stops_when_luacov_dependency_fails()
  local command_calls = 0
  _with_stubs({
    { target = fs_lib, key = "path_exists", value = function(path)
      lu.assertIs(path, "/repo/.toolcache/luarocks/lib/lua/5.4/cluacov/hook.so")
      return false
    end },
    { target = fs_lib, key = "ensure_dir", value = function() return true end },
    { target = proc_lib, key = "run_command", value = function()
      command_calls = command_calls + 1
      return { ok = true }
    end },
    { target = bootstrap, key = "ensure_luacov_tree", value = function(repo_root)
      lu.assertIs(repo_root, "/repo")
      return nil, "luacov failed"
    end },
  }, function()
    local ok, err = bootstrap.ensure_cluacov_tree("/repo")
    lu.assertNil(ok)
    lu.assertIs(err, "luacov failed")
  end)
  lu.assertIs(command_calls, 0)
end


return TestBootstrap
