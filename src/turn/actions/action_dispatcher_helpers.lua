local ctx_mod = require("src.turn.actions.context")

local helpers = {}

local INVALIDATING_ACTION_TYPES = {
  ui_button = true,
  item_slot_click = true,
  choice_select = true,
  choice_cancel = true,
  complete_optional_action_phase = true,
  market_page_prev = true,
  market_page_next = true,
  market_tab_select = true,
}

function helpers.should_invalidate_ui(action)
  return INVALIDATING_ACTION_TYPES[action.type] == true
end

function helpers.invalidate_ui_model(output_ports, state)
  if output_ports and type(output_ports.invalidate_ui_model) == "function" then
    output_ports.invalidate_ui_model(state)
  end
end

local function _blocked_gate(gate_state)
  return gate_state ~= nil and gate_state.input_blocked == true
end

local function _cancel_action(action)
  return action ~= nil and action.type == "choice_cancel"
end

local function _market_buy_choice(choice)
  return choice ~= nil and choice.kind == "market_buy"
end

local function _same_choice(action, choice)
  return action.choice_id ~= nil and choice.id ~= nil and action.choice_id == choice.id
end

function helpers.allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
  if not _blocked_gate(gate_state) then
    return false
  end
  if not _cancel_action(action) then
    return false
  end
  local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
  if not _market_buy_choice(choice) then
    return false
  end
  return _same_choice(action, choice)
end

local function _pending_choice(game)
  return game and game.turn and game.turn.pending_choice or nil
end

local function _choice_closed(pending, choice)
  return choice ~= nil and (pending == nil or pending.id == nil or pending.id ~= choice.id)
end

function helpers.clear_choice_if_closed(turn_dispatch, game, state, opts, choice)
  local pending = _pending_choice(game)
  if _choice_closed(pending, choice) then
    turn_dispatch.clear_choice(state, opts)
  end
end

function helpers.optional_completion_status(result)
  if result.ok == true then
    return { status = "applied" }
  end
  if result.reason == "blocked" then
    return { status = "blocked", reason = result.reason }
  end
  return { status = "rejected", reason = result.reason }
end

function helpers.ensure_input_source(action)
  if action.input_source == nil then
    action.input_source = "user"
  end
end

return helpers

--[[ mutate4lua-manifest
version=4
projectHash=953afec062ea7b1a
scope.0.id=chunk:src/turn/actions/action_dispatcher_helpers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=88
scope.0.semanticHash=cb8a7ea97f2abd33
scope.1.id=function:helpers.should_invalidate_ui
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=3003b231b90363a6
scope.2.id=function:helpers.invalidate_ui_model
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=24
scope.2.semanticHash=ac69a862fa1decc8
scope.3.id=function:_blocked_gate
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=be8994585243633b
scope.4.id=function:_cancel_action
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=812996efe26ec454
scope.5.id=function:_market_buy_choice
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=36
scope.5.semanticHash=812996efe26ec454
scope.6.id=function:_same_choice
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=e407ead9f7ad0a60
scope.7.id=function:helpers.allows_market_cancel_while_blocked
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=54
scope.7.semanticHash=f5fe5bfb9bab1d94
scope.8.id=function:_pending_choice
scope.8.kind=function
scope.8.startLine=56
scope.8.endLine=58
scope.8.semanticHash=c250138038aa193a
scope.9.id=function:_choice_closed
scope.9.kind=function
scope.9.startLine=60
scope.9.endLine=62
scope.9.semanticHash=2e941eb77e4c698a
scope.10.id=function:helpers.clear_choice_if_closed
scope.10.kind=function
scope.10.startLine=64
scope.10.endLine=69
scope.10.semanticHash=793e1ec77170a6b2
scope.11.id=function:helpers.optional_completion_status
scope.11.kind=function
scope.11.startLine=71
scope.11.endLine=79
scope.11.semanticHash=0b7481247a30f2ef
scope.12.id=function:helpers.ensure_input_source
scope.12.kind=function
scope.12.startLine=81
scope.12.endLine=85
scope.12.semanticHash=0b122e2cd9deaf3e
]]
