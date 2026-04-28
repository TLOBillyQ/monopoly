local support = require("support.gameplay_support")
local _new_game = support.new_game
local item_preconsume_policy = require("src.core.choice.item_preconsume_policy")
local choice_handler_factory = require("src.rules.choice_handler_factory")
local validator = require("src.turn.actions.validator")
local availability = require("src.rules.items.availability")
local runtime_state = require("src.state.runtime_state")
local logger = require("src.core.utils.logger")

local _validate = validator._validate_item_slot_action
local _resolve = validator._resolve_item_slot_resolution

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
      use_item = function(_, _, item_id)
        assert(item_id == 2005, "item_phase_choice should forward selected item_id")
        return {
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
      use_item = function(_, _, item_id)
        assert(item_id == 2005, "item_phase_choice should forward selected item_id")
        return {
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

local function _test_validate_item_slot_action_valid_option_without_phase_returns_true()
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
end

local function _test_validate_item_slot_action_invalid_option_returns_false()
  local choice = {
    options = { { id = "item_123" } },
  }
  local action = { actor_role_id = 1 }

  local result = _validate({}, choice, action, "item_999")
  _crap_assert_eq(result, false, "invalid option returns false")
end

local function _test_validate_item_slot_action_availability_denied_returns_false()
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
end

local function _test_resolve_item_slot_resolution_invalid_action_returns_invalid_action()
  local result = _resolve({}, {}, { id = "something_else", actor_role_id = 1 }, {})
  _crap_assert_eq(result.ok, false, "invalid action should fail")
  _crap_assert_eq(result.reason, "invalid_action", "invalid action reason")
end

local function _test_resolve_item_slot_resolution_missing_choice_returns_missing_choice()
  _with_patched_dependencies({
    get_pending_choice = function()
      return nil
    end,
  }, function()
    local result = _resolve({}, {}, { id = "item_slot_1", actor_role_id = 1 }, { turn = {} })
    _crap_assert_eq(result.ok, false, "missing choice should fail")
    _crap_assert_eq(result.reason, "missing_choice", "missing choice reason")
  end)
end

local function _test_resolve_item_slot_resolution_missing_item_id_returns_missing_item_id()
  local pending_choice = {
    id = "choice_1",
    kind = "item_phase_choice",
    options = { { id = "item_123" } },
  }

  _with_patched_dependencies({
    get_pending_choice = function()
      return pending_choice
    end,
    warn = function() end,
  }, function()
    local result = _resolve({
      resolve_slot_action = function()
        return nil
      end,
    }, {}, {
      id = "item_slot_1",
      actor_role_id = 1,
      input_source = "user",
    }, {})

    _crap_assert_eq(result.ok, false, "missing item id should fail")
    _crap_assert_eq(result.reason, "missing_item_id", "missing item id reason")
  end)
end

local function _test_resolve_item_slot_resolution_success_returns_choice_select_action()
  local pending_choice = {
    id = "choice_1",
    kind = "item_phase_choice",
    options = { { id = "item_123" } },
  }

  _with_patched_dependencies({
    get_pending_choice = function()
      return pending_choice
    end,
  }, function()
    local action = {
      id = "item_slot_1",
      actor_role_id = 1,
      input_source = "user",
    }
    local result = _resolve({
      resolve_slot_action = function(actor_role_id, slot_id)
        _crap_assert_eq(actor_role_id, 1, "resolve_slot_action actor role id")
        _crap_assert_eq(slot_id, "item_slot_1", "resolve_slot_action slot id")
        return "item_123"
      end,
    }, {}, action, {})

    _crap_assert_eq(result.ok, true, "success should return ok")
    _crap_assert_eq(result.action.type, "choice_select", "resolved action type")
    _crap_assert_eq(result.action.choice_id, "choice_1", "resolved choice id")
    _crap_assert_eq(result.action.option_id, "item_123", "resolved option id")
    _crap_assert_eq(result.action.actor_role_id, 1, "resolved actor role id")
    _crap_assert_eq(result.action.input_source, "user", "resolved input source")
  end)
end

return {
  name = "choices_validation",
  tests = {
    { name = "_test_item_preconsume_each_option_iterates_without_return", run = _item_choice_handler_t2_tests[1] },
    { name = "_test_item_preconsume_each_option_stops_on_return", run = _item_choice_handler_t2_tests[2] },
    { name = "_test_item_preconsume_is_cancel_action_recognizes_choice_cancel", run = _item_choice_handler_t2_tests[3] },
    { name = "_test_item_preconsume_returns_nil_choice_spec_unchanged", run = _item_choice_handler_t2_tests[4] },
    { name = "_test_item_preconsume_marks_choice_spec_and_disables_cancel", run = _item_choice_handler_t2_tests[5] },
    { name = "_test_item_preconsume_preserves_existing_context_fields", run = _item_choice_handler_t2_tests[6] },
    { name = "_test_item_phase_choice_decorates_repeatable_followup_meta", run = _item_choice_handler_t2_tests[7] },
    { name = "_test_item_phase_choice_decorates_preconsumed_followup_meta", run = _item_choice_handler_t2_tests[8] },
    { name = "_validate_item_slot_action valid option and no phase returns true", run = _test_validate_item_slot_action_valid_option_without_phase_returns_true },
    { name = "_validate_item_slot_action invalid option returns false", run = _test_validate_item_slot_action_invalid_option_returns_false },
    { name = "_validate_item_slot_action availability denied returns false", run = _test_validate_item_slot_action_availability_denied_returns_false },
    { name = "_resolve_item_slot_resolution invalid action returns invalid_action", run = _test_resolve_item_slot_resolution_invalid_action_returns_invalid_action },
    { name = "_resolve_item_slot_resolution missing choice returns missing_choice", run = _test_resolve_item_slot_resolution_missing_choice_returns_missing_choice },
    { name = "_resolve_item_slot_resolution missing item id returns missing_item_id", run = _test_resolve_item_slot_resolution_missing_item_id_returns_missing_item_id },
    { name = "_resolve_item_slot_resolution success returns choice_select action", run = _test_resolve_item_slot_resolution_success_returns_choice_select_action },
  },
}
