local logger = require("src.foundation.log")
local choice_ports = require("src.turn.deadlines.choice_ports")
local pending_confirmation = require("src.state.pending_confirmation")

local force_skip = {}

local function _should_refund_preconsume(choice)
  if type(choice) ~= "table" or type(choice.meta) ~= "table" then
    return false
  end
  if choice.meta.item_preconsumed ~= true then
    return false
  end
  return choice.meta.item_id ~= nil and choice.owner_role_id ~= nil
end

local function _game_or_state_game(game, state)
  return game or (state and state._game or nil)
end

local function _refund_helper()
  local ok, helper = pcall(require, "src.rules.choice.item_preconsume_policy")
  if ok and type(helper) == "table" and type(helper.refund) == "function" then
    return helper
  end
  return nil
end

local function _refund_preconsume(game, state, choice)
  if not _should_refund_preconsume(choice) then
    return
  end
  local helper = _refund_helper()
  if helper then
    pcall(helper.refund, _game_or_state_game(game, state), choice)
  end
end

local function _emitable(monopoly_events)
  return type(monopoly_events) == "table" and type(monopoly_events.emit) == "function"
end

local function _choice_field(choice, key)
  return choice and choice[key] or nil
end

local function _force_skip_payload(reason, choice)
  return {
    reason = reason or "tick_timeout",
    choice_id = _choice_field(choice, "id"),
    kind = _choice_field(choice, "kind"),
  }
end

local function _emit_foundation_event(reason, choice)
  local ok, monopoly_events = pcall(require, "src.foundation.events")
  if ok and _emitable(monopoly_events) then
    pcall(monopoly_events.emit, "fb.choice_force_skipped", _force_skip_payload(reason, choice))
  end
end

local function _log_force_skip_event(reason, choice)
  logger.warn("[Eggy]", "choice_force_skipped",
    "reason=" .. tostring(reason),
    "choice_id=" .. tostring(choice and choice.id or nil),
    "kind=" .. tostring(choice and choice.kind or nil))
end

local function _emit_force_skip_event(reason, choice)
  _emit_foundation_event(reason, choice)
  _log_force_skip_event(reason, choice)
end

local function _mark_force_skip_pending(game, state)
  if type(state) == "table" then
    state._choice_force_skip_pending = true
  end
  if game and game.turn then
    game.turn._choice_force_skip_pending = true
  end
end

local function _clear_pending_choice_via_port(state)
  local output_ports = choice_ports.resolve_output_ports(state)
  if output_ports then
    local clear_pending_choice = output_ports.clear_pending_choice
    if type(clear_pending_choice) == "function" then
      pcall(clear_pending_choice, state)
    end
  end
end

local function _clear_force_skip_state(game, state)
  if type(state) == "table" then
    pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    _clear_pending_choice_via_port(state)
  end
  if game and game.turn then
    game.turn.pending_choice = nil
  end
end

local function _cancel_choice_deadlines(api, state)
  if type(state) ~= "table" then
    return
  end
  api.cancel(state, "choice")
  api.cancel(state, "market_buy")
  api.cancel(state, "target_select")
  api.cancel(state, "modal_popup")
end

local function _advance_after_force_skip(game)
  if game and not game.finished and type(game.advance_turn) == "function" then
    pcall(game.advance_turn, game)
  end
end

function force_skip.install(api)
  function api.force_skip(game, state, choice, reason)
    _mark_force_skip_pending(game, state)
    _refund_preconsume(game, state, choice)
    _clear_force_skip_state(game, state)
    _cancel_choice_deadlines(api, state)
    _emit_force_skip_event(reason, choice)
    _advance_after_force_skip(game)
  end
end

return force_skip

--[[ mutate4lua-manifest
version=4
projectHash=f6607d5833519158
scope.0.id=chunk:src/turn/deadlines/force_skip.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=107
scope.0.semanticHash=88656bd9d54520c3
scope.1.id=function:_should_refund_preconsume
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=15
scope.1.semanticHash=b4e2e2dd5a6c99fa
scope.2.id=function:_refund_preconsume
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=25
scope.2.semanticHash=94e74d2dd09f08e8
scope.3.id=function:_emit_foundation_event
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=36
scope.3.semanticHash=a11f182987b3389d
scope.4.id=function:_log_force_skip_event
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=43
scope.4.semanticHash=d5f42a181e99a942
scope.5.id=function:_emit_force_skip_event
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=48
scope.5.semanticHash=45e35726263dabc2
scope.6.id=function:_mark_force_skip_pending
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=57
scope.6.semanticHash=77e83005efcc9e66
scope.7.id=function:_clear_pending_choice_via_port
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=67
scope.7.semanticHash=e1191ce2a203ff07
scope.8.id=function:_clear_force_skip_state
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=77
scope.8.semanticHash=4d36621abd80f933
scope.9.id=function:_cancel_choice_deadlines
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=87
scope.9.semanticHash=03ea485c880567c9
scope.10.id=function:_advance_after_force_skip
scope.10.kind=function
scope.10.startLine=89
scope.10.endLine=93
scope.10.semanticHash=72768aad01fd8405
scope.11.id=function:force_skip.install
scope.11.kind=function
scope.11.startLine=95
scope.11.endLine=104
scope.11.semanticHash=8fbb0779b5e7766b
scope.12.id=function:api.force_skip
scope.12.kind=function
scope.12.startLine=96
scope.12.endLine=103
scope.12.semanticHash=da52af157cbba71a
]]
