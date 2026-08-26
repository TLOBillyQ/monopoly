local mutate4lua_paths = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _path_exists(path)
  local file = io.open(path, "rb")
  if file ~= nil then
    file:close()
    return true
  end
  return false
end

function mutate4lua_paths.activate(tool_root)
  local normalized = _normalize_path(tool_root)
  local root = normalized .. "/share/lua/5.4"
  assert(_path_exists(root .. "/mutate4lua/cli.lua"), "mutate4lua not found in luarocks tree")
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
