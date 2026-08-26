local control = require("src.player.control")

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

local function _find_preferred(options, preferred_id)
  for _, opt in ipairs(options or {}) do
    local option_id = opt.id or opt
    if option_id == preferred_id then
      return option_id
    end
  end
  return nil
end

local function _resolve_target_option(options, preferred_ids)
  for _, preferred_id in ipairs(preferred_ids) do
    local found = _find_preferred(options, preferred_id)
    if found ~= nil then
      return found
    end
  end
  return _first_option_id(options)
end

local function _board_target_resolver(agent_ref, kind)
  return kind == "roadblock_target" and agent_ref.pick_roadblock_target or agent_ref.pick_demolish_target
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
    local resolver = _board_target_resolver(agent_ref, choice.kind)
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

  local function _handle_landing_optional_effect(game, actor, choice)
    local _ = game
    local target = _resolve_target_option(choice.options or {}, { "buy_land", "upgrade_land" })
    if target then
      return _build_choice_action(choice, actor, target)
    end
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end

  local function _handle_card_prompt_choice(game, actor, choice)
    local _ = game
    return _build_choice_action(choice, actor, "use")
  end

  local function _handle_cancel_choice(game, actor, choice)
    local _ = game
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end

  -- Every handler takes (game, actor, choice); kinds absent here get no auto action.
  local _handlers_by_kind = {
    remote_dice_value = _handle_remote_dice_choice,
    roadblock_target = _handle_board_target_choice,
    demolish_target = _handle_board_target_choice,
    item_target_player = _handle_target_player_choice,
    rent_card_prompt = _handle_card_prompt_choice,
    tax_card_prompt = _handle_card_prompt_choice,
    landing_optional_effect = _handle_landing_optional_effect,
    item_phase_passive = _handle_cancel_choice,
    market_buy = _handle_cancel_choice,
  }

  return function(game, choice)
    local actor = _choice_owner(game, choice)
    if not control.is_computer_controlled(actor) then
      return nil
    end
    local handler = _handlers_by_kind[choice.kind]
    if handler == nil then
      return nil
    end
    return handler(game, actor, choice)
  end
end

return decision_engine

--[[ mutate4lua-manifest
version=4
projectHash=c4f0faddf69f5020
scope.0.id=chunk:src/computer/agent/decision.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=128
scope.0.semanticHash=6eb84968873ce46e
scope.1.id=function:_first_option_id
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=9bb303d8705003bc
scope.2.id=function:_choice_owner
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=21
scope.2.semanticHash=c0e359c40c512f3b
scope.3.id=function:_build_choice_action
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=30
scope.3.semanticHash=96cc3d6c00413b1a
scope.4.id=function:_find_preferred
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=40
scope.4.semanticHash=76a50153e8e8a621
scope.5.id=function:_resolve_target_option
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=50
scope.5.semanticHash=596e891a93f8b14e
scope.6.id=function:_board_target_resolver
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=54
scope.6.semanticHash=0b6194444388fabb
scope.7.id=function:decision_engine.build
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=125
scope.7.semanticHash=64c16d31a9f617ca
scope.8.id=function:_handle_remote_dice_choice
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=64
scope.8.semanticHash=a2b91249d0997f3d
scope.9.id=function:_handle_board_target_choice
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=72
scope.9.semanticHash=8341691283185afd
scope.10.id=function:_handle_target_player_choice
scope.10.kind=function
scope.10.startLine=74
scope.10.endLine=80
scope.10.semanticHash=2ad54b104c83e137
scope.11.id=function:_handle_landing_optional_effect
scope.11.kind=function
scope.11.startLine=82
scope.11.endLine=89
scope.11.semanticHash=2d3b48403618dd53
scope.12.id=function:_handle_card_prompt_choice
scope.12.kind=function
scope.12.startLine=91
scope.12.endLine=94
scope.12.semanticHash=18186555c3a6d946
scope.13.id=function:_handle_cancel_choice
scope.13.kind=function
scope.13.startLine=96
scope.13.endLine=99
scope.13.semanticHash=5c8ac3999a22f998
scope.14.id=function:<anonymous>
scope.14.kind=function
scope.14.startLine=114
scope.14.endLine=124
scope.14.semanticHash=75766520e16c88b7
]]
