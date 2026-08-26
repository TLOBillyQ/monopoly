local _self = debug.getinfo(1, "S").source or "@tools/packages/crap/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local bootstrap_env, bootstrap = _sb.install("tools/packages/crap", _self)
local env_lib = require("foundation.env")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local tool_cli = require("foundation.tool_cli")
local REPO_ROOT = bootstrap_env.repo_root
local crap_tool = assert(bootstrap.ensure_tool("crap4lua", bootstrap_env))

local _env = {
  cwd = REPO_ROOT, command_name = "tools/packages/crap/runner.lua", open_path = proc_lib.open_path,
  tool_root = crap_tool.root,
  default_config = path_lib.join_path(REPO_ROOT, "tools/packages/crap/config.lua"),
  default_tier_config = path_lib.join_path(REPO_ROOT, "tools/packages/crap/coverage_tiers.lua"),
  default_report_out = "tmp/crap_report.json", default_view_dir = "tmp/crap_view", default_top = 20,
  -- 与 config.lua 的 crap_threshold 对齐（上游 v0.1.0：6 -> 5.0）；summary --gate 用。
  default_gate_threshold = 5.0,
  tmp_env_var = "EGGY_CRAP_TMP", tmp_root = path_lib.join_path(env_lib.system_tmp_dir(), "eggy_crap"),
}

if ... == "packages.crap.runner" then
  return { env = _env, run = function(args, env)
    return require("crap4lua.cli").run(args, tool_cli.merge_env(_env, env)) == 0
  end }
end
local _args = arg or {}
if #_args == 0 then
  _args = { "report" }
end
os.exit(require("crap4lua.cli").run(_args, _env))
