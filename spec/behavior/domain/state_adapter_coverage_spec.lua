local output_port = require("src.turn.output.state_adapter")
local runtime_state = require("src.state.runtime_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain state adapter coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("is_ui_dirty reflects dirty state", function()
    local state = {}
    _assert_eq(output_port.is_ui_dirty(state), false, "fresh state should not be dirty")
    output_port.invalidate_ui_model(state)
    _assert_eq(output_port.is_ui_dirty(state), true, "state should be dirty after invalidate_ui_model")
  end)

  it("invalidate_ui_model returns false when already dirty", function()
    local state = {}
    _assert_eq(output_port.invalidate_ui_model(state), true, "first invalidate should return true")
    _assert_eq(output_port.invalidate_ui_model(state), false, "second invalidate should return false")
  end)

  it("clear_ui_dirty returns false when not dirty", function()
    local state = {}
    _assert_eq(output_port.clear_ui_dirty(state), false, "clear_ui_dirty on clean state should return false")
  end)

  it("clear_ui_dirty clears dirty flag and returns true", function()
    local state = {}
    output_port.invalidate_ui_model(state)
    _assert_eq(output_port.clear_ui_dirty(state), true, "clear_ui_dirty on dirty state should return true")
    _assert_eq(runtime_state.is_ui_dirty(state), false, "after clear_ui_dirty state should be clean")
  end)

  it("get_ui_model returns synced model", function()
    local state = {}
    local model = { screen = "gameplay" }
    output_port.sync_ui_model(state, model)
    _assert_eq(output_port.get_ui_model(state), model, "get_ui_model should return synced model")
  end)

  it("get_pending_choice returns synced choice", function()
    local state = {}
    local choice = { id = 20, kind = "market_buy" }
    output_port.sync_pending_choice(state, choice, { elapsed_seconds = 1.5 })
    _assert_eq(output_port.get_pending_choice(state), choice, "get_pending_choice should return synced choice")
  end)

  it("get_pending_choice_id returns choice id", function()
    local state = {}
    local choice = { id = 30, kind = "item_phase_choice" }
    output_port.sync_pending_choice(state, choice)
    _assert_eq(output_port.get_pending_choice_id(state), 30, "get_pending_choice_id should return choice id")
  end)

  it("get_pending_choice_elapsed returns elapsed", function()
    local state = {}
    local choice = { id = 40, kind = "market_buy" }
    output_port.sync_pending_choice(state, choice, { elapsed_seconds = 2.75 })
    _assert_eq(output_port.get_pending_choice_elapsed(state), 2.75, "get_pending_choice_elapsed should return elapsed")
  end)

  it("set_pending_choice_elapsed updates elapsed", function()
    local state = {}
    output_port.set_pending_choice_elapsed(state, 3.5)
    _assert_eq(output_port.get_pending_choice_elapsed(state), 3.5, "set_pending_choice_elapsed should update elapsed")
  end)

  it("set_pending_choice_id updates choice id", function()
    local state = {}
    output_port.set_pending_choice_id(state, 99)
    _assert_eq(output_port.get_pending_choice_id(state), 99, "set_pending_choice_id should update choice id")
  end)

  it("clear_pending_choice resets choice fields", function()
    local state = {}
    local choice = { id = 50, kind = "item_phase_choice" }
    output_port.sync_pending_choice(state, choice, { elapsed_seconds = 1.0 })
    output_port.clear_pending_choice(state)
    _assert_eq(output_port.get_pending_choice(state), nil, "after clear_pending_choice choice should be nil")
    _assert_eq(output_port.get_pending_choice_id(state), nil, "after clear_pending_choice choice id should be nil")
    _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "after clear_pending_choice elapsed should be zero")
  end)

  it("get_modal_elapsed returns synced elapsed", function()
    local state = {}
    output_port.sync_modal_timer(state, { ref = "pop_1", elapsed_seconds = 4.0 })
    _assert_eq(output_port.get_modal_elapsed(state), 4.0, "get_modal_elapsed should return synced elapsed")
  end)

  it("get_modal_ref returns synced ref", function()
    local state = {}
    output_port.sync_modal_timer(state, { ref = "pop_2", elapsed_seconds = 0.5 })
    _assert_eq(output_port.get_modal_ref(state), "pop_2", "get_modal_ref should return synced ref")
  end)

  it("build_runtime_output_ports returns all port functions", function()
    local ports = output_port.build_runtime_output_ports()
    local expected_keys = {
      "invalidate_ui_model", "clear_ui_dirty", "is_ui_dirty",
      "sync_ui_model", "get_ui_model",
      "sync_pending_choice", "clear_pending_choice", "get_pending_choice",
      "get_pending_choice_id", "get_pending_choice_elapsed",
      "set_pending_choice_elapsed", "set_pending_choice_id",
      "sync_modal_timer", "get_modal_elapsed", "get_modal_ref",
    }
    for _, key in ipairs(expected_keys) do
      assert(type(ports[key]) == "function",
        "build_runtime_output_ports should include " .. tostring(key))
    end
  end)

  it("build_base_output_ports matches runtime output ports", function()
    local rt_ports = output_port.build_runtime_output_ports()
    local base_ports = output_port.build_base_output_ports()
    for key, fn in pairs(rt_ports) do
      assert(type(base_ports[key]) == "function",
        "build_base_output_ports should include " .. tostring(key))
      _assert_eq(base_ports[key], fn, "build_base_output_ports." .. key .. " should be same fn as build_runtime_output_ports")
    end
  end)
end)
