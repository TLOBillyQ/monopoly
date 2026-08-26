local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/foundation/bootstrap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/foundation"
end

local runtime_paths = dofile(_module_dir() .. "/runtime_paths.lua")

local bootstrap = {}

function bootstrap.resolve(script_path, opts)
  opts = opts or {}
  return runtime_paths.resolve({
    source_path = script_path or opts.source_path or (debug.getinfo(2, "S") and debug.getinfo(2, "S").source) or "",
    cwd = opts.cwd or runtime_paths.current_dir(),
  })
end

function bootstrap.install(script_path, opts)
  local env = bootstrap.resolve(script_path, opts)
  local helper_path = runtime_paths.join_path(env.tools_dir, "foundation/package_path_helper.lua")
  local helper = dofile(helper_path)
  helper.install_eggy_package_paths({
    repo_root = env.repo_root,
  })
  helper.install_luarocks_tree_paths({
    repo_root = env.repo_root,
  })
  return env
end

local function _luarocks_tree_dir(repo_root)
  return runtime_paths.join_path(repo_root, ".toolcache/luarocks")
end

local function _parse_rockspec_version(url)
  local filename = tostring(url):match("([^/]+)%.rockspec$") or ""
  local _, version = filename:match("^([%w_]+)-(%d+%.%d+%.%d+-%d+)$")
  return version
end

local function _luarocks_list(tree, name, version)
  -- 调用方已确保 foundation 可用(package.path 已装好)。
  local proc_lib = require("foundation.proc")
  return proc_lib.run_command({
    "luarocks",
    "--tree", tree,
    "--lua-version", "5.4",
    "list", name, version,
    "--porcelain",
  })
end

local function _is_tool_installed(tree, name, url)
  local version = _parse_rockspec_version(url)
  if version == nil then
    return false, "cannot parse version from rockspec url: " .. tostring(url)
  end
  local result = _luarocks_list(tree, name, version)
  if result.ok ~= true then
    return false, tostring(result.output)
  end
  local escaped_name = name:gsub("%-", "%%-")
  local escaped_version = version:gsub("%-", "%%-")
  local pattern = "^" .. escaped_name .. "%s+" .. escaped_version .. "%s+installed"
  for line in tostring(result.output or ""):gmatch("[^\r\n]+") do
    if line:match(pattern) then
      return true
    end
  end
  return false
end

local function _luarocks_install(tree, url)
  local proc_lib = require("foundation.proc")
  return proc_lib.run_command({
    "luarocks",
    "--tree", tree,
    "--lua-version", "5.4",
    "install", url,
  })
end

function bootstrap.ensure_luaunit_tree(repo_root)
  local path_lib = require("foundation.path")
  local fs_lib = require("foundation.fs")
  local proc_lib = require("foundation.proc")
  local tree = _luarocks_tree_dir(repo_root)
  local marker = path_lib.join_path(tree, "share/lua/5.4/luaunit.lua")
  if fs_lib.path_exists(marker) == true then
    return true
  end

  local ok, err = fs_lib.ensure_dir(tree)
  if not ok then
    return nil, err
  end

  local result = proc_lib.run_command({
    "luarocks",
    "--tree", tree,
    "--lua-version", "5.4",
    "install", "luaunit", "3.5-1",
  })
  if result.ok ~= true then
    return nil, "luarocks install failed for luaunit: " .. tostring(result.output)
  end

  if fs_lib.path_exists(marker) ~= true then
    return nil, "luaunit not found in luarocks tree after install"
  end

  return true
end

-- 覆盖率引擎 luacov 由上游 rockspec（crap4lua/mutate4lua
-- v0.1.0)以依赖形式带入 tree,这里只做显式确保——runner `-c` 与 coverage.lua
-- 车道在无 crap4lua 前置调用时也能直接落地它。钉 0.17.0-1 与上游一致。
function bootstrap.ensure_luacov_tree(repo_root)
  local path_lib = require("foundation.path")
  local fs_lib = require("foundation.fs")
  local proc_lib = require("foundation.proc")
  local tree = _luarocks_tree_dir(repo_root)
  local marker = path_lib.join_path(tree, "share/lua/5.4/luacov/runner.lua")
  if fs_lib.path_exists(marker) == true then
    return true
  end

  local ok, err = fs_lib.ensure_dir(tree)
  if not ok then
    return nil, err
  end

  local result = proc_lib.run_command({
    "luarocks",
    "--tree", tree,
    "--lua-version", "5.4",
    "install", "luacov", "0.17.0-1",
  })
  if result.ok ~= true then
    return nil, "luarocks install failed for luacov: " .. tostring(result.output)
  end

  if fs_lib.path_exists(marker) ~= true then
    return nil, "luacov not found in luarocks tree after install"
  end

  return true
end

-- cluacov = luacov 的可选 C hook 加速器(lunarmodules/cluacov 1.0.0-1)。
-- luacov.runner 顶层 pcall(require, "cluacov.version") 成功即改用 C hook;
-- mutate4lua 归因矩阵构建是全套 spec 下的 line-hook 热点,启用后显著降 wall。
-- 钉 1.0.0-1;C 扩展 marker 是 hook.so(仅 version.lua 不够——证明 .so 已编进 tree)。
function bootstrap.ensure_cluacov_tree(repo_root)
  local path_lib = require("foundation.path")
  local fs_lib = require("foundation.fs")
  local proc_lib = require("foundation.proc")
  local tree = _luarocks_tree_dir(repo_root)
  local marker = path_lib.join_path(tree, "lib/lua/5.4/cluacov/hook.so")
  if fs_lib.path_exists(marker) == true then
    return true
  end

  local ok, err = fs_lib.ensure_dir(tree)
  if not ok then
    return nil, err
  end

  -- cluacov rockspec 依赖 luacov >= 0.13;先确保 base engine 在 tree。
  local luacov_ok, luacov_err = bootstrap.ensure_luacov_tree(repo_root)
  if luacov_ok ~= true then
    return nil, luacov_err
  end

  local result = proc_lib.run_command({
    "luarocks",
    "--tree", tree,
    "--lua-version", "5.4",
    "install", "cluacov", "1.0.0-1",
  })
  if result.ok ~= true then
    return nil, "luarocks install failed for cluacov: " .. tostring(result.output)
  end

  if fs_lib.path_exists(marker) ~= true then
    return nil, "cluacov not found in luarocks tree after install"
  end

  return true
end

function bootstrap.ensure_tool(name, env_or_opts)
  local env = env_or_opts
  if env == nil or env.repo_root == nil then
    env = bootstrap.resolve(nil, env_or_opts or {})
  end

  local lockfile = require("foundation.tool_lockfile")
  local lock, lock_err = lockfile.read_lock(env)
  if lock == nil then
    return nil, lock_err
  end

  local entry = lock.tools[name]
  if entry == nil then
    return nil, "tool missing from lockfile: " .. tostring(name)
  end

  local fs_lib = require("foundation.fs")
  local tree = _luarocks_tree_dir(env.repo_root)
  local ok, ensure_err = fs_lib.ensure_dir(tree)
  if not ok then
    return nil, ensure_err
  end

  if not _is_tool_installed(tree, name, entry.url) then
    local result = _luarocks_install(tree, entry.url)
    if result.ok ~= true then
      return nil, "luarocks install failed for " .. tostring(name) .. ": " .. tostring(result.output)
    end
    if not _is_tool_installed(tree, name, entry.url) then
      return nil, tostring(name) .. " not found in luarocks tree after install"
    end
  end

  return {
    name = name,
    root = tree,
    url = entry.url,
  }
end

return bootstrap
