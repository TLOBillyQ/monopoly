---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_bootstrap.lua") end

require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local tool_lockfile = require("foundation.tool_lockfile")
local runtime_paths = dofile("tools/foundation/runtime_paths.lua")

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
  local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]+$") .. "/../bootstrap.lua"))
  bootstrap.install(nil, { cwd = root })
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
  local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]+$") .. "/../bootstrap.lua"))
  bootstrap.install(nil, { cwd = root })
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


return TestBootstrap
