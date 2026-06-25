local common = require("shared.lib.common")
local lockfile = require("shared.tool_lockfile")
local fetch = require("shared.tool_cache_fetch")

local tool_cache = {}

local function _prepend_package_path(pattern)
  if tostring(package.path):find(pattern, 1, true) == nil then
    package.path = pattern .. ";" .. package.path
  end
end

function tool_cache.parse_lock_contents(content)
  return lockfile.parse_contents(content)
end

function tool_cache.lock_path(env)
  return common.join_path((env or {}).repo_root or ".", "swarmforge/tools.lock")
end

function tool_cache.cache_root(env)
  return common.join_path((env or {}).repo_root or ".", ".swarmforge/tools")
end

function tool_cache.read_lock(env)
  local path = tool_cache.lock_path(env)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  return tool_cache.parse_lock_contents(content)
end

function tool_cache.tool_dir(env, name, commit)
  return common.join_path(tool_cache.cache_root(env), tostring(name) .. "@" .. tostring(commit))
end

function tool_cache.add_lua_paths(tool_root)
  local lib_root = common.join_path(tool_root, "lib")
  _prepend_package_path(common.join_path(lib_root, "?.lua"))
  _prepend_package_path(common.join_path(lib_root, "?/init.lua"))
end

function tool_cache.install_locked_tool_paths(env)
  local lock, err = tool_cache.read_lock(env)
  if lock == nil then
    return nil, err
  end
  for _, name in ipairs(lock.ordered or {}) do
    local entry = lock.tools[name]
    tool_cache.add_lua_paths(tool_cache.tool_dir(env, name, entry.commit))
  end
  return true
end

function tool_cache.ensure_tool(name, env, opts)
  opts = opts or {}
  local def = lockfile.definition(name)
  if def == nil then
    return nil, "unknown tool: " .. tostring(name)
  end

  local lock, err = tool_cache.read_lock(env)
  if lock == nil then
    return nil, err
  end
  local entry = lock.tools[name]
  if entry == nil then
    return nil, "tool missing from lockfile: " .. tostring(name)
  end

  local cache_root = tool_cache.cache_root(env)
  local ok, ensure_err = common.ensure_dir(cache_root)
  if not ok then
    return nil, ensure_err
  end

  local root = tool_cache.tool_dir(env, name, entry.commit)
  local lock_path = common.join_path(cache_root, tostring(name) .. ".lock")
  local _, fetch_err = fetch.with_lock(lock_path, function()
    local cache_ok = fetch.cache_valid(root, entry.commit, def, opts)
    if not cache_ok then
      local tmp = common.join_path(cache_root, "." .. tostring(name) .. "@" .. tostring(entry.commit) .. ".tmp")
      local ok_populate, populate_err = fetch.populate(root, tmp, name, entry, opts)
      if ok_populate == nil then
        return nil, populate_err
      end
    end

    local refreshed_ok, refreshed_err = fetch.cache_valid(root, entry.commit, def, opts)
    if not refreshed_ok then
      return nil, "cached tool invalid after clone: " .. tostring(refreshed_err)
    end
    return true
  end)
  if fetch_err ~= nil then
    return nil, fetch_err
  end

  tool_cache.add_lua_paths(root)
  return {
    name = name,
    root = root,
    repo = entry.repo,
    commit = entry.commit,
  }
end

return tool_cache
