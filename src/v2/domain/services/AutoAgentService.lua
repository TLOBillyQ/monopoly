local gameplay_rules = require("Config.GameplayRules")

local auto_agent_service = {}

local item_ids = gameplay_rules.item_ids or {}

local function _first_option_id(options)
  if not options or #options == 0 then
    return nil
  end
  return options[1].id or options[1]
end

function auto_agent_service.is_auto_player(player)
  if not player then
    return false
  end
  return player.is_ai == true or player.auto == true
end

function auto_agent_service.auto_choice_action(state, choice)
  if not choice then
    return nil
  end
  local owner_seat = choice.meta and choice.meta.owner_seat or state.turn.current_seat
  local owner = state.players[owner_seat]
  if not auto_agent_service.is_auto_player(owner) then
    return nil
  end

  if choice.kind == "landing_optional_effect" then
    for _, option in ipairs(choice.options or {}) do
      local option_id = option.id or option
      if option_id == "buy_land" then
        return { type = "choice_select", option_id = option_id }
      end
    end
    for _, option in ipairs(choice.options or {}) do
      local option_id = option.id or option
      if option_id == "upgrade_land" then
        return { type = "choice_select", option_id = option_id }
      end
    end
    return { type = "choice_select", option_id = _first_option_id(choice.options) }
  end

  if choice.kind == "market_buy" then
    return { type = "choice_cancel" }
  end

  if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
    return { type = "choice_select", option_id = "use" }
  end

  if choice.kind == "steal_prompt" then
    return { type = "choice_select", option_id = "use" }
  end

  if choice.kind == "steal_item" then
    return { type = "choice_select", option_id = _first_option_id(choice.options) }
  end

  if choice.kind == "remote_dice_value" then
    local prefer = 6
    for _, option in ipairs(choice.options or {}) do
      local option_id = option.id or option
      if tonumber(option_id) == prefer then
        return { type = "choice_select", option_id = option_id }
      end
    end
    return { type = "choice_select", option_id = _first_option_id(choice.options) }
  end

  if choice.kind == "roadblock_target"
      or choice.kind == "demolish_target"
      or choice.kind == "item_target_player" then
    return { type = "choice_select", option_id = _first_option_id(choice.options) }
  end

  if choice.kind == "item_phase_choice" then
    local options = choice.options or {}
    for _, option in ipairs(options) do
      local option_id = option.id or option
      if option_id == item_ids.dice_multiplier
          or option_id == item_ids.remote_dice
          or option_id == item_ids.clear_obstacles then
        return { type = "choice_select", option_id = option_id }
      end
    end
    return { type = "choice_cancel" }
  end

  return nil
end

return auto_agent_service
