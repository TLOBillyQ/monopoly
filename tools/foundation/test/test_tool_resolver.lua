---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_tool_resolver.lua") end

require("test.bootstrap").install_package_paths()

local check = require("luassert")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local tool_resolver = require("foundation.tool_resolver")


local _SHA_OLD = "1111111111111111111111111111111111111111"
local _SHA_NEW = "2222222222222222222222222222222222222222"

local function _temp_env(tag)
  local root = env_lib.make_temp_path(tag, "")
  fs_lib.remove_path(root)
  check.is_true(fs_lib.ensure_dir(root))
  return { tool_cache_dir = path_lib.join_path(root, ".toolcache") }, root
end

local function _run_ok(sha)
  return function(command)
    check.same({ "git", "ls-remote", "http://example.invalid/eggy/dry4lua.git", "HEAD" }, command)
    return { ok = true, output = sha .. "\tHEAD\n" }
  end
end

local function _run_fail()
  return function()
    return { ok = false, code = 128, output = "network unreachable" }
  end
end

describe("tool resolver", function()
it("head commit appends git suffix and parses sha", function()
  local sha, err = tool_resolver.head_commit("http://example.invalid/eggy/dry4lua", _run_ok(_SHA_NEW))

  check.is_nil(err)
  check.equal(_SHA_NEW, sha)
end)

it("head commit reports remote failure", function()
  local sha, err = tool_resolver.head_commit("http://example.invalid/eggy/dry4lua", _run_fail())

  check.is_nil(sha)
  check.truthy(tostring(err):find("git ls-remote failed", 1, true) ~= nil)
end)

it("cache roundtrip", function()
  local env, root = _temp_env("tool_resolver_roundtrip")
  check.is_true(tool_resolver.write_cache(env, {
    dry4lua = { commit = _SHA_NEW, installed = _SHA_OLD, resolved_at = 123 },
  }))
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  check.equal(_SHA_NEW, cache.dry4lua.commit)
  check.equal(_SHA_OLD, cache.dry4lua.installed)
  check.equal(123, cache.dry4lua.resolved_at)
end)

it("cache dash installed reads as nil", function()
  local env, root = _temp_env("tool_resolver_dash")
  check.is_true(tool_resolver.write_cache(env, {
    dry4lua = { commit = _SHA_NEW, resolved_at = 123 },
  }))
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  check.equal(_SHA_NEW, cache.dry4lua.commit)
  check.is_nil(cache.dry4lua.installed)
end)

it("resolve hits fresh cache without network", function()
  local env, root = _temp_env("tool_resolver_fresh")
  check.is_true(tool_resolver.write_cache(env, {
    dry4lua = { commit = _SHA_OLD, installed = _SHA_OLD, resolved_at = os.time() },
  }))

  local resolved, err = tool_resolver.resolve(
    "dry4lua", "http://example.invalid/eggy/dry4lua", env, { run = _run_fail() }
  )
  fs_lib.remove_path(root)

  check.is_nil(err)
  check.equal(_SHA_OLD, resolved.commit)
  check.equal(_SHA_OLD, resolved.installed)
  check.equal("cache", resolved.source)
end)

it("resolve refreshes stale cache from remote", function()
  local env, root = _temp_env("tool_resolver_refresh")
  check.is_true(tool_resolver.write_cache(env, {
    dry4lua = { commit = _SHA_OLD, installed = _SHA_OLD, resolved_at = os.time() - 25 * 3600 },
  }))

  local resolved, err = tool_resolver.resolve(
    "dry4lua", "http://example.invalid/eggy/dry4lua", env, { run = _run_ok(_SHA_NEW) }
  )
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  check.is_nil(err)
  check.equal(_SHA_NEW, resolved.commit)
  check.equal("remote", resolved.source)
  -- 远端解析成功只更新 head;installed 保留,由 mark_installed 在装完后更新。
  check.equal(_SHA_NEW, cache.dry4lua.commit)
  check.equal(_SHA_OLD, cache.dry4lua.installed)
end)

it("resolve falls back to stale cache offline", function()
  local env, root = _temp_env("tool_resolver_offline")
  check.is_true(tool_resolver.write_cache(env, {
    dry4lua = { commit = _SHA_OLD, installed = _SHA_OLD, resolved_at = os.time() - 25 * 3600 },
  }))

  local resolved, err = tool_resolver.resolve(
    "dry4lua", "http://example.invalid/eggy/dry4lua", env, { run = _run_fail() }
  )
  fs_lib.remove_path(root)

  check.is_nil(err)
  check.equal(_SHA_OLD, resolved.commit)
  check.equal("stale-cache", resolved.source)
  check.is_not_nil(resolved.warning)
end)

it("resolve fails without cache offline", function()
  local env, root = _temp_env("tool_resolver_no_cache")
  local resolved, err = tool_resolver.resolve(
    "dry4lua", "http://example.invalid/eggy/dry4lua", env, { run = _run_fail() }
  )
  fs_lib.remove_path(root)

  check.is_nil(resolved)
  check.is_not_nil(err)
end)

it("mark installed records actual commit", function()
  local env, root = _temp_env("tool_resolver_mark")
  check.is_true(tool_resolver.mark_installed(env, "dry4lua", _SHA_NEW))
  local cache = tool_resolver.read_cache(env)
  fs_lib.remove_path(root)

  check.equal(_SHA_NEW, cache.dry4lua.commit)
  check.equal(_SHA_NEW, cache.dry4lua.installed)
end)

end)
