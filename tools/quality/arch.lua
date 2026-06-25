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
local arch_tool = assert(bootstrap.ensure_tool("arch_view", bootstrap_env))

local _env = {
  cwd = bootstrap_env.repo_root,
  command_name = "tools/quality/arch.lua",
  default_config_path = require("shared.lib.common").join_path(bootstrap_env.repo_root, "tools/quality/arch/config.json"),
  script_dir = arch_tool.root,
}
local cli = require("arch_view.cli")
local function _merge(env)
  local merged = {}
  for key, value in pairs(_env) do merged[key] = value end
  for key, value in pairs(env or {}) do merged[key] = value end
  return merged
end

if ... == "quality.arch" then
  return { env = _env, run = function(args, env) return cli.run(args or {}, _merge(env)) end }
end

local effective_args = arg or {}
if #effective_args == 0 then effective_args = { "check" } end
os.exit(cli.run(effective_args, _env) and 0 or 1)
