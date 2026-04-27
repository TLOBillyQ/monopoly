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
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
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

local function _test_ui_event_router_action_log_toggle_uses_role_context()
  local function new_node()
    local node = {}
    function node:listen(_, cb)
      self._listener_cb = cb
      return {
        destroy = function()
          self._listener_cb = nil
        end,
      }
    end
    return node
  end

  local node_map = {
    ["基础_行动日志图标"] = new_node(),
  }
  local function query_nodes_by_name(name)
    local node = node_map[name]
    if not node then
      node = new_node()
      node_map[name] = node
    end
    return { node }
  end

  local state = {
    ui = ui_view.build_ui_state(),
    ui_model = { choice = nil },
    pending_choice_selected_option_id = nil,
    choice_visible_option_ids = nil,
  }
  local role = _build_role_with_events(101, {})

  _with_patches({
    { key = "all_roles", value = { role } },
    { target = host_runtime_bridge, key = "resolve_roles", value = function()
      return { role }
    end },
    { target = host_runtime_bridge, key = "resolve_role", value = function(role_id)
      if tostring(role_id) == "101" then
        return role
      end
      return nil
    end },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = query_nodes_by_name,
      client_role = nil,
    } },
  }, function()
    canvas_event_router.bind(state, function()
      return {}
    end)

    local role_id = role.get_roleid()
    _assert_eq(state.ui.debug_visible_by_role[role_id], nil, "action_log role flag should start nil")
    assert(type(node_map["基础_行动日志图标"]._listener_cb) == "function", "action_log button should bind click listener")
    local before = require("src.ui.ctl.event_state").resolve_debug_enabled(state, role_id)
    node_map["基础_行动日志图标"]._listener_cb({ role = role })
    local first_value = state.ui.debug_visible_by_role[role_id]
    _assert_eq(first_value, not before, "action_log toggle should invert role visibility")
    _assert_eq(UIManager.client_role, nil, "action_log toggle should restore client role")

    node_map["基础_行动日志图标"]._listener_cb({ role = role })
    local second_value = state.ui.debug_visible_by_role[role_id]
    assert(second_value ~= first_value, "action_log toggle should flip role visibility after second click")
    _assert_eq(UIManager.client_role, nil, "action_log toggle should restore client role after second click")
  end)
end

local function _test_ui_event_router_rejects_action_log_without_role()
  local function new_node()
    local node = {}
    function node:listen(_, cb)
      self._listener_cb = cb
      return {
        destroy = function()
          self._listener_cb = nil
        end,
      }
    end
    return node
  end

  local show_tip_calls = 0
  local node_map = {
    ["基础_行动日志图标"] = new_node(),
  }
  local local_role = _build_role_with_events("101", {})

  _with_patches({
    { key = "all_roles", value = { local_role } },
    { target = host_runtime_bridge, key = "resolve_roles", value = function()
      return { local_role }
    end },
    { target = host_runtime_bridge, key = "resolve_role", value = function(role_id)
      if tostring(role_id) == "101" then
        return local_role
      end
      return nil
    end },
    { key = "GameAPI", value = {
      get_role = function(role_id)
        if tostring(role_id) == "101" then
          return local_role
        end
        return nil
      end,
    } },
    { key = "GlobalAPI", value = { show_tips = function()
      show_tip_calls = show_tip_calls + 1
    end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = function(name)
        local node = node_map[name] or new_node()
        node_map[name] = node
        return { node }
      end,
      client_role = nil,
    } },
  }, function()
    local state = {
      ui = ui_view.build_ui_state(),
      ui_model = { choice = nil },
      pending_choice_selected_option_id = nil,
      choice_visible_option_ids = nil,
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map["基础_行动日志图标"]._listener_cb({})
    _assert_eq(state.ui.debug_visible_by_role[101], nil, "missing role click should not mutate role debug state")
  end)

  _assert_eq(show_tip_calls, 1, "missing role click should show tip once")
end

local function _test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing()
  local function new_node()
    local node = {}
    function node:listen(_, cb)
      self._listener_cb = cb
      return {
        destroy = function()
          self._listener_cb = nil
        end,
      }
    end
    return node
  end

  local show_tip_calls = 0
  local node_map = {
    ["基础_行动日志图标"] = new_node(),
  }
  local local_role = _build_role_with_events("101", {})

  _with_patches({
    { key = "all_roles", value = { local_role } },
    { target = host_runtime_bridge, key = "resolve_roles", value = function()
      return { local_role }
    end },
    { target = host_runtime_bridge, key = "resolve_role", value = function(role_id)
      if tostring(role_id) == "101" then
        return local_role
      end
      return nil
    end },
    { key = "GlobalAPI", value = { show_tips = function()
      show_tip_calls = show_tip_calls + 1
    end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = function(name)
        local node = node_map[name] or new_node()
        node_map[name] = node
        return { node }
      end,
      client_role = nil,
    } },
  }, function()
    local state = {
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = 2,
      },
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map["基础_行动日志图标"]._listener_cb({ role = local_role })
    _assert_eq(state.ui.debug_visible_by_role[101], true, "first click should enable local debug")
    node_map["基础_行动日志图标"]._listener_cb({})
    _assert_eq(state.ui.debug_visible_by_role[101], false, "second click without role should use cached local role")
    _assert_eq(state.ui.debug_visible_by_role[2], nil, "action_log should not fall back to current_player_id")
  end)

  _assert_eq(show_tip_calls, 0, "cached local role should avoid missing context tip")
end

local function _test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player()
  local always_show_nodes = require("src.ui.schema.base")

  local function new_node()
    local node = {}
    function node:listen(_, cb)
      self._listener_cb = cb
      return {
        destroy = function()
          self._listener_cb = nil
        end,
      }
    end
    return node
  end

  local show_tip_calls = 0
  local node_map = {
    [always_show_nodes.auto_button] = new_node(),
  }
  local game = _new_game()
  local local_role = {
    get_roleid = function()
      return "2"
    end,
  }
  local before_player1 = game.players[1].auto == true
  local before_player2 = game.players[2].auto == true
  local after_first_click_player2 = nil

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function()
      show_tip_calls = show_tip_calls + 1
    end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = function(name)
        local node = node_map[name] or new_node()
        node_map[name] = node
        return { node }
      end,
      client_role = nil,
    } },
  }, function()
    local state = {
      turn_action_port = {
        dispatch_action = function(game_ctx, state_ctx, action, opts)
          return dispatch.dispatch_action(game_ctx, state_ctx, action, opts)
        end,
        should_block_action = function()
          return false
        end,
      },
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = 1,
      },
    }
    canvas_event_router.bind(state, function()
      return game
    end)
    node_map[always_show_nodes.auto_button]._listener_cb({ role = local_role })
    after_first_click_player2 = game.players[2].auto == true
    state.ui_model.current_player_id = 1
    node_map[always_show_nodes.auto_button]._listener_cb({})
  end)

  _assert_eq(game.players[1].auto == true, before_player1, "auto clicks should not toggle current player state")
  _assert_eq(after_first_click_player2, not before_player2, "auto first click should toggle local player state")
  _assert_eq(game.players[2].auto == true, before_player2, "auto second click should toggle cached local role back")
  _assert_eq(show_tip_calls, 0, "auto cached local role should avoid missing context tip")
end

local function _test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys()
  local state = {
    ui = {
      debug_log_enabled_by_role = {
        ["1"] = true,
      },
    },
  }

  local enabled_by_int = require("src.ui.ctl.event_state").resolve_debug_enabled(state, 1)
  local enabled_by_string = require("src.ui.ctl.event_state").resolve_debug_enabled(state, "1")

  _assert_eq(enabled_by_int, true, "debug_enabled should read string key by int role_id")
  _assert_eq(enabled_by_string, true, "debug_enabled should read string key by string role_id")
end

return {
  name = "presentation_action_log_and_role_context",
  tests = {
    { name = "_test_ui_event_router_action_log_toggle_uses_role_context", run = _test_ui_event_router_action_log_toggle_uses_role_context },
    { name = "_test_ui_event_router_rejects_action_log_without_role", run = _test_ui_event_router_rejects_action_log_without_role },
    { name = "_test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing", run = _test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing },
    { name = "_test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player", run = _test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player },
    { name = "_test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys", run = _test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys },
  },
}
