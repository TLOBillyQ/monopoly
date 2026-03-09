local support = require("support.presentation_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.migrate_legacy_ui_state_for_test
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local gameplay_loop = support.gameplay_loop
local turn_move = support.turn_move
local event_handlers = require("src.presentation.runtime.event_handlers")
local paid_currency_bridge = require("src.game.systems.commerce.paid_currency_bridge")
local dispatch = require("src.game.flow.turn.dispatch")
local runtime_port = require("src.presentation.runtime.ui")
local ui_intent_dispatcher = require("src.presentation.input.intent_dispatcher")
local choice_openers = require("src.presentation.view.widgets.choice_screen_service.openers")
local market_view = require("src.presentation.view.render.market")
local market_layout = require("src.presentation.view.support.market_layout")
local canvas_event_router = require("src.presentation.runtime.canvas_event_router")
local ui_view = require("src.presentation.runtime.view")
local ui_status_3d_layer = require("src.presentation.view.render.status3d")
local action_anim = require("src.presentation.view.render.action_anim")
local move_anim = require("src.presentation.view.render.move_anim")
local runtime_cls = require("src.game.flow.turn.engine")
local turn_effects = require("src.presentation.view.widgets.turn_effects")
local popup_renderer = require("src.presentation.view.widgets.popup_renderer")
local market_modal_renderer = require("src.presentation.view.widgets.market_modal_renderer")
local debug_ports_module = require("src.presentation.runtime.ports.debug_ports")
local role_control_lock_policy = require("src.presentation.input.role_control_lock_policy")
local ui_touch_policy = require("src.presentation.input.touch_policy")
local ui_choice_route_policy = require("src.presentation.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local runtime_event_bridge = require("src.infrastructure.runtime.event_bridge")
local market_cfg = require("Config.generated.market")
local runtime_constants = require("src.core.config.runtime_constants")
local gameplay_rules = require("src.core.config.gameplay_rules")
local host_runtime = require("src.presentation.runtime.host")
local runtime_state = require("src.core.state_access.runtime_state")
local target_choice_effects = require("src.presentation.view.render.target_choice_effects")
local vec3 = require("fixtures.vec3")


local function _ui_runtime(state)
  return runtime_state.ensure_ui_runtime(state)
end

local function _wrap_ui_refs(image_refs)
  return {
    images = image_refs or {},
  }
end

local function _build_popup_view_state(refs, card_node)
  local function new_node(seed)
    local node = seed or {}
    if not node.listen then
      function node:listen(_, cb)
        self._listener_cb = cb
        return {
          destroy = function()
            self._listener_cb = nil
          end,
        }
      end
    end
    return node
  end
  local state = {
    ui = ui_view.build_ui_state(),
    ui_refs = _wrap_ui_refs(refs or { ["Empty"] = "EMPTY" }),
  }
  state.ui.choice_active = false
  state.ui.market_active = false
  local nodes = {
    ["卡牌展示屏"] = new_node(),
    ["卡牌展示_标题"] = new_node(),
    ["卡牌展示_图片"] = new_node(card_node or {}),
  }
  local function query_nodes_by_name(name)
    local node = nodes[name]
    if not node then
      node = new_node()
      nodes[name] = node
    end
    return { node }
  end
  return state, nodes, query_nodes_by_name
end

local function _build_role_with_events(role_id, events)
  return {
    get_roleid = function() return role_id end,
    send_ui_custom_event = function(event_name)
      events[#events + 1] = event_name
    end,
  }
end

local function _has_event(list, name)
  for _, value in ipairs(list or {}) do
    if value == name then
      return true
    end
  end
  return false
end

local function _build_choice_modal_state()
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
  local state = {
    pending_choice_id = nil,
    pending_choice_elapsed = 0,
    pending_choice_selected_option_id = nil,
    ui = ui_view.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
  }
  _bind_ui_runtime(state)
  local names = {
    "玩家选择屏", "玩家选择_标题",
    "玩家选择_槽位1", "玩家选择_槽位2", "玩家选择_槽位3", "玩家选择_槽位4",
    "位置选择屏", "位置_副标题", "位置_放置文本",
    "位置-槽位1按钮", "位置-槽位2按钮", "位置-槽位3按钮", "位置-槽位4按钮", "位置-槽位5按钮", "位置-槽位6按钮", "位置-槽位7按钮",
    "位置-槽位1文本", "位置-槽位2文本", "位置-槽位3文本", "位置-槽位4文本", "位置-槽位5文本", "位置-槽位6文本", "位置-槽位7文本",
    "位置-槽位1投影", "位置-槽位2投影", "位置-槽位3投影", "位置-槽位4投影", "位置-槽位5投影", "位置-槽位6投影", "位置-槽位7投影",
    "遥控骰子屏", "遥控骰子_标题", "遥控骰子_正文",
    "遥控骰子_选项_01", "遥控骰子_选项_02", "遥控骰子_选项_03",
    "遥控骰子_选项_04", "遥控骰子_选项_05", "遥控骰子_选项_06",
    "通用二次确认屏", "通用二次确认_标题", "通用二次确认_文本", "通用二次确认_确定按钮", "通用二次确认_取消",
    "卡牌展示屏", "卡牌展示_标题", "卡牌展示_图片",
    "黑市屏", "黑市_购买按钮", "黑市_关闭", "黑市_售价", "黑市_选中卡牌",
  }
  local nodes = {}
  for _, name in ipairs(names) do
    nodes[name] = new_node()
  end
  local function query_nodes_by_name(name)
    local node = nodes[name]
    if not node then
      node = new_node()
      nodes[name] = node
    end
    return { node }
  end
  return state, nodes, query_nodes_by_name
end

local function _build_target_pick_env()
  local state, nodes, query_nodes = _build_choice_modal_state()
  local choice = {
    id = 99,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = 1,
    uses_target_picker = true,
    target_picker_owner_role_id = 1,
    title = "选位置",
    body = "body",
    options = {
      { id = 101, label = "A" },
      { id = 102, label = "B" },
      { id = 103, label = "C" },
    },
    allow_cancel = true,
    meta = { player_id = 1 },
  }
  local game = {
    turn = { pending_choice = choice },
    current_player = function()
      return { id = 1 }
    end,
  }

  local tile_positions = {
    [101] = vec3.with_sub_length(10, 0, 0),
    [102] = vec3.with_sub_length(20, 0, 0),
    [103] = vec3.with_sub_length(30, 0, 0),
  }
  local tile_unit_ids = {
    [101] = 1101,
    [102] = 1102,
    [103] = 1103,
  }
  local tiles = {}
  local tile_index_by_unit_id = {}
  for option_id, pos in pairs(tile_positions) do
    tiles[option_id] = {
      get_position = function()
        return pos
      end,
    }
    tile_index_by_unit_id[tile_unit_ids[option_id]] = option_id
  end
  local arrow = {
    visible = false,
    last_position = nil,
  }
  arrow.set_model_visible = function(visible)
    arrow.visible = visible == true
  end
  arrow.set_position = function(pos)
    arrow.last_position = pos
  end

  state.game = game
  state.ui_model = { choice = choice, current_player_id = 1 }
  _bind_ui_runtime(state)
  state.ui.choice_active = true
  state.ui.active_choice_screen_key = "target"
  state.board_scene = {
    tiles = tiles,
    target_pick = {
      marker_unit_id = 9001,
      tile_index_by_unit_id = tile_index_by_unit_id,
      arrow_unit = arrow,
    },
  }
  state.turn_action_port = {
    dispatched = {},
    dispatch_action = function(_, _, action)
      state.turn_action_port.dispatched[#state.turn_action_port.dispatched + 1] = action
    end,
    should_block_action = function()
      return false
    end,
  }

  return {
    state = state,
    nodes = nodes,
    query_nodes = query_nodes,
    choice = choice,
    game = game,
    tile_positions = tile_positions,
    tile_unit_ids = tile_unit_ids,
    arrow = arrow,
  }
end


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
    { target = ui_view, key = "select_market_option", value = function(_, option_id)
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
    { target = ui_view, key = "close_popup", value = function()
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
  local role = {
    get_roleid = function()
      return 101
    end,
  }
  _with_patches({
    { key = "all_roles", value = { role } },
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
  local role = {
    get_roleid = function()
      return 101
    end,
  }

  _with_patches({
    { key = "all_roles", value = { role } },
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
  local base_nodes = require("src.presentation.view.canvas.base.nodes")

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

local function _test_ui_event_router_injects_actor_for_market_confirm_and_cancel()
  local market_nodes = require("src.presentation.view.canvas.market.nodes")

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
  local base_nodes = require("src.presentation.view.canvas.base.nodes")

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
    { name = "_test_ui_event_router_injects_actor_for_market_confirm_and_cancel", run = _test_ui_event_router_injects_actor_for_market_confirm_and_cancel },
    { name = "_test_ui_event_router_rejects_next_without_actor_context", run = _test_ui_event_router_rejects_next_without_actor_context },
  },
}
