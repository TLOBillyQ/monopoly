-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end
local function _assert_identity(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local function _assert_contains(actual, expected, message)
  luassert.matches(expected, actual, 1, true, message)
end
local action_dispatcher = require("src.turn.actions.action_dispatcher")

describe("TestActionDispatch", function()

local function _new_dispatcher(opts)
  opts = opts or {}
  local gate = opts.gate or {
    resolve_gate_state = function()
      return { input_blocked = false }
    end,
    should_block_action = function()
      return false
    end,
  }
  local context = {
    resolve_dispatch_context = function(state, explicit)
      return explicit or state.dispatch_context
    end,
  }
  return action_dispatcher.new({
    gate = gate,
    context = context,
    handlers = opts.handlers or {},
  })
end

local function _state(output_ports, pending_choice)
  return {
    dispatch_context = {
      output_ports = output_ports or {},
      ui_sync_ports = {},
      clock_ports = {},
    },
    pending_choice = pending_choice,
  }
end

it("test_dispatches_in_gate_invalidation_handler_order", function()
  local calls = {}
  local dispatcher = _new_dispatcher({
    gate = {
      resolve_gate_state = function()
        calls[#calls + 1] = "gate"
        return { input_blocked = false }
      end,
      should_block_action = function()
        return false
      end,
    },
    handlers = {
      ui_button = function(_, _, action)
        calls[#calls + 1] = "handler:" .. action.id
        return { status = "applied" }
      end,
    },
  })
  local state = _state({
    invalidate_ui_model = function()
      calls[#calls + 1] = "invalidate"
    end,
  })

  local result = dispatcher.dispatch_action({}, state, { type = "ui_button", id = "next" })

  _assert_same(result, { status = "applied" })
  _assert_same(calls, { "gate", "invalidate", "handler:next" })
end)

it("test_gate_block_stops_before_invalidation_and_handler", function()
  local invalidated = false
  local handled = false
  local dispatcher = _new_dispatcher({
    gate = {
      resolve_gate_state = function()
        return { input_blocked = true }
      end,
      should_block_action = function()
        return true
      end,
    },
    handlers = {
      ui_button = function()
        handled = true
      end,
    },
  })
  local state = _state({
    invalidate_ui_model = function()
      invalidated = true
    end,
  })

  local result = dispatcher.dispatch_action({}, state, { type = "ui_button", id = "next" })

  _assert_same(result, { status = "blocked" })
  luassert.is_false(invalidated)
  luassert.is_false(handled)
end)

it("test_market_cancel_can_cross_a_blocked_gate", function()
  local choice = { id = "market-1", kind = "market_buy" }
  local dispatcher = _new_dispatcher({
    gate = {
      resolve_gate_state = function()
        return { input_blocked = true }
      end,
      should_block_action = function()
        return true
      end,
    },
    handlers = {
      choice_cancel = function()
        return { status = "applied" }
      end,
    },
  })
  local game = { turn = { pending_choice = choice } }

  local result = dispatcher.dispatch_action(game, _state({}, choice), {
    type = "choice_cancel",
    choice_id = choice.id,
  })

  _assert_same(result, { status = "applied" })
end)

it("test_invalidates_only_ui_model_changing_actions", function()
  local invalidated = 0
  local handlers = {}
  local action_types = {
    "ui_button", "item_slot_click", "choice_select", "choice_cancel",
    "complete_optional_action_phase", "market_page_prev", "market_page_next", "market_tab_select",
  }
  for _, action_type in ipairs(action_types) do
    handlers[action_type] = function()
      return { status = "applied" }
    end
  end
  handlers.choice_force_skip = handlers.ui_button
  local dispatcher = _new_dispatcher({ handlers = handlers })
  local state = _state({
    invalidate_ui_model = function()
      invalidated = invalidated + 1
    end,
  })

  for _, action_type in ipairs(action_types) do
    dispatcher.dispatch_action({}, state, { type = action_type })
  end
  dispatcher.dispatch_action({}, state, { type = "choice_force_skip" })

  _assert_same(invalidated, #action_types)
end)

it("test_preserves_handler_status_and_rejects_unknown_actions", function()
  local blocked = { status = "blocked", reason = "probe" }
  local dispatcher = _new_dispatcher({
    handlers = {
      probe = function()
        return blocked
      end,
    },
  })
  local state = _state()

  _assert_identity(dispatcher.dispatch_action({}, state, { type = "probe" }), blocked)
  _assert_same(dispatcher.dispatch_action({}, state, { type = "unknown" }), { status = "rejected" })
end)

it("test_defaults_input_source_before_calling_handler", function()
  local received_source
  local dispatcher = _new_dispatcher({
    handlers = {
      probe = function(_, _, action)
        received_source = action.input_source
        return { status = "applied" }
      end,
    },
  })

  dispatcher.dispatch_action({}, _state(), { type = "probe" })

  _assert_same(received_source, "user")
end)

it("test_reentrant_handler_uses_the_same_dispatcher_instance", function()
  local calls = {}
  local dispatcher = _new_dispatcher({
    handlers = {
      ui_button = function(game, state, _, opts, ctx, redispatch)
        calls[#calls + 1] = "ui_button"
        return redispatch(game, state, { type = "choice_select" }, opts, ctx)
      end,
      choice_select = function()
        calls[#calls + 1] = "choice_select"
        return { status = "applied" }
      end,
    },
  })

  local result = dispatcher.dispatch_action({}, _state(), { type = "ui_button", id = "cancel" })

  _assert_same(result, { status = "applied" })
  _assert_same(calls, { "ui_button", "choice_select" })
end)

it("test_missing_action_fails_fast", function()
  local dispatcher = _new_dispatcher()

  local ok, err = pcall(dispatcher.dispatch_action, {}, _state(), nil)

  luassert.is_false(ok)
  _assert_contains(tostring(err), "missing action")
end)
end)
