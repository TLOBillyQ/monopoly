local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/mutate.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local REPO_ROOT = bootstrap_env.repo_root
local mutate4lua_root = _normalize_path(bootstrap_env.vendor_dir) .. "/mutate4lua/lib"
local mutate4lua_patterns = {
  mutate4lua_root .. "/?.lua",
  mutate4lua_root .. "/?/init.lua",
}
for index = #mutate4lua_patterns, 1, -1 do
  local pattern = mutate4lua_patterns[index]
  if not package.path:find(pattern, 1, true) then
    package.path = pattern .. ";" .. package.path
  end
end

local _env = {
  cwd = REPO_ROOT, command_name = "tools/quality/mutate.lua",
  default_driver = "tools/quality/mutate/driver.lua",
  busted_driver = "tools/quality/mutate/busted_adapter.lua",
  busted_discover = function(lane)
    return require("quality.mutate.busted_adapter").discover_specs(lane)
  end,
}

if ... == "quality.mutate" then
  return { env = _env, run = function(args, env)
    local m = {} for k, v in pairs(_env) do m[k] = v end for k, v in pairs(env or {}) do m[k] = v end
    return require("mutate4lua.cli").run(args, m)
  end }
end
os.exit(require("mutate4lua.cli").run(arg or {}, _env))
