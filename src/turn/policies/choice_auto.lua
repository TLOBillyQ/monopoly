local number_utils = require("src.foundation.number")
local choice_contract = require("src.config.choice.contract")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local auto_play_port = require("src.rules.ports.auto_play")
local optional_action_choice = require("src.turn.optional_action_choice")

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

local function _dispatch_auto_actor_mode(game, choice, allow_first_option_fallback, is_auto_actor, min_visible, elapsed)
  if not _can_auto_actor_choose(is_auto_actor, min_visible, elapsed) then
    return nil
  end
  return _build_auto_or_fallback_action(game, choice, allow_first_option_fallback)
end

local function _dispatch_timeout_mode(game, choice)
  if optional_action_choice.is_cancelable_optional_action_choice(choice) then
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

local function _dispatch_mode(game, choice, mode, is_auto_actor, min_visible, elapsed)
  if mode == "wait_choice" then
    return _dispatch_auto_actor_mode(game, choice, false, is_auto_actor, min_visible, elapsed)
  end
  if mode == "tick_min_visible" then
    return _dispatch_auto_actor_mode(game, choice, true, is_auto_actor, min_visible, elapsed)
  end
  if mode == "tick_timeout" then
    return _dispatch_timeout_mode(game, choice)
  end
  return nil
end

choice_auto_policy.resolve_choice_owner = _resolve_choice_owner

local function _decide_before_mode(choice, ctx)
  if not (choice and choice.id) then
    return true, nil
  end
  if ctx.pending_action then
    return true, ctx.pending_action
  end
  return false, nil
end

local function _dispatch_mode_or_fallback(game, choice, ctx, mode, is_auto_actor, min_visible, elapsed)
  local result = _dispatch_mode(game, choice, mode, is_auto_actor, min_visible, elapsed)
  if result ~= nil then
    return result
  end
  return _build_auto_or_fallback_action(game, choice, ctx.allow_first_option_fallback == true)
end

function choice_auto_policy.decide(game, _state, choice, ctx)
  ctx = ctx or {}
  local handled, action = _decide_before_mode(choice, ctx)
  if handled then
    return action
  end

  local mode = ctx.mode or "wait_choice"
  local is_auto_actor = _resolve_auto_actor_flag(game, choice, ctx)
  local min_visible = _normalize_visible_seconds(ctx.min_visible_seconds)
  local elapsed = _normalize_visible_seconds(ctx.elapsed_seconds)
  return _dispatch_mode_or_fallback(game, choice, ctx, mode, is_auto_actor, min_visible, elapsed)
end

return choice_auto_policy

--[[ mutate4lua-manifest
version=2
projectHash=c3a8a302db63a6b3
scope.0.id=chunk:src/turn/policies/choice_auto.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=157
scope.0.semanticHash=0daffa807a34ffe5
scope.1.id=function:_resolve_choice_owner:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=21
scope.1.semanticHash=9a64ffe944066964
scope.2.id=function:_pick_first_choice_option:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=33
scope.2.semanticHash=31a4a25726108120
scope.3.id=function:_build_auto_or_fallback_action:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=63
scope.3.semanticHash=04e15064d27bd973
scope.4.id=function:_normalize_visible_seconds:65
scope.4.kind=function
scope.4.startLine=65
scope.4.endLine=70
scope.4.semanticHash=0fb92c54b5fdc015
scope.5.id=function:_can_auto_actor_choose:72
scope.5.kind=function
scope.5.startLine=72
scope.5.endLine=77
scope.5.semanticHash=00bdaaaf623adcdf
scope.6.id=function:_resolve_auto_actor_flag:79
scope.6.kind=function
scope.6.startLine=79
scope.6.endLine=86
scope.6.semanticHash=635cd85c9fad982f
scope.7.id=function:_dispatch_auto_actor_mode:88
scope.7.kind=function
scope.7.startLine=88
scope.7.endLine=93
scope.7.semanticHash=e7fadf43d6edee01
scope.8.id=function:_dispatch_timeout_mode:95
scope.8.kind=function
scope.8.startLine=95
scope.8.endLine=107
scope.8.semanticHash=0e908792b7900328
scope.9.id=function:_dispatch_mode:109
scope.9.kind=function
scope.9.startLine=109
scope.9.endLine=120
scope.9.semanticHash=3e0a0e8ac4b185cf
scope.10.id=function:_decide_before_mode:124
scope.10.kind=function
scope.10.startLine=124
scope.10.endLine=132
scope.10.semanticHash=0fa151e82fd08d0f
scope.11.id=function:_dispatch_mode_or_fallback:134
scope.11.kind=function
scope.11.startLine=134
scope.11.endLine=140
scope.11.semanticHash=2ad3cc3614339123
scope.12.id=function:choice_auto_policy.decide:142
scope.12.kind=function
scope.12.startLine=142
scope.12.endLine=154
scope.12.semanticHash=1c39283a98db0c31
]]
