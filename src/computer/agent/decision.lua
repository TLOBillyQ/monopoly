local path_planner = require("src.computer.agent.path")

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
    if choice.kind == "roadblock_target" or choice.kind == "demolish_target" then
      return _handle_board_target_choice(game, actor, choice)
    end
    if choice.kind == "item_target_player" then
      return _handle_target_player_choice(game, actor, choice)
    end
    if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
      return _build_choice_action(choice, actor, "use")
    end
    if choice.kind == "landing_optional_effect" then
      return _handle_landing_optional_effect(choice, actor)
    end
    if choice.kind == "item_phase_choice" or choice.kind == "item_phase_passive" or choice.kind == "market_buy" then
      return _build_choice_action(choice, actor, nil, "choice_cancel")
    end
    return nil
  end
end

return decision_engine

--[[ mutate4lua-manifest
version=2
projectHash=7e2d69d12fb3b5f8
scope.0.id=chunk:src/computer/agent/decision.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=106
scope.0.semanticHash=c18cbb127b13270c
scope.0.lastMutatedAt=2026-07-07T04:12:18Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=6
scope.0.lastMutationKilled=6
scope.1.id=function:_first_option_id:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=010b61d8cb38be7b
scope.1.lastMutatedAt=2026-07-07T04:12:18Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_choice_owner:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=21
scope.2.semanticHash=189cbebb46dc811f
scope.2.lastMutatedAt=2026-07-07T04:12:18Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_build_choice_action:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=30
scope.3.semanticHash=61e6ef8d2ac2a6bc
scope.3.lastMutatedAt=2026-07-07T04:12:18Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:_handle_remote_dice_choice:48
scope.4.kind=function
scope.4.startLine=48
scope.4.endLine=52
scope.4.semanticHash=06a54c7d843dcb58
scope.4.lastMutatedAt=2026-07-07T04:12:18Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=2
scope.4.lastMutationKilled=2
scope.5.id=function:_handle_board_target_choice:54
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=60
scope.5.semanticHash=e56da494997ca6cb
scope.5.lastMutatedAt=2026-07-07T04:12:18Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=11
scope.5.lastMutationKilled=11
scope.6.id=function:_handle_target_player_choice:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=68
scope.6.semanticHash=bdce5aa2da81b61a
scope.6.lastMutatedAt=2026-07-07T04:12:18Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:_handle_landing_optional_effect:70
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=76
scope.7.semanticHash=32ac03ad0eefd9e4
scope.7.lastMutatedAt=2026-07-07T04:12:18Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:anonymous@78:78
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=102
scope.8.semanticHash=eb92c08f97e3867a
scope.8.lastMutatedAt=2026-07-07T04:12:18Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=33
scope.8.lastMutationKilled=33
scope.9.id=function:decision_engine.build:47
scope.9.kind=function
scope.9.startLine=47
scope.9.endLine=103
scope.9.semanticHash=824dd93e7f3129e9
]]
