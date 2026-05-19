local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/arch.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local cli = require("arch_view.cli")

local REPO_ROOT = bootstrap_env.repo_root
local VENDOR_DIR = bootstrap_env.vendor_dir

local effective_args = arg or {}
if #effective_args == 0 then
  effective_args = { "check" }
end
local exit_code = cli.run(effective_args, {
  cwd = REPO_ROOT,
  default_config_path = common.join_path(REPO_ROOT, "tools/quality/arch/config.json"),
  default_engine = "auto",
  script_dir = common.join_path(VENDOR_DIR, "arch_view"),
})
os.exit(exit_code)
