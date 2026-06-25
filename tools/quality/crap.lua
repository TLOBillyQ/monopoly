local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/crap.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local common = require("shared.lib.common")
local REPO_ROOT = bootstrap_env.repo_root
local crap_tool = assert(bootstrap.ensure_tool("crap4lua", bootstrap_env))

local _env = {
  cwd = REPO_ROOT, command_name = "tools/quality/crap.lua", open_path = common.open_path,
  tool_root = crap_tool.root,
  default_config = common.join_path(REPO_ROOT, "tools/quality/crap/config.lua"),
  default_tier_config = common.join_path(REPO_ROOT, "tools/quality/crap/coverage_tiers.lua"),
  default_report_out = "tmp/crap_report.json", default_view_dir = "tmp/crap_view", default_top = 20,
  tmp_env_var = "MONOPOLY_CRAP_TMP", tmp_root = common.join_path(common.system_tmp_dir(), "monopoly_crap"),
}

if ... == "quality.crap" then
  return { env = _env, run = function(args, env)
    local m = {} for k, v in pairs(_env) do m[k] = v end for k, v in pairs(env or {}) do m[k] = v end
    return require("crap4lua.cli").run(args, m) == 0
  end }
end
local _args = arg or {}
if #_args == 0 then
  _args = { "report" }
end
os.exit(require("crap4lua.cli").run(_args, _env))
