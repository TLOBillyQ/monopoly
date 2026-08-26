local number_utils = require("src.foundation.number")
local owner = require("src.turn.choice.owner")
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local auto_play_port = require("src.rules.ports.auto_play")
local control = require("src.player.control")
local optional_action_choice = require("src.turn.optional_action_choice")

local choice_auto_policy = {}

local function _resolve_choice_owner(game, choice)
  return owner.resolve_player(game, choice)
end

local function _choice_options(choice)
  return choice and choice.options or nil
end

local function _first_option_id(first)
  return first.id or first
end

local function _pick_first_choice_option(choice)
  local options = _choice_options(choice)
  if type(options) ~= "table" then
    return nil
  end
  local first = options[1]
  if first == nil then
    return nil
  end
  return _first_option_id(first)
end

local function _select_option_action(choice, option_id)
  if option_id == nil then
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
end

local function _build_auto_or_fallback_action(game, choice, allow_first_option_fallback)
  if item_preconsume_policy.is_preconsumed(choice) then
    return _select_option_action(choice, item_preconsume_policy.first_option_id(choice))
  end
  local auto_action = auto_play_port.auto_action_for_choice(game, choice)
  if auto_action then
    return auto_action
  end
  if not allow_first_option_fallback then
    return nil
  end
  return _select_option_action(choice, _pick_first_choice_option(choice))
end

local function _normalize_visible_seconds(value)
  if not number_utils.is_numeric(value) or value < 0 then
    return 0
  end
  return value
end

local function _can_computer_actor_choose(is_computer_controlled_actor, min_visible, elapsed)
  if not is_computer_controlled_actor then
    return false
  end
  return min_visible <= 0 or elapsed >= min_visible
end

local function _resolve_computer_controlled_actor(game, choice, ctx)
  local is_computer_controlled = ctx.is_computer_controlled_actor
  if is_computer_controlled == nil then
    local actor = _resolve_choice_owner(game, choice)
    is_computer_controlled = actor and control.is_computer_controlled(actor) or false
  end
  return is_computer_controlled == true
end

local function _dispatch_computer_actor_mode(game, choice, allow_first_option_fallback, is_computer_controlled_actor, min_visible, elapsed)
  if not _can_computer_actor_choose(is_computer_controlled_actor, min_visible, elapsed) then
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

local function _dispatch_mode(game, choice, mode, is_computer_controlled_actor, min_visible, elapsed)
  if mode == "wait_choice" then
    return _dispatch_computer_actor_mode(game, choice, false, is_computer_controlled_actor, min_visible, elapsed)
  end
  if mode == "tick_min_visible" then
    return _dispatch_computer_actor_mode(game, choice, true, is_computer_controlled_actor, min_visible, elapsed)
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

local function _dispatch_mode_or_fallback(game, choice, ctx, mode, is_computer_controlled_actor, min_visible, elapsed)
  local result = _dispatch_mode(game, choice, mode, is_computer_controlled_actor, min_visible, elapsed)
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
  local is_computer_controlled_actor = _resolve_computer_controlled_actor(game, choice, ctx)
  local min_visible = _normalize_visible_seconds(ctx.min_visible_seconds)
  local elapsed = _normalize_visible_seconds(ctx.elapsed_seconds)
  return _dispatch_mode_or_fallback(game, choice, ctx, mode, is_computer_controlled_actor, min_visible, elapsed)
end

return choice_auto_policy

--[[ mutate4lua-manifest
version=4
projectHash=70079e693050d234
scope.0.id=chunk:src/turn/policies/choice_auto.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=575f39ade5f63878
scope.1.id=function:_resolve_choice_owner
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=aba9250a8c6b104f
scope.2.id=function:_choice_options
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_first_option_id
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=09efe3832adbceef
scope.4.id=function:_pick_first_choice_option
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=32
scope.4.semanticHash=c490344a8bdaf2df
scope.5.id=function:_select_option_action
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=43
scope.5.semanticHash=661f6169214c0398
scope.6.id=function:_build_auto_or_fallback_action
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=57
scope.6.semanticHash=cac3bee7e0a0df45
scope.7.id=function:_normalize_visible_seconds
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=64
scope.7.semanticHash=d988c7fda12ed118
scope.8.id=function:_can_computer_actor_choose
scope.8.kind=function
scope.8.startLine=66
scope.8.endLine=71
scope.8.semanticHash=b5e3efd8fe6ea028
scope.9.id=function:_resolve_computer_controlled_actor
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=80
scope.9.semanticHash=2249a55fadeda19b
scope.10.id=function:_dispatch_computer_actor_mode
scope.10.kind=function
scope.10.startLine=82
scope.10.endLine=87
scope.10.semanticHash=141b492ec82e1a79
scope.11.id=function:_dispatch_timeout_mode
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=101
scope.11.semanticHash=67a21d55cd5b55e0
scope.12.id=function:_dispatch_mode
scope.12.kind=function
scope.12.startLine=103
scope.12.endLine=114
scope.12.semanticHash=fa56b1e3eb05994b
scope.13.id=function:_decide_before_mode
scope.13.kind=function
scope.13.startLine=118
scope.13.endLine=126
scope.13.semanticHash=b276afdcf8ff571a
scope.14.id=function:_dispatch_mode_or_fallback
scope.14.kind=function
scope.14.startLine=128
scope.14.endLine=134
scope.14.semanticHash=9ce2a140e8f97027
scope.15.id=function:choice_auto_policy.decide
scope.15.kind=function
scope.15.startLine=136
scope.15.endLine=148
scope.15.semanticHash=f290237b5b42b4b7
]]
