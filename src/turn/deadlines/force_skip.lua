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

local function _refund_preconsume(state, choice)
  if not _should_refund_preconsume(choice) then
    return
  end
  local ok, helper = pcall(require, "src.rules.choice.item_preconsume_policy")
  if ok and type(helper) == "table" and type(helper.refund) == "function" then
    pcall(helper.refund, state and state._game or nil, choice)
  end
end

local function _emit_foundation_event(reason, choice)
  local ok, monopoly_events = pcall(require, "src.foundation.events")
  if ok and type(monopoly_events) == "table" and type(monopoly_events.emit) == "function" then
    pcall(monopoly_events.emit, "fb.choice_force_skipped", {
      reason = reason or "tick_timeout",
      choice_id = choice and choice.id or nil,
      kind = choice and choice.kind or nil,
    })
  end
end

local function _log_force_skip_event(reason, choice)
  logger.info("[Eggy]", "choice_force_skipped",
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

local function _clear_force_skip_state(game, state)
  if type(state) == "table" then
    pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    local output_ports = choice_ports.resolve_output_ports(state)
    if output_ports then
      local clear_pending_choice = output_ports.clear_pending_choice
      if type(clear_pending_choice) == "function" then
        pcall(clear_pending_choice, state)
      end
    end
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
    _refund_preconsume(state, choice)
    _clear_force_skip_state(game, state)
    _cancel_choice_deadlines(api, state)
    _emit_force_skip_event(reason, choice)
    _advance_after_force_skip(game)
  end
end

return force_skip

--[[ mutate4lua-manifest
version=2
projectHash=bf063aedbdd472c3
scope.0.id=chunk:src/turn/deadlines/force_skip.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=9b54a757bc291ccb
scope.1.id=function:_should_refund_preconsume:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=d49469986f236eae
scope.2.id=function:_refund_preconsume:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=24
scope.2.semanticHash=8a3616efc086c7f6
scope.3.id=function:_emit_foundation_event:26
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=35
scope.3.semanticHash=111a7206345879a4
scope.4.id=function:_log_force_skip_event:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=42
scope.4.semanticHash=9afac98794839d95
scope.5.id=function:_emit_force_skip_event:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=47
scope.5.semanticHash=1e9f861710c2e6f6
scope.6.id=function:_mark_force_skip_pending:49
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=56
scope.6.semanticHash=d83eb47bcc8068fe
scope.7.id=function:_clear_force_skip_state:58
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=72
scope.7.semanticHash=1582c984034c7102
scope.8.id=function:_cancel_choice_deadlines:74
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=82
scope.8.semanticHash=ecebd7610e1daa91
scope.9.id=function:_advance_after_force_skip:84
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=88
scope.9.semanticHash=ca68a6f1e1e4603d
scope.10.id=function:api.force_skip:91
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=98
scope.10.semanticHash=d913c5ebc7bc6b27
scope.11.id=function:force_skip.install:90
scope.11.kind=function
scope.11.startLine=90
scope.11.endLine=99
scope.11.semanticHash=a671c4e278b33a05
]]
