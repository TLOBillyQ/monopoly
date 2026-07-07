local view_command = require("src.ui.input.view_command")

describe("view_command_dispatcher", function()
  it("dispatch returns false with no state ports and nil intent", function()
    local result = view_command.dispatch({}, nil)
    assert(result == false, "expected false for nil intent")
  end)

  it("dispatch returns false with no state ports and unknown intent type", function()
    local result = view_command.dispatch({}, { type = "not_a_real_action_xyz" })
    assert(result == false, "expected false for unknown intent type")
  end)

  it("dispatch delegates to ports.view_command when available", function()
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
    assert(result == true, "expected true from ports dispatch")
    assert(captured == intent, "expected intent forwarded to ports")
  end)

  it("dispatch returns false when ports dispatch returns non-true", function()
    local state = {
      gameplay_loop_ports = {
        view_command = {
          dispatch = function() return false end,
        },
      },
    }
    local result = view_command.dispatch(state, { type = "x" })
    assert(result == false, "expected false when ports dispatch returns false")
  end)

  it("dispatch returns false when ports dispatch returns nil", function()
    local state = {
      gameplay_loop_ports = {
        view_command = {
          dispatch = function() return nil end,
        },
      },
    }
    local result = view_command.dispatch(state, { type = "x" })
    assert(result == false, "expected false when ports dispatch returns nil")
  end)

  it("dispatch warns and returns false when the view_command port is missing", function()
    local logger = require("src.foundation.log")
    local warn_calls = {}
    local saved_warn = logger.warn
    logger.warn = function(...) warn_calls[#warn_calls + 1] = { ... } end
    local ok, result = pcall(view_command.dispatch, {}, { type = "popup_confirm" })
    logger.warn = saved_warn
    assert(ok, "expected no error for popup_confirm without ports")
    assert(result == false, "expected false when port is missing")
    assert(#warn_calls == 1, "expected one warn for missing port, got " .. #warn_calls)
    local found = false
    for _, arg in ipairs(warn_calls[1]) do
      if tostring(arg):find("popup_confirm", 1, true) then found = true end
    end
    assert(found, "warn must include the dropped intent type")
  end)
end)
