local M = {}

local function _validate_mode(mode)
  assert(
    mode == "auto" or mode == "dev" or mode == "release_trimmed",
    "invalid MONO_REGRESSION_MODE: " .. tostring(mode) .. " (expected auto|dev|release_trimmed)"
  )
end

function M.resolve_behavior_mode(explicit_mode)
  local raw = explicit_mode
  if raw == nil or raw == "" then
    raw = os.getenv("MONO_REGRESSION_MODE")
  end
  local mode = (raw and raw ~= "") and raw or "auto"
  _validate_mode(mode)
  if mode ~= "auto" then
    return mode
  end

  local vehicles_cfg = require("Config.generated.vehicles")
  local market_cfg = require("Config.generated.market")
  local chance_cfg = require("Config.generated.chance_cards")
  if #vehicles_cfg > 0 then
    return "dev"
  end
  for _, row in ipairs(market_cfg) do
    if row.kind == "vehicle" then
      return "dev"
    end
  end
  for _, card in ipairs(chance_cfg) do
    if card.effect == "set_vehicle" then
      return "dev"
    end
  end
  return "release_trimmed"
end

return M
