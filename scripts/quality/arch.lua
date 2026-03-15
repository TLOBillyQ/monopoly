local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _script_dir()
  local raw_path = arg and arg[0] or "scripts/quality/arch.lua"
  local normalized = _normalize_path(raw_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local SCRIPT_DIR = _script_dir()
local REPO_ROOT = _normalize_path(SCRIPT_DIR .. "/../..")
local ARCH_VIEW_DIR = _normalize_path(SCRIPT_DIR .. "/../../vendor/arch_view")
local ARCH_CONFIG_PATH = _normalize_path(SCRIPT_DIR .. "/arch/config.json")
local package_path_helper = require("scripts.shared.package_path_helper")

package_path_helper.install_monopoly_package_paths({ repo_root = REPO_ROOT, arch_view_root = ARCH_VIEW_DIR })

local arch_view = require("arch_view")

local M = {}

function M.run(args, env)
  env = env or {}
  return arch_view.run_cli(args or arg or {}, {
    cwd = env.cwd or REPO_ROOT,
    asset_root = env.asset_root or _normalize_path(ARCH_VIEW_DIR .. "/viewer"),
    default_config_path = env.default_config_path or ARCH_CONFIG_PATH,
    default_engine = env.default_engine or "auto",
    open_path = env.open_path,
  })
end

function M.main()
  return M.run(arg or {})
end

if ... == "quality.arch" then
  return M
end

M.main()
