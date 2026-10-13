-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
---@diagnostic disable: need-check-nil, different-requires, undefined-field

local gameplay_fixtures = require("test.support.gameplay_fixtures")


describe("TestTestPorts", function()

it("test_provides_safe_default_ports", function()
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

  luassert.is_nil(ports.modal.close_choice_modal())
  luassert.is_nil(ports.modal.open_choice_modal())
  luassert.is_nil(ports.modal.close_popup())
  luassert.is.equal( 0,ports.anim.play_move_anim())
  luassert.is.equal( 0,ports.anim.play_action_anim())
  luassert.is_nil(ports.anim.reset_status_3d())
  luassert.is_nil(ports.anim.sync_status_3d())
  luassert.is_nil(ports.ui_sync.apply_input_lock())
  luassert.is_nil(ports.ui_sync.step_choice_timeout())
  luassert.is_nil(ports.ui_sync.step_modal_timeout())
  luassert.is_nil(ports.ui_sync.update_countdown())
  luassert.is_nil(ports.ui_sync.build_model())
  luassert.is.equal( false,ports.ui_sync.refresh_from_dirty())
  luassert.is.equal( false,ports.ui_sync.follow_camera())
  luassert.is.equal( state.ui,ports.ui_sync.get_ui_state(state))
  luassert.is.equal( false,ports.ui_sync.is_input_blocked(state))
  luassert.is.equal( true,ports.ui_sync.is_popup_active(state))
  luassert.is.equal( true,ports.ui_sync.is_choice_active(state))
  luassert.is.equal( 2,ports.ui_sync.get_popup_owner_index(state))

  local gate = ports.ui_sync.resolve_ui_gate(state)
  luassert.is.equal( false,gate.input_blocked)
  luassert.is.equal( true,gate.choice_active)
  luassert.is.equal( false,gate.market_active)
  luassert.is.equal( true,gate.popup_active)
  luassert.is.equal( 7,gate.popup_seq)
  luassert.is.equal( 1.5,gate.popup_auto_close_seconds)
  luassert.is.equal( 2,gate.popup_owner_index)
  local empty_gate = ports.ui_sync.resolve_ui_gate(nil)
  luassert.is.equal( false,empty_gate.input_blocked)
  luassert.is.equal( false,empty_gate.choice_active)
  luassert.is.equal( false,empty_gate.market_active)
  luassert.is.equal( false,empty_gate.popup_active)
  -- 契约钉死：测试替身每次 resolve 返回全新 gate 表，先取的 gate
  -- 不被后续 resolve 就地改写（防断言重排后假绿/误诊）
  luassert.is_false(rawequal(gate, empty_gate))
  luassert.is.equal( true,gate.choice_active)
  luassert.is.equal( true,gate.popup_active)
  luassert.is.equal( 7,gate.popup_seq)

  luassert.is.equal( false,ports.ui_sync.set_input_blocked({}, true))
  luassert.is.equal( false,ports.ui_sync.set_input_blocked(state, false))
  luassert.is.equal( true,ports.ui_sync.set_input_blocked(state, true))
  luassert.is.equal( true,state.ui.input_blocked)
  luassert.is_nil(ports.debug.sync_event_log())
  luassert.is.equal( false,ports.debug.resolve_event_log_enabled())
  luassert.is.equal( 0,ports.clock.wall_now_seconds())
  luassert.is.equal( 3,ports.clock.wall_diff_seconds(5, 2))
  luassert.is.equal( 0,ports.clock.wall_diff_seconds(nil, nil))
  luassert.is.equal( 0,ports.clock.cpu_now_seconds())
  luassert.is.equal( 4,ports.clock.cpu_diff_seconds(9, 5))
  luassert.is.equal( 0,ports.clock.cpu_diff_seconds(nil, nil))
  luassert.is_nil(ports.state.apply_role_control_lock())
  luassert.is_nil(ports.state.install_event_handlers())
  luassert.is_nil(ports.state.on_bankruptcy_tiles_cleared())
end)

it("test_uses_game_api_wall_clock_functions_when_available", function()
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
    luassert.is.equal( 12,ports.clock.wall_now_seconds())
    luassert.is.equal( 9,ports.clock.wall_diff_seconds(4, 5))
  end)
  _G.GameAPI = previous
  if not ok then
    error(err)
  end
end)

it("test_forwards_explicit_overrides", function()
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

  luassert.is.equal( "close_choice",ports.modal.close_choice_modal())
  luassert.is.equal( "open_choice",ports.modal.open_choice_modal())
  luassert.is.equal( "close_popup",ports.modal.close_popup())
  luassert.is.equal( "move",ports.anim.play_move_anim())
  luassert.is.equal( "action",ports.anim.play_action_anim())
  luassert.is.equal( "reset_status",ports.anim.reset_status_3d())
  luassert.is.equal( "sync_status",ports.anim.sync_status_3d())
  luassert.is.equal( "input_lock",ports.ui_sync.apply_input_lock())
  luassert.is.equal( "choice_timeout",ports.ui_sync.step_choice_timeout())
  luassert.is.equal( "modal_timeout",ports.ui_sync.step_modal_timeout())
  luassert.is.equal( "countdown",ports.ui_sync.update_countdown())
  luassert.is.equal( "model",ports.ui_sync.build_model())
  luassert.is.equal( "refresh",ports.ui_sync.refresh_from_dirty())
  luassert.is.equal( "follow",ports.ui_sync.follow_camera())
  luassert.is.equal( "ui_state",ports.ui_sync.get_ui_state())
  luassert.is.equal( "input_blocked",ports.ui_sync.is_input_blocked())
  luassert.is.equal( "popup_active",ports.ui_sync.is_popup_active())
  luassert.is.equal( "choice_active",ports.ui_sync.is_choice_active())
  luassert.is.equal( "popup_owner",ports.ui_sync.get_popup_owner_index())
  luassert.is.equal( "gate",ports.ui_sync.resolve_ui_gate())
  luassert.is.equal( "set_input",ports.ui_sync.set_input_blocked())
  luassert.is.equal( "sync_log",ports.debug.sync_event_log())
  luassert.is.equal( "event_log_enabled",ports.debug.resolve_event_log_enabled())
  luassert.is.equal( "wall_now",ports.clock.wall_now_seconds())
  luassert.is.equal( "wall_diff",ports.clock.wall_diff_seconds())
  luassert.is.equal( "cpu_now",ports.clock.cpu_now_seconds())
  luassert.is.equal( "cpu_diff",ports.clock.cpu_diff_seconds())
  luassert.is.equal( "role_lock",ports.state.apply_role_control_lock())
  luassert.is.equal( "events",ports.state.install_event_handlers())
  luassert.is.equal( "bankruptcy",ports.state.on_bankruptcy_tiles_cleared())
end)


end)
