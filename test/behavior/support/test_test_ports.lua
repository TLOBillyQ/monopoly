---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local gameplay_fixtures = require("test.support.gameplay_fixtures")

-- 原生 LuaUnit 迁移:describe 拍平为单个 Test* 类,断言词汇从 luassert 兼容层
-- 切到 lu.assertXxx,用例数与改写前一一对应(3 例)。get_ui_state 默认替身返回
-- state.ui 本身(identity),故 equals → assertIs 等价。

TestTestPorts = {}

function TestTestPorts:test_provides_safe_default_ports()
  local ports = gameplay_fixtures.build_test_ports()
  local state = {
    ui = {
      input_blocked = false,
      popup_active = true,
      choice_active = true,
      market_active = false,
      popup_seq = 7,
      popup_owner_index = 2,
      popup_payload = { auto_close_seconds = 1.5 },
    },
  }

  lu.assertNil(ports.modal.close_choice_modal())
  lu.assertNil(ports.modal.open_choice_modal())
  lu.assertNil(ports.modal.close_popup())
  lu.assertIs(ports.anim.play_move_anim(), 0)
  lu.assertIs(ports.anim.play_action_anim(), 0)
  lu.assertNil(ports.anim.reset_status_3d())
  lu.assertNil(ports.anim.sync_status_3d())
  lu.assertNil(ports.ui_sync.apply_input_lock())
  lu.assertNil(ports.ui_sync.step_choice_timeout())
  lu.assertNil(ports.ui_sync.step_modal_timeout())
  lu.assertNil(ports.ui_sync.update_countdown())
  lu.assertNil(ports.ui_sync.build_model())
  lu.assertIs(ports.ui_sync.refresh_from_dirty(), false)
  lu.assertIs(ports.ui_sync.follow_camera(), false)
  lu.assertIs(ports.ui_sync.get_ui_state(state), state.ui)
  lu.assertIs(ports.ui_sync.is_input_blocked(state), false)
  lu.assertIs(ports.ui_sync.is_popup_active(state), true)
  lu.assertIs(ports.ui_sync.is_choice_active(state), true)
  lu.assertIs(ports.ui_sync.get_popup_owner_index(state), 2)

  local gate = ports.ui_sync.resolve_ui_gate(state)
  lu.assertIs(gate.input_blocked, false)
  lu.assertIs(gate.choice_active, true)
  lu.assertIs(gate.market_active, false)
  lu.assertIs(gate.popup_active, true)
  lu.assertIs(gate.popup_seq, 7)
  lu.assertIs(gate.popup_auto_close_seconds, 1.5)
  lu.assertIs(gate.popup_owner_index, 2)
  local empty_gate = ports.ui_sync.resolve_ui_gate(nil)
  lu.assertIs(empty_gate.input_blocked, false)
  lu.assertIs(empty_gate.choice_active, false)
  lu.assertIs(empty_gate.market_active, false)
  lu.assertIs(empty_gate.popup_active, false)
  -- 契约钉死：测试替身每次 resolve 返回全新 gate 表，先取的 gate
  -- 不被后续 resolve 就地改写（防断言重排后假绿/误诊）
  lu.assertFalse(rawequal(gate, empty_gate))
  lu.assertIs(gate.choice_active, true)
  lu.assertIs(gate.popup_active, true)
  lu.assertIs(gate.popup_seq, 7)

  lu.assertIs(ports.ui_sync.set_input_blocked({}, true), false)
  lu.assertIs(ports.ui_sync.set_input_blocked(state, false), false)
  lu.assertIs(ports.ui_sync.set_input_blocked(state, true), true)
  lu.assertIs(state.ui.input_blocked, true)
  lu.assertNil(ports.debug.sync_event_log())
  lu.assertIs(ports.debug.resolve_event_log_enabled(), false)
  lu.assertIs(ports.clock.wall_now_seconds(), 0)
  lu.assertIs(ports.clock.wall_diff_seconds(5, 2), 3)
  lu.assertIs(ports.clock.wall_diff_seconds(nil, nil), 0)
  lu.assertIs(ports.clock.cpu_now_seconds(), 0)
  lu.assertIs(ports.clock.cpu_diff_seconds(9, 5), 4)
  lu.assertIs(ports.clock.cpu_diff_seconds(nil, nil), 0)
  lu.assertNil(ports.state.apply_role_control_lock())
  lu.assertNil(ports.state.install_event_handlers())
  lu.assertNil(ports.state.on_bankruptcy_tiles_cleared())
end

function TestTestPorts:test_uses_game_api_wall_clock_functions_when_available()
  local previous = rawget(_G, "GameAPI")
  _G.GameAPI = {
    get_timestamp = function()
      return 12
    end,
    get_timestamp_diff = function(left, right)
      return left + right
    end,
  }

  local ok, err = pcall(function()
    local ports = gameplay_fixtures.build_test_ports()
    lu.assertIs(ports.clock.wall_now_seconds(), 12)
    lu.assertIs(ports.clock.wall_diff_seconds(4, 5), 9)
  end)
  _G.GameAPI = previous
  if not ok then
    error(err)
  end
end

function TestTestPorts:test_forwards_explicit_overrides()
  local overrides = {
    close_choice_modal = function() return "close_choice" end,
    open_choice_modal = function() return "open_choice" end,
    close_popup = function() return "close_popup" end,
    play_move_anim = function() return "move" end,
    play_action_anim = function() return "action" end,
    reset_status_3d = function() return "reset_status" end,
    sync_status_3d = function() return "sync_status" end,
    apply_input_lock = function() return "input_lock" end,
    step_choice_timeout = function() return "choice_timeout" end,
    step_modal_timeout = function() return "modal_timeout" end,
    update_countdown = function() return "countdown" end,
    build_model = function() return "model" end,
    refresh_from_dirty = function() return "refresh" end,
    follow_camera = function() return "follow" end,
    get_ui_state = function() return "ui_state" end,
    is_input_blocked = function() return "input_blocked" end,
    is_popup_active = function() return "popup_active" end,
    is_choice_active = function() return "choice_active" end,
    get_popup_owner_index = function() return "popup_owner" end,
    resolve_ui_gate = function() return "gate" end,
    set_input_blocked = function() return "set_input" end,
    sync_event_log = function() return "sync_log" end,
    resolve_event_log_enabled = function() return "event_log_enabled" end,
    wall_now_seconds = function() return "wall_now" end,
    wall_diff_seconds = function() return "wall_diff" end,
    cpu_now_seconds = function() return "cpu_now" end,
    cpu_diff_seconds = function() return "cpu_diff" end,
    apply_role_control_lock = function() return "role_lock" end,
    install_event_handlers = function() return "events" end,
    on_bankruptcy_tiles_cleared = function() return "bankruptcy" end,
  }
  local ports = gameplay_fixtures.build_test_ports(overrides)

  lu.assertIs(ports.modal.close_choice_modal(), "close_choice")
  lu.assertIs(ports.modal.open_choice_modal(), "open_choice")
  lu.assertIs(ports.modal.close_popup(), "close_popup")
  lu.assertIs(ports.anim.play_move_anim(), "move")
  lu.assertIs(ports.anim.play_action_anim(), "action")
  lu.assertIs(ports.anim.reset_status_3d(), "reset_status")
  lu.assertIs(ports.anim.sync_status_3d(), "sync_status")
  lu.assertIs(ports.ui_sync.apply_input_lock(), "input_lock")
  lu.assertIs(ports.ui_sync.step_choice_timeout(), "choice_timeout")
  lu.assertIs(ports.ui_sync.step_modal_timeout(), "modal_timeout")
  lu.assertIs(ports.ui_sync.update_countdown(), "countdown")
  lu.assertIs(ports.ui_sync.build_model(), "model")
  lu.assertIs(ports.ui_sync.refresh_from_dirty(), "refresh")
  lu.assertIs(ports.ui_sync.follow_camera(), "follow")
  lu.assertIs(ports.ui_sync.get_ui_state(), "ui_state")
  lu.assertIs(ports.ui_sync.is_input_blocked(), "input_blocked")
  lu.assertIs(ports.ui_sync.is_popup_active(), "popup_active")
  lu.assertIs(ports.ui_sync.is_choice_active(), "choice_active")
  lu.assertIs(ports.ui_sync.get_popup_owner_index(), "popup_owner")
  lu.assertIs(ports.ui_sync.resolve_ui_gate(), "gate")
  lu.assertIs(ports.ui_sync.set_input_blocked(), "set_input")
  lu.assertIs(ports.debug.sync_event_log(), "sync_log")
  lu.assertIs(ports.debug.resolve_event_log_enabled(), "event_log_enabled")
  lu.assertIs(ports.clock.wall_now_seconds(), "wall_now")
  lu.assertIs(ports.clock.wall_diff_seconds(), "wall_diff")
  lu.assertIs(ports.clock.cpu_now_seconds(), "cpu_now")
  lu.assertIs(ports.clock.cpu_diff_seconds(), "cpu_diff")
  lu.assertIs(ports.state.apply_role_control_lock(), "role_lock")
  lu.assertIs(ports.state.install_event_handlers(), "events")
  lu.assertIs(ports.state.on_bankruptcy_tiles_cleared(), "bankruptcy")
end


return TestTestPorts
