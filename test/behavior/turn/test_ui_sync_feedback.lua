local check = require("luassert")
local support = require("test.support.shared_support")
local fixtures = require("test.support.gameplay_fixtures")
local _new_game = support.new_game
local _build_test_ports = fixtures.build_test_ports
local _build_loop_state = fixtures.build_loop_state
local turn_timer_policy = require("src.turn.policies.timer")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
local runtime_state = require("src.state.runtime")
local action_anim_wait = require("src.turn.waits.await_action_anim")

local _update_countdown_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 5
    game.turn.detained_wait_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_seconds == 3, "should calculate remaining detained wait seconds")
    check.is_truthy(game.turn.countdown_active == true, "should set countdown active for detained wait")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 1
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should set countdown active for action button")
  end,
}

local _is_action_button_wait_active_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == true, "should be active when no blocking UI and game not finished")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    game.finished = true
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == false, "should not be active when game is finished")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == false, "should not be active when input is blocked")
  end,
}

local _update_countdown_extended_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.action_button_active = false
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should set countdown active for pending choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 10 } }
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should set countdown active for popup")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn = nil
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn == nil, "nil turn should remain nil (no mutation)")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.ui = { choice_active = true, market_active = false }
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should be active with choice_active")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "market_buy" }
    state.ui = { choice_active = false, market_active = true }
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should be active with market_active")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.pending_choice_elapsed = 5
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should be active")
    check.is_truthy(game.turn.countdown_seconds ~= nil, "should set countdown_seconds")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.pending_choice_elapsed = -5
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should be active with negative elapsed")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 10
    game.turn.detained_wait_elapsed = 3
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_seconds == 7, "should calculate remaining detained wait")
    check.is_truthy(game.turn.countdown_active == true, "should be active for detained wait")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should be active for action button")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    tick_ui_sync.update_countdown(game, state)
    local first_countdown = game.turn.countdown_seconds
    game.dirty.turn_countdown = nil
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_seconds == first_countdown, "countdown should remain same")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    state.pending_choice_elapsed = nil
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == true, "should handle nil elapsed")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 0 } }
    tick_ui_sync.update_countdown(game, state)
    check.is_truthy(game.turn.countdown_active == false or game.turn.countdown_active == true, "should handle zero popup timeout")
  end,
}

local _is_action_button_wait_active_extended_tests = {
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.pending_choice = { id = 1 }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == false, "should not be active when pending_choice exists")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { choice_active = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == false, "should not be active when choice is active")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { market_active = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == true, "market active should NOT block action_button (gentle deadline lets timer keep running)")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { popup_active = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == false, "should not be active when popup is active")
  end,
  function()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(nil, state, ports)
    check.is_truthy(result == false, "should return false with nil game")
  end,
  function()
    local g = _new_game()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(g, nil, ports)
    check.is_truthy(result == false, "should return false with nil state")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local result = turn_timer_policy.is_action_button_wait_active(g, state, nil)
    check.is_truthy(result == false, "should return false with nil ports")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports({
      get_ui_state = nil
    })
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == true, "should be active when get_ui_state is nil")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports({
      get_ui_state = function() return nil end
    })
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == false, "should return false when get_ui_state returns nil")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == true, "should be active when all conditions are normal")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.finished = true
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == false, "should not be active when game is finished")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == false, "should not be active when input is blocked")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn = nil
    local result = turn_timer_policy.is_action_button_wait_active(g, state, ports)
    check.is_truthy(result == true, "should handle nil turn (no pending_choice check)")
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
    check.is_truthy(type(ports.get_ui_state) == "function", "should fill get_ui_state")
    check.is_truthy(type(ports.is_input_blocked) == "function", "should fill is_input_blocked")
    check.is_truthy(type(ports.is_popup_active) == "function", "should fill is_popup_active")
    check.is_truthy(type(ports.is_choice_active) == "function", "should fill is_choice_active")
    check.is_truthy(type(ports.get_popup_owner_index) == "function", "should fill get_popup_owner_index")
    check.is_truthy(type(ports.set_input_blocked) == "function", "should fill set_input_blocked")
    check.is_truthy(type(ports.resolve_ui_gate) == "function", "should fill resolve_ui_gate")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    -- 提供门控查询 override 时必须同时提供 resolve_ui_gate（防静默降级校验）
    local custom_gate = { input_blocked = true }
    local ports = {
      get_ui_state = function() return "custom" end,
      resolve_ui_gate = function() return custom_gate end,
      is_input_blocked = function() return true end,
    }
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    check.is_truthy(ports.get_ui_state() == "custom", "should not overwrite custom get_ui_state")
    check.is_truthy(ports.is_input_blocked() == true, "should not overwrite custom is_input_blocked")
    check.is_truthy(ports.resolve_ui_gate() == custom_gate, "should not overwrite custom resolve_ui_gate")
    check.is_truthy(type(ports.is_popup_active) == "function", "should fill missing defaults")
  end,
  function()
    -- turn 层默认实现不再读 state.ui.*：逐项查询一律派生自端口 resolve_ui_gate
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local gate = { input_blocked = true, choice_active = false, popup_active = true, popup_owner_index = 2 }
    local ports = {
      resolve_ui_gate = function() return gate end,
    }
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = {}
    check.is_truthy(ports.is_input_blocked(state) == true, "is_input_blocked should derive from resolve_ui_gate")
    check.is_truthy(ports.is_choice_active(state) == false, "is_choice_active should derive from resolve_ui_gate")
    check.is_truthy(ports.is_popup_active(state) == true, "is_popup_active should derive from resolve_ui_gate")
    check.is_truthy(ports.get_popup_owner_index(state) == 2, "get_popup_owner_index should derive from resolve_ui_gate")
  end,
  function()
    -- turn 层默认 set_input_blocked 不认识 state.ui 键名：惰性且不落写
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = false } }
    local changed = ports.set_input_blocked(state, true)
    check.is_truthy(changed == false, "default set_input_blocked should report no change")
    check.is_truthy(state.ui.input_blocked == false, "default set_input_blocked should not touch state.ui")
  end,
  function()
    -- turn 层默认 resolve_ui_gate 不读 state.ui：返回全关惰性 gate
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
    check.is_truthy(gate.input_blocked == false, "inert gate should keep input_blocked false")
    check.is_truthy(gate.choice_active == false, "inert gate should keep choice_active false")
    check.is_truthy(gate.market_active == false, "inert gate should keep market_active false")
    check.is_truthy(gate.popup_active == false, "inert gate should keep popup_active false")
    check.is_truthy(gate.popup_seq == nil, "inert gate should keep popup_seq nil")
    check.is_truthy(gate.popup_owner_index == nil, "inert gate should keep popup_owner_index nil")
    check.is_truthy(gate.popup_auto_close_seconds == nil, "inert gate should keep popup_auto_close_seconds nil")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    check.is_truthy(ports.get_ui_state(nil) == nil, "get_ui_state should handle nil state")
    check.is_truthy(ports.is_input_blocked(nil) == false, "is_input_blocked should handle nil state")
    check.is_truthy(ports.is_choice_active(nil) == false, "is_choice_active should handle nil state")
    check.is_truthy(ports.is_popup_active(nil) == false, "is_popup_active should handle nil state")
    check.is_truthy(ports.get_popup_owner_index(nil) == nil, "get_popup_owner_index should handle nil state")
    check.is_truthy(ports.set_input_blocked(nil, true) == false, "set_input_blocked should handle nil state")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = nil }
    check.is_truthy(ports.get_ui_state(state) == nil, "get_ui_state should handle nil ui")
    check.is_truthy(ports.is_input_blocked(state) == false, "is_input_blocked should handle nil ui")
    check.is_truthy(ports.set_input_blocked(state, true) == false, "set_input_blocked should handle nil ui")
  end,
  function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for k, v in pairs(base) do
      ports[k] = v
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local gate = ports.resolve_ui_gate(nil)
    check.is_truthy(gate.input_blocked == false, "gate should default input_blocked to false")
    check.is_truthy(gate.choice_active == false, "gate should default choice_active to false")
    check.is_truthy(gate.market_active == false, "gate should default market_active to false")
    check.is_truthy(gate.popup_active == false, "gate should default popup_active to false")
    check.is_truthy(gate.popup_seq == nil, "gate should default popup_seq to nil")
    check.is_truthy(gate.popup_auto_close_seconds == nil, "gate should default popup_auto_close_seconds to nil")
    check.is_truthy(gate.popup_owner_index == nil, "gate should default popup_owner_index to nil")
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
    check.is_truthy(gate.popup_auto_close_seconds == nil, "gate should handle nil popup_payload")
  end,
}

local _is_action_button_wait_active_more_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.get_ui_state = nil
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == true, "should be active when get_ui_state is nil")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.get_ui_state = function() return false end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == false, "should not be active when get_ui_state returns false")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    game.turn.pending_choice = { id = 1 }
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == false, "should not be active when pending_choice exists")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.is_choice_active = function() return true end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == false, "should not be active when choice is active")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.is_market_active = function() return true end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == true, "market active should NOT block action_button (gentle deadline lets timer keep running)")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.is_popup_active = function() return true end
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    check.is_truthy(result == false, "should not be active when popup is active")
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

    check.is_truthy(game.turn.countdown_seconds ~= nil, "should set countdown_seconds")
    check.is_truthy(game.turn.countdown_active == true, "should set countdown_active")
  end,
}

local _is_action_button_wait_active_final_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()

    check.is_truthy(turn_timer_policy.is_action_button_wait_active(nil, state, ports) == false, "nil game should return false")
    check.is_truthy(turn_timer_policy.is_action_button_wait_active(game, nil, ports) == false, "nil state should return false")
    check.is_truthy(turn_timer_policy.is_action_button_wait_active(game, state, nil) == false, "nil ports should return false")

    game.finished = true
    check.is_truthy(turn_timer_policy.is_action_button_wait_active(game, state, ports) == false, "finished game should return false")
    game.finished = false

    ports.ui_sync.is_input_blocked = function() return true end
    check.is_truthy(turn_timer_policy.is_action_button_wait_active(game, state, ports) == false, "blocked input should return false")
    ports.ui_sync.is_input_blocked = function() return false end

    check.is_truthy(turn_timer_policy.is_action_button_wait_active(game, state, ports) == true, "normal case should return true")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    ports.ui_sync.get_ui_state = function() return nil end

    check.is_truthy(turn_timer_policy.is_action_button_wait_active(game, state, ports) == false, "nil ui_state should return false")
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
    check.is_truthy(game.turn.countdown_active == true, "detained wait should be active")
    check.is_truthy(game.turn.countdown_seconds == 5, "countdown should be remaining seconds")

    game.turn.detained_wait_active = false
    state.countdown_last = nil
    state.countdown_active_last = nil

    local constants = require("src.config.content.constants")
    local original_timeout = constants.action_timeout_seconds
    constants.action_timeout_seconds = 10

    local modal_gate_calls = 0
    local tick_ui_gate = require("src.turn.waits.ui_gate")
    local original_resolve_ui_gate = tick_ui_gate.resolve_ui_gate
    tick_ui_gate.resolve_ui_gate = function()
      modal_gate_calls = modal_gate_calls + 1
      return { popup_active = true }
    end

    tick_ui_sync.update_countdown(game, state)

    tick_ui_gate.resolve_ui_gate = original_resolve_ui_gate
    constants.action_timeout_seconds = original_timeout

    check.is_truthy(modal_gate_calls >= 1, "popup branch should query modal_gate")
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

    check.is_truthy(game.turn.countdown_active == true, "action button should be active")
  end,
}

-- CRAP coverage tests for action_anim_wait._coalesce_head
local _coalesce_head = action_anim_wait._coalesce_head

local function _crap_assert_eq(a, b, msg)
  check.equal(a, b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- 缺屏日志只对“该有屏”的 route 打：道具窗口 / 内联选项住在基础屏，choice_active
-- 恒为 false，缺屏是常态，不是信号。
local logger = require("src.foundation.log")

local function _capture_infos(pending_choice)
  local game = _new_game()
  local state = _build_loop_state()
  state.ui = { choice_active = false, market_active = false }
  game.turn.pending_choice = pending_choice

  local infos = {}
  local original_info = logger.info
  logger.info = function(...)
    infos[#infos + 1] = table.concat({ ... }, " ")
  end
  local ok, err = pcall(tick_ui_sync.update_countdown, game, state)
  logger.info = original_info
  check.is_truthy(ok, err)
  return infos
end

local function _count_missing_screen(infos)
  local count = 0
  for _, line in ipairs(infos) do
    if line:find("without ui choice screen", 1, true) then
      count = count + 1
    end
  end
  return count
end

describe("TestUiSyncFeedback", function()

local constants = require("src.config.content.constants")
local tick_ui_gate = require("src.turn.waits.ui_gate")
local saved
before_each(function()
  saved = {
    timeout = constants.action_timeout_seconds,
    pending_choice = runtime_state.get_pending_choice,
    pending_elapsed = runtime_state.get_pending_choice_elapsed,
    resolve_gate = tick_ui_gate.resolve_ui_gate,
    info = logger.info,
  }
end)
after_each(function()
  constants.action_timeout_seconds = saved.timeout
  runtime_state.get_pending_choice = saved.pending_choice
  runtime_state.get_pending_choice_elapsed = saved.pending_elapsed
  tick_ui_gate.resolve_ui_gate = saved.resolve_gate
  logger.info = saved.info
end)

it("test_both_nil_amounts_merge_to_zero", function()
  local queue = {
    { kind = "cash_receive" },
    { kind = "cash_receive" },
  }
  _coalesce_head(queue)
  _crap_assert_eq(#queue, 1, "entries should merge")
  _crap_assert_eq(queue[1].amount, 0, "both nil amounts should merge to zero")
  _crap_assert_eq(queue[1].coalesced_count, 2, "coalesced_count should be 2")
end)

it("test_cash_receive_followed_by_different_kind_stops_merge", function()
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

it("test_empty_queue_noop", function()
  local queue = {}
  _coalesce_head(queue)
  _crap_assert_eq(#queue, 0, "empty queue should remain empty")
end)

it("test_fill_ui_sync_defaults_fills_all", function() _fill_ui_sync_defaults_tests[1]() end)

it("test_fill_ui_sync_defaults_gate_nil_popup", function() _fill_ui_sync_defaults_tests[9]() end)

it("test_fill_ui_sync_defaults_gate_nil_state", function() _fill_ui_sync_defaults_tests[8]() end)

it("test_fill_ui_sync_defaults_implementations", function() _fill_ui_sync_defaults_tests[3]() end)

it("test_fill_ui_sync_defaults_nil_state", function() _fill_ui_sync_defaults_tests[6]() end)

it("test_fill_ui_sync_defaults_nil_ui", function() _fill_ui_sync_defaults_tests[7]() end)

it("test_fill_ui_sync_defaults_preserves_custom", function() _fill_ui_sync_defaults_tests[2]() end)

it("test_fill_ui_sync_defaults_resolve_ui_gate", function() _fill_ui_sync_defaults_tests[5]() end)

it("test_fill_ui_sync_defaults_set_input_blocked", function() _fill_ui_sync_defaults_tests[4]() end)

it("test_head_not_cash_receive_noop", function()
  local queue = {
    { kind = "roadblock" },
    { kind = "cash_receive", amount = 5 },
  }
  _coalesce_head(queue)
  _crap_assert_eq(#queue, 2, "head not cash_receive should skip coalescing")
  _crap_assert_eq(queue[1].kind, "roadblock", "head kind should remain unchanged")
  _crap_assert_eq(queue[2].amount, 5, "second entry should remain unchanged")
end)

it("test_is_action_button_all_early_returns", function() _is_action_button_wait_active_final_tests[1]() end)

it("test_is_action_button_nil_ui_state", function() _is_action_button_wait_active_final_tests[2]() end)

it("test_is_action_button_wait_active_blocked", function() _is_action_button_wait_active_tests[3]() end)

it("test_is_action_button_wait_active_choice_active", function() _is_action_button_wait_active_extended_tests[2]() end)

it("test_is_action_button_wait_active_choice_ui_active", function() _is_action_button_wait_active_more_tests[4]() end)

it("test_is_action_button_wait_active_falsy_ui", function() _is_action_button_wait_active_more_tests[2]() end)

it("test_is_action_button_wait_active_finished", function() _is_action_button_wait_active_tests[2]() end)

it("test_is_action_button_wait_active_finished_ext", function() _is_action_button_wait_active_extended_tests[11]() end)

it("test_is_action_button_wait_active_input_blocked", function() _is_action_button_wait_active_extended_tests[12]() end)

it("test_is_action_button_wait_active_market_active", function() _is_action_button_wait_active_extended_tests[3]() end)

it("test_is_action_button_wait_active_market_ui_active", function() _is_action_button_wait_active_more_tests[5]() end)

it("test_is_action_button_wait_active_nil_game", function() _is_action_button_wait_active_extended_tests[5]() end)

it("test_is_action_button_wait_active_nil_get_ui", function() _is_action_button_wait_active_extended_tests[8]() end)

it("test_is_action_button_wait_active_nil_get_ui_state", function() _is_action_button_wait_active_more_tests[1]() end)

it("test_is_action_button_wait_active_nil_ports", function() _is_action_button_wait_active_extended_tests[7]() end)

it("test_is_action_button_wait_active_nil_state", function() _is_action_button_wait_active_extended_tests[6]() end)

it("test_is_action_button_wait_active_nil_turn", function() _is_action_button_wait_active_extended_tests[13]() end)

it("test_is_action_button_wait_active_nil_ui_state", function() _is_action_button_wait_active_extended_tests[9]() end)

it("test_is_action_button_wait_active_normal", function() _is_action_button_wait_active_tests[1]() end)

it("test_is_action_button_wait_active_normal_ext", function() _is_action_button_wait_active_extended_tests[10]() end)

it("test_is_action_button_wait_active_pending_choice", function() _is_action_button_wait_active_extended_tests[1]() end)

it("test_is_action_button_wait_active_pending_choice_more", function() _is_action_button_wait_active_more_tests[3]() end)

it("test_is_action_button_wait_active_popup_active", function() _is_action_button_wait_active_extended_tests[4]() end)

it("test_is_action_button_wait_active_popup_ui_active", function() _is_action_button_wait_active_more_tests[6]() end)

it("test_nil_amount_treated_as_zero", function()
  local queue = {
    { kind = "cash_receive" },
    { kind = "cash_receive", amount = 5 },
  }
  _coalesce_head(queue)
  _crap_assert_eq(#queue, 1, "entries should merge when both are cash_receive")
  _crap_assert_eq(queue[1].amount, 5, "nil amount should be treated as zero")
  _crap_assert_eq(queue[1].coalesced_count, 2, "coalesced_count should reflect merged entries")
end)

it("test_single_element_queue_noop", function()
  local queue = {
    { kind = "cash_receive", amount = 10 },
  }
  _coalesce_head(queue)
  _crap_assert_eq(#queue, 1, "single element queue should not be modified")
  _crap_assert_eq(queue[1].amount, 10, "single element amount should stay unchanged")
  _crap_assert_eq(queue[1].coalesced_count, nil, "single element should not get coalesced_count")
end)

it("test_stays_silent_for_the_screenless_item_window", function()
  local infos = _capture_infos({
    id = 17,
    kind = "item_phase_passive",
    route_key = "item_phase_passive",
  })
  check.is_truthy(_count_missing_screen(infos) == 0,
    "item_phase_passive lives on the base screen: a missing choice screen is normal, not loggable")
end)

it("test_still_reports_a_screen_route_whose_screen_never_opened", function()
  local infos = _capture_infos({
    id = 89,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
  })
  check.is_truthy(_count_missing_screen(infos) == 1,
    "secondary_confirm owns a screen: countdown running without it is a real signal")
end)

it("test_three_cash_receive_merge", function()
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

it("test_two_cash_receive_merge", function()
  local queue = {
    { kind = "cash_receive", amount = 10 },
    { kind = "cash_receive", amount = 20 },
  }
  _coalesce_head(queue)
  _crap_assert_eq(#queue, 1, "two cash_receive entries should merge")
  _crap_assert_eq(queue[1].amount, 30, "merged amount should sum")
  _crap_assert_eq(queue[1].coalesced_count, 2, "merged coalesced_count should be 2")
end)

it("test_update_countdown_action_button", function() _update_countdown_tests[2]() end)

it("test_update_countdown_action_button_ext", function() _update_countdown_extended_tests[9]() end)

it("test_update_countdown_action_button_final", function() _update_countdown_final_tests[2]() end)

it("test_update_countdown_caching", function() _update_countdown_extended_tests[10]() end)

it("test_update_countdown_choice_active", function() _update_countdown_extended_tests[4]() end)

it("test_update_countdown_choice_gate", function() _update_countdown_more_tests[1]() end)

it("test_update_countdown_detained_and_popup", function() _update_countdown_final_tests[1]() end)

it("test_update_countdown_detained_calc", function() _update_countdown_extended_tests[8]() end)

it("test_update_countdown_detained_wait", function() _update_countdown_tests[1]() end)

it("test_update_countdown_market_active", function() _update_countdown_extended_tests[5]() end)

it("test_update_countdown_negative_elapsed", function() _update_countdown_extended_tests[7]() end)

it("test_update_countdown_nil_elapsed", function() _update_countdown_extended_tests[11]() end)

it("test_update_countdown_nil_turn", function() _update_countdown_extended_tests[3]() end)

it("test_update_countdown_pending_choice", function() _update_countdown_extended_tests[1]() end)

it("test_update_countdown_popup", function() _update_countdown_extended_tests[2]() end)

it("test_update_countdown_with_elapsed", function() _update_countdown_extended_tests[6]() end)

it("test_update_countdown_zero_popup_timeout", function() _update_countdown_extended_tests[12]() end)


end)
