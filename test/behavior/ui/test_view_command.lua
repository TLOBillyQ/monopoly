local lu = require("luaunit")
local view_command = require("src.ui.input.view_command")

TestViewCommand = {}

function TestViewCommand:test_dispatch_returns_false_with_no_state_ports_and_nil_intent()
  local result = view_command.dispatch({}, nil)
  lu.assertEvalToTrue(result == false, "expected false for nil intent")
end

function TestViewCommand:test_dispatch_returns_false_with_no_state_ports_and_unknown_intent_type()
  local result = view_command.dispatch({}, { type = "not_a_real_action_xyz" })
  lu.assertEvalToTrue(result == false, "expected false for unknown intent type")
end

function TestViewCommand:test_dispatch_delegates_to_ports_view_command_when_available()
  local captured = nil
  local state = {
    gameplay_loop_ports = {
      view_command = {
        dispatch = function(_, intent)
          captured = intent
          return true
        end,
      },
    },
  }
  local intent = { type = "some_action" }
  local result = view_command.dispatch(state, intent)
  lu.assertEvalToTrue(result == true, "expected true from ports dispatch")
  lu.assertEvalToTrue(captured == intent, "expected intent forwarded to ports")
end

function TestViewCommand:test_dispatch_returns_false_when_ports_dispatch_returns_non_true()
  local state = {
    gameplay_loop_ports = {
      view_command = {
        dispatch = function() return false end,
      },
    },
  }
  local result = view_command.dispatch(state, { type = "x" })
  lu.assertEvalToTrue(result == false, "expected false when ports dispatch returns false")
end

function TestViewCommand:test_dispatch_returns_false_when_ports_dispatch_returns_nil()
  local state = {
    gameplay_loop_ports = {
      view_command = {
        dispatch = function() return nil end,
      },
    },
  }
  local result = view_command.dispatch(state, { type = "x" })
  lu.assertEvalToTrue(result == false, "expected false when ports dispatch returns nil")
end

function TestViewCommand:test_dispatch_warns_and_returns_false_when_the_view_command_port_is_missing()
  local logger = require("src.foundation.log")
  local warn_calls = {}
  local saved_warn = logger.warn
  logger.warn = function(...) warn_calls[#warn_calls + 1] = { ... } end
  local ok, result = pcall(view_command.dispatch, {}, { type = "popup_confirm" })
  logger.warn = saved_warn
  lu.assertEvalToTrue(ok, "expected no error for popup_confirm without ports")
  lu.assertEvalToTrue(result == false, "expected false when port is missing")
  lu.assertEvalToTrue(#warn_calls == 1, "expected one warn for missing port, got " .. #warn_calls)
  local found = false
  for _, arg in ipairs(warn_calls[1]) do
    if tostring(arg):find("popup_confirm", 1, true) then found = true end
  end
  lu.assertEvalToTrue(found, "warn must include the dropped intent type")
end


return TestViewCommand
