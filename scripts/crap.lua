local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/crap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = _module_dir()
local REPO_ROOT = _normalize_path(SCRIPT_DIR .. "/..")
local CRAP4LUA_ROOT = _normalize_path(REPO_ROOT .. "/vendor/crap4lua")
local ARCH_VIEW_ROOT = _normalize_path(REPO_ROOT .. "/vendor/arch_view")
local DEFAULT_CONFIG_PATH = _normalize_path(REPO_ROOT .. "/scripts/quality/crap_monopoly.config.lua")
local package_path_helper = require("scripts.package_path_helper")

package_path_helper.install_monopoly_package_paths({
  arch_view_root = ARCH_VIEW_ROOT,
})

package.path = CRAP4LUA_ROOT .. "/lib/?.lua;"
  .. CRAP4LUA_ROOT .. "/lib/?/?.lua;"
  .. REPO_ROOT .. "/?.lua;"
  .. REPO_ROOT .. "/?/?.lua;"
  .. REPO_ROOT .. "/?/init.lua;"
  .. REPO_ROOT .. "/tests/?.lua;"
  .. REPO_ROOT .. "/tests/?/?.lua;"
  .. SCRIPT_DIR .. "/?.lua;"
  .. SCRIPT_DIR .. "/?/?.lua;"
  .. package.path

local common = require("crap4lua.common")
local core = require("crap4lua")

local M = {}

local function _default_tmp_root()
  local env_root = os.getenv("MONOPOLY_CRAP_TMP")
  if env_root ~= nil and env_root ~= "" then
    return common.normalize_path(env_root)
  end
  return common.join_path(common.system_tmp_dir(), "monopoly_crap")
end

local function _resolve_cli_path(base, path)
  local normalized = common.normalize_path(path)
  if normalized == "" then
    return common.resolve_path(base, normalized)
  end
  if normalized == "tmp" or normalized:match("^tmp/") then
    local suffix = normalized == "tmp" and "" or normalized:sub(5)
    return common.resolve_path(_default_tmp_root(), suffix)
  end
  return common.resolve_path(base, normalized)
end

local function _copy_args(args)
  local copied = {}
  for index, value in ipairs(args or {}) do
    copied[index] = value
  end
  return copied
end

local function _has_flag(args, flag)
  for _, value in ipairs(args or {}) do
    if value == flag then
      return true
    end
  end
  return false
end

local function _with_default_config(args)
  local command = args[1]
  local rewritten = { command, "--config", DEFAULT_CONFIG_PATH }
  for index = 2, #args do
    rewritten[#rewritten + 1] = args[index]
  end
  return rewritten
end

local function _rewrite_cli_paths(args)
  local rewritten = {}
  local cwd = common.current_dir()
  local path_flags = {
    ["--out"] = true,
    ["--out-dir"] = true,
    ["--in-json"] = true,
    ["--project-root"] = true,
  }

  local index = 1
  while index <= #args do
    local token = args[index]
    rewritten[#rewritten + 1] = token
    if path_flags[token] == true and args[index + 1] ~= nil then
      rewritten[#rewritten + 1] = _resolve_cli_path(cwd, args[index + 1])
      index = index + 2
    else
      index = index + 1
    end
  end

  return rewritten
end

local function _prepare_args(args)
  local normalized = _copy_args(args)
  if #normalized == 0 then
    normalized = {
      "viewer",
      "--config", DEFAULT_CONFIG_PATH,
      "--out-dir", "tmp/crap_view",
      "--open",
    }
    return _rewrite_cli_paths(normalized)
  end

  local command = normalized[1]
  if command == "report" and not _has_flag(normalized, "--config") then
    normalized = _with_default_config(normalized)
    return _rewrite_cli_paths(normalized)
  end
  if command == "viewer"
      and not _has_flag(normalized, "--config")
      and not _has_flag(normalized, "--in-json") then
    normalized = _with_default_config(normalized)
    return _rewrite_cli_paths(normalized)
  end
  return _rewrite_cli_paths(normalized)
end

function M.default_tmp_root()
  return _default_tmp_root()
end

function M.default_config_path()
  return DEFAULT_CONFIG_PATH
end

function M.resolve_cli_path(base, path)
  return _resolve_cli_path(base, path)
end

function M.run(args, env)
  env = env or {}
  env.command_name = env.command_name or "scripts/crap.lua"
  env.resolve_cli_path = env.resolve_cli_path or _resolve_cli_path
  env.default_config_path = env.default_config_path or DEFAULT_CONFIG_PATH
  return core.run(_prepare_args(args or arg or {}), env)
end

function M.main()
  return M.run(arg or {})
end

if ... == "crap" then
  return M
end

M.main()
