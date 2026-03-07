local support = require("TestSupport")
local _assert_eq = support.assert_eq

local runtime_state = require("src.core.state_access.runtime_state")
local output_port = require("src.game.flow.output_adapters.use_case_output_port")
local tick_ui_sync = require("src.game.flow.turn.tick_ui_sync")
local validator = require("src.game.flow.turn.turn_dispatch_validator")

local function _test_runtime_state_defaults_to_runtime_only_structure()
  local state = {}

  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  _assert_eq(ui_runtime.ui_dirty, false, "ensure_ui_runtime should default dirty flag to false")
  _assert_eq(runtime_state.get_ui_model(state), nil, "get_ui_model should default to nil")
  _assert_eq(runtime_state.get_pending_choice_id(state), nil, "get_pending_choice_id should default to nil")
  _assert_eq(runtime_state.get_pending_choice_elapsed(state), 0, "get_pending_choice_elapsed should default to zero")
  _assert_eq(runtime_state.get_modal_elapsed(state), 0, "get_modal_elapsed should default to zero")
  _assert_eq(runtime_state.get_modal_ref(state), nil, "get_modal_ref should default to nil")

  state.ui_model = { marker = "legacy_model" }
  state.pending_choice = { id = 7, kind = "market_buy" }
  state.pending_choice_id = 7
  state.pending_choice_elapsed = 1.5
  state.ui_modal_elapsed = 2.25
  state.ui_modal_ref = "popup_1"

  _assert_eq(runtime_state.get_ui_model(state), nil,
    "legacy root ui_model should no longer seed ui_runtime")
  _assert_eq(runtime_state.get_pending_choice_id(state), nil,
    "legacy root pending choice id should no longer seed ui_runtime")
end

local function _test_output_port_uses_runtime_state_accessors()
  local state = {}
  local model = { screen = "choice" }
  local choice = { id = 11, kind = "item_phase_choice" }

  _assert_eq(output_port.invalidate_ui(state), true, "invalidate_ui should mark ui_runtime dirty")
  _assert_eq(runtime_state.is_ui_dirty(state), true, "invalidate_ui should write ui_runtime dirty flag")
  _assert_eq(state.ui_dirty, nil, "invalidate_ui should not write legacy ui_dirty directly")

  output_port.sync_ui_model(state, model)
  _assert_eq(runtime_state.get_ui_model(state), model, "sync_ui_model should write ui_runtime model")
  _assert_eq(state.ui_model, nil, "sync_ui_model should not mirror into legacy state directly")

  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 3.5 })
  _assert_eq(runtime_state.get_pending_choice(state), choice, "sync_pending_choice should write ui_runtime choice")
  _assert_eq(runtime_state.get_pending_choice_elapsed(state), 3.5,
    "sync_pending_choice should write ui_runtime elapsed")
  _assert_eq(state.pending_choice, nil, "sync_pending_choice should not mirror into legacy state directly")

  output_port.sync_modal_timer(state, { ref = "popup_ref", elapsed_seconds = 2.0 })
  _assert_eq(runtime_state.get_modal_ref(state), "popup_ref", "sync_modal_timer should write ui_runtime ref")
  _assert_eq(runtime_state.get_modal_elapsed(state), 2.0, "sync_modal_timer should write ui_runtime elapsed")
  _assert_eq(state.ui_modal_ref, nil, "sync_modal_timer should not mirror into legacy state directly")
end

local function _test_tick_ui_sync_update_countdown_reads_ui_runtime()
  local game = {
    turn = {
      detained_wait_active = false,
      countdown_seconds = 0,
      countdown_active = false,
    },
    dirty = {},
  }
  local state = {
    countdown_last = nil,
    countdown_active_last = nil,
    ui_runtime = {
      pending_choice = { id = 3, kind = "market_buy" },
      pending_choice_elapsed = 2.0,
    },
  }

  tick_ui_sync.update_countdown(game, state)

  _assert_eq(game.turn.countdown_seconds, 28, "market choice countdown should use ui_runtime pending choice elapsed")
  _assert_eq(game.turn.countdown_active, true, "countdown should become active when ui_runtime has pending choice")
  _assert_eq(game.dirty.turn_countdown, true, "countdown change should mark turn_countdown dirty")
  _assert_eq(game.dirty.any, true, "countdown change should mark any dirty")
end

local function _test_validator_resolve_item_slot_action_reads_ui_runtime_choice()
  local state = {
    ui_runtime = {
      pending_choice = {
        id = 21,
        kind = "item_phase_choice",
        options = {
          { id = 1001 },
        },
      },
    },
  }
  local action = {
    id = "item_slot_1",
    actor_role_id = 8,
    input_source = "user",
  }
  local item_slot_source = {
    resolve_slot_action = function(actor_role_id, slot_id)
      _assert_eq(actor_role_id, 8, "resolve_slot_action should receive actor role id")
      _assert_eq(slot_id, "item_slot_1", "resolve_slot_action should receive slot id")
      return 1001
    end,
  }

  local resolved = validator.resolve_item_slot_action(item_slot_source, state, action)
  _assert_eq(resolved.ok, true, "validator should resolve item slot action from ui_runtime pending choice")
  _assert_eq(resolved.action.choice_id, 21, "resolved action should keep pending choice id")
  _assert_eq(resolved.action.option_id, 1001, "resolved action should keep resolved item id")
end

return {
  name = "ui_runtime_state_contract",
  tests = {
    {
      name = "runtime_state_defaults_to_runtime_only_structure",
      run = _test_runtime_state_defaults_to_runtime_only_structure,
    },
    {
      name = "output_port_uses_runtime_state_accessors",
      run = _test_output_port_uses_runtime_state_accessors,
    },
    {
      name = "tick_ui_sync_update_countdown_reads_ui_runtime",
      run = _test_tick_ui_sync_update_countdown_reads_ui_runtime,
    },
    {
      name = "validator_resolve_item_slot_action_reads_ui_runtime_choice",
      run = _test_validator_resolve_item_slot_action_reads_ui_runtime_choice,
    },
  },
}
