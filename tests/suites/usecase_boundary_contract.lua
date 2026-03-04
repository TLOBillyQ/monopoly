local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local turn_action_port = require("src.presentation.interaction.ui_intent_dispatcher.TurnActionPort")
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")
local runtime_ports = require("src.core.RuntimePorts")

local function _test_turn_action_port_resolve_defaults()
  local resolved = turn_action_port.resolve({}, nil)
  local res = resolved.dispatch_action({}, {}, { type = "noop" }, {})
  _assert_eq(res.status, "rejected", "default dispatch_action should reject")
  _assert_eq(resolved.should_block_action({}, { type = "noop" }), false, "default should_block_action should be false")
end

local function _test_turn_action_port_override_precedence()
  local calls = 0
  local state = {
    turn_action_port = {
      dispatch_action = function()
        calls = calls + 1
        return { status = "state" }
      end,
      should_block_action = function()
        return false
      end,
    },
  }
  local resolved = turn_action_port.resolve(state, {
    turn_action_port = {
      dispatch_action = function()
        calls = calls + 1
        return { status = "override" }
      end,
      should_block_action = function()
        return true
      end,
    },
  })
  local res = resolved.dispatch_action({}, {}, { type = "noop" }, {})
  _assert_eq(res.status, "override", "override port should take precedence over state port")
  _assert_eq(calls, 1, "dispatch should call override implementation once")
  _assert_eq(resolved.should_block_action({}, { type = "noop" }), true, "override should_block_action should take precedence")
end

local function _test_turn_action_port_normalize_auto_intent_contract()
  local state = {}
  local intent = { type = "ui_button", id = "auto", actor_role_id = 7 }
  _with_patches({
    { target = turn_action_port, key = "normalize_auto_intent", value = turn_action_port.normalize_auto_intent },
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local out = turn_action_port.normalize_auto_intent(state, intent)
    _assert_eq(out.type, "ui_button", "normalize should preserve type")
    _assert_eq(out.id, "auto", "normalize should preserve button id")
    _assert_eq(out.actor_role_id, 7, "normalize should preserve actor role fallback")
  end)
end

local function _test_turn_action_port_normalize_auto_intent_rejects_missing_actor()
  local state = {}
  local intent = { type = "ui_button", id = "auto" }
  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local out = turn_action_port.normalize_auto_intent(state, intent)
    _assert_eq(out, nil, "normalize should reject auto intent without actor context")
  end)
end

local function _test_gameplay_loop_clock_contract_split_sources()
  runtime_ports.reset_for_tests()
  local default_ports = gameplay_loop_ports.resolve(nil)
  local default_clock = default_ports.clock
  _assert_eq(default_clock.wall_now_seconds(), 0, "default wall clock should be environment-agnostic zero fallback")
  _assert_eq(default_clock.wall_diff_seconds(9, 7), 2, "default wall diff should stay arithmetic fallback")
  _assert_eq(default_clock.cpu_now_seconds(), 0, "default cpu clock should be environment-agnostic zero fallback")
  _assert_eq(default_clock.cpu_diff_seconds(9, 7), 2, "default cpu diff should remain arithmetic")

  runtime_ports.configure({
    wall_now_seconds = function() return 42 end,
    wall_diff_seconds = function(a, b) return (a - b) * 10 end,
    cpu_now_seconds = function() return 1.5 end,
    cpu_diff_seconds = function(a, b) return a - b end,
  })
  local injected_ports = gameplay_loop_ports.resolve({
    clock = {
      wall_now_seconds = function()
        return runtime_ports.wall_now_seconds()
      end,
      wall_diff_seconds = function(a, b)
        return runtime_ports.wall_diff_seconds(a, b)
      end,
      cpu_now_seconds = function()
        return runtime_ports.cpu_now_seconds()
      end,
      cpu_diff_seconds = function(a, b)
        return runtime_ports.cpu_diff_seconds(a, b)
      end,
    },
  })
  local clock = injected_ports.clock
  _assert_eq(clock.wall_now_seconds(), 42, "injected wall clock should be used when provided")
  _assert_eq(clock.wall_diff_seconds(9, 7), 20, "injected wall diff should preserve injected semantics")
  _assert_eq(clock.cpu_now_seconds(), 1.5, "injected cpu clock should be used when provided")
  _assert_eq(clock.cpu_diff_seconds(9, 7), 2, "injected cpu diff should remain arithmetic")
  runtime_ports.reset_for_tests()
end

return {
  name = "usecase_boundary_contract",
  tests = {
    { name = "turn_action_port_resolve_defaults", run = _test_turn_action_port_resolve_defaults },
    { name = "turn_action_port_override_precedence", run = _test_turn_action_port_override_precedence },
    { name = "turn_action_port_normalize_auto_intent_contract", run = _test_turn_action_port_normalize_auto_intent_contract },
    { name = "turn_action_port_normalize_auto_intent_rejects_missing_actor", run = _test_turn_action_port_normalize_auto_intent_rejects_missing_actor },
    { name = "gameplay_loop_clock_contract_split_sources", run = _test_gameplay_loop_clock_contract_split_sources },
  },
}
