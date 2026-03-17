local M = {}
local _resolved_mode = nil

local function _validate_mode(mode)
  assert(
    mode == "auto" or mode == "dev" or mode == "release",
    "invalid MONO_BUILD_MODE: " .. tostring(mode) .. " (expected auto|dev|release)"
  )
end

function M.resolve_behavior_mode(explicit_mode)
  if explicit_mode and explicit_mode ~= "" then
    _validate_mode(explicit_mode)
    return explicit_mode
  end

  if _resolved_mode ~= nil then
    return _resolved_mode
  end

  local raw = os.getenv("MONO_BUILD_MODE")
  local mode = (raw and raw ~= "") and raw or "auto"
  _validate_mode(mode)
  if mode ~= "auto" then
    _resolved_mode = mode
    return mode
  end
  _resolved_mode = "dev"
  return _resolved_mode
end

return M
