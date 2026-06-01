local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local item_slot_data = require("src.turn.actions.item_slot_data")
local turn_action_gate = require("src.turn.policies.action_gate")
local role_id_utils = require("src.foundation.identity")
local choice_contract = require("src.config.choice.contract")
local runtime_state = require("src.state.runtime")
local availability = require("src.rules.items.availability")

local validator = {}

local function _is_turn_bound_ui_button(action_id)
  return action_id == "next" or action_id and string.match(action_id, "^item_slot_(%d+)$") ~= nil
end

local function _resolve_current_player_role_id(game)
  local current = game and game.current_player and game:current_player() or nil
  return current and number_utils.to_integer(current.id) or nil
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return _resolve_current_player_role_id(game)
end

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

local function _choice_has_item_option(choice, item_id)
  local options = assert(choice.options, "missing choice options")
  for _, option in ipairs(options) do
    if (option.id or option) == item_id then
      return true
    end
  end
  return false
end

local function _validate_item_phase_option(choice, item_id)
  if _choice_has_item_option(choice, item_id) then
    return true
  end
  logger.warn("invalid item option:", tostring(item_id))
  return false
end

local function _resolve_item_phase_actor(runtime_game, actor_role_id)
  if not runtime_game or type(runtime_game.find_player_by_id) ~= "function" then
    return nil
  end
  return runtime_game:find_player_by_id(actor_role_id)
end

local function _validate_item_phase_availability(runtime_game, choice, actor_role_id, item_id)
  local actor = _resolve_item_phase_actor(runtime_game, actor_role_id)
  local phase = choice and choice.meta and choice.meta.phase or nil
  if not actor or type(phase) ~= "string" or phase == "" then
    return true
  end
  local can_offer = availability.can_offer_in_phase(runtime_game, actor, item_id, phase)
  if can_offer then
    return true
  end
  logger.warn("item slot denied by availability:", tostring(item_id), tostring(phase))
  return false
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

local function _validate_item_slot_action(runtime_game, choice, action, item_id)
  if not _validate_item_phase_option(choice, item_id) then
    return false
  end
  if not _validate_item_phase_availability(runtime_game, choice, action.actor_role_id, item_id) then
    return false
  end
  return true
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

local function _resolve_item_slot_resolution(item_slot_source, state, action, game)
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

  if not _validate_item_phase_option(choice, item_id) then
    return {
      ok = false,
      reason = "invalid_item_option",
    }
  end

  if not _validate_item_phase_availability(runtime_game, choice, action.actor_role_id, item_id) then
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

local function _resolve_ui_gate(state, ui_sync_ports)
  if ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" then
    return ui_sync_ports.resolve_ui_gate(state)
  end
  return nil
end

local function _extract_turn_state(state)
  if type(state) == "table" and state.game then
    return state.game.turn
  end
  return nil
end

function validator.resolve_gate_state(state, ui_sync_ports)
  local gate = turn_action_gate.resolve_gate_state(_resolve_ui_gate(state, ui_sync_ports))
  local turn = _extract_turn_state(state)
  return {
    input_blocked = gate.input_blocked == true,
    choice_active = gate.choice_active == true,
    market_active = gate.market_active == true,
    popup_active = gate.popup_active == true,
    phase = turn and turn.phase or nil,
    detained_wait_active = turn and turn.detained_wait_active == true or false,
  }
end

validator.should_block_action = turn_action_gate.should_block_action

function validator.validate_actor_role(game, action)
  if not _is_turn_bound_ui_button(action and action.id) then
    return true
  end
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local current_index = game.turn.current_player_index
  local current_player = current_index and game.players and game.players[current_index] or nil
  local current_role_id = role_id_utils.normalize(current_player and current_player.id or nil)
  local actor_role_id = role_id_utils.normalize(action.actor_role_id)
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action.id))
    return false
  end
  if current_role_id == nil then
    logger.warn("ui_button missing current_role_id:", tostring(action.id))
    return false
  end
  if not role_id_utils.equals(actor_role_id, current_role_id) then
    logger.warn(
      "ui_button blocked by actor check:",
      tostring(action.id),
      "actor_role_id=" .. tostring(actor_role_id),
      "current_role_id=" .. tostring(current_role_id)
    )
    return false
  end
  return true
end

function validator.validate_choice_actor(game, action, choice)
  local actor_role_id = role_id_utils.normalize(action and action.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("choice action missing actor_role_id:", tostring(action and action.type))
    return false
  end
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  if owner_role_id ~= nil and not role_id_utils.equals(actor_role_id, owner_role_id) then
    logger.warn(
      "choice action blocked by actor check:",
      tostring(action and action.type),
      "actor_role_id=" .. tostring(actor_role_id),
      "owner_role_id=" .. tostring(owner_role_id)
    )
    return false
  end
  return true
end

function validator.validate_choice_id(action, choice)
  if not action or not choice then
    return false
  end
  if not action.choice_id or action.choice_id ~= choice.id then
    logger.warn(
      "choice action mismatch:",
      tostring(action.type),
      "action_choice_id=" .. tostring(action.choice_id),
      "pending_choice_id=" .. tostring(choice.id)
    )
    return false
  end
  return true
end

function validator.validate_choice_action(game, action, choice)
  if not choice or not choice.id then
    logger.warn("choice action without pending choice:", tostring(action and action.type))
    return false
  end
  if not validator.validate_choice_actor(game, action, choice) then
    return false
  end
  return validator.validate_choice_id(action, choice)
end

function validator.resolve_item_slot_action(item_slot_source, state, action, game)
  local result = _resolve_item_slot_resolution(item_slot_source, state, action, game)
  if result.reason == "invalid_action" then
    return nil
  end
  if not result.ok then
    return { ok = false }
  end
  return result
end

validator._resolve_item_slot_resolution = _resolve_item_slot_resolution
validator._validate_item_slot_action = _validate_item_slot_action

return validator

--[[ mutate4lua-manifest
version=2
projectHash=1e3893c081c5a9ba
scope.0.id=chunk:src/turn/actions/validator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=291
scope.0.semanticHash=6e0a93de0b68c7fc
scope.0.lastMutatedAt=2026-06-01T12:35:55Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=14
scope.0.lastMutationKilled=14
scope.1.id=function:_is_turn_bound_ui_button:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=5fa9abe5a74cb137
scope.1.lastMutatedAt=2026-06-01T12:35:55Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_resolve_current_player_role_id:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=19
scope.2.semanticHash=09250e687842076d
scope.2.lastMutatedAt=2026-06-01T12:35:55Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_resolve_choice_owner_role_id:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=27
scope.3.semanticHash=77559ad9d6b68d87
scope.3.lastMutatedAt=2026-06-01T12:35:55Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_resolve_item_slot_source:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=34
scope.4.semanticHash=5a55bfdc9e26817e
scope.4.lastMutatedAt=2026-06-01T12:35:55Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=8
scope.4.lastMutationKilled=8
scope.5.id=function:_resolve_item_slot_id:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=41
scope.5.semanticHash=de006d868ae3e46a
scope.5.lastMutatedAt=2026-06-01T12:35:55Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=5
scope.6.id=function:_resolve_runtime_game:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=45
scope.6.semanticHash=fafa1b815c071846
scope.6.lastMutatedAt=2026-06-01T12:35:55Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=1
scope.7.id=function:_resolve_pending_item_phase_choice:47
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=56
scope.7.semanticHash=cb468093e4fc32b5
scope.7.lastMutatedAt=2026-06-01T12:35:55Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=11
scope.7.lastMutationKilled=11
scope.8.id=function:_validate_item_phase_option:68
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=74
scope.8.semanticHash=174317088426505c
scope.8.lastMutatedAt=2026-06-01T12:35:55Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:_resolve_item_phase_actor:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=81
scope.9.semanticHash=957b90940ed474b7
scope.9.lastMutatedAt=2026-06-01T12:35:55Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=6
scope.9.lastMutationKilled=6
scope.10.id=function:_validate_item_phase_availability:83
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=95
scope.10.semanticHash=ff9c622ecadcf202
scope.10.lastMutatedAt=2026-06-01T12:35:55Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=17
scope.10.lastMutationKilled=17
scope.11.id=function:_resolve_selected_item_id:97
scope.11.kind=function
scope.11.startLine=97
scope.11.endLine=105
scope.11.semanticHash=ddcf2c1456043f42
scope.11.lastMutatedAt=2026-06-01T12:35:55Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=3
scope.11.lastMutationKilled=3
scope.12.id=function:_validate_item_slot_action:107
scope.12.kind=function
scope.12.startLine=107
scope.12.endLine=115
scope.12.semanticHash=e565edd4818bf014
scope.12.lastMutatedAt=2026-06-01T12:35:55Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=7
scope.12.lastMutationKilled=7
scope.13.id=function:_build_choice_select_action:117
scope.13.kind=function
scope.13.startLine=117
scope.13.endLine=125
scope.13.semanticHash=0a452e1aff283c8e
scope.13.lastMutatedAt=2026-06-01T12:35:55Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:_resolve_item_slot_resolution:127
scope.14.kind=function
scope.14.startLine=127
scope.14.endLine=170
scope.14.semanticHash=c84f72fc08072be2
scope.14.lastMutatedAt=2026-06-01T12:35:55Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=25
scope.14.lastMutationKilled=25
scope.15.id=function:_resolve_ui_gate:172
scope.15.kind=function
scope.15.startLine=172
scope.15.endLine=177
scope.15.semanticHash=a58d42ec64d1e93c
scope.15.lastMutatedAt=2026-06-01T12:35:55Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=5
scope.15.lastMutationKilled=5
scope.16.id=function:_extract_turn_state:179
scope.16.kind=function
scope.16.startLine=179
scope.16.endLine=184
scope.16.semanticHash=7a4dc08f584b619e
scope.16.lastMutatedAt=2026-06-01T12:35:55Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=4
scope.16.lastMutationKilled=4
scope.17.id=function:validator.resolve_gate_state:186
scope.17.kind=function
scope.17.startLine=186
scope.17.endLine=197
scope.17.semanticHash=adfbe8b615af7617
scope.17.lastMutatedAt=2026-06-01T12:35:55Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=17
scope.17.lastMutationKilled=17
scope.18.id=function:validator.validate_actor_role:201
scope.18.kind=function
scope.18.startLine=201
scope.18.endLine=228
scope.18.semanticHash=646a07f4bfcffd1c
scope.18.lastMutatedAt=2026-06-01T12:35:55Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=20
scope.18.lastMutationKilled=20
scope.19.id=function:validator.validate_choice_actor:230
scope.19.kind=function
scope.19.startLine=230
scope.19.endLine=247
scope.19.semanticHash=47e44acee3c25f96
scope.19.lastMutatedAt=2026-06-01T12:35:55Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=12
scope.19.lastMutationKilled=12
scope.20.id=function:validator.validate_choice_id:249
scope.20.kind=function
scope.20.startLine=249
scope.20.endLine=263
scope.20.semanticHash=c5ad6b1a019ea024
scope.20.lastMutatedAt=2026-06-01T12:35:55Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=10
scope.20.lastMutationKilled=10
scope.21.id=function:validator.validate_choice_action:265
scope.21.kind=function
scope.21.startLine=265
scope.21.endLine=274
scope.21.semanticHash=91832ece5e1b03f4
scope.21.lastMutatedAt=2026-06-01T12:35:55Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=9
scope.21.lastMutationKilled=9
scope.22.id=function:validator.resolve_item_slot_action:276
scope.22.kind=function
scope.22.startLine=276
scope.22.endLine=285
scope.22.semanticHash=182c79412ebb4001
scope.22.lastMutatedAt=2026-06-01T12:35:55Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=5
scope.22.lastMutationKilled=5
]]
