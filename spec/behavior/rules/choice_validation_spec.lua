local support = require("spec.support.shared_support")
local _new_game = support.new_game
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local choice_handler_factory = require("src.rules.choice_handlers.factory")
local validator = require("src.turn.actions.validator")
local availability = require("src.rules.items.availability")
local runtime_state = require("src.state.runtime")
local logger = require("src.foundation.log")

local _validate = validator._validate_item_slot_action

local _item_choice_handler_t2_tests = {
  function()
    local seen = {}
    local result = item_preconsume_policy.each_option({
      options = {
        { id = "opt1", label = "A" },
        "opt2",
        { label = "ignored" },
      },
    }, function(option, option_id, index)
      seen[#seen + 1] = {
        option = option,
        option_id = option_id,
        index = index,
      }
    end)
    assert(result == nil, "each_option should return nil when the visitor never stops iteration")
    assert(seen[1].option_id == "opt1", "each_option should expose the first table option id")
    assert(seen[2].option_id == "opt2", "each_option should expose string options directly")
    assert(seen[3].option_id == seen[3].option, "each_option should fall back to the raw option when id is missing")
  end,
  function()
    local seen = {}
    local result = item_preconsume_policy.each_option({
      options = {
        { id = "opt1" },
        "opt2",
        { id = "opt3" },
      },
    }, function(option, option_id, index)
      seen[#seen + 1] = {
        option = option,
        option_id = option_id,
        index = index,
      }
      if index == 2 then
        return option_id
      end
    end)
    assert(result == "opt2", "each_option should stop when the visitor returns a value")
    assert(#seen == 2, "each_option should stop visiting after a non-nil return")
  end,
  function()
    assert(item_preconsume_policy.is_cancel_action({ type = "choice_cancel" }) == true,
      "is_cancel_action should accept choice_cancel")
    assert(item_preconsume_policy.is_cancel_action({ type = "choice_select" }) == false,
      "is_cancel_action should reject non-cancel actions")
    assert(item_preconsume_policy.is_cancel_action(nil) == false,
      "is_cancel_action should reject nil actions")
  end,
  function()
    local decorated = item_preconsume_policy.decorate_followup_choice_spec(nil, {
      item_id = 2005,
      player_id = 7,
    })
    assert(decorated == nil, "decorate_followup_choice_spec should return nil choice_spec unchanged")
  end,
  function()
    local choice_spec = {
      allow_cancel = true,
      cancel_label = "返回",
    }
    local decorated = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, nil)
    assert(decorated == choice_spec, "decorate_followup_choice_spec should mutate and return the original choice_spec")
    assert(choice_spec.allow_cancel == false, "decorate_followup_choice_spec should disable cancel")
    assert(choice_spec.cancel_label == nil, "decorate_followup_choice_spec should clear cancel label")
    assert(choice_spec.meta.item_preconsumed == true, "decorate_followup_choice_spec should mark item_preconsumed")
  end,
  function()
    local choice_spec = {
      allow_cancel = true,
      cancel_label = "返回",
    }
    local meta = item_preconsume_policy.ensure_followup_meta(choice_spec)
    assert(meta == choice_spec.meta, "ensure_followup_meta should return the choice meta table")
    assert(meta.item_preconsumed == true, "ensure_followup_meta should mark item_preconsumed")

    item_preconsume_policy.disable_followup_cancel(choice_spec)
    assert(choice_spec.allow_cancel == false, "disable_followup_cancel should disable cancel")
    assert(choice_spec.cancel_label == nil, "disable_followup_cancel should clear cancel label")

    item_preconsume_policy.merge_preconsume_context(meta, {
      item_id = 2005,
      player_id = 7,
    })
    assert(meta.item_id == 2005, "merge_preconsume_context should backfill item_id")
    assert(meta.player_id == 7, "merge_preconsume_context should backfill player_id")

    item_preconsume_policy.merge_preconsume_context(meta, {
      item_id = 9001,
      player_id = 77,
    })
    assert(meta.item_id == 2005, "merge_preconsume_context should not overwrite item_id")
    assert(meta.player_id == 7, "merge_preconsume_context should not overwrite player_id")
  end,
  function()
    local choice_spec = {
      meta = {
        item_id = 9001,
        player_id = 77,
      },
    }
    item_preconsume_policy.decorate_followup_choice_spec(choice_spec, {
      item_id = 2005,
      player_id = 7,
    })
    assert(choice_spec.meta.item_preconsumed == true, "decorate_followup_choice_spec should keep preconsumed marker")
    assert(choice_spec.meta.item_id == 9001, "decorate_followup_choice_spec should not overwrite existing item_id")
    assert(choice_spec.meta.player_id == 77, "decorate_followup_choice_spec should not overwrite existing player_id")
  end,
  function()
    local game = _new_game()
    local player = game.players[1]
    local captured_choice_spec = nil
    player.inventory:add({ id = 2005 })
    local handlers = choice_handler_factory.build_item_handlers({
      finish_choice = function(_, stay)
        return { stay = stay == true }
      end,
      finish_active_item_phase = function() end,
      begin_item_use = function(_, _, item_id)
        assert(item_id == 2005, "item_phase_choice should forward selected item_id")
        return {
          ok = true,
          waiting = true,
          intent = {
            choice_spec = {
              kind = "remote_dice_value",
              allow_cancel = false,
              cancel_label = "old",
              meta = {
                player_id = 999,
              },
            },
          },
        }
      end,
    })
    local original_dispatch = require("src.rules.ports.intent_output").dispatch
    require("src.rules.ports.intent_output").dispatch = function(_, intent)
      captured_choice_spec = intent and intent.choice_spec or nil
      return true
    end

    local ok, result = pcall(function()
      return handlers.item_phase_choice.execute(game, {
        kind = "item_phase_choice",
        meta = {
          player_id = player.id,
          phase = "pre_action",
          resume_next_state = "roll",
          resume_next_args = { player_id = player.id },
        },
      }, {
        option_id = 2005,
      })
    end)

    require("src.rules.ports.intent_output").dispatch = original_dispatch

    assert(ok, result)
    assert(result and result.stay == true, "repeatable item phase should keep waiting when followup choice opens")
    assert(captured_choice_spec ~= nil, "repeatable item phase should dispatch followup choice")
    assert(captured_choice_spec.allow_cancel == true, "repeatable followup should stay cancelable")
    assert(captured_choice_spec.cancel_label == "old", "repeatable followup should preserve existing cancel label")
    assert(captured_choice_spec.meta.phase == "pre_action", "repeatable followup should preserve phase meta")
    assert(captured_choice_spec.meta.item_id == 2005, "repeatable followup should attach selected item_id")
    assert(captured_choice_spec.meta.player_id == 999, "repeatable followup should not overwrite existing player_id")
  end,
  function()
    local game = _new_game()
    local player = game.players[1]
    local captured_choice_spec = nil
    player.inventory:add({ id = 2005 })
    local handlers = choice_handler_factory.build_item_handlers({
      finish_choice = function(_, stay)
        return { stay = stay == true }
      end,
      finish_active_item_phase = function() end,
      begin_item_use = function(_, _, item_id)
        assert(item_id == 2005, "item_phase_choice should forward selected item_id")
        return {
          ok = true,
          waiting = true,
          intent = {
            choice_spec = {
              kind = "remote_dice_value",
              allow_cancel = true,
              cancel_label = "返回",
              meta = {
                item_id = 7001,
                player_id = 88,
              },
            },
          },
        }
      end,
    })
    local intent_output_port = require("src.rules.ports.intent_output")
    local original_dispatch = intent_output_port.dispatch
    intent_output_port.dispatch = function(_, intent)
      captured_choice_spec = intent and intent.choice_spec or nil
      return true
    end

    local ok, result = pcall(function()
      return handlers.item_phase_choice.execute(game, {
        kind = "item_phase_choice",
        meta = {
          player_id = player.id,
          phase = "landing",
        },
      }, {
        option_id = 2005,
      })
    end)

    intent_output_port.dispatch = original_dispatch

    assert(ok, result)
    assert(result and result.stay == true, "non-repeatable item phase should keep waiting when followup choice opens")
    assert(captured_choice_spec ~= nil, "non-repeatable item phase should dispatch followup choice")
    assert(captured_choice_spec.allow_cancel == false, "preconsumed followup should disable cancel")
    assert(captured_choice_spec.cancel_label == nil, "preconsumed followup should clear cancel label")
    assert(captured_choice_spec.meta.item_preconsumed == true, "preconsumed followup should mark consumed state")
    assert(captured_choice_spec.meta.item_id == 7001, "preconsumed followup should preserve existing item_id")
    assert(captured_choice_spec.meta.player_id == 88, "preconsumed followup should preserve existing player_id")
  end,
}

local function _crap_assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _with_patched_dependencies(overrides, fn)
  local orig_warn = logger.warn
  local orig_can_offer = availability.can_offer_in_phase
  local orig_get_pending = runtime_state.get_pending_choice

  logger.warn = overrides.warn or orig_warn
  availability.can_offer_in_phase = overrides.can_offer_in_phase or orig_can_offer
  runtime_state.get_pending_choice = overrides.get_pending_choice or orig_get_pending

  local ok, result = pcall(fn)

  logger.warn = orig_warn
  availability.can_offer_in_phase = orig_can_offer
  runtime_state.get_pending_choice = orig_get_pending

  if not ok then
    error(result, 2)
  end
  return result
end

describe("choices_validation", function()
  it("_test_item_preconsume_each_option_iterates_without_return", _item_choice_handler_t2_tests[1])

  it("_test_item_preconsume_each_option_stops_on_return", _item_choice_handler_t2_tests[2])

  it("_test_item_preconsume_is_cancel_action_recognizes_choice_cancel", _item_choice_handler_t2_tests[3])

  it("_test_item_preconsume_returns_nil_choice_spec_unchanged", _item_choice_handler_t2_tests[4])

  it("_test_item_preconsume_marks_choice_spec_and_disables_cancel", _item_choice_handler_t2_tests[5])

  it("_test_item_preconsume_preserves_existing_context_fields", _item_choice_handler_t2_tests[6])

  it("_test_item_phase_choice_decorates_repeatable_followup_meta", _item_choice_handler_t2_tests[7])

  it("_test_item_phase_choice_decorates_preconsumed_followup_meta", _item_choice_handler_t2_tests[8])

  it("_validate_item_slot_action valid option and no phase returns true", function()
    local choice = {
      options = { { id = "item_123" } },
      meta = {},
    }
    local action = { actor_role_id = 1 }
    local runtime_game = {
      find_player_by_id = function()
        return nil
      end,
    }

    local result = _validate(runtime_game, choice, action, "item_123")
    _crap_assert_eq(result, true, "valid option without phase returns true")
  end)

  it("_validate_item_slot_action invalid option returns false", function()
    local choice = {
      options = { { id = "item_123" } },
    }
    local action = { actor_role_id = 1 }

    local result = _validate({}, choice, action, "item_999")
    _crap_assert_eq(result, false, "invalid option returns false")
  end)

  it("_validate_item_slot_action availability denied returns false", function()
    _with_patched_dependencies({
      warn = function() end,
      can_offer_in_phase = function(_, actor, item_id, phase)
        _crap_assert_eq(actor.id, 1, "availability receives resolved actor")
        _crap_assert_eq(item_id, "item_123", "availability receives selected item")
        _crap_assert_eq(phase, "pre_move", "availability receives phase")
        return false
      end,
    }, function()
      local choice = {
        options = { { id = "item_123" } },
        meta = { phase = "pre_move" },
      }
      local action = { actor_role_id = 1 }
      local runtime_game = {
        find_player_by_id = function()
          return { id = 1 }
        end,
      }

      local result = _validate(runtime_game, choice, action, "item_123")
      _crap_assert_eq(result, false, "availability denial returns false")
    end)
  end)

end)
