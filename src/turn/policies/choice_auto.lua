local number_utils = require("src.foundation.number")
local choice_contract = require("src.config.choice.contract")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local auto_play_port = require("src.rules.ports.auto_play")
local optional_action_completion = require("src.turn.optional_action_completion")

local choice_auto_policy = {}

local function _resolve_choice_owner(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player
    end
  end
  if game and game.current_player then
    return game:current_player()
  end
  return nil
end

local function _pick_first_choice_option(choice)
  local options = choice and choice.options or nil
  if type(options) ~= "table" then
    return nil
  end
  local first = options[1]
  if first == nil then
    return nil
  end
  return first.id or first
end

local function _build_auto_or_fallback_action(game, choice, allow_first_option_fallback)
  if item_preconsume_policy.is_preconsumed(choice) then
    local option_id = item_preconsume_policy.first_option_id(choice)
    if option_id == nil then
      return nil
    end
    return {
      type = "choice_select",
      choice_id = choice.id,
      option_id = option_id,
    }
  end
  local auto_action = auto_play_port.auto_action_for_choice(game, choice)
  if auto_action then
    return auto_action
  end
  if not allow_first_option_fallback then
    return nil
  end
  local option_id = _pick_first_choice_option(choice)
  if option_id == nil then
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
end

local function _normalize_visible_seconds(value)
  if not number_utils.is_numeric(value) or value < 0 then
    return 0
  end
  return value
end

local function _can_auto_actor_choose(is_auto_actor, min_visible, elapsed)
  if not is_auto_actor then
    return false
  end
  return min_visible <= 0 or elapsed >= min_visible
end

local function _resolve_auto_actor_flag(game, choice, ctx)
  local is_auto_actor = ctx.is_auto_actor
  if is_auto_actor == nil then
    local actor = _resolve_choice_owner(game, choice)
    is_auto_actor = actor and auto_play_port.is_auto_player(game, actor) or false
  end
  return is_auto_actor == true
end

local function _dispatch_mode(game, choice, mode, is_auto_actor, min_visible, elapsed)
  if mode == "wait_choice" then
    if not _can_auto_actor_choose(is_auto_actor, min_visible, elapsed) then
      return nil
    end
    return _build_auto_or_fallback_action(game, choice, false)
  end
  if mode == "tick_min_visible" then
    if not _can_auto_actor_choose(is_auto_actor, min_visible, elapsed) then
      return nil
    end
    return _build_auto_or_fallback_action(game, choice, true)
  end
  if mode == "tick_timeout" then
    if optional_action_completion.is_cancelable_optional_action_choice(choice) then
      return { type = "complete_optional_action_phase" }
    end
    if choice.allow_cancel == true then
      return { type = "choice_cancel", choice_id = choice.id }
    end
    local fallback = _build_auto_or_fallback_action(game, choice, true)
    if fallback ~= nil then
      return fallback
    end
    return { type = "choice_force_skip", choice_id = choice.id }
  end
  return nil
end

choice_auto_policy.resolve_choice_owner = _resolve_choice_owner

function choice_auto_policy.decide(game, _state, choice, ctx)
  if not (choice and choice.id) then
    return nil
  end
  ctx = ctx or {}
  if ctx.pending_action then
    return ctx.pending_action
  end

  local mode = ctx.mode or "wait_choice"
  local is_auto_actor = _resolve_auto_actor_flag(game, choice, ctx)
  local min_visible = _normalize_visible_seconds(ctx.min_visible_seconds)
  local elapsed = _normalize_visible_seconds(ctx.elapsed_seconds)

  local result = _dispatch_mode(game, choice, mode, is_auto_actor, min_visible, elapsed)
  if result ~= nil then
    return result
  end
  return _build_auto_or_fallback_action(game, choice, ctx.allow_first_option_fallback == true)
end

return choice_auto_policy

--[[ mutate4lua-manifest
version=2
projectHash=d5a3932c13c0c697
scope.0.id=chunk:src/turn/policies/choice_auto.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=a1701cd7e4af4084
scope.1.id=function:_resolve_choice_owner:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=20
scope.1.semanticHash=9a64ffe944066964
scope.2.id=function:_pick_first_choice_option:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=32
scope.2.semanticHash=31a4a25726108120
scope.3.id=function:_build_auto_or_fallback_action:34
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=62
scope.3.semanticHash=04e15064d27bd973
scope.4.id=function:_normalize_visible_seconds:64
scope.4.kind=function
scope.4.startLine=64
scope.4.endLine=69
scope.4.semanticHash=0fb92c54b5fdc015
scope.5.id=function:_can_auto_actor_choose:71
scope.5.kind=function
scope.5.startLine=71
scope.5.endLine=76
scope.5.semanticHash=00bdaaaf623adcdf
scope.6.id=function:_resolve_auto_actor_flag:78
scope.6.kind=function
scope.6.startLine=78
scope.6.endLine=85
scope.6.semanticHash=635cd85c9fad982f
scope.7.id=function:_dispatch_mode:87
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=111
scope.7.semanticHash=486c130e4c7929d1
scope.8.id=function:choice_auto_policy.decide:115
scope.8.kind=function
scope.8.startLine=115
scope.8.endLine=134
scope.8.semanticHash=91ed2f16fbb3af64
]]
