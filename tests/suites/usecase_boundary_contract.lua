local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local turn_action_port = require("src.presentation.interaction.ui_intent_dispatcher.TurnActionPort")
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")

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

local function _test_gameplay_loop_clock_contract_split_sources()
  _with_patches({
    { key = "GameAPI", value = {
      get_timestamp = function() return 42 end,
      get_timestamp_diff = function(a, b) return (a - b) * 10 end,
    } },
    { target = os, key = "clock", value = function() return 1.5 end },
  }, function()
    local ports = gameplay_loop_ports.resolve(nil)
    local clock = ports.clock
    _assert_eq(clock.wall_now_seconds(), 42, "wall clock must use GameAPI timestamp")
    _assert_eq(clock.wall_diff_seconds(9, 7), 20, "wall diff must use GameAPI diff")
    _assert_eq(clock.cpu_now_seconds(), 1.5, "cpu clock must use os.clock")
    _assert_eq(clock.cpu_diff_seconds(9, 7), 2, "cpu diff must remain arithmetic")
  end)
end

return {
  name = "usecase_boundary_contract",
  tests = {
    { name = "turn_action_port_resolve_defaults", run = _test_turn_action_port_resolve_defaults },
    { name = "turn_action_port_override_precedence", run = _test_turn_action_port_override_precedence },
    { name = "turn_action_port_normalize_auto_intent_contract", run = _test_turn_action_port_normalize_auto_intent_contract },
    { name = "gameplay_loop_clock_contract_split_sources", run = _test_gameplay_loop_clock_contract_split_sources },
  },
}
