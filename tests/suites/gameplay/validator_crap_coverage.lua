local validator = require("src.turn.actions.validator")
local availability = require("src.rules.items.availability")
local runtime_state = require("src.state.runtime_state")
local logger = require("src.core.utils.logger")

local _validate = validator._validate_item_slot_action
local _resolve = validator._resolve_item_slot_resolution

local function _assert_eq(a, b, msg)
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
  _assert_eq(result, true, "valid option without phase returns true")
end

local function _test_validate_item_slot_action_invalid_option_returns_false()
  local choice = {
    options = { { id = "item_123" } },
  }
  local action = { actor_role_id = 1 }

  local result = _validate({}, choice, action, "item_999")
  _assert_eq(result, false, "invalid option returns false")
end

local function _test_validate_item_slot_action_availability_denied_returns_false()
  _with_patched_dependencies({
    warn = function() end,
    can_offer_in_phase = function(_, actor, item_id, phase)
      _assert_eq(actor.id, 1, "availability receives resolved actor")
      _assert_eq(item_id, "item_123", "availability receives selected item")
      _assert_eq(phase, "pre_move", "availability receives phase")
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
    _assert_eq(result, false, "availability denial returns false")
  end)
end

local function _test_resolve_item_slot_resolution_invalid_action_returns_invalid_action()
  local result = _resolve({}, {}, { id = "something_else", actor_role_id = 1 }, {})
  _assert_eq(result.ok, false, "invalid action should fail")
  _assert_eq(result.reason, "invalid_action", "invalid action reason")
end

local function _test_resolve_item_slot_resolution_missing_choice_returns_missing_choice()
  _with_patched_dependencies({
    get_pending_choice = function()
      return nil
    end,
  }, function()
    local result = _resolve({}, {}, { id = "item_slot_1", actor_role_id = 1 }, { turn = {} })
    _assert_eq(result.ok, false, "missing choice should fail")
    _assert_eq(result.reason, "missing_choice", "missing choice reason")
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

    _assert_eq(result.ok, false, "missing item id should fail")
    _assert_eq(result.reason, "missing_item_id", "missing item id reason")
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
        _assert_eq(actor_role_id, 1, "resolve_slot_action actor role id")
        _assert_eq(slot_id, "item_slot_1", "resolve_slot_action slot id")
        return "item_123"
      end,
    }, {}, action, {})

    _assert_eq(result.ok, true, "success should return ok")
    _assert_eq(result.action.type, "choice_select", "resolved action type")
    _assert_eq(result.action.choice_id, "choice_1", "resolved choice id")
    _assert_eq(result.action.option_id, "item_123", "resolved option id")
    _assert_eq(result.action.actor_role_id, 1, "resolved actor role id")
    _assert_eq(result.action.input_source, "user", "resolved input source")
  end)
end

return {
  name = "validator_crap_coverage",
  tests = {
    {
      name = "_validate_item_slot_action valid option and no phase returns true",
      run = _test_validate_item_slot_action_valid_option_without_phase_returns_true,
    },
    {
      name = "_validate_item_slot_action invalid option returns false",
      run = _test_validate_item_slot_action_invalid_option_returns_false,
    },
    {
      name = "_validate_item_slot_action availability denied returns false",
      run = _test_validate_item_slot_action_availability_denied_returns_false,
    },
    {
      name = "_resolve_item_slot_resolution invalid action returns invalid_action",
      run = _test_resolve_item_slot_resolution_invalid_action_returns_invalid_action,
    },
    {
      name = "_resolve_item_slot_resolution missing choice returns missing_choice",
      run = _test_resolve_item_slot_resolution_missing_choice_returns_missing_choice,
    },
    {
      name = "_resolve_item_slot_resolution missing item id returns missing_item_id",
      run = _test_resolve_item_slot_resolution_missing_item_id_returns_missing_item_id,
    },
    {
      name = "_resolve_item_slot_resolution success returns choice_select action",
      run = _test_resolve_item_slot_resolution_success_returns_choice_select_action,
    },
  },
}
