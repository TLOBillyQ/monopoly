local policy = {}

local function _resolve_option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

function policy.is_building_choice(choice)
  if not choice then
    return false
  end
  local kind = choice.kind
  if kind ~= "landing_optional_effect" and kind ~= "land_optional_effect" then
    return false
  end
  local options = choice.options or {}
  if #options == 0 then
    return false
  end
  for _, option in ipairs(options) do
    local option_id = _resolve_option_id(option)
    if option_id ~= "buy_land" and option_id ~= "upgrade_land" then
      return false
    end
  end
  return true
end

function policy.resolve(choice)
  if not choice then
    return "target"
  end
  local kind = choice.kind
  if kind == "market_buy" then
    return "market"
  end
  if kind == "remote_dice_value" then
    return "remote"
  end
  if kind == "item_target_player" then
    return "player"
  end
  if kind == "roadblock_target" or kind == "demolish_target" then
    return "target"
  end
  if policy.is_building_choice(choice) then
    return "building"
  end
  return "target"
end

function policy.requires_confirm(screen_key)
  return screen_key == "building"
end

return policy
