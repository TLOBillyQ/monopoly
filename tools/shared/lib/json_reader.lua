local common = require("shared.lib.common")

local function _append_package_path(path_pattern)
  if not tostring(package.path):find(path_pattern, 1, true) then
    package.path = package.path .. ";" .. path_pattern
  end
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/shared/lib/json_reader.lua"
  local normalized = common.normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/shared/lib"
end

local bootstrap = dofile(_module_dir() .. "/../bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local repo_root = env.repo_root
local vendor_root = common.join_path(repo_root, "vendor/scrap4lua/lib")

_append_package_path(common.join_path(vendor_root, "?.lua"))
_append_package_path(common.join_path(vendor_root, "?/?.lua"))

return require("scrap4lua.json_reader")
