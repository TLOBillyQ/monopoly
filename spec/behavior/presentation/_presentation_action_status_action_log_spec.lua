local P = require("support.presentation_action_status_prelude")
local _new_game = P.new_game
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local _build_role_with_events = P.build_role_with_events
local dispatch = require("src.turn.actions.action_dispatcher")
local canvas_event_router = require("src.ui.coord.canvas_event_router")
local ui_view = require("src.ui.coord.ui_runtime")
local host_runtime_bridge = require("src.ui.host_bridge")

describe("presentation_action_log_and_role_context", function()
  it("_test_ui_event_router_action_log_toggle_uses_role_context", function()
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
      local before = require("src.ui.coord.event_state").resolve_event_log_enabled(state, role_id)
      node_map["基础_行动日志图标"]._listener_cb({ role = role })
      local first_value = state.ui.debug_visible_by_role[role_id]
      _assert_eq(first_value, not before, "action_log toggle should invert role visibility")
      _assert_eq(UIManager.client_role, nil, "action_log toggle should restore client role")

      node_map["基础_行动日志图标"]._listener_cb({ role = role })
      local second_value = state.ui.debug_visible_by_role[role_id]
      assert(second_value ~= first_value, "action_log toggle should flip role visibility after second click")
      _assert_eq(UIManager.client_role, nil, "action_log toggle should restore client role after second click")
    end)
  end)

  it("_test_ui_event_router_rejects_action_log_without_role", function()
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
  end)

  it("_test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing", function()
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
  end)

  it("_test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player", function()
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
  end)

  it("_test_ui_event_state_resolve_event_log_enabled_supports_mixed_role_id_keys", function()
    local state = {
      ui = {
        debug_log_enabled_by_role = {
          ["1"] = true,
        },
      },
    }

    local enabled_by_int = require("src.ui.coord.event_state").resolve_event_log_enabled(state, 1)
    local enabled_by_string = require("src.ui.coord.event_state").resolve_event_log_enabled(state, "1")

    _assert_eq(enabled_by_int, true, "event_log_enabled should read string key by int role_id")
    _assert_eq(enabled_by_string, true, "event_log_enabled should read string key by string role_id")
  end)
end)
