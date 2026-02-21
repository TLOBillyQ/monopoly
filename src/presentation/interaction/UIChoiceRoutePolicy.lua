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
  local explicit_route = choice and (choice.route_key or (type(choice.route) == "table" and choice.route.route_key) or nil)
  if explicit_route ~= nil and explicit_route ~= "" then
    return explicit_route
  end
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

function policy.requires_confirm(choice_or_screen)
  if type(choice_or_screen) == "table" then
    local explicit = choice_or_screen.requires_confirm
    if type(explicit) == "boolean" then
      return explicit
    end
    return policy.resolve(choice_or_screen) == "building"
  end
  return choice_or_screen == "building"
end

return policy
