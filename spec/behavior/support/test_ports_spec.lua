local test_ports = require("spec.support.scenario_suites.shared.test_ports")

describe("scenario test_ports fixture", function()
  it("provides safe default ports", function()
    local ports = test_ports.build()
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

    assert.is_nil(ports.modal.close_choice_modal())
    assert.is_nil(ports.modal.open_choice_modal())
    assert.is_nil(ports.modal.close_popup())
    assert.equals(0, ports.anim.play_move_anim())
    assert.equals(0, ports.anim.play_action_anim())
    assert.is_nil(ports.anim.reset_status_3d())
    assert.is_nil(ports.anim.sync_status_3d())
    assert.is_nil(ports.ui_sync.apply_input_lock())
    assert.is_nil(ports.ui_sync.step_choice_timeout())
    assert.is_nil(ports.ui_sync.step_modal_timeout())
    assert.is_nil(ports.ui_sync.update_countdown())
    assert.is_nil(ports.ui_sync.build_model())
    assert.equals(false, ports.ui_sync.refresh_from_dirty())
    assert.equals(false, ports.ui_sync.follow_camera())
    assert.equals(state.ui, ports.ui_sync.get_ui_state(state))
    assert.equals(false, ports.ui_sync.is_input_blocked(state))
    assert.equals(true, ports.ui_sync.is_popup_active(state))
    assert.equals(true, ports.ui_sync.is_choice_active(state))
    assert.equals(2, ports.ui_sync.get_popup_owner_index(state))

    local gate = ports.ui_sync.resolve_ui_gate(state)
    assert.equals(false, gate.input_blocked)
    assert.equals(true, gate.choice_active)
    assert.equals(false, gate.market_active)
    assert.equals(true, gate.popup_active)
    assert.equals(7, gate.popup_seq)
    assert.equals(1.5, gate.popup_auto_close_seconds)
    assert.equals(2, gate.popup_owner_index)
    local empty_gate = ports.ui_sync.resolve_ui_gate(nil)
    assert.equals(false, empty_gate.input_blocked)
    assert.equals(false, empty_gate.choice_active)
    assert.equals(false, empty_gate.market_active)
    assert.equals(false, empty_gate.popup_active)

    assert.equals(false, ports.ui_sync.set_input_blocked({}, true))
    assert.equals(false, ports.ui_sync.set_input_blocked(state, false))
    assert.equals(true, ports.ui_sync.set_input_blocked(state, true))
    assert.equals(true, state.ui.input_blocked)
    assert.is_nil(ports.debug.log_status())
    assert.is_nil(ports.debug.sync_event_log())
    assert.equals(false, ports.debug.resolve_event_log_enabled())
    assert.equals(0, ports.clock.wall_now_seconds())
    assert.equals(3, ports.clock.wall_diff_seconds(5, 2))
    assert.equals(0, ports.clock.wall_diff_seconds(nil, nil))
    assert.equals(0, ports.clock.cpu_now_seconds())
    assert.equals(4, ports.clock.cpu_diff_seconds(9, 5))
    assert.equals(0, ports.clock.cpu_diff_seconds(nil, nil))
    assert.is_nil(ports.state.apply_role_control_lock())
    assert.is_nil(ports.state.install_event_handlers())
    assert.is_nil(ports.state.on_bankruptcy_tiles_cleared())
  end)

  it("uses GameAPI wall clock functions when available", function()
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
      local ports = test_ports.build()
      assert.equals(12, ports.clock.wall_now_seconds())
      assert.equals(9, ports.clock.wall_diff_seconds(4, 5))
    end)
    _G.GameAPI = previous
    if not ok then
      error(err)
    end
  end)

  it("forwards explicit overrides", function()
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
      log_status = function() return "log_status" end,
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
    local ports = test_ports.build(overrides)

    assert.equals("close_choice", ports.modal.close_choice_modal())
    assert.equals("open_choice", ports.modal.open_choice_modal())
    assert.equals("close_popup", ports.modal.close_popup())
    assert.equals("move", ports.anim.play_move_anim())
    assert.equals("action", ports.anim.play_action_anim())
    assert.equals("reset_status", ports.anim.reset_status_3d())
    assert.equals("sync_status", ports.anim.sync_status_3d())
    assert.equals("input_lock", ports.ui_sync.apply_input_lock())
    assert.equals("choice_timeout", ports.ui_sync.step_choice_timeout())
    assert.equals("modal_timeout", ports.ui_sync.step_modal_timeout())
    assert.equals("countdown", ports.ui_sync.update_countdown())
    assert.equals("model", ports.ui_sync.build_model())
    assert.equals("refresh", ports.ui_sync.refresh_from_dirty())
    assert.equals("follow", ports.ui_sync.follow_camera())
    assert.equals("ui_state", ports.ui_sync.get_ui_state())
    assert.equals("input_blocked", ports.ui_sync.is_input_blocked())
    assert.equals("popup_active", ports.ui_sync.is_popup_active())
    assert.equals("choice_active", ports.ui_sync.is_choice_active())
    assert.equals("popup_owner", ports.ui_sync.get_popup_owner_index())
    assert.equals("gate", ports.ui_sync.resolve_ui_gate())
    assert.equals("set_input", ports.ui_sync.set_input_blocked())
    assert.equals("log_status", ports.debug.log_status())
    assert.equals("sync_log", ports.debug.sync_event_log())
    assert.equals("event_log_enabled", ports.debug.resolve_event_log_enabled())
    assert.equals("wall_now", ports.clock.wall_now_seconds())
    assert.equals("wall_diff", ports.clock.wall_diff_seconds())
    assert.equals("cpu_now", ports.clock.cpu_now_seconds())
    assert.equals("cpu_diff", ports.clock.cpu_diff_seconds())
    assert.equals("role_lock", ports.state.apply_role_control_lock())
    assert.equals("events", ports.state.install_event_handlers())
    assert.equals("bankruptcy", ports.state.on_bankruptcy_tiles_cleared())
  end)
end)
