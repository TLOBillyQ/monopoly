local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/dry.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local dry4lua_lib = _normalize_path(bootstrap_env.vendor_dir) .. "/dry4lua/lib/?.lua"
if not package.path:find(dry4lua_lib, 1, true) then
  package.path = dry4lua_lib .. ";" .. package.path
end

local cli = require("dry4lua.cli")
local exit_code = cli.run(arg or {})
os.exit(exit_code)
