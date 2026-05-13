local common = require("shared.lib.common")

local function _discover_by_glob(lane)
  local root = common.normalize_path(common.join_path("spec", tostring(lane or "")))
  local files, err = common.collect_files(root, ".lua")
  if files == nil then
    return nil, err
  end

  local project_root = common.normalize_path(common.current_dir())
  local prefix = project_root:gsub("/+$", "") .. "/"
  local specs = {}
  for _, path in ipairs(files) do
    local normalized = common.normalize_path(path)
    if normalized:match("_spec%.lua$") ~= nil then
      if normalized:sub(1, #prefix) == prefix then
        normalized = normalized:sub(#prefix + 1)
      end
      specs[#specs + 1] = normalized
    end
  end
  table.sort(specs)
  return specs
end

local M = {}

function M.discover_specs(lane)
  local normalized_lane = tostring(lane or "behavior")

  local specs, err = _discover_by_glob(normalized_lane)
  if specs == nil then
    return nil, err
  end

  if normalized_lane == "contract" then
    local filtered = {}
    for _, path in ipairs(specs) do
      if path:match("/[_]smoke_spec%.lua$") == nil then
        filtered[#filtered + 1] = path
      end
    end
    return filtered
  end

  return specs
end

return M
