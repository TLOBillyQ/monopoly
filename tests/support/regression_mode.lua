local M = {}
local _resolved_mode = nil

local function _validate_mode(mode)
  assert(
    mode == "auto" or mode == "dev" or mode == "release_trimmed",
    "invalid MONO_REGRESSION_MODE: " .. tostring(mode) .. " (expected auto|dev|release_trimmed)"
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

  local raw = os.getenv("MONO_REGRESSION_MODE")
  local mode = (raw and raw ~= "") and raw or "auto"
  _validate_mode(mode)
  if mode ~= "auto" then
    _resolved_mode = mode
    return mode
  end

  local vehicles_cfg = require("Config.generated.vehicles")
  local market_cfg = require("Config.generated.market")
  local chance_cfg = require("Config.generated.chance_cards")
  if #vehicles_cfg > 0 then
    _resolved_mode = "dev"
    return _resolved_mode
  end
  for _, row in ipairs(market_cfg) do
    if row.kind == "vehicle" then
      _resolved_mode = "dev"
      return _resolved_mode
    end
  end
  for _, card in ipairs(chance_cfg) do
    if card.effect == "set_vehicle" then
      _resolved_mode = "dev"
      return _resolved_mode
    end
  end
  _resolved_mode = "release_trimmed"
  return _resolved_mode
end

return M
