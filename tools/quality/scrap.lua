local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/scrap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local REPO_ROOT = bootstrap_env.repo_root
local scrap_lib = _normalize_path(bootstrap_env.vendor_dir) .. "/scrap4lua/lib/?.lua"
if not package.path:find(scrap_lib, 1, true) then
  package.path = scrap_lib .. ";" .. package.path
end

local cli = require("scrap4lua.cli")
local exit_code = cli.run(arg or {}, {
  cwd = REPO_ROOT,
  default_config = common.join_path(REPO_ROOT, "tools/quality/scrap/config.lua"),
  tmp_env_var = "MONOPOLY_SCRAP_TMP",
  tmp_root = common.join_path(common.system_tmp_dir(), "monopoly_scrap"),
  default_index_out = "tmp/scrap_index.json",
  default_clusters_out = "tmp/scrap_clusters.json",
  default_view_dir = "tmp/scrap_view",
  command_name = "tools/quality/scrap.lua",
})
os.exit(exit_code)
