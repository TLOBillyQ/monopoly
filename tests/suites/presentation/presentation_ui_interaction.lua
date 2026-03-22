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
local debug_ports_module = require("src.presentation.runtime.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local gameplay_rules = require("src.config.gameplay.rules")
local host_runtime = require("src.host.eggy")
local runtime_state = require("src.state.state_access.runtime_state")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
local raycast = require("src.host.eggy.raycast")
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


local function _test_ui_intent_dispatcher_market_select_updates_ui_only()
  local selected_option = nil
  local state = {
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local game = {}

  _with_patches({
    { target = market_modal_renderer, key = "select_market_option", value = function(_, option_id)
      selected_option = option_id
    end },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "market_select",
      option_id = 99,
    }, {})
  end)

  _assert_eq(selected_option, 99, "market_select should update selected option")
end

local function _test_ui_intent_dispatcher_popup_confirm_closes_popup()
  local closed = 0
  local state = {
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local game = {}

  _with_patches({
    { target = modal_presenter, key = "close_popup", value = function()
      closed = closed + 1
    end },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "popup_confirm",
    }, {})
  end)

  _assert_eq(closed, 1, "popup_confirm should close popup once")
end

local function _test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context()
  local state = {
    ui = ui_view.build_ui_state(),
  }
  local game = {}
  local role = _build_role_with_events(101, {})
  _with_patches({
    { key = "all_roles", value = { role } },
    { key = "GameAPI", value = {
      get_role = function(role_id)
        if role_id == 101 then
          return role
        end
        return nil
      end,
    } },
    { key = "UIManager", value = {
      client_role = nil,
      query_nodes_by_name = function()
        return { { visible = false } }
      end,
    } },
    { target = gameplay_rules, key = "debug_log_enabled", value = false },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "toggle_action_log",
      actor_role_id = 101,
    }, {})
    _assert_eq(state.ui.debug_visible_by_role[101], true, "toggle_action_log should enable action_log for actor role")
    _assert_eq(UIManager.client_role, nil, "toggle_action_log should restore client role")

    ui_intent_dispatcher.dispatch(state, game, {
      type = "toggle_action_log",
      actor_role_id = 101,
    }, {})
    _assert_eq(state.ui.debug_visible_by_role[101], false, "toggle_action_log second click should disable action_log")
    _assert_eq(UIManager.client_role, nil, "toggle_action_log second click should restore client role")
  end)
end

local function _test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game()
  local dispatch_calls = 0
  local state = {
    ui = ui_view.build_ui_state(),
    turn_action_port = {
      dispatch_action = function()
        dispatch_calls = dispatch_calls + 1
      end,
      should_block_action = function()
        return true
      end,
    },
  }
  local role = _build_role_with_events(101, {})

  _with_patches({
    { key = "all_roles", value = { role } },
    { key = "GameAPI", value = {
      get_role = function(role_id)
        if role_id == 101 then
          return role
        end
        return nil
      end,
    } },
    { key = "UIManager", value = {
      client_role = nil,
      query_nodes_by_name = function()
        return { { visible = false } }
      end,
    } },
    { target = gameplay_rules, key = "debug_log_enabled", value = false },
  }, function()
    ui_intent_dispatcher.dispatch(state, nil, {
      type = "toggle_action_log",
      actor_role_id = 101,
    }, {})
  end)

  _assert_eq(dispatch_calls, 0, "toggle_action_log should not dispatch gameplay action")
  _assert_eq(state.ui.debug_visible_by_role[101], true, "toggle_action_log should bypass block without game")
end

local function _test_ui_intent_dispatcher_toggle_action_log_resolves_role_via_game_api()
  local events = {}
  local state = {
    ui = ui_view.build_ui_state(),
  }
  local game = {}
  local role = _build_role_with_events(101, events)

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GameAPI", value = {
      get_role = function(role_id)
        if role_id == 101 then
          return role
        end
        return nil
      end,
    } },
    { key = "UIManager", value = {
      client_role = nil,
      query_nodes_by_name = function()
        return { { visible = false } }
      end,
    } },
    { target = gameplay_rules, key = "debug_log_enabled", value = false },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "toggle_action_log",
      actor_role_id = 101,
    }, {})
  end)

  assert(_has_event(events, "显示调试屏"), "toggle_action_log should send 显示调试屏 via GameAPI role fallback")
  _assert_eq(state.ui.debug_visible_by_role[101], true, "toggle_action_log should enable role debug state")
end

local function _test_ui_intent_dispatcher_toggle_action_log_warns_when_role_event_channel_missing()
  local warn_count = 0
  local state = {
    ui = ui_view.build_ui_state(),
  }
  local game = {}
  local ok = false

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GameAPI", value = {} },
    { key = "UIManager", value = {
      client_role = nil,
      query_nodes_by_name = function()
        return { { visible = false } }
      end,
    } },
    { target = gameplay_rules, key = "debug_log_enabled", value = false },
    { target = logger, key = "warn", value = function(...)
      if tostring((...)) == "toggle_action_log missing role event channel:" then
        warn_count = warn_count + 1
      end
    end },
  }, function()
    ok = pcall(function()
      ui_intent_dispatcher.dispatch(state, game, {
        type = "toggle_action_log",
        actor_role_id = 101,
      }, {})
    end)
  end)

  assert(ok == true, "toggle_action_log should not crash when role event channel is missing")
  _assert_eq(state.ui.debug_visible_by_role[101], true, "toggle_action_log should still toggle debug state")
  _assert_eq(warn_count, 1, "toggle_action_log should warn once when role cannot send ui event")
end

local function _test_ui_intent_dispatcher_auto_button_keeps_intent_actor_role_id()
  local captured = nil
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        captured = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local game = {}
  local local_role = {
    get_roleid = function()
      return 1
    end,
  }

  _with_patches({
    { key = "UIManager", value = { client_role = local_role } },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "ui_button",
      id = "auto",
      actor_role_id = 2,
    }, {})
  end)

  _assert_eq(captured and captured.actor_role_id, 2, "auto dispatch should keep explicit actor role id")
end

local function _test_ui_intent_dispatcher_auto_button_falls_back_to_intent_actor_when_local_missing()
  local captured = nil
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        captured = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local game = {}

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "ui_button",
      id = "auto",
      actor_role_id = 2,
    }, {})
  end)

  _assert_eq(captured and captured.actor_role_id, 2, "auto dispatch should fallback to intent actor when local role missing")
end

local function _test_ui_intent_dispatcher_auto_button_rejects_when_actor_missing()
  local captured = nil
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        captured = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local game = {}

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "ui_button",
      id = "auto",
    }, {})
  end)

  _assert_eq(captured, nil, "auto dispatch should be rejected when actor role is missing")
end

local function _test_ui_intent_dispatcher_auto_button_honors_intent_actor_during_other_turn()
  local g = _new_game()
  g.turn.current_player_index = 1
  local state = {
    turn_action_port = {
      dispatch_action = function(game, state_ctx, action, opts)
        return dispatch.dispatch_action(game, state_ctx, action, opts)
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local local_role = {
    get_roleid = function()
      return 2
    end,
  }
  local before_1 = g.players[1].auto
  local before_2 = g.players[2].auto

  _with_patches({
    { key = "UIManager", value = { client_role = local_role } },
  }, function()
    ui_intent_dispatcher.dispatch(state, g, {
      type = "ui_button",
      id = "auto",
      actor_role_id = 1,
    }, {})
  end)

  _assert_eq(g.players[1].auto, not before_1, "auto click should toggle explicit actor role auto state")
  _assert_eq(g.players[2].auto, before_2, "auto click should not be rewritten to local role")
end


local function _test_ui_event_router_injects_actor_for_next_with_current_player_fallback()
  local base_nodes = require("src.ui.schema.base_nodes")

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

  local captured = {}
  local show_tip_calls = 0
  local node_map = {
    [base_nodes.action_button] = new_node(),
  }

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
        dispatch_action = function(_, _, action)
          captured[#captured + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = "2",
      },
    }
    _bind_ui_runtime(state)
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map[base_nodes.action_button]._listener_cb({})
  end)

  _assert_eq(show_tip_calls, 0, "next click with current_player fallback should not show tip")
  _assert_eq(captured[1] and captured[1].type, "ui_button", "next click should dispatch ui_button")
  _assert_eq(captured[1] and captured[1].id, "next", "next click should keep action id")
  _assert_eq(captured[1] and captured[1].actor_role_id, 2, "next click should inject normalized actor_role_id")
end

local function _test_ui_event_router_turn_bound_actor_prefers_current_player_over_stale_cache()
  local base_nodes = require("src.ui.schema.base_nodes")

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

  local captured = {}
  local node_map = {
    [base_nodes.action_button] = new_node(),
  }

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function() end } },
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
        dispatch_action = function(_, _, action)
          captured[#captured + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = "2",
      },
      local_actor_role_id = 1,
    }
    _bind_ui_runtime(state)
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map[base_nodes.action_button]._listener_cb({})
  end)

  _assert_eq(captured[1] and captured[1].actor_role_id, 2,
    "turn-bound actor resolution should prefer current_player_id over stale cache")
end

local function _test_local_actor_resolver_turn_bound_prefers_client_role_over_current_player()
  local local_actor_resolver = require("src.ui.ctl.local_actor_resolver")
  local client_role = {
    get_roleid = function()
      return 3
    end,
  }

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "UIManager", value = { client_role = client_role } },
  }, function()
    local state = {
      ui_model = {
        current_player_id = "2",
      },
      local_actor_role_id = 1,
    }
    local resolved = local_actor_resolver.resolve_turn_bound(state)
    _assert_eq(resolved, 3, "turn-bound actor resolution should keep explicit client role ahead of current_player_id")
  end)
end

local function _test_ui_event_router_injects_actor_for_market_confirm_and_cancel()
  local market_nodes = require("src.ui.schema.market_nodes")

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

  local captured = {}
  local node_map = {
    [market_nodes.confirm] = new_node(),
    [market_nodes.close] = new_node(),
  }

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function() end } },
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
        dispatch_action = function(_, _, action)
          captured[#captured + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = "3",
        choice = {
          id = 12,
          kind = "market_buy",
          route_key = "market",
          allow_cancel = true,
          options = { { id = 34, label = "X" } },
        },
        market = {
          choice_id = 12,
          options = { { id = 34, label = "X" } },
        },
      },
      pending_choice_selected_option_id = 34,
    }
    _bind_ui_runtime(state)
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map[market_nodes.confirm]._listener_cb({})
    node_map[market_nodes.close]._listener_cb({})
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_select", "market_confirm should dispatch choice_select")
  _assert_eq(captured[1] and captured[1].choice_id, 12, "market_confirm should keep choice id")
  _assert_eq(captured[1] and captured[1].option_id, 34, "market_confirm should keep option id")
  _assert_eq(captured[1] and captured[1].actor_role_id, 3, "market_confirm should inject actor_role_id")
  _assert_eq(captured[2] and captured[2].type, "choice_cancel", "market_close should dispatch choice_cancel")
  _assert_eq(captured[2] and captured[2].choice_id, 12, "market_close should keep choice id")
  _assert_eq(captured[2] and captured[2].actor_role_id, 3, "market_close should inject actor_role_id")
end

local function _test_ui_event_router_rejects_next_without_actor_context()
  local base_nodes = require("src.ui.schema.base_nodes")

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

  local captured = {}
  local show_tip_calls = 0
  local node_map = {
    [base_nodes.action_button] = new_node(),
  }

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
        dispatch_action = function(_, _, action)
          captured[#captured + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = nil,
      },
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map[base_nodes.action_button]._listener_cb({})
  end)

  _assert_eq(captured[1], nil, "next click without actor context should be rejected")
  _assert_eq(show_tip_calls, 1, "next click without actor context should show tip once")
end

local function _test_raycast_build_camera_ray_supports_table_vectors()
  local role = {
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 1, y = 2, z = 3 }
        end,
      }
    end,
    get_camera_dir = function()
      return { x = 0, y = 0, z = 1 }
    end,
  }

  local ray = assert(raycast.build_camera_ray(role, {
    eye_offset_y = "invalid",
    ray_distance = "invalid",
  }))

  _assert_eq(ray.start_pos.x, 1, "camera ray should keep x when using table vectors")
  _assert_eq(ray.start_pos.y, 3.5, "camera ray should apply default eye offset when cfg is invalid")
  _assert_eq(ray.start_pos.z, 3, "camera ray should keep z when using table vectors")
  _assert_eq(ray.end_pos.x, 1, "camera ray end should keep x when direction is forward")
  _assert_eq(ray.end_pos.y, 3.5, "camera ray end should keep y when direction is flat")
  _assert_eq(ray.end_pos.z, 27, "camera ray should apply default ray distance when cfg is invalid")
end

local function _test_raycast_get_unit_id_uses_lua_api_then_unit_method_fallback()
  local unit = {
    get_unit_id = function()
      return 99
    end,
  }
  local lua_api_calls = 0

  _with_patches({
    { key = "LuaAPI", value = {
      get_unit_id = function()
        lua_api_calls = lua_api_calls + 1
        return 88
      end,
    } },
  }, function()
    _assert_eq(raycast.get_unit_id(unit), 88, "raycast should prefer LuaAPI.get_unit_id when available")
  end)

  _with_patches({
    { key = "LuaAPI", value = {
      get_unit_id = function()
        lua_api_calls = lua_api_calls + 1
        error("boom")
      end,
    } },
  }, function()
    _assert_eq(raycast.get_unit_id(unit), 99, "raycast should fall back to unit method when LuaAPI.get_unit_id fails")
  end)

  assert(lua_api_calls >= 2, "raycast get_unit_id should try LuaAPI before local fallback")
end

local function _test_ui_event_state_base_screen_active_requires_modal_free_ui()
  local ui_event_state = require("src.ui.ctl.event_state")
  _assert_eq(ui_event_state.is_base_screen_active({ ui = {} }), true,
    "base screen should be active when no modal flags are set")
  _assert_eq(ui_event_state.is_base_screen_active({ ui = { market_active = true } }), false,
    "market screen should disable base screen")
  _assert_eq(ui_event_state.is_base_screen_active({ ui = { choice_active = true } }), false,
    "choice screen should disable base screen")
  _assert_eq(ui_event_state.is_base_screen_active({ ui = { popup_active = true } }), false,
    "popup should disable base screen")
  _assert_eq(ui_event_state.is_base_screen_active({}), false,
    "missing ui state should disable base screen")
end

local function _test_ui_sync_ports_rebuilds_model_before_reopening_choice()
  local ui_sync_ports = require("src.presentation.runtime.ports.ui_sync")
  local runtime_state_local = require("src.state.state_access.runtime_state")
  local rebuilt = {
    choice = { id = 42, kind = "remote", route_key = "remote", options = { { id = 1, label = "A" } } },
    market = { choice_id = 42 },
  }
  local state = {
    ui = ui_view.build_ui_state(),
    ui_model = {
      choice = { id = 1 },
    },
  }
  local opened_choice = nil
  local opened_market = nil

  _with_patches({
    { target = require("src.presentation.runtime.ports.ui_sync.choice_state"), key = "should_reconcile", value = function()
      return true
    end },
    { target = require("src.presentation.runtime.ports.ui_sync.model"), key = "build_model", value = function()
      return rebuilt
    end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function(_, choice, market)
      opened_choice = choice
      opened_market = market
    end },
  }, function()
    ui_sync_ports.build({
      get_ui_state = function(current_state)
        return current_state.ui
      end,
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    }).on_pending_choice({}, state, { id = 42 })
  end)

  _assert_eq(runtime_state_local.get_ui_model(state), rebuilt, "ui sync should cache rebuilt model before reopening")
  _assert_eq(opened_choice, rebuilt.choice, "ui sync should reopen with rebuilt choice view")
  _assert_eq(opened_market, rebuilt.market, "ui sync should reopen with rebuilt market view")
  _assert_eq(runtime_state_local.is_ui_dirty(state), true, "ui sync should mark ui dirty when pending choice arrives")
end

local function _test_debug_view_global_and_role_paths_preserve_state()
  local debug_view = require("src.ui.ctl.debug_view")
  local runtime_ui = require("src.ui.render.runtime_ui")
  local state = {
    ui = ui_view.build_ui_state(),
  }
  local role = {
    get_roleid = function()
      return 7
    end,
  }
  local calls = {}

  state.ui.set_debug_log = function(_, text)
    calls[#calls + 1] = { kind = "log", text = text }
  end
  state.ui.set_debug_visible = function(_, visible)
    calls[#calls + 1] = { kind = "visible", value = visible }
  end

  _with_patches({
    { target = runtime_ui, key = "get_client_role", value = function() return nil end },
  }, function()
    debug_view.set_debug_log(state, "all")
    _assert_eq(debug_view.set_debug_visible(state, true), true, "global debug path should succeed without role")
  end)

  _with_patches({
    { target = runtime_ui, key = "resolve_role_id", value = function()
      return 7
    end },
  }, function()
    _assert_eq(debug_view.set_debug_visible_for_role(state, role, false), true,
      "role debug path should persist visibility by role")
    debug_view.set_debug_log_for_role(state, role, "role only")
  end)

  _assert_eq(state.ui.debug_visible, true, "global path should keep ui.debug_visible in sync")
  _assert_eq(state.ui.debug_visible_by_role[7], false, "role path should persist debug visibility by role")
  _assert_eq(state.ui.debug_log_enabled_by_role[7], false, "role path should persist debug log flag by role")
  _assert_eq(calls[1].text, "all", "global log path should pass through text")
  _assert_eq(calls[#calls].text, "role only", "role log path should pass through text")
end

local function _test_actor_context_and_host_runtime_fallbacks()
  local actor_context = require("src.ui.ctl.actor_context")
  local host_runtime_local = require("src.host.eggy")
  local runtime_ui = require("src.ui.render.runtime_ui")
  local runtime_context = require("src.host.eggy.context")
  local listed_role = {
    get_roleid = function()
      return 3
    end,
  }
  local fallback_role = {
    get_roleid = function()
      return 4
    end,
  }
  local client_role = {
    get_roleid = function()
      return 99
    end,
  }
  local handler = function() end
  local registered = nil

  _with_patches({
    { target = require("src.host.eggy.role_resolver"), key = "resolve_roles", value = function()
      return { listed_role }
    end },
    { target = require("src.host.eggy.role_resolver"), key = "resolve_role_with", value = function(role_id)
      if role_id == 4 then
        return fallback_role
      end
      return nil
    end },
    { target = runtime_ui, key = "get_client_role", value = function()
      return client_role
    end },
    { target = runtime_ui, key = "resolve_role_id", value = function(role)
      return role and role.get_roleid and role:get_roleid() or nil
    end },
    { target = runtime_context, key = "current", value = function()
      return {
        env = {
          LuaAPI = {
            global_register_custom_event = function(event_name, fn)
              registered = { name = event_name, handler = fn }
            end,
          },
        },
      }
    end },
  }, function()
    _assert_eq(actor_context.resolve_role_by_id(nil), client_role, "nil role id should fall back to client role")
    _assert_eq(actor_context.resolve_role_by_id(3), listed_role, "actor context should prefer resolved role list")
    local resolved_fallback = actor_context.resolve_role_by_id(4)
    _assert_eq(resolved_fallback:get_roleid(), 4, "actor context should fall back to resolve_role")
    local synthetic = actor_context.resolve_role_by_id(5)
    _assert_eq(type(synthetic.get_roleid), "function", "actor context should synthesize missing roles")
    _assert_eq(synthetic:get_roleid(), 5, "synthetic role should preserve requested role id")
    _assert_eq(host_runtime_local.register_custom_event("evt", handler), true,
      "host runtime should register custom event when LuaAPI exists")
  end)

  _assert_eq(registered.name, "evt", "host runtime should pass event name through")
  _assert_eq(registered.handler, handler, "host runtime should pass handler through")
  _assert_eq(host_runtime_local.register_custom_event(nil, handler), false,
    "host runtime should reject invalid event name")
end


local function _test_raycast_pick_with_tries_multiple_apis_in_order()
  local calls = {}
  local mock_hit = { unit = { _id = 123 } }

  _with_patches({
    { key = "GameAPI", value = {
      raycast_unit = function()
        calls[#calls + 1] = "raycast_unit"
        return nil
      end,
      get_obstacle_by_raycast = function()
        calls[#calls + 1] = "get_obstacle_by_raycast"
        return mock_hit
      end,
      get_first_customtriggerspace_in_raycast = function()
        calls[#calls + 1] = "get_first_customtriggerspace_in_raycast"
        return nil
      end,
    } },
  }, function()
    local hit = raycast.pick_first_hit_unit({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, nil)
    _assert_eq(hit ~= nil, true, "pick_first_hit_unit should return hit when second API succeeds")
    _assert_eq(hit.unit._id, 123, "pick_first_hit_unit should return unit from successful API")
    _assert_eq(calls[1], "raycast_unit", "pick_first_hit_unit should try raycast_unit first")
    _assert_eq(calls[2], "get_obstacle_by_raycast", "pick_first_hit_unit should fall back to get_obstacle_by_raycast")
    _assert_eq(#calls, 2, "pick_first_hit_unit should stop after successful hit")
  end)
end

local function _test_raycast_pick_with_returns_nil_when_all_apis_fail()
  local calls = {}

  _with_patches({
    { key = "GameAPI", value = {
      raycast_unit = function()
        calls[#calls + 1] = "raycast_unit"
        error("api error")
      end,
      get_obstacle_by_raycast = function()
        calls[#calls + 1] = "get_obstacle_by_raycast"
        return nil
      end,
      get_first_customtriggerspace_in_raycast = function()
        calls[#calls + 1] = "get_first_customtriggerspace_in_raycast"
        return nil
      end,
    } },
  }, function()
    local hit, err = raycast.pick_first_hit_unit({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, nil)
    _assert_eq(hit, nil, "pick_first_hit_unit should return nil when all APIs fail")
    _assert_eq(err, "missing raycast api", "pick_first_hit_unit should return error message when all APIs fail")
    _assert_eq(#calls, 3, "pick_first_hit_unit should try all three APIs")
  end)
end

local function _test_raycast_pick_with_resolves_hit_unit_from_various_formats()
  local results = {}

  _with_patches({
    { key = "GameAPI", value = {
      raycast_unit = function()
        return { unit = { _id = 1 } }
      end,
    } },
  }, function()
    local hit = raycast.pick_first_hit_unit({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, nil)
    results.unit_field = hit and hit.unit._id
  end)

  _with_patches({
    { key = "GameAPI", value = {
      raycast_unit = function()
        return { hit_unit = { _id = 2 } }
      end,
    } },
  }, function()
    local hit = raycast.pick_first_hit_unit({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, nil)
    results.hit_unit_field = hit and hit.unit._id
  end)

  _with_patches({
    { key = "GameAPI", value = {
      raycast_unit = function()
        return { obstacle = { _id = 3 } }
      end,
    } },
  }, function()
    local hit = raycast.pick_first_hit_unit({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, nil)
    results.obstacle_field = hit and hit.unit._id
  end)

  _with_patches({
    { key = "GameAPI", value = {
      raycast_unit = function()
        return { { _id = 4 } }
      end,
    } },
  }, function()
    local hit = raycast.pick_first_hit_unit({ x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }, nil)
    results.first_array_element = hit and hit.unit._id
  end)

  _assert_eq(results.unit_field, 1, "pick_with should resolve unit from hit.unit field")
  _assert_eq(results.hit_unit_field, 2, "pick_with should resolve unit from hit.hit_unit field")
  _assert_eq(results.obstacle_field, 3, "pick_with should resolve unit from hit.obstacle field")
  _assert_eq(results.first_array_element, 4, "pick_with should resolve unit from hit[1] field")
end

local function _test_view_command_ports_toggle_action_log_aborts_when_ui_missing()
  local view_command_ports = require("src.presentation.runtime.ports.view_command")
  local ports = view_command_ports.build()
  local state = {}

  local result = ports.dispatch(state, { type = "toggle_action_log", actor_role_id = 1 })
  _assert_eq(result, true, "toggle_action_log should return true even when ui is missing")
end

local function _test_view_command_ports_toggle_action_log_warns_when_actor_role_id_missing()
  local view_command_ports = require("src.presentation.runtime.ports.view_command")
  local logger = require("src.core.utils.logger")
  local ports = view_command_ports.build()
  local warn_calls = {}
  local state = { ui = {} }

  _with_patches({
    { target = logger, key = "warn", value = function(...)
      warn_calls[#warn_calls + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    local result = ports.dispatch(state, { type = "toggle_action_log" })
    _assert_eq(result, true, "toggle_action_log should return true even when actor_role_id is missing")
    _assert_eq(#warn_calls >= 1, true, "toggle_action_log should warn when actor_role_id is missing")
  end)
end

local function _test_choice_ui_state_rejects_current_player_fallback_when_local_role_stale()
  local choice_ui_state = require("src.presentation.runtime.ports.ui_sync.choice_state")
  local players = {
    { id = 1, is_ai = false, auto = false },
    { id = 2, is_ai = false, auto = false },
  }
  local state = {
    ui = ui_view.build_ui_state(),
    local_actor_role_id = 1,
  }
  _bind_ui_runtime(state)
  runtime_state.set_ui_model(state, {
    current_player_id = 2,
  })
  local choice = {
    id = 12,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = 2,
  }
  local game = {
    turn = {
      current_player_index = 2,
      phase = "wait_choice",
    },
    players = players,
  }
  game.find_player_by_id = function(_, role_id)
      for _, player in ipairs(players) do
        if player.id == role_id then
          return player
        end
      end
      return nil
    end

  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  _assert_eq(gate.local_owner, false, "choice gate should reject current player fallback when local role is stale")
  _assert_eq(gate.expects_ui, false, "shared market choice should stay hidden for non-owner local role")
end

local function _test_choice_ui_state_accepts_explicit_local_owner()
  local choice_ui_state = require("src.presentation.runtime.ports.ui_sync.choice_state")
  local players = {
    { id = 1, is_ai = false, auto = false },
    { id = 2, is_ai = false, auto = false },
  }
  local state = {
    ui = ui_view.build_ui_state(),
    local_actor_role_id = 2,
  }
  _bind_ui_runtime(state)
  runtime_state.set_ui_model(state, {
    current_player_id = 1,
  })
  local choice = {
    id = 13,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = 2,
  }
  local game = {
    turn = {
      current_player_index = 1,
      phase = "wait_choice",
    },
    players = players,
  }
  game.find_player_by_id = function(_, role_id)
      for _, player in ipairs(players) do
        if player.id == role_id then
          return player
        end
      end
      return nil
    end

  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  _assert_eq(gate.local_owner, true, "choice gate should honor explicit local owner")
  _assert_eq(gate.expects_ui, true, "owner local role should still open shared confirm UI")
end

return {
  name = "presentation_ui.interaction",
  tests = {
    { name = "_test_ui_intent_dispatcher_market_select_updates_ui_only", run = _test_ui_intent_dispatcher_market_select_updates_ui_only },
    { name = "_test_ui_intent_dispatcher_popup_confirm_closes_popup", run = _test_ui_intent_dispatcher_popup_confirm_closes_popup },
    { name = "_test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context", run = _test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context },
    { name = "_test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game", run = _test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game },
    { name = "_test_ui_intent_dispatcher_toggle_action_log_resolves_role_via_game_api", run = _test_ui_intent_dispatcher_toggle_action_log_resolves_role_via_game_api },
    { name = "_test_ui_intent_dispatcher_toggle_action_log_warns_when_role_event_channel_missing", run = _test_ui_intent_dispatcher_toggle_action_log_warns_when_role_event_channel_missing },
    { name = "_test_ui_intent_dispatcher_auto_button_keeps_intent_actor_role_id", run = _test_ui_intent_dispatcher_auto_button_keeps_intent_actor_role_id },
    { name = "_test_ui_intent_dispatcher_auto_button_falls_back_to_intent_actor_when_local_missing", run = _test_ui_intent_dispatcher_auto_button_falls_back_to_intent_actor_when_local_missing },
    { name = "_test_ui_intent_dispatcher_auto_button_rejects_when_actor_missing", run = _test_ui_intent_dispatcher_auto_button_rejects_when_actor_missing },
    { name = "_test_ui_intent_dispatcher_auto_button_honors_intent_actor_during_other_turn", run = _test_ui_intent_dispatcher_auto_button_honors_intent_actor_during_other_turn },
    { name = "_test_ui_event_router_injects_actor_for_next_with_current_player_fallback", run = _test_ui_event_router_injects_actor_for_next_with_current_player_fallback },
    {
      name = "_test_ui_event_router_turn_bound_actor_prefers_current_player_over_stale_cache",
      run = _test_ui_event_router_turn_bound_actor_prefers_current_player_over_stale_cache,
    },
    {
      name = "_test_local_actor_resolver_turn_bound_prefers_client_role_over_current_player",
      run = _test_local_actor_resolver_turn_bound_prefers_client_role_over_current_player,
    },
    { name = "_test_ui_event_router_injects_actor_for_market_confirm_and_cancel", run = _test_ui_event_router_injects_actor_for_market_confirm_and_cancel },
    { name = "_test_ui_event_router_rejects_next_without_actor_context", run = _test_ui_event_router_rejects_next_without_actor_context },
    { name = "_test_raycast_build_camera_ray_supports_table_vectors", run = _test_raycast_build_camera_ray_supports_table_vectors },
    { name = "_test_raycast_get_unit_id_uses_lua_api_then_unit_method_fallback", run = _test_raycast_get_unit_id_uses_lua_api_then_unit_method_fallback },
    { name = "_test_ui_event_state_base_screen_active_requires_modal_free_ui", run = _test_ui_event_state_base_screen_active_requires_modal_free_ui },
    { name = "_test_ui_sync_ports_rebuilds_model_before_reopening_choice", run = _test_ui_sync_ports_rebuilds_model_before_reopening_choice },
    { name = "_test_debug_view_global_and_role_paths_preserve_state", run = _test_debug_view_global_and_role_paths_preserve_state },
    { name = "_test_actor_context_and_host_runtime_fallbacks", run = _test_actor_context_and_host_runtime_fallbacks },
    { name = "_test_raycast_pick_with_tries_multiple_apis_in_order", run = _test_raycast_pick_with_tries_multiple_apis_in_order },
    { name = "_test_raycast_pick_with_returns_nil_when_all_apis_fail", run = _test_raycast_pick_with_returns_nil_when_all_apis_fail },
    { name = "_test_raycast_pick_with_resolves_hit_unit_from_various_formats", run = _test_raycast_pick_with_resolves_hit_unit_from_various_formats },
    {
      name = "_test_choice_ui_state_rejects_current_player_fallback_when_local_role_stale",
      run = _test_choice_ui_state_rejects_current_player_fallback_when_local_role_stale,
    },
    { name = "_test_choice_ui_state_accepts_explicit_local_owner", run = _test_choice_ui_state_accepts_explicit_local_owner },
    { name = "_test_view_command_ports_toggle_action_log_aborts_when_ui_missing", run = _test_view_command_ports_toggle_action_log_aborts_when_ui_missing },
    { name = "_test_view_command_ports_toggle_action_log_warns_when_actor_role_id_missing", run = _test_view_command_ports_toggle_action_log_warns_when_actor_role_id_missing },
  },
}
