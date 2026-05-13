local P = require("support.presentation_action_status_prelude")
local tick_timeout = P.tick_timeout
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local _build_popup_view_state = P.build_popup_view_state
local runtime_port = require("src.ui.render.runtime_ui")
local market_view = require("src.ui.render.market")
local ui_view = require("src.ui.coord.ui_runtime")
local ui_events = require("src.ui.coord.ui_events")
local modal_presenter = require("src.ui.coord.modal")
local popup_renderer = require("src.ui.coord.popup")
local market_modal_renderer = require("src.ui.coord.market")
local event_log_ports_module = require("src.ui.ports.event_log")
local dice_nodes = require("src.ui.schema.dice")
local remote_choice_nodes = require("src.ui.schema.remote_choice")

describe("presentation_popup_and_modal_renderers", function()
  it("_test_popup_timeout_closes_even_when_input_blocked", function()
    local state, nodes, query_nodes = _build_popup_view_state({
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
    }, {
      set_texture_keep_size = function() end,
    })

    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
      { key = "all_roles", value = nil },
    }, function()
      state.gameplay_loop_ports = require("src.ui.ports").build(state)
      modal_presenter.push_popup(state, {
        title = "道具卡",
        body = "测试",
        image_ref = 2001,
        auto_close_seconds = 0.1,
      })
      state.ui.input_blocked = true
      tick_timeout.step_default_modal({}, state, 0.2)
    end)

    _assert_eq(state.ui.popup_active, false, "popup should auto close under input blocked")
    _assert_eq(nodes["卡牌展示屏"].visible, false, "popup root should hide after timeout")
  end)

  it("_test_popup_defer_policy_queues_and_replays_in_order", function()
    local popup_presenter = require("src.ui.coord.popup")
    local canvas = require("src.ui.coord.canvas_coordinator")
    local state = {
      ui = ui_view.build_ui_state(),
      ui_dirty = false,
    }
    local shown = {}
    local hide_calls = 0
    _with_patches({
      { target = popup_presenter, key = "show", value = function(_, payload)
        shown[#shown + 1] = payload and payload.title or ""
      end },
      { target = popup_presenter, key = "hide", value = function()
        hide_calls = hide_calls + 1
      end },
      { target = popup_presenter, key = "switch_popup_canvas", value = function() end },
      { target = canvas, key = "resolve_popup_return_canvas", value = function()
        return canvas.CANVAS_BASE
      end },
      { target = canvas, key = "resolve_canvas_after_popup", value = function()
        return canvas.CANVAS_BASE
      end },
    }, function()
      modal_presenter.push_popup(state, { title = "A", body = "A" })
      modal_presenter.push_popup(state, { title = "B", body = "B" }, { policy = "defer" })
      _assert_eq(#shown, 1, "defer popup should not replace active popup immediately")
      _assert_eq(state.ui.popup_queue and #state.ui.popup_queue or 0, 1, "defer popup should be queued")
      modal_presenter.close_popup(state)
    end)

    _assert_eq(hide_calls, 1, "close should hide current popup once")
    _assert_eq(#shown, 2, "queued popup should be shown after close")
    _assert_eq(shown[1], "A", "first popup title should be A")
    _assert_eq(shown[2], "B", "queued popup title should be B")
  end)

  it("_test_popup_close_keeps_roll_canvas_during_action_anim", function()
    local canvas = require("src.ui.coord.canvas_coordinator")
    local original_switch = canvas.switch
    local state = {
      ui = ui_view.build_ui_state(),
      ui_model = { current_player_id = 1 },
      game = {
        turn = {
          phase = "wait_action_anim",
          action_anim = { kind = "roll", seq = 2 },
        },
      },
    }
    local events = {}
    local switch_targets = {}
    state.ui.popup_active = true
    state.ui.popup_kind = "item_card"
    state.ui.popup_payload = { kind = "item_card", title = "道具卡", body = "测试" }
    state.ui.popup_return_canvas = remote_choice_nodes.canvas

    _with_patches({
      { target = popup_renderer, key = "hide", value = function() end },
      { target = ui_events, key = "send_to_all", value = function(event_name)
        events[#events + 1] = event_name
      end },
      { target = canvas, key = "switch", value = function(ui, target)
        switch_targets[#switch_targets + 1] = target
        return original_switch(ui, target)
      end },
    }, function()
      modal_presenter.close_popup(state)
    end)

    _assert_eq(switch_targets[#switch_targets], dice_nodes.canvas,
      "roll action anim should restore dice canvas after popup close")
    for _, event_name in ipairs(events) do
      assert(event_name ~= ui_events.hide[dice_nodes.canvas],
        "popup close during roll action anim must not hide dice canvas")
    end
  end)

  it("_test_popup_renderer_switch_popup_canvas_restores_client_role_nil", function()
    local canvas = require("src.ui.coord.canvas_coordinator")
    local role_ctx = require("src.ui.view.role_context")
    local manager = { client_role = { stale = true } }
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local role2 = { id = 2, get_roleid = function() return 2 end }

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
        fn(role1)
        fn(role2)
      end },
      { target = runtime_port, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime_port, key = "with_client_role", value = function(role, fn)
        local prev = manager.client_role
        manager.client_role = role
        local ok, err = pcall(fn)
        manager.client_role = prev
        if not ok then
          error(err)
        end
      end },
      { target = role_ctx, key = "resolve", value = function(role)
        return { can_operate = role == role1 }
      end },
      { target = canvas, key = "switch_for_role", value = function() end },
      { target = canvas, key = "switch", value = function() end },
    }, function()
      popup_renderer.switch_popup_canvas({
        ui = {},
        ui_model = {},
      }, "card", canvas.CANVAS_POPUP, canvas.CANVAS_BASE)
    end)

    _assert_eq(manager.client_role, nil, "popup renderer should restore client_role to nil")
  end)

  it("_test_market_modal_renderer_open_restores_client_role_nil", function()
    local canvas = require("src.ui.coord.canvas_coordinator")
    local role_ctx = require("src.ui.view.role_context")
    local manager = { client_role = { stale = true } }
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local role2 = { id = 2, get_roleid = function() return 2 end }

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
        fn(role1)
        fn(role2)
      end },
      { target = runtime_port, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime_port, key = "with_client_role", value = function(role, fn)
        local prev = manager.client_role
        manager.client_role = role
        local ok, err = pcall(fn)
        manager.client_role = prev
        if not ok then
          error(err)
        end
      end },
      { target = role_ctx, key = "resolve", value = function(role)
        return { can_operate = role == role1 }
      end },
      { target = canvas, key = "switch_for_role", value = function() end },
      { target = canvas, key = "switch", value = function() end },
      { target = market_view, key = "refresh_market", value = function() return true end },
    }, function()
      local state = {
        ui = {},
        ui_model = {},
        pending_choice_selected_option_id = nil,
      }
      local choice = {
        options = { { id = 1 } },
        allow_cancel = true,
        cancel_label = "取消",
      }
      market_modal_renderer.open_market_panel(state, choice, 10, nil)
    end)

    _assert_eq(manager.client_role, nil, "market modal renderer should restore client_role to nil")
  end)

  it("_test_event_log_ports_sync_restores_client_role_nil", function()
    local ui_event_state = require("src.ui.coord.event_state")
    local ui_view_service = require("src.ui.coord.ui_runtime")
    local manager = { client_role = { stale = true } }
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local role2 = { id = 2, get_roleid = function() return 2 end }
    local ports = event_log_ports_module.build({
      log_status = function() end,
    })

    _with_patches({
      { key = "UIManager", value = manager },
      { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
        fn(role1)
        fn(role2)
      end },
      { target = runtime_port, key = "set_client_role", value = function(role)
        manager.client_role = role
      end },
      { target = runtime_port, key = "with_client_role", value = function(role, fn)
        local prev = manager.client_role
        manager.client_role = role
        local ok, err = pcall(fn)
        manager.client_role = prev
        if not ok then
          error(err)
        end
      end },
      { target = runtime_port, key = "resolve_role_id", value = function(role)
        return role and role.id or nil
      end },
      { target = ui_event_state, key = "resolve_event_log_enabled", value = function(_, role_id)
        return role_id == 1
      end },
      { target = ui_view_service, key = "set_event_log_visible_for_role", value = function() end },
      { target = ui_view_service, key = "set_event_log_for_role", value = function() end },
    }, function()
      local state = {
        ui = ui_view.build_ui_state(),
        _debug_log_enabled_by_role = {},
        _debug_log_seq_by_role = {},
      }
      ports.sync_event_log(state)
    end)

    _assert_eq(manager.client_role, nil, "event log ports sync should restore client_role to nil")
  end)
end)
