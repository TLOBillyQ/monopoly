local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir()
  local raw_path = arg and arg[0] or "scripts/arch.lua"
  local normalized = _normalize_path(raw_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = _script_dir()
local ARCH_VIEW_DIR = _normalize_path(SCRIPT_DIR .. "/../vendor/arch_view")
local ARCH_CONFIG_PATH = _normalize_path(SCRIPT_DIR .. "/arch/config.lua")
local package_path_helper = require("scripts.package_path_helper")

package_path_helper.install_monopoly_package_paths({
  arch_view_root = ARCH_VIEW_DIR,
})

local cli = require("arch_view.cli")

local M = {}

function M.run(args, env)
  env = env or {}
  env.script_dir = ARCH_VIEW_DIR
  env.default_project_root = _normalize_path(SCRIPT_DIR .. "/..")
  env.default_config_path = ARCH_CONFIG_PATH
  return cli.run(args or arg or {}, env)
end

function M.main()
  return M.run(arg or {})
end

if ... == "arch" then
  return M
end

M.main()
