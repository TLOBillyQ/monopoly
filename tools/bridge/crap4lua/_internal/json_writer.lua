local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/bridge/crap4lua/_internal/json_writer.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/bridge/crap4lua/_internal"
end

local bootstrap = dofile(_module_dir() .. "/../../../shared/bootstrap.lua")
bootstrap.install(debug.getinfo(1, "S").source)

return require("shared.lib.json_writer")
