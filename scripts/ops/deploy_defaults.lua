local common = require("shared.lib.common")

local deploy_defaults = {}

local function _normalized_home_dir(home_dir)
  local normalized = common.normalize_path(home_dir)
  if normalized == "" then
    return ""
  end
  return normalized:gsub("/+$", "")
end

local function _candidate_paths(options)
  local home_dir = _normalized_home_dir(options.home_dir or "")

  if options.is_windows == true then
    return {
      "C:/Users/Lzx_8/Desktop/dev/LuaSource_大富翁-发布",
    }
  end

  if home_dir == "" then
    return {}
  end

  if options.is_macos == true then
    return {
      common.join_path(home_dir, "Documents/eggy/LuaSource_大富翁-发布"),
    }
  end

  return {}
end

function deploy_defaults.resolve(options)
  local candidates = _candidate_paths(options or {})
  for _, candidate in ipairs(candidates) do
    if common.path_exists(candidate) then
      return candidate
    end
  end
  return candidates[1]
end

function deploy_defaults.candidates(options)
  local resolved = {}
  for _, candidate in ipairs(_candidate_paths(options or {})) do
    resolved[#resolved + 1] = candidate
  end
  return resolved
end

return deploy_defaults
