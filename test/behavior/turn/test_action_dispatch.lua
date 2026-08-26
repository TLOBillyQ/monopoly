local lu = require("luaunit")
local action_dispatcher = require("src.turn.actions.action_dispatcher")

TestActionDispatch = {}

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

function TestActionDispatch:test_dispatches_in_gate_invalidation_handler_order()
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

  lu.assertEquals(result, { status = "applied" })
  lu.assertEquals(calls, { "gate", "invalidate", "handler:next" })
end

function TestActionDispatch:test_gate_block_stops_before_invalidation_and_handler()
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

  lu.assertEquals(result, { status = "blocked" })
  lu.assertFalse(invalidated)
  lu.assertFalse(handled)
end

function TestActionDispatch:test_market_cancel_can_cross_a_blocked_gate()
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

  lu.assertEquals(result, { status = "applied" })
end

function TestActionDispatch:test_invalidates_only_ui_model_changing_actions()
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

  lu.assertEquals(invalidated, #action_types)
end

function TestActionDispatch:test_preserves_handler_status_and_rejects_unknown_actions()
  local blocked = { status = "blocked", reason = "probe" }
  local dispatcher = _new_dispatcher({
    handlers = {
      probe = function()
        return blocked
      end,
    },
  })
  local state = _state()

  lu.assertIs(dispatcher.dispatch_action({}, state, { type = "probe" }), blocked)
  lu.assertEquals(dispatcher.dispatch_action({}, state, { type = "unknown" }), { status = "rejected" })
end

function TestActionDispatch:test_defaults_input_source_before_calling_handler()
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

  lu.assertEquals(received_source, "user")
end

function TestActionDispatch:test_reentrant_handler_uses_the_same_dispatcher_instance()
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

  lu.assertEquals(result, { status = "applied" })
  lu.assertEquals(calls, { "ui_button", "choice_select" })
end

function TestActionDispatch:test_missing_action_fails_fast()
  local dispatcher = _new_dispatcher()

  local ok, err = pcall(dispatcher.dispatch_action, {}, _state(), nil)

  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "missing action")
end

return TestActionDispatch
