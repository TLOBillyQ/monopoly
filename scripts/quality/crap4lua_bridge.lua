local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/quality/crap4lua_bridge.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local script_dir = _module_dir()
local repo_root = _normalize_path(script_dir .. "/../..")
package.path = table.concat({
  repo_root .. "/vendor/crap4lua/lib/?.lua",
  repo_root .. "/vendor/crap4lua/lib/?/?.lua",
  package.path,
}, ";")

dofile(repo_root .. "/scripts/shared/package_path_helper.lua").install_monopoly_package_paths({
  repo_root = repo_root,
  arch_view_root = repo_root .. "/vendor/arch_view",
})

local bridge = require("crap4lua.bridge")
local ok, err = pcall(function()
  bridge.run_cli(arg or {}, {
    command_name = "scripts/quality/crap4lua_bridge.lua",
    default_config_path = repo_root .. "/scripts/quality/crap/config.lua",
  })
end)
if not ok then
  io.stderr:write(tostring(err), "\n")
  os.exit(1)
end
