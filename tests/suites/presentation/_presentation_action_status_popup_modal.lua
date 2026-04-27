-- luacheck: ignore 211
local support = require("support.presentation_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local gameplay_loop = support.gameplay_loop
local turn_move = support.turn_move
local event_handlers = require("src.ui.ctl.event_handlers")
local paid_currency_bridge = require("src.rules.commerce.paid_currency_bridge")
local dispatch = require("src.turn.actions.action_dispatcher")
local runtime_port = require("src.ui.render.runtime_ui")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local choice_openers = require("src.ui.ctl.choice_screens.openers")
local market_view = require("src.ui.render.market")
local market_layout = require("src.ui.schema.market_layout")
local canvas_event_router = require("src.ui.ctl.canvas_event_router")
local ui_view = require("src.ui.ctl.ui_runtime")
local modal_presenter = require("src.ui.ctl.modal")
local ui_status_3d_layer = require("src.ui.render.status3d")
local action_anim = require("src.ui.render.action_anim")
local move_anim = require("src.ui.render.move_anim")
local runtime_cls = require("src.turn.loop.scheduler_runtime")
local turn_effects = require("src.ui.wid.turn_effects")
local popup_renderer = require("src.ui.ctl.popup")
local market_modal_renderer = require("src.ui.ctl.market")
local debug_ports_module = require("src.ui.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock")
local ui_touch_policy = require("src.ui.input.touch")
local ui_choice_route_policy = require("src.ui.input.choice_route")
local logger = require("src.core.utils.logger")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local target_pick = require("src.config.gameplay.target_pick")
local host_runtime = require("src.host")
local host_runtime_bridge = require("src.ui.host_bridge")
local runtime_state = require("src.ui.state")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
local vec3 = require("fixtures.vec3")

local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

local _wrap_ui_refs = support.wrap_ui_refs
local _build_popup_view_state = support.build_popup_view_state
local _build_role_with_events = support.build_role_with_events
local _has_event = support.has_event
local _build_choice_modal_state = support.build_choice_modal_state
local _build_target_pick_env = support.build_target_pick_env

local function _with_target_pick_runtime(env, fn)
  local marker_seq = 0
  local created_markers = {}
  local current_hit = nil
  local owner_role = {
    get_ctrl_unit = function()
      return {
        get_position = function()
          return vec3.with_sub_length(0, 0, 0)
        end,
      }
    end,
  }
  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = env.query_nodes, EVENT = { CLICK = "CLICK" } } },
    { key = "all_roles", value = nil },
    { target = host_runtime, key = "resolve_role", value = function()
      return owner_role
    end },
    { target = host_runtime, key = "build_camera_ray", value = function()
      return { start_pos = vec3.with_sub_length(0, 1, 0), end_pos = vec3.with_sub_length(0, 1, 20) }
    end },
    { target = host_runtime, key = "pick_first_hit_unit", value = function()
      return current_hit
    end },
    { target = host_runtime, key = "create_unit_with_scale", value = function(_, pos)
      marker_seq = marker_seq + 1
      local marker = {
        _unit_id = 3000 + marker_seq,
        _position = pos,
      }
      created_markers[#created_markers + 1] = marker
      return marker
    end },
    { target = host_runtime, key = "destroy_unit", value = function(marker)
      marker._destroyed = true
    end },
    { target = host_runtime, key = "get_unit_id", value = function(unit)
      return unit and unit._unit_id or nil
    end },
    { target = host_runtime, key = "resolve_hit_position", value = function(hit)
      return hit and hit.hit_pos or nil
    end },
  }, function()
    fn({
      set_hit = function(unit_id, hit_pos)
        if unit_id == nil then
          current_hit = nil
          return
        end
        current_hit = {
          unit = { _unit_id = unit_id },
          hit = { hit_pos = hit_pos },
        }
      end,
      created_markers = created_markers,
    })
  end)
end

local function _test_popup_timeout_closes_even_when_input_blocked()
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
end

local function _test_popup_defer_policy_queues_and_replays_in_order()
  local popup_presenter = require("src.ui.ctl.popup")
  local canvas = require("src.ui.ctl.canvas_coordinator")
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
    { target = popup_presenter, key = "switch_canvas", value = function() end },
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
end

local function _test_popup_renderer_switch_popup_canvas_restores_client_role_nil()
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local role_ctx = require("src.ui.pres.role_context")
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
end

local function _test_market_modal_renderer_open_restores_client_role_nil()
  local canvas = require("src.ui.ctl.canvas_coordinator")
  local role_ctx = require("src.ui.pres.role_context")
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
end

local function _test_debug_ports_sync_restores_client_role_nil()
  local ui_event_state = require("src.ui.ctl.event_state")
  local ui_view_service = require("src.ui.ctl.ui_runtime")
  local manager = { client_role = { stale = true } }
  local role1 = { id = 1, get_roleid = function() return 1 end }
  local role2 = { id = 2, get_roleid = function() return 2 end }
  local ports = debug_ports_module.build({
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
    { target = ui_event_state, key = "resolve_debug_enabled", value = function(_, role_id)
      return role_id == 1
    end },
    { target = ui_view_service, key = "set_debug_visible_for_role", value = function() end },
    { target = ui_view_service, key = "set_debug_log_for_role", value = function() end },
  }, function()
    local state = {
      ui = ui_view.build_ui_state(),
      _debug_log_enabled_by_role = {},
      _debug_log_seq_by_role = {},
    }
    ports.sync_debug_log(state)
  end)

  _assert_eq(manager.client_role, nil, "debug ports sync should restore client_role to nil")
end

return {
  name = "presentation_popup_and_modal_renderers",
  tests = {
    { name = "_test_popup_timeout_closes_even_when_input_blocked", run = _test_popup_timeout_closes_even_when_input_blocked },
    { name = "_test_popup_defer_policy_queues_and_replays_in_order", run = _test_popup_defer_policy_queues_and_replays_in_order },
    { name = "_test_popup_renderer_switch_popup_canvas_restores_client_role_nil", run = _test_popup_renderer_switch_popup_canvas_restores_client_role_nil },
    { name = "_test_market_modal_renderer_open_restores_client_role_nil", run = _test_market_modal_renderer_open_restores_client_role_nil },
    { name = "_test_debug_ports_sync_restores_client_role_nil", run = _test_debug_ports_sync_restores_client_role_nil },
  },
}
