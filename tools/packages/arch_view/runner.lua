local _self = debug.getinfo(1, "S").source or "@tools/packages/arch_view/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local bootstrap_env, bootstrap = _sb.install("tools/packages/arch_view", _self)
assert(bootstrap.ensure_tool("arch_view", bootstrap_env))

local _env = {
  cwd = bootstrap_env.repo_root,
  command_name = "tools/packages/arch_view/runner.lua",
  default_config_path = require("foundation.path").join_path(bootstrap_env.repo_root, "tools/packages/arch_view/config.json"),
}
local cli = require("arch_view.cli")
local tool_cli = require("foundation.tool_cli")

if ... == "packages.arch_view.runner" then
  return { env = _env, run = function(args, env) return cli.run(args or {}, tool_cli.merge_env(_env, env)) end }
end

local effective_args = arg or {}
if #effective_args == 0 then effective_args = { "check" } end
os.exit(cli.run(effective_args, _env) and 0 or 1)