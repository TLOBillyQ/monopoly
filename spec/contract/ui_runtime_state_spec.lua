---@diagnostic disable: undefined-global, undefined-field, duplicate-set-field, unused-local, need-check-nil
local shared = require("tests.support.shared_support")

local runtime_state = require("src.state.runtime_state")
local output_port = require("src.turn.output.state_adapter")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local validator = require("src.turn.actions.validator")
local availability = require("src.rules.items.availability")

describe("ui_runtime_state_contract", function()
  local original_can_offer_in_phase

  before_each(function()
    original_can_offer_in_phase = availability.can_offer_in_phase
  end)

  after_each(function()
    availability.can_offer_in_phase = original_can_offer_in_phase
  end)

  it("runtime_state_defaults_to_runtime_only_structure", function()
    local state = {}

    local ui_runtime = runtime_state.ensure_ui_runtime(state)
    assert.equals(false, ui_runtime.ui_dirty, "ensure_ui_runtime should default dirty flag to false")
    assert.is_nil(runtime_state.get_ui_model(state), "get_ui_model should default to nil")
    assert.is_nil(runtime_state.get_pending_choice_id(state), "get_pending_choice_id should default to nil")
    assert.equals(0, runtime_state.get_pending_choice_elapsed(state), "get_pending_choice_elapsed should default to zero")
    assert.equals(0, runtime_state.get_modal_elapsed(state), "get_modal_elapsed should default to zero")
    assert.is_nil(runtime_state.get_modal_ref(state), "get_modal_ref should default to nil")

    state.ui_model = { marker = "legacy_model" }
    state.pending_choice = { id = 7, kind = "market_buy" }
    state.pending_choice_id = 7
    state.pending_choice_elapsed = 1.5
    state.ui_modal_elapsed = 2.25
    state.ui_modal_ref = "popup_1"

    assert.is_nil(runtime_state.get_ui_model(state), "legacy root ui_model should no longer seed ui_runtime")
    assert.is_nil(runtime_state.get_pending_choice_id(state), "legacy root pending choice id should no longer seed ui_runtime")
  end)

  it("output_port_uses_runtime_state_accessors", function()
    local state = {}
    local model = { screen = "choice" }
    local choice = { id = 11, kind = "item_phase_choice" }

    assert.is_true(output_port.invalidate_ui_model(state), "invalidate_ui_model should mark ui_runtime dirty")
    assert.is_true(runtime_state.is_ui_dirty(state), "invalidate_ui_model should write ui_runtime dirty flag")
    assert.is_nil(state.ui_dirty, "invalidate_ui_model should not write legacy ui_dirty directly")

    output_port.sync_ui_model(state, model)
    assert.equals(model, runtime_state.get_ui_model(state), "sync_ui_model should write ui_runtime model")
    assert.is_nil(state.ui_model, "sync_ui_model should not mirror into legacy state directly")

    output_port.sync_pending_choice(state, choice, { elapsed_seconds = 3.5 })
    assert.equals(choice, runtime_state.get_pending_choice(state), "sync_pending_choice should write ui_runtime choice")
    assert.equals(3.5, runtime_state.get_pending_choice_elapsed(state), "sync_pending_choice should write ui_runtime elapsed")
    assert.is_nil(state.pending_choice, "sync_pending_choice should not mirror into legacy state directly")

    output_port.sync_modal_timer(state, { ref = "popup_ref", elapsed_seconds = 2.0 })
    assert.equals("popup_ref", runtime_state.get_modal_ref(state), "sync_modal_timer should write ui_runtime ref")
    assert.equals(2.0, runtime_state.get_modal_elapsed(state), "sync_modal_timer should write ui_runtime elapsed")
    assert.is_nil(state.ui_modal_ref, "sync_modal_timer should not mirror into legacy state directly")
  end)

  it("tick_ui_sync_update_countdown_reads_ui_runtime", function()
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

    assert.equals(28, game.turn.countdown_seconds, "market choice countdown should use ui_runtime pending choice elapsed")
    assert.is_true(game.turn.countdown_active, "countdown should become active when ui_runtime has pending choice")
    assert.is_true(game.dirty.turn_countdown, "countdown change should mark turn_countdown dirty")
    assert.is_true(game.dirty.any, "countdown change should mark any dirty")
  end)

  it("validator_resolve_item_slot_action_reads_ui_runtime_choice", function()
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
        assert.equals(8, actor_role_id, "resolve_slot_action should receive actor role id")
        assert.equals("item_slot_1", slot_id, "resolve_slot_action should receive slot id")
        return 1001
      end,
    }

    local resolved = validator.resolve_item_slot_action(item_slot_source, state, action)
    assert.is_true(resolved.ok, "validator should resolve item slot action from ui_runtime pending choice")
    assert.equals(21, resolved.action.choice_id, "resolved action should keep pending choice id")
    assert.equals(1001, resolved.action.option_id, "resolved action should keep resolved item id")
  end)

  it("validator_resolve_item_slot_action_falls_back_to_turn_pending_choice", function()
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
        assert.equals(8, actor_role_id, "resolve_slot_action should receive actor role id")
        assert.equals("item_slot_1", slot_id, "resolve_slot_action should receive slot id")
        return 2005
      end,
    }

    local resolved = validator.resolve_item_slot_action(item_slot_source, state, action, game)
    assert.is_true(resolved.ok, "validator should fall back to turn pending choice when ui_runtime is stale")
    assert.equals(31, resolved.action.choice_id, "resolved action should keep turn pending choice id")
    assert.equals(2005, resolved.action.option_id, "resolved action should keep resolved item id")
  end)

  it("validator_resolve_item_slot_action_rejects_non_item_phase_choice", function()
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
    assert.is_false(resolved.ok, "validator should reject non item_phase pending choice")
  end)

  it("validator_accepts_item_phase_passive", function()
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
      resolve_slot_action = function()
        return 2005
      end,
    }

    local resolved = validator.resolve_item_slot_action(item_slot_source, state, {
      id = "item_slot_1",
      actor_role_id = 8,
    })
    assert.is_true(resolved.ok, "validator should accept item_phase_passive as valid pending choice kind")
    assert.equals(51, resolved.action.choice_id, "resolved action should keep pending choice id from item_phase_passive")
    assert.equals(2005, resolved.action.option_id, "resolved action should keep resolved item id")
  end)

  it("validator_resolve_item_slot_action_rejects_missing_slot_mapping", function()
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
    assert.is_false(resolved.ok, "validator should reject missing slot mapping")
  end)

  it("validator_resolve_item_slot_action_asserts_when_choice_options_are_missing", function()
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

    assert.is_false(ok, "validator should assert when choice.options is missing")
    assert.is_true(tostring(err):find("missing choice options", 1, true) ~= nil,
      "validator should report missing choice options")
  end)

  it("validator_resolve_item_slot_action_skips_availability_when_phase_is_blank", function()
    local calls = 0
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

    assert.is_true(ok, resolved)
    assert.equals(0, calls, "blank phase should skip availability recheck")
    assert.is_true(resolved.ok, "blank phase should still resolve a valid item slot action")
    assert.equals(1001, resolved.action.option_id, "blank phase should preserve resolved item id")
  end)

  it("validator_resolve_item_slot_action_rejects_invalid_option", function()
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

    assert.is_false(resolved.ok, "validator should reject slot ids that are not in choice options")
  end)

  it("validator_resolve_item_slot_resolution_reports_missing_slot_mapping", function()
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

    assert.is_false(result.ok, "intermediate result should fail when slot mapping is missing")
    assert.equals("missing_item_id", result.reason, "intermediate result should expose missing item id reason")
  end)

  it("validator_resolve_item_slot_resolution_reports_availability_denial", function()
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

    assert.equals(false, result.ok, "intermediate result should fail when availability denies the slot")
    assert.equals("item_slot_denied_by_availability", result.reason,
      "intermediate result should expose availability denial reason")
  end)
end)
