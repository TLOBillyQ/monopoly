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

  it("fallback handles popup_confirm without error", function()
    local ok = pcall(view_command.dispatch, {}, { type = "popup_confirm" })
    assert(ok, "expected no error for popup_confirm")
  end)
end)
