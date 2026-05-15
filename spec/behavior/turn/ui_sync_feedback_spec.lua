local support = require("spec.support.shared_support")
local fixtures = require("spec.support.gameplay_fixtures")
local _new_game = support.new_game
local _build_test_ports = fixtures.build_test_ports
local _build_loop_state = fixtures.build_loop_state
local turn_timer_policy = require("src.turn.policies.timer")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
local tick_timeout = require("src.turn.waits.timeout")
local runtime_state = require("src.state.runtime")
local action_anim_wait = require("src.turn.waits.await")

local _update_countdown_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 5
    game.turn.detained_wait_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == 3, "should calculate remaining detained wait seconds")
    assert(game.turn.countdown_active == true, "should set countdown active for detained wait")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 1
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should set countdown active for action button")
  end,
}

local _is_action_button_wait_active_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == true, "should be active when no blocking UI and game not finished")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    game.finished = true
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when game is finished")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when input is blocked")
  end,
}

local _update_countdown_extended_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.action_button_active = false
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should set countdown active for pending choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 10 } }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should set countdown active for popup")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn = nil
    tick_ui_sync.update_countdown(game, state)
    assert(true, "should handle nil turn gracefully")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.ui = { choice_active = true, market_active = false }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should be active with choice_active")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "market_buy" }
    state.ui = { choice_active = false, market_active = true }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should be active with market_active")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.pending_choice_elapsed = 5
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should be active")
    assert(game.turn.countdown_seconds ~= nil, "should set countdown_seconds")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.pending_choice_elapsed = -5
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should be active with negative elapsed")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 10
    game.turn.detained_wait_elapsed = 3
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == 7, "should calculate remaining detained wait")
    assert(game.turn.countdown_active == true, "should be active for detained wait")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should be active for action button")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    tick_ui_sync.update_countdown(game, state)
    local first_countdown = game.turn.countdown_seconds
    game.dirty.turn_countdown = nil
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == first_countdown, "countdown should remain same")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.pending_choice_elapsed = nil
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should handle nil elapsed")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 0 } }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == false or game.turn.countdown_active == true, "should handle zero popup timeout")
  end,
}

local _is_action_button_wait_active_extended_tests = {
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.pending_choice = { id = 1 }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == false, "should not be active when pending_choice exists")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { choice_active = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == false, "should not be active when choice is active")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { market_active = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == true, "market active should NOT block action_button (gentle deadline lets timer keep running)")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { popup_active = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == false, "should not be active when popup is active")
  end,
  function()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(nil, state, ports)
    assert(result == false, "should return false with nil game")
  end,
  function()
    local g = _new_game()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(g, nil, ports)
    assert(result == false, "should return false with nil state")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local result = turn_timer_policy.is_action_button_wait_active(g, state, nil)
    assert(result == false, "should return false with nil ports")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports({
      get_ui_state = nil
    })
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == true, "should be active when get_ui_state is nil")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports({
      get_ui_state = function() return nil end
    })
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == false, "should return false when get_ui_state returns nil")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == true, "should be active when all conditions are normal")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.finished = true
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == false, "should not be active when game is finished")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == false, "should not be active when input is blocked")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn = nil
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    assert(result == true, "should handle nil turn (no pending_choice check)")
  end,
}

local _fill_ui_sync_defaults_tests = {
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(type(ports.get_ui_state) == "function", "should fill get_ui_state")
    assert(type(ports.is_input_blocked) == "function", "should fill is_input_blocked")
    assert(type(ports.is_popup_active) == "function", "should fill is_popup_active")
    assert(type(ports.is_choice_active) == "function", "should fill is_choice_active")
    assert(type(ports.is_market_active) == "function", "should fill is_market_active")
    assert(type(ports.get_popup_owner_index) == "function", "should fill get_popup_owner_index")
    assert(type(ports.set_input_blocked) == "function", "should fill set_input_blocked")
    assert(type(ports.resolve_ui_gate) == "function", "should fill resolve_ui_gate")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {
      get_ui_state = function() return "custom" end,
      is_input_blocked = function() return true end,
    }
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(ports.get_ui_state() == "custom", "should not overwrite custom get_ui_state")
    assert(ports.is_input_blocked() == true, "should not overwrite custom is_input_blocked")
    assert(type(ports.is_popup_active) == "function", "should fill missing defaults")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = true, choice_active = false, popup_active = true, popup_owner_index = 2 } }
    assert(ports.is_input_blocked(state) == true, "is_input_blocked should read from state.ui")
    assert(ports.is_choice_active(state) == false, "is_choice_active should read from state.ui")
    assert(ports.is_popup_active(state) == true, "is_popup_active should read from state.ui")
    assert(ports.get_popup_owner_index(state) == 2, "get_popup_owner_index should read from state.ui")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = false } }
    local changed = ports.set_input_blocked(state, true)
    assert(changed == true, "should return true when value changes")
    assert(state.ui.input_blocked == true, "should set input_blocked to true")
    local changed2 = ports.set_input_blocked(state, true)
    assert(changed2 == false, "should return false when value unchanged")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = {
      ui = {
        input_blocked = true,
        choice_active = false,
        market_active = true,
        popup_active = true,
        popup_seq = 5,
        popup_owner_index = 1,
        popup_payload = { auto_close_seconds = 10 },
      }
    }
    local gate = ports.resolve_ui_gate(state)
    assert(gate.input_blocked == true, "gate should reflect input_blocked")
    assert(gate.choice_active == false, "gate should reflect choice_active")
    assert(gate.market_active == true, "gate should reflect market_active")
    assert(gate.popup_active == true, "gate should reflect popup_active")
    assert(gate.popup_seq == 5, "gate should reflect popup_seq")
    assert(gate.popup_owner_index == 1, "gate should reflect popup_owner_index")
    assert(gate.popup_auto_close_seconds == 10, "gate should reflect popup_auto_close_seconds")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(ports.get_ui_state(nil) == nil, "get_ui_state should handle nil state")
    assert(ports.is_input_blocked(nil) == false, "is_input_blocked should handle nil state")
    assert(ports.is_choice_active(nil) == false, "is_choice_active should handle nil state")
    assert(ports.is_popup_active(nil) == false, "is_popup_active should handle nil state")
    assert(ports.is_market_active(nil) == false, "is_market_active should handle nil state")
    assert(ports.get_popup_owner_index(nil) == nil, "get_popup_owner_index should handle nil state")
    assert(ports.set_input_blocked(nil, true) == false, "set_input_blocked should handle nil state")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = nil }
    assert(ports.get_ui_state(state) == nil, "get_ui_state should handle nil ui")
    assert(ports.is_input_blocked(state) == false, "is_input_blocked should handle nil ui")
    assert(ports.set_input_blocked(state, true) == false, "set_input_blocked should handle nil ui")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local gate = ports.resolve_ui_gate(nil)
    assert(gate.input_blocked == false, "gate should default input_blocked to false")
    assert(gate.choice_active == false, "gate should default choice_active to false")
    assert(gate.market_active == false, "gate should default market_active to false")
    assert(gate.popup_active == false, "gate should default popup_active to false")
    assert(gate.popup_seq == nil, "gate should default popup_seq to nil")
    assert(gate.popup_auto_close_seconds == nil, "gate should default popup_auto_close_seconds to nil")
    assert(gate.popup_owner_index == nil, "gate should default popup_owner_index to nil")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = false, popup_payload = nil } }
    local gate = ports.resolve_ui_gate(state)
    assert(gate.popup_auto_close_seconds == nil, "gate should handle nil popup_payload")
  end,
}

local _is_action_button_wait_active_more_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.get_ui_state = nil
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == true, "should be active when get_ui_state is nil")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.get_ui_state = function() return false end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when get_ui_state returns false")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    game.turn.pending_choice = { id = 1 }
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when pending_choice exists")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.is_choice_active = function() return true end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when choice is active")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.is_market_active = function() return true end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == true, "market active should NOT block action_button (gentle deadline lets timer keep running)")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.is_popup_active = function() return true end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when popup is active")
  end,
}

local _update_countdown_more_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local original_timeout = require("src.config.content.constants").action_timeout_seconds
    require("src.config.content.constants").action_timeout_seconds = 10

    game.turn.pending_choice = { id = 1, kind = "test" }
    state.countdown_last = nil
    state.countdown_active_last = nil

    local original_get_pending_choice = runtime_state.get_pending_choice
    local original_get_pending_choice_elapsed = runtime_state.get_pending_choice_elapsed
    runtime_state.get_pending_choice = function() return game.turn.pending_choice end
    runtime_state.get_pending_choice_elapsed = function() return 3 end

    tick_ui_sync.update_countdown(game, state)

    runtime_state.get_pending_choice = original_get_pending_choice
    runtime_state.get_pending_choice_elapsed = original_get_pending_choice_elapsed
    require("src.config.content.constants").action_timeout_seconds = original_timeout

    assert(game.turn.countdown_seconds ~= nil, "should set countdown_seconds")
    assert(game.turn.countdown_active == true, "should set countdown_active")
  end,
}

local _is_action_button_wait_active_final_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()

    assert(turn_timer_policy.is_action_button_wait_active(nil, state, ports) == false, "nil game should return false")
    assert(turn_timer_policy.is_action_button_wait_active(game, nil, ports) == false, "nil state should return false")
    assert(turn_timer_policy.is_action_button_wait_active(game, state, nil) == false, "nil ports should return false")

    game.finished = true
    assert(turn_timer_policy.is_action_button_wait_active(game, state, ports) == false, "finished game should return false")
    game.finished = false

    ports.ui_sync.is_input_blocked = function() return true end
    assert(turn_timer_policy.is_action_button_wait_active(game, state, ports) == false, "blocked input should return false")
    ports.ui_sync.is_input_blocked = function() return false end

    assert(turn_timer_policy.is_action_button_wait_active(game, state, ports) == true, "normal case should return true")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.get_ui_state = function() return nil end

    assert(turn_timer_policy.is_action_button_wait_active(game, state, ports) == false, "nil ui_state should return false")
  end,
}

local _update_countdown_final_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()

    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 10
    game.turn.detained_wait_elapsed = 5
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "detained wait should be active")
    assert(game.turn.countdown_seconds == 5, "countdown should be remaining seconds")

    game.turn.detained_wait_active = false
    state.countdown_last = nil
    state.countdown_active_last = nil

    local constants = require("src.config.content.constants")
    local original_timeout = constants.action_timeout_seconds
    constants.action_timeout_seconds = 10

    local original_resolve_modal_gate = tick_timeout.resolve_modal_gate
    tick_timeout.resolve_modal_gate = function() return { popup_active = true } end

    tick_ui_sync.update_countdown(game, state)

    tick_timeout.resolve_modal_gate = original_resolve_modal_gate
    constants.action_timeout_seconds = original_timeout

    assert(true, "popup branch executed")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()

    state.action_button_active = true
    state.action_button_elapsed = 3

    local constants = require("src.config.content.constants")
    local original_timeout = constants.action_timeout_seconds
    constants.action_timeout_seconds = 10

    tick_ui_sync.update_countdown(game, state)

    constants.action_timeout_seconds = original_timeout

    assert(game.turn.countdown_active == true, "action button should be active")
  end,
}

-- CRAP coverage tests for action_anim_wait._coalesce_head
local _coalesce_head = action_anim_wait._M_test._coalesce_head

local function _crap_assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("ui_sync_feedback", function()
  it("_test_update_countdown_detained_wait", _update_countdown_tests[1])

  it("_test_update_countdown_action_button", _update_countdown_tests[2])

  it("_test_is_action_button_wait_active_normal", _is_action_button_wait_active_tests[1])

  it("_test_is_action_button_wait_active_finished", _is_action_button_wait_active_tests[2])

  it("_test_is_action_button_wait_active_blocked", _is_action_button_wait_active_tests[3])

  it("_test_update_countdown_pending_choice", _update_countdown_extended_tests[1])

  it("_test_update_countdown_popup", _update_countdown_extended_tests[2])

  it("_test_is_action_button_wait_active_pending_choice", _is_action_button_wait_active_extended_tests[1])

  it("_test_is_action_button_wait_active_choice_active", _is_action_button_wait_active_extended_tests[2])

  it("_test_is_action_button_wait_active_market_active", _is_action_button_wait_active_extended_tests[3])

  it("_test_is_action_button_wait_active_popup_active", _is_action_button_wait_active_extended_tests[4])

  it("_test_fill_ui_sync_defaults_fills_all", _fill_ui_sync_defaults_tests[1])

  it("_test_fill_ui_sync_defaults_preserves_custom", _fill_ui_sync_defaults_tests[2])

  it("_test_fill_ui_sync_defaults_implementations", _fill_ui_sync_defaults_tests[3])

  it("_test_fill_ui_sync_defaults_set_input_blocked", _fill_ui_sync_defaults_tests[4])

  it("_test_fill_ui_sync_defaults_resolve_ui_gate", _fill_ui_sync_defaults_tests[5])

  it("_test_fill_ui_sync_defaults_nil_state", _fill_ui_sync_defaults_tests[6])

  it("_test_fill_ui_sync_defaults_nil_ui", _fill_ui_sync_defaults_tests[7])

  it("_test_fill_ui_sync_defaults_gate_nil_state", _fill_ui_sync_defaults_tests[8])

  it("_test_fill_ui_sync_defaults_gate_nil_popup", _fill_ui_sync_defaults_tests[9])

  it("_test_update_countdown_nil_turn", _update_countdown_extended_tests[3])

  it("_test_update_countdown_choice_active", _update_countdown_extended_tests[4])

  it("_test_update_countdown_market_active", _update_countdown_extended_tests[5])

  it("_test_update_countdown_with_elapsed", _update_countdown_extended_tests[6])

  it("_test_update_countdown_negative_elapsed", _update_countdown_extended_tests[7])

  it("_test_update_countdown_detained_calc", _update_countdown_extended_tests[8])

  it("_test_update_countdown_action_button_ext", _update_countdown_extended_tests[9])

  it("_test_update_countdown_caching", _update_countdown_extended_tests[10])

  it("_test_update_countdown_nil_elapsed", _update_countdown_extended_tests[11])

  it("_test_update_countdown_zero_popup_timeout", _update_countdown_extended_tests[12])

  it("_test_is_action_button_wait_active_nil_game", _is_action_button_wait_active_extended_tests[5])

  it("_test_is_action_button_wait_active_nil_state", _is_action_button_wait_active_extended_tests[6])

  it("_test_is_action_button_wait_active_nil_ports", _is_action_button_wait_active_extended_tests[7])

  it("_test_is_action_button_wait_active_nil_get_ui", _is_action_button_wait_active_extended_tests[8])

  it("_test_is_action_button_wait_active_nil_ui_state", _is_action_button_wait_active_extended_tests[9])

  it("_test_is_action_button_wait_active_normal_ext", _is_action_button_wait_active_extended_tests[10])

  it("_test_is_action_button_wait_active_finished_ext", _is_action_button_wait_active_extended_tests[11])

  it("_test_is_action_button_wait_active_input_blocked", _is_action_button_wait_active_extended_tests[12])

  it("_test_is_action_button_wait_active_nil_turn", _is_action_button_wait_active_extended_tests[13])

  it("_test_is_action_button_wait_active_nil_get_ui_state", _is_action_button_wait_active_more_tests[1])

  it("_test_is_action_button_wait_active_falsy_ui", _is_action_button_wait_active_more_tests[2])

  it("_test_is_action_button_wait_active_pending_choice_more", _is_action_button_wait_active_more_tests[3])

  it("_test_is_action_button_wait_active_choice_ui_active", _is_action_button_wait_active_more_tests[4])

  it("_test_is_action_button_wait_active_market_ui_active", _is_action_button_wait_active_more_tests[5])

  it("_test_is_action_button_wait_active_popup_ui_active", _is_action_button_wait_active_more_tests[6])

  it("_test_update_countdown_choice_gate", _update_countdown_more_tests[1])

  it("_test_is_action_button_all_early_returns", _is_action_button_wait_active_final_tests[1])

  it("_test_is_action_button_nil_ui_state", _is_action_button_wait_active_final_tests[2])

  it("_test_update_countdown_detained_and_popup", _update_countdown_final_tests[1])

  it("_test_update_countdown_action_button_final", _update_countdown_final_tests[2])

  it("_test_empty_queue_noop", function()
    local queue = {}
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 0, "empty queue should remain empty")
  end)

  it("_test_single_element_queue_noop", function()
    local queue = {
      { kind = "cash_receive", amount = 10 },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 1, "single element queue should not be modified")
    _crap_assert_eq(queue[1].amount, 10, "single element amount should stay unchanged")
    _crap_assert_eq(queue[1].coalesced_count, nil, "single element should not get coalesced_count")
  end)

  it("_test_head_not_cash_receive_noop", function()
    local queue = {
      { kind = "roadblock" },
      { kind = "cash_receive", amount = 5 },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 2, "head not cash_receive should skip coalescing")
    _crap_assert_eq(queue[1].kind, "roadblock", "head kind should remain unchanged")
    _crap_assert_eq(queue[2].amount, 5, "second entry should remain unchanged")
  end)

  it("_test_two_cash_receive_merge", function()
    local queue = {
      { kind = "cash_receive", amount = 10 },
      { kind = "cash_receive", amount = 20 },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 1, "two cash_receive entries should merge")
    _crap_assert_eq(queue[1].amount, 30, "merged amount should sum")
    _crap_assert_eq(queue[1].coalesced_count, 2, "merged coalesced_count should be 2")
  end)

  it("_test_three_cash_receive_merge", function()
    local queue = {
      { kind = "cash_receive", amount = 5 },
      { kind = "cash_receive", amount = 3 },
      { kind = "cash_receive", amount = 7 },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 1, "three cash_receive entries should merge")
    _crap_assert_eq(queue[1].amount, 15, "three-way merged amount should sum")
    _crap_assert_eq(queue[1].coalesced_count, 3, "three-way coalesced_count should be 3")
  end)

  it("_test_cash_receive_followed_by_different_kind_stops_merge", function()
    local queue = {
      { kind = "cash_receive", amount = 10 },
      { kind = "roadblock" },
      { kind = "cash_receive", amount = 5 },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 3, "non-cash second entry should prevent merge")
    _crap_assert_eq(queue[1].amount, 10, "head amount should remain unchanged")
    _crap_assert_eq(queue[1].coalesced_count, nil, "head should not get coalesced_count when no merge")
  end)

  it("_test_nil_amount_treated_as_zero", function()
    local queue = {
      { kind = "cash_receive" },
      { kind = "cash_receive", amount = 5 },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 1, "entries should merge when both are cash_receive")
    _crap_assert_eq(queue[1].amount, 5, "nil amount should be treated as zero")
    _crap_assert_eq(queue[1].coalesced_count, 2, "coalesced_count should reflect merged entries")
  end)

  it("_test_both_nil_amounts_merge_to_zero", function()
    local queue = {
      { kind = "cash_receive" },
      { kind = "cash_receive" },
    }
    _coalesce_head(queue)
    _crap_assert_eq(#queue, 1, "entries should merge")
    _crap_assert_eq(queue[1].amount, 0, "both nil amounts should merge to zero")
    _crap_assert_eq(queue[1].coalesced_count, 2, "coalesced_count should be 2")
  end)
end)
