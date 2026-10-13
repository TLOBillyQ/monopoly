require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())
local function assert_identity(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local function assert_equal(actual, expected, message)
  luassert.is.same(expected, actual, message)
end

TestPortsInit = {}

function TestPortsInit:test_loads_all_sub_port_modules_under_debug_hook()
  package.loaded["src.ui.ports.init"] = nil
  local ports = require("src.ui.ports.init")
  luassert.truthy(type(ports) == "table", "expected table")
end

function TestPortsInit:test_ui_sync_facade_forwards_gate_and_dirty_refresh_results()
  local ui_sync = require("src.ui.ports.ui_sync")
  local state = {
    ui = {
      input_blocked = false,
      popup_active = true,
      choice_active = true,
      market_active = false,
      popup_owner_index = 2,
      canvas_state = {},
    },
  }
  local common = {
    get_ui_state = function()
      return state.ui
    end,
  }
  local ports = ui_sync.build(common)

  assert_identity(ports.get_ui_state(state), state.ui)
  assert_identity(ports.refresh_from_dirty({ turn = {} }, state, { any = false, ui = false }), false)
  assert_identity(ports.is_input_blocked(state), false)
  assert_identity(ports.is_popup_active(state), true)
  assert_identity(ports.is_choice_active(state), true)
  assert_identity(ports.get_popup_owner_index(state), 2)
  local gate = ports.resolve_ui_gate(state)
  assert_identity(gate.input_blocked, false)
  assert_identity(gate.choice_active, true)
  assert_identity(gate.market_active, false)
  assert_identity(gate.popup_active, true)
  assert_identity(gate.popup_owner_index, 2)
  assert_identity(ports.set_input_blocked(state, true), true)
  assert_identity(state.ui.input_blocked, true)
  assert_identity(ports.set_input_blocked(state, true), false)
end

function TestPortsInit:test_set_input_blocked_returns_false_when_ui_state_is_nil()
  local ui_sync = require("src.ui.ports.ui_sync")
  local ports = ui_sync.build({ get_ui_state = function() return nil end })
  assert_identity(ports.set_input_blocked({}, true), false)
end

function TestPortsInit:test_resolve_choice_ui_state_forwards_the_choice_gate_state_result()
  local ui_sync = require("src.ui.ports.ui_sync")
  local choice_state = ui_sync._choice_state
  local ports = ui_sync.build({ get_ui_state = function() return nil end })
  local game = { turn = { phase = "wait_choice", current_player_index = 1 }, players = { { id = 1 } } }
  local state = { ui = {} }
  local choice = { id = "c1", route_key = "base_inline" }
  local direct = choice_state.resolve_gate_state(game, state, choice)
  local through = ports.resolve_choice_ui_state(game, state, choice)
  assert_identity(through, direct)
  luassert.is_not_nil(through)
end

local function _probe_subject(ui)
  local ui_sync = require("src.ui.ports.ui_sync")
  local state = { ui = ui }
  local ports = ui_sync.build({ get_ui_state = function() return state.ui end })
  local game = {
    turn = { phase = "wait_choice", current_player_index = 1 },
    players = { { id = 1 } },
  }
  local choice = { id = 6, kind = "landing_optional_effect", owner_role_id = 1, route_key = "secondary_confirm" }
  require("src.turn.output.player_control_snapshot").install(game)
  require("src.state.runtime").set_pending_choice(state, choice)
  return ports, game, state
end

local function _with_served_owner(fn)
  local support = require("test.support.shared_support")
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  support.with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function()
      return { { get_roleid = function() return 1 end } }
    end },
  }, fn)
end

function TestPortsInit:test_probe_choice_ui_missing_warns_with_full_gate_fields_when_the_screen_is_missing()
  -- #523 验收 pin（真缺屏仍告警）：expects_ui=true 且 open=false 时 probe
  -- 必须刷出带取证全字段的 warn。
  local core_runtime = require("src.state.runtime")
  local support = require("test.support.shared_support")
  local ports, game, state = _probe_subject({})
  local captured
  _with_served_owner(function()
    support.with_patches({
      { target = core_runtime, key = "log_once", value = function(_, ...) captured = { ... } end },
    }, function()
      ports.probe_choice_ui_missing(game, state)
    end)
  end)
  luassert.truthy(captured ~= nil, "a genuinely missing screen still warns")
  assert_equal(captured[2], "choice_runtime_without_ui_6", "the warn key carries the choice id")
  assert_equal(captured[9], "phase=wait_choice")
  assert_equal(captured[10], "served_owner=true")
  assert_equal(captured[11], "owner_computer_controlled=false")
  assert_equal(captured[12], "expects_ui=true")
  assert_equal(captured[13], "open=false")
end

function TestPortsInit:test_probe_choice_ui_missing_stays_silent_when_the_screen_is_open()
  -- #523 同帧误报回归 pin（生产链路）：屏已开（choice_active + 同
  -- screen_key）时 probe 不告警。
  local core_runtime = require("src.state.runtime")
  local support = require("test.support.shared_support")
  local ports, game, state = _probe_subject({
    choice_active = true,
    active_choice_screen_key = "secondary_confirm",
  })
  local captured
  _with_served_owner(function()
    support.with_patches({
      { target = core_runtime, key = "log_once", value = function(_, ...) captured = { ... } end },
    }, function()
      ports.probe_choice_ui_missing(game, state)
    end)
  end)
  luassert.truthy(captured == nil, "an opened screen never warns")
end


return TestPortsInit
