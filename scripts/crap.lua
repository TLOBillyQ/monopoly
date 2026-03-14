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
local package_path_helper = require("scripts.package_path_helper")

package_path_helper.install_monopoly_package_paths({
  arch_view_root = ARCH_VIEW_ROOT,
})

package.path = CRAP4LUA_ROOT .. "/?.lua;"
  .. CRAP4LUA_ROOT .. "/?/?.lua;"
  .. REPO_ROOT .. "/?.lua;"
  .. REPO_ROOT .. "/?/?.lua;"
  .. REPO_ROOT .. "/?/init.lua;"
  .. REPO_ROOT .. "/tests/?.lua;"
  .. REPO_ROOT .. "/tests/?/?.lua;"
  .. SCRIPT_DIR .. "/?.lua;"
  .. SCRIPT_DIR .. "/?/?.lua;"
  .. package.path

local adapter = require("quality.crap_monopoly_adapter")
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

function M.default_tmp_root()
  return _default_tmp_root()
end

function M.resolve_cli_path(base, path)
  return _resolve_cli_path(base, path)
end

function M.run(args, env)
  env = env or {}
  env.command_name = env.command_name or "scripts/crap.lua"
  env.module_root = env.module_root or CRAP4LUA_ROOT
  env.asset_root = env.asset_root or _normalize_path(CRAP4LUA_ROOT .. "/viewer")
  env.default_project_root = env.default_project_root or REPO_ROOT
  env.resolve_cli_path = env.resolve_cli_path or _resolve_cli_path
  env.resolve_lane_suites = env.resolve_lane_suites or adapter.resolve_lane_suites
  env.run_all = env.run_all or adapter.run_all
  env.debug_api = env.debug_api or debug
  return core.run(args or arg or {}, env)
end

function M.main()
  return M.run(arg or {})
end

if ... == "crap" then
  return M
end

M.main()
