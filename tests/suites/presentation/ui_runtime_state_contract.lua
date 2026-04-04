local support = require("support.presentation_support")
local _assert_eq = support.assert_eq

local runtime_state = require("src.state.state_access.runtime_state")
local output_port = require("src.turn.output.state_adapter")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local validator = require("src.turn.actions.validator")
local availability = require("src.rules.items.availability")

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

  _assert_eq(output_port.invalidate_ui_model(state), true, "invalidate_ui_model should mark ui_runtime dirty")
  _assert_eq(runtime_state.is_ui_dirty(state), true, "invalidate_ui_model should write ui_runtime dirty flag")
  _assert_eq(state.ui_dirty, nil, "invalidate_ui_model should not write legacy ui_dirty directly")

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

local function _test_validator_resolve_item_slot_action_falls_back_to_turn_pending_choice()
  local state = {
    ui_runtime = {
      pending_choice = nil,
    },
  }
  local game = {
    turn = {
      pending_choice = {
        id = 31,
        kind = "item_phase_choice",
        options = {
          { id = 2005 },
        },
        meta = {
          phase = "post_action",
        },
      },
    },
    find_player_by_id = function()
      return nil
    end,
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
      return 2005
    end,
  }

  local resolved = validator.resolve_item_slot_action(item_slot_source, state, action, game)
  _assert_eq(resolved.ok, true, "validator should fall back to turn pending choice when ui_runtime is stale")
  _assert_eq(resolved.action.choice_id, 31, "resolved action should keep turn pending choice id")
  _assert_eq(resolved.action.option_id, 2005, "resolved action should keep resolved item id")
end

local function _test_validator_resolve_item_slot_action_rejects_non_item_phase_choice()
  local state = {
    ui_runtime = {
      pending_choice = {
        id = 41,
        kind = "market_buy",
        options = {
          { id = 1001 },
        },
      },
    },
  }

  local resolved = validator.resolve_item_slot_action({}, state, {
    id = "item_slot_1",
    actor_role_id = 8,
  })
  _assert_eq(resolved.ok, false, "validator should reject non item_phase pending choice")
end

local function _test_validator_resolve_item_slot_action_rejects_missing_slot_mapping()
  local state = {
    ui_runtime = {
      pending_choice = {
        id = 51,
        kind = "item_phase_choice",
        options = {
          { id = 1001 },
        },
      },
    },
  }

  local resolved = validator.resolve_item_slot_action({}, state, {
    id = "item_slot_1",
    actor_role_id = 8,
  })
  _assert_eq(resolved.ok, false, "validator should reject missing slot mapping")
end

local function _test_validator_resolve_item_slot_action_asserts_when_choice_options_are_missing()
  local ok, err = pcall(function()
    validator.resolve_item_slot_action({
      resolve_slot_action = function()
        return 1001
      end,
    }, {
      ui_runtime = {
        pending_choice = {
          id = 61,
          kind = "item_phase_choice",
        },
      },
    }, {
      id = "item_slot_1",
      actor_role_id = 8,
    })
  end)

  _assert_eq(ok, false, "validator should assert when choice.options is missing")
  assert(tostring(err):find("missing choice options", 1, true) ~= nil,
    "validator should report missing choice options")
end

local function _test_validator_resolve_item_slot_action_skips_availability_when_phase_is_blank()
  local calls = 0
  local original_can_offer = availability.can_offer_in_phase
  availability.can_offer_in_phase = function()
    calls = calls + 1
    return false
  end

  local ok, resolved = pcall(function()
    return validator.resolve_item_slot_action({
      resolve_slot_action = function()
        return 1001
      end,
    }, {
      ui_runtime = {
        pending_choice = {
          id = 71,
          kind = "item_phase_choice",
          options = {
            { id = 1001 },
          },
          meta = {
            phase = "",
          },
        },
      },
      game = {
        find_player_by_id = function()
          return { id = 8 }
        end,
      },
    }, {
      id = "item_slot_1",
      actor_role_id = 8,
      input_source = "user",
    })
  end)

  availability.can_offer_in_phase = original_can_offer

  assert(ok, resolved)
  _assert_eq(calls, 0, "blank phase should skip availability recheck")
  _assert_eq(resolved.ok, true, "blank phase should still resolve a valid item slot action")
  _assert_eq(resolved.action.option_id, 1001, "blank phase should preserve resolved item id")
end

local function _test_validator_resolve_item_slot_action_rejects_invalid_option()
  local resolved = validator.resolve_item_slot_action({
    resolve_slot_action = function()
      return 9999
    end,
  }, {
    ui_runtime = {
      pending_choice = {
        id = 81,
        kind = "item_phase_choice",
        options = {
          { id = 1001 },
        },
      },
    },
  }, {
    id = "item_slot_1",
    actor_role_id = 8,
  })

  _assert_eq(resolved.ok, false, "validator should reject slot ids that are not in choice options")
end

local function _test_validator_resolve_item_slot_resolution_reports_missing_slot_mapping()
  local result = validator._resolve_item_slot_resolution({
    resolve_slot_action = function()
      return nil
    end,
  }, {
    ui_runtime = {
      pending_choice = {
        id = 91,
        kind = "item_phase_choice",
        options = {
          { id = 1001 },
        },
      },
    },
  }, {
    id = "item_slot_1",
    actor_role_id = 8,
  })

  _assert_eq(result.ok, false, "intermediate result should fail when slot mapping is missing")
  _assert_eq(result.reason, "missing_item_id", "intermediate result should expose missing item id reason")
end

local function _test_validator_resolve_item_slot_resolution_reports_availability_denial()
  local original_can_offer = availability.can_offer_in_phase
  availability.can_offer_in_phase = function()
    return false, "special_condition_failed"
  end

  local result = validator._resolve_item_slot_resolution({
    resolve_slot_action = function()
      return 1001
    end,
  }, {
    ui_runtime = {
      pending_choice = {
        id = 92,
        kind = "item_phase_choice",
        options = {
          { id = 1001 },
        },
        meta = {
          phase = "post_action",
        },
      },
    },
    game = {
      find_player_by_id = function()
        return { id = 8 }
      end,
    },
  }, {
    id = "item_slot_1",
    actor_role_id = 8,
    input_source = "user",
  })

  availability.can_offer_in_phase = original_can_offer

  _assert_eq(result.ok, false, "intermediate result should fail when availability denies the slot")
  _assert_eq(result.reason, "item_slot_denied_by_availability",
    "intermediate result should expose availability denial reason")
end

local function _test_validator_accepts_item_phase_passive()
  local state = {
    ui_runtime = {
      pending_choice = {
        id = 51,
        kind = "item_phase_passive",
        options = {
          { id = 2005 },
        },
        meta = {
          phase = "post_action",
        },
      },
    },
  }
  local item_slot_source = {
    resolve_slot_action = function(actor_role_id, slot_id)
      return 2005
    end,
  }

  local resolved = validator.resolve_item_slot_action(item_slot_source, state, {
    id = "item_slot_1",
    actor_role_id = 8,
  })
  _assert_eq(resolved.ok, true, "validator should accept item_phase_passive as valid pending choice kind")
  _assert_eq(resolved.action.choice_id, 51, "resolved action should keep pending choice id from item_phase_passive")
  _assert_eq(resolved.action.option_id, 2005, "resolved action should keep resolved item id")
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
    {
      name = "validator_resolve_item_slot_action_falls_back_to_turn_pending_choice",
      run = _test_validator_resolve_item_slot_action_falls_back_to_turn_pending_choice,
    },
    {
      name = "validator_resolve_item_slot_action_rejects_non_item_phase_choice",
      run = _test_validator_resolve_item_slot_action_rejects_non_item_phase_choice,
    },
    {
      name = "validator_accepts_item_phase_passive",
      run = _test_validator_accepts_item_phase_passive,
    },
    {
      name = "validator_resolve_item_slot_action_rejects_missing_slot_mapping",
      run = _test_validator_resolve_item_slot_action_rejects_missing_slot_mapping,
    },
    {
      name = "validator_resolve_item_slot_action_asserts_when_choice_options_are_missing",
      run = _test_validator_resolve_item_slot_action_asserts_when_choice_options_are_missing,
    },
    {
      name = "validator_resolve_item_slot_action_skips_availability_when_phase_is_blank",
      run = _test_validator_resolve_item_slot_action_skips_availability_when_phase_is_blank,
    },
    {
      name = "validator_resolve_item_slot_action_rejects_invalid_option",
      run = _test_validator_resolve_item_slot_action_rejects_invalid_option,
    },
    {
      name = "validator_resolve_item_slot_resolution_reports_missing_slot_mapping",
      run = _test_validator_resolve_item_slot_resolution_reports_missing_slot_mapping,
    },
    {
      name = "validator_resolve_item_slot_resolution_reports_availability_denial",
      run = _test_validator_resolve_item_slot_resolution_reports_availability_denial,
    },
  },
}
