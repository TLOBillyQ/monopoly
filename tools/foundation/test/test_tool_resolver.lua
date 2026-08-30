---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_tool_resolver.lua") end

require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local tool_resolver = require("foundation.tool_resolver")

TestToolResolver = {}

local _SHA_OLD = "1111111111111111111111111111111111111111"
local _SHA_NEW = "2222222222222222222222222222222222222222"

local function _temp_env(tag)
  local root = env_lib.make_temp_path(tag, "")
  fs_lib.remove_path(root)
  lu.assertTrue(fs_lib.ensure_dir(root))
  return { tool_cache_dir = path_lib.join_path(root, ".toolcache") }, root
end

local function _run_ok(sha)
  return function(command)
    lu.assertEquals(command, { "git", "ls-remote", "http://example.invalid/eggy/mutate4lua.git", "HEAD" })
    return { ok = true, output = sha .. "\tHEAD\n" }
  end
end

local function _run_fail()
  return function()
    return { ok = false, code = 128, output = "network unreachable" }
  end
end

function TestToolResolver:test_head_commit_appends_git_suffix_and_parses_sha()
  local sha, err = tool_resolver.head_commit("http://example.invalid/eggy/mutate4lua", _run_ok(_SHA_NEW))

  lu.assertNil(err)
  lu.assertIs(sha, _SHA_NEW)
end

function TestToolResolver:test_head_commit_reports_remote_failure()
  local sha, err = tool_resolver.head_commit("http://example.invalid/eggy/mutate4lua", _run_fail())

  lu.assertNil(sha)
  lu.assertEvalToTrue(tostring(err):find("git ls-remote failed", 1, true) ~= nil)
end

function TestToolResolver:test_cache_roundtrip()
  local env, root = _temp_env("tool_resolver_roundtrip")
  lu.assertTrue(tool_resolver.write_cache(env, {
    mutate4lua = { commit = _SHA_NEW, installed = _SHA_OLD, resolved_at = 123 },
  }))
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  lu.assertIs(cache.mutate4lua.commit, _SHA_NEW)
  lu.assertIs(cache.mutate4lua.installed, _SHA_OLD)
  lu.assertIs(cache.mutate4lua.resolved_at, 123)
end

function TestToolResolver:test_cache_dash_installed_reads_as_nil()
  local env, root = _temp_env("tool_resolver_dash")
  lu.assertTrue(tool_resolver.write_cache(env, {
    mutate4lua = { commit = _SHA_NEW, resolved_at = 123 },
  }))
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  lu.assertIs(cache.mutate4lua.commit, _SHA_NEW)
  lu.assertNil(cache.mutate4lua.installed)
end

function TestToolResolver:test_resolve_hits_fresh_cache_without_network()
  local env, root = _temp_env("tool_resolver_fresh")
  lu.assertTrue(tool_resolver.write_cache(env, {
    mutate4lua = { commit = _SHA_OLD, installed = _SHA_OLD, resolved_at = os.time() },
  }))

  local resolved, err = tool_resolver.resolve(
    "mutate4lua", "http://example.invalid/eggy/mutate4lua", env, { run = _run_fail() }
  )
  fs_lib.remove_path(root)

  lu.assertNil(err)
  lu.assertIs(resolved.commit, _SHA_OLD)
  lu.assertIs(resolved.installed, _SHA_OLD)
  lu.assertIs(resolved.source, "cache")
end

function TestToolResolver:test_resolve_refreshes_stale_cache_from_remote()
  local env, root = _temp_env("tool_resolver_refresh")
  lu.assertTrue(tool_resolver.write_cache(env, {
    mutate4lua = { commit = _SHA_OLD, installed = _SHA_OLD, resolved_at = os.time() - 25 * 3600 },
  }))

  local resolved, err = tool_resolver.resolve(
    "mutate4lua", "http://example.invalid/eggy/mutate4lua", env, { run = _run_ok(_SHA_NEW) }
  )
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  lu.assertNil(err)
  lu.assertIs(resolved.commit, _SHA_NEW)
  lu.assertIs(resolved.source, "remote")
  -- 远端解析成功只更新 head;installed 保留,由 mark_installed 在装完后更新。
  lu.assertIs(cache.mutate4lua.commit, _SHA_NEW)
  lu.assertIs(cache.mutate4lua.installed, _SHA_OLD)
end

function TestToolResolver:test_resolve_falls_back_to_stale_cache_offline()
  local env, root = _temp_env("tool_resolver_offline")
  lu.assertTrue(tool_resolver.write_cache(env, {
    mutate4lua = { commit = _SHA_OLD, installed = _SHA_OLD, resolved_at = os.time() - 25 * 3600 },
  }))

  local resolved, err = tool_resolver.resolve(
    "mutate4lua", "http://example.invalid/eggy/mutate4lua", env, { run = _run_fail() }
  )
  fs_lib.remove_path(root)

  lu.assertNil(err)
  lu.assertIs(resolved.commit, _SHA_OLD)
  lu.assertIs(resolved.source, "stale-cache")
  lu.assertNotNil(resolved.warning)
end

function TestToolResolver:test_resolve_fails_without_cache_offline()
  local env, root = _temp_env("tool_resolver_no_cache")
  local resolved, err = tool_resolver.resolve(
    "mutate4lua", "http://example.invalid/eggy/mutate4lua", env, { run = _run_fail() }
  )
  fs_lib.remove_path(root)

  lu.assertNil(resolved)
  lu.assertNotNil(err)
end

function TestToolResolver:test_mark_installed_records_actual_commit()
  local env, root = _temp_env("tool_resolver_mark")
  lu.assertTrue(tool_resolver.mark_installed(env, "mutate4lua", _SHA_NEW))
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  lu.assertIs(cache.mutate4lua.commit, _SHA_NEW)
  lu.assertIs(cache.mutate4lua.installed, _SHA_NEW)
end

return TestToolResolver
