local mutate4lua_paths = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

function mutate4lua_paths.activate(vendor_dir)
  local root = _normalize_path(vendor_dir) .. "/mutate4lua/lib"
  local patterns = {
    root .. "/?.lua",
    root .. "/?/init.lua",
  }
  for _, pattern in ipairs(patterns) do
    if not tostring(package.path):find(pattern, 1, true) then
      package.path = pattern .. ";" .. package.path
    end
  end
end

return mutate4lua_paths
