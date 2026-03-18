local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/bridge/crap4lua/_internal/common.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/bridge/crap4lua/_internal"
end

local bootstrap = dofile(_module_dir() .. "/../../../shared/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)

local shared_common = require("shared.lib.common")
local common = {}
for key, value in pairs(shared_common) do
  common[key] = value
end

function common.resolve_cli_path(base, path)
  return shared_common.resolve_path(base, path)
end

function common.relative_to(base, path)
  local normalized_base = shared_common.normalize_path(base):gsub("/+$", "")
  local normalized_path = shared_common.normalize_path(path):gsub("^@", "")
  if normalized_path == normalized_base then
    return "."
  end
  if normalized_path:sub(1, #normalized_base + 1) == normalized_base .. "/" then
    return normalized_path:sub(#normalized_base + 2)
  end
  return normalized_path
end

return common
