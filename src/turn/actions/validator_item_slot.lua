local logger = require("src.foundation.log")
local item_slot_data = require("src.turn.actions.item_slot_data")
local runtime_state = require("src.state.runtime")
local item_phase = require("src.turn.actions.validator_item_phase")

local validator_item_slot = {}

local function _resolve_item_slot_source(item_slot_source)
  if type(item_slot_source) == "table" and type(item_slot_source.resolve_slot_action) == "function" then
    return item_slot_source
  end
  return item_slot_data.from_ui_state(item_slot_source)
end

local function _resolve_item_slot_id(source, actor_role_id, slot_id)
  if not source or type(source.resolve_slot_action) ~= "function" then
    return nil
  end
  return source.resolve_slot_action(actor_role_id, slot_id)
end

local function _resolve_runtime_game(state, game)
  return game or (state and state.game)
end

local function _resolve_pending_item_phase_choice(state, runtime_game)
  local choice = runtime_state.get_pending_choice(state)
  if (not choice) and runtime_game and runtime_game.turn then
    choice = runtime_game.turn.pending_choice
  end
  if not choice or (choice.kind ~= "item_phase_choice" and choice.kind ~= "item_phase_passive") then
    return nil
  end
  return choice
end

local function _resolve_selected_item_id(item_slot_source, action)
  local source = _resolve_item_slot_source(item_slot_source)
  local item_id = _resolve_item_slot_id(source, action.actor_role_id, action.id)
  if item_id then
    return item_id
  end
  logger.warn("missing item_id:", tostring(action.id))
  return nil
end

local function _build_choice_select_action(choice, action, item_id)
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = item_id,
    actor_role_id = action.actor_role_id,
    input_source = action.input_source,
  }
end

function validator_item_slot.resolve_item_slot_resolution(item_slot_source, state, action, game)
  if not (action and action.id and string.match(action.id, "^item_slot_(%d+)$")) then
    return {
      ok = false,
      reason = "invalid_action",
    }
  end

  local runtime_game = _resolve_runtime_game(state, game)
  local choice = _resolve_pending_item_phase_choice(state, runtime_game)
  if not choice then
    return {
      ok = false,
      reason = "missing_choice",
    }
  end

  local item_id = _resolve_selected_item_id(item_slot_source, action)
  if not item_id then
    return {
      ok = false,
      reason = "missing_item_id",
    }
  end

  if not item_phase.validate_item_phase_option(choice, item_id) then
    return {
      ok = false,
      reason = "invalid_item_option",
    }
  end

  if not item_phase.validate_item_phase_availability(runtime_game, choice, action.actor_role_id, item_id) then
    return {
      ok = false,
      reason = "item_slot_denied_by_availability",
    }
  end

  return {
    ok = true,
    action = _build_choice_select_action(choice, action, item_id),
  }
end

function validator_item_slot.resolve_item_slot_action(item_slot_source, state, action, game)
  local result = validator_item_slot.resolve_item_slot_resolution(item_slot_source, state, action, game)
  if result.reason == "invalid_action" then
    return nil
  end
  if not result.ok then
    return { ok = false }
  end
  return result
end

return validator_item_slot

--[[ mutate4lua-manifest
version=2
projectHash=b89114f31a9e0498
scope.0.id=chunk:src/turn/actions/validator_item_slot.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=114
scope.0.semanticHash=1110d3dfea8e559b
scope.1.id=function:_resolve_item_slot_source:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=5a55bfdc9e26817e
scope.2.id=function:_resolve_item_slot_id:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=20
scope.2.semanticHash=de006d868ae3e46a
scope.3.id=function:_resolve_runtime_game:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=24
scope.3.semanticHash=fafa1b815c071846
scope.4.id=function:_resolve_pending_item_phase_choice:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=35
scope.4.semanticHash=cb468093e4fc32b5
scope.5.id=function:_resolve_selected_item_id:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=45
scope.5.semanticHash=ddcf2c1456043f42
scope.6.id=function:_build_choice_select_action:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=55
scope.6.semanticHash=0a452e1aff283c8e
scope.7.id=function:validator_item_slot.resolve_item_slot_resolution:57
scope.7.kind=function
scope.7.startLine=57
scope.7.endLine=100
scope.7.semanticHash=037710c7ad8ca890
scope.8.id=function:validator_item_slot.resolve_item_slot_action:102
scope.8.kind=function
scope.8.startLine=102
scope.8.endLine=111
scope.8.semanticHash=d8b16a308afc920a
]]
