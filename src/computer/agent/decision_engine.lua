local path_planner = require("src.computer.agent.path_planner")

local decision_engine = {}

local function _first_option_id(options)
  if not options or #options == 0 then
    return nil
  end
  return options[1].id or options[1]
end

local function _choice_owner(game, choice)
  local meta = choice.meta or {}
  if meta.player_id and game.find_player_by_id then
    local player = game:find_player_by_id(meta.player_id)
    if player then
      return player
    end
  end
  return game:current_player()
end

local function _build_choice_action(choice, actor, option_id, action_type)
  return {
    type = action_type or "choice_select",
    choice_id = choice.id,
    option_id = option_id,
    actor_role_id = actor.id,
  }
end

local function _resolve_target_option(options, preferred_ids)
  for _, preferred_id in ipairs(preferred_ids) do
    for _, opt in ipairs(options or {}) do
      local option_id = opt.id or opt
      if option_id == preferred_id then
        return option_id
      end
    end
  end
  return _first_option_id(options)
end

-- build returns auto_action_for_choice bound to the given agent_ref table.
-- agent_ref must expose: pick_remote_dice_value, pick_roadblock_target,
-- pick_demolish_target, pick_target_player (looked up at call time to allow patching).
function decision_engine.build(agent_ref)
  local function _handle_remote_dice_choice(game, actor, choice)
    local dice_count = choice.meta.dice_count
    local value = agent_ref.pick_remote_dice_value(game, actor, dice_count)
    return _build_choice_action(choice, actor, value or _first_option_id(choice.options))
  end

  local function _handle_board_target_choice(game, actor, choice)
    local resolver = choice.kind == "roadblock_target" and agent_ref.pick_roadblock_target or agent_ref.pick_demolish_target
    local option_id = choice.kind == "roadblock_target"
      and resolver(game, actor)
      or resolver(game, actor, 3)
    return _build_choice_action(choice, actor, option_id or _first_option_id(choice.options))
  end

  local function _handle_target_player_choice(game, actor, choice)
    local target = agent_ref.pick_target_player(game, actor, choice.meta.item_id, choice.options)
    if target then
      return _build_choice_action(choice, actor, target.id)
    end
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end

  local function _handle_simple_pick_or_cancel(choice, actor)
    local option_id = _first_option_id(choice.options)
    if option_id then
      return _build_choice_action(choice, actor, option_id)
    end
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end

  local function _handle_landing_optional_effect(choice, actor)
    local target = _resolve_target_option(choice.options or {}, { "buy_land", "upgrade_land" })
    if target then
      return _build_choice_action(choice, actor, target)
    end
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end

  return function(game, choice)
    local actor = _choice_owner(game, choice)
    if not path_planner.is_auto_player(actor) then
      return nil
    end
    if choice.kind == "remote_dice_value" then
      return _handle_remote_dice_choice(game, actor, choice)
    end
    if choice.kind == "roadblock_target" or choice.kind == "demolish_target" or choice.kind == "missile_target" then
      return _handle_board_target_choice(game, actor, choice)
    end
    if choice.kind == "item_target_player" then
      return _handle_target_player_choice(game, actor, choice)
    end
    if choice.kind == "steal_item" then
      return _handle_simple_pick_or_cancel(choice, actor)
    end
    if choice.kind == "steal_prompt" then
      return _build_choice_action(choice, actor, "use")
    end
    if choice.kind == "landing_optional_effect" then
      return _handle_landing_optional_effect(choice, actor)
    end
    if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
      return _build_choice_action(choice, actor, "use")
    end
    if choice.kind == "item_phase_choice" then
      return _build_choice_action(choice, actor, nil, "choice_cancel")
    end
    if choice.kind == "market_buy" then
      return _build_choice_action(choice, actor, nil, "choice_cancel")
    end
    return nil
  end
end

return decision_engine
