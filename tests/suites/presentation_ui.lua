local support = require("TestSupport")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _open_choice = support.open_choice
local _get_choice = support.get_choice
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local turn_anim = support.turn_anim
local tick_timeout = support.tick_timeout
local constants = support.constants
local choice_resolver = support.choice_resolver
local gameplay_loop = support.gameplay_loop
local turn_move = support.turn_move
local event_handlers = require("src.presentation.api.UIEventHandlers")
local paid_currency_bridge = require("src.game.systems.commerce.PaidCurrencyBridge")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local runtime_port = require("src.presentation.api.UIRuntimePort")
local ui_intent_dispatcher = require("src.presentation.interaction.UIIntentDispatcher")
local market_view = require("src.presentation.render.MarketView")
local market_layout = require("src.presentation.shared.MarketLayout")
local ui_event_router = require("src.presentation.interaction.UIEventRouter")
local ui_view = require("src.presentation.api.UIViewService")
local ui_status_3d_layer = require("src.presentation.render.Status3DService")
local action_anim = require("src.presentation.render.ActionAnim")
local move_anim = require("src.presentation.render.MoveAnim")
local turn_engine_cls = require("src.game.core.runtime.TurnEngine")
local turn_effects = require("src.presentation.ui.UITurnEffects")
local role_control_lock_policy = require("src.presentation.interaction.UIRoleControlLockPolicy")
local ui_touch_policy = require("src.presentation.interaction.UITouchPolicy")
local ui_choice_route_policy = require("src.presentation.interaction.UIChoiceRoutePolicy")
local logger = require("src.core.Logger")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local market_cfg = require("Config.Generated.Market")
local runtime_constants = require("Config.RuntimeConstants")
local gameplay_rules = require("Config.GameplayRules")
local vec3 = require("fixtures.vec3")

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
    ui_refs = refs or { ["Empty"] = "EMPTY" },
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
    ui_refs = { ["Empty"] = "EMPTY" },
  }
  local names = {
    "玩家选择屏", "玩家选择_标题",
    "玩家选择_槽位1", "玩家选择_槽位2", "玩家选择_槽位3", "玩家选择_槽位4",
    "位置选择屏", "位置_副标题", "位置_放置文本",
    "位置_前1", "位置_前2", "位置_前3", "位置_后1", "位置_后2", "位置_后3", "位置_脚下",
    "遥控骰子屏", "遥控骰子_标题", "遥控骰子_正文",
    "遥控骰子_选项_01", "遥控骰子_选项_02", "遥控骰子_选项_03",
    "遥控骰子_选项_04", "遥控骰子_选项_05", "遥控骰子_选项_06", "遥控骰子_取消",
    "建筑升级屏", "建筑升级_标题", "建筑升级_文本", "建筑升级_确定按钮", "建筑升级_取消",
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

local function _test_move_anim_callback_and_delay()
  local dispatched = {}
  local layer = { wait_move_anim = true }
  local game = {
    turn = {
      move_anim = { seq = 1 },
      phase = "wait_move_anim",
    },
    dispatch_action = function(_, action)
      table.insert(dispatched, action)
    end,
  }
  local delay_called = nil
  local function call_delay(delay, cb)
    delay_called = delay
    cb()
  end
  _with_patches({
    { key = "LuaAPI", value = { call_delay_time = call_delay } },
    { key = "SetTimeOut", value = call_delay },
  }, function()
    turn_anim.step_move_anim(game, layer, {
      on_move_anim = function(_, anim)
        _assert_eq(anim.seq, 1, "anim seq forwarded")
        return 0.2
      end,
    })
  end)
  _assert_eq(delay_called, 0.2, "delay requested")
  _assert_eq(#dispatched, 1, "move_anim_done dispatched")
  _assert_eq(dispatched[1].seq, 1, "move_anim_done seq")
end

local function _test_popup_timeout_auto_confirm()
  local g = _new_game()
  local layer = {}
  layer.ui_modal_elapsed = 0
  layer.ui_modal_ref = nil
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    return
  end
  local near_timeout = timeout * 0.9
  local popup = {
    active = true,
    confirm_called = 0,
    confirm = function(self)
      self.confirm_called = self.confirm_called + 1
      self.active = false
      return true
    end,
  }
  layer.modal = { active = popup }
  local timeout_opts = {
    is_active = function(l)
      return l.modal and l.modal.active and l.modal.active.active
    end,
    get_ref = function(l)
      return l.modal and l.modal.active
    end,
    on_timeout = function(l)
      l.modal.active:confirm()
    end,
  }
  tick_timeout.step_modal_timeout(layer, near_timeout, timeout_opts)
  _assert_eq(popup.confirm_called, 0, "popup should not auto confirm before timeout")
  tick_timeout.step_modal_timeout(layer, near_timeout + 1, timeout_opts)
  _assert_eq(popup.confirm_called, 1, "popup should auto confirm after timeout")
end

local function _test_runtime_port_with_client_role_restores_nested_context()
  local role1 = { name = "r1" }
  local role2 = { name = "r2" }
  local original = { name = "origin" }
  local manager = { client_role = original }

  _with_patches({
    { key = "UIManager", value = manager },
  }, function()
    runtime_port.with_client_role(role1, function()
      assert(UIManager.client_role == role1, "outer with_client_role should set role1")
      runtime_port.with_client_role(role2, function()
        assert(UIManager.client_role == role2, "nested with_client_role should set role2")
      end)
      assert(UIManager.client_role == role1, "nested with_client_role should restore outer role")
    end)
    assert(UIManager.client_role == original, "with_client_role should restore original role")

    local ok = pcall(function()
      runtime_port.with_client_role(role1, function()
        error("boom")
      end)
    end)
    assert(ok == false, "with_client_role should rethrow callback error")
    assert(UIManager.client_role == original, "with_client_role should restore role after error")
  end)
end

local function _test_runtime_port_native_size_prefers_native_method()
  local native_calls = 0
  local keep_calls = 0
  local node = {
    set_texture_native_size = function(_, image_key)
      native_calls = native_calls + 1
      _assert_eq(image_key, "IMG_NATIVE", "native path should forward image key")
    end,
    set_texture_keep_size = function()
      keep_calls = keep_calls + 1
    end,
  }

  runtime_port.set_node_texture_native_size(node, "IMG_NATIVE")

  _assert_eq(native_calls, 1, "native path should prefer set_texture_native_size")
  _assert_eq(keep_calls, 0, "native path should not fallback to keep-size when native exists")
end

local function _test_runtime_port_native_size_fallback_keep_size()
  local keep_calls = 0
  local node = {
    set_texture_keep_size = function(_, image_key)
      keep_calls = keep_calls + 1
      _assert_eq(image_key, "IMG_KEEP", "keep-size fallback should forward image key")
    end,
  }

  runtime_port.set_node_texture_native_size(node, "IMG_KEEP")

  _assert_eq(keep_calls, 1, "native path should fallback to keep-size when native is missing")
end

local function _test_runtime_port_native_size_fallback_image_texture()
  local node = {}

  runtime_port.set_node_texture_native_size(node, "IMG_TEXTURE")

  _assert_eq(node.image_texture, "IMG_TEXTURE", "native path should fallback to image_texture field")
end

local function _test_choice_timeout_supports_explicit_timeout_strategy()
  local game = {
    players = { [1] = { id = 1 } },
    turn = {
      pending_choice = {
        id = 7,
        kind = "test",
        options = { { id = 11, label = "a" } },
      },
      current_player_index = 1,
    },
    current_player = function(self)
      return self.players[self.turn.current_player_index]
    end,
  }
  local state = {
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
  }
  local dispatched = nil
  _with_patches({
    { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action)
      dispatched = action
    end },
    { target = ui_view, key = "close_choice_modal", value = function() end },
  }, function()
    tick_timeout.step_choice_timeout(game, state, 0.11, {
      on_pending_choice = function() end,
      is_choice_active = function()
        return true
      end,
      get_timeout_seconds = function()
        return 0.1
      end,
      build_action = function(_, _, choice)
        return {
          type = "choice_select",
          choice_id = choice.id,
          option_id = 11,
        }
      end,
    })
  end)
  assert(dispatched and dispatched.type == "choice_select", "explicit timeout strategy should dispatch action")
  assert(dispatched and dispatched.choice_id == 7, "explicit timeout strategy should use pending choice id")
end

local function _test_tick_timeout_default_policy_isolation()
  local policy = tick_timeout.default_policy()
  policy.choice.get_timeout_seconds = function()
    return 999
  end
  local fresh_policy = tick_timeout.default_policy()
  local timeout = fresh_policy.choice.get_timeout_seconds()
  assert(timeout ~= 999, "default policy should not be mutated by external override")
end

local function _test_invalid_choice_option_rejected()
  local g = _new_game()
  local choice = _open_choice(g, {
    kind = "market_buy",
    options = { { id = 1, label = "X" } },
    meta = { player_id = g:current_player().id },
  })
  choice_resolver.resolve(g, choice, { option_id = 999 })
  assert(_get_choice(g) ~= nil, "invalid option should keep choice")
end

local function _test_move_anim_wait_and_resume()
  local g = _new_game()
  g.ui_port = _build_ui_port({ wait_move_anim = true })
  local player = g:current_player()
  g.last_turn = {
    player_id = player.id,
    player_name = player.name,
    skipped = false,
    rolls = nil,
    total = nil,
    move_result = nil,
    note = nil,
  }
  local phases = {
    start = function()
      return "move", { player = player, total = 1, raw_total = 1 }
    end,
    move = turn_move,
    landing = function()
      return nil
    end,
  }
  g.turn_engine = turn_engine_cls:new(g, phases, { experimental_coroutine_turn = true })

  local res = g.turn_engine:run_turn()
  assert(res == "wait_move_anim", "should wait for move anim")
  local seq = g.turn.move_anim and g.turn.move_anim.seq
  assert(seq, "move_anim seq should be set")

  g:dispatch_action({ type = "move_anim_done", seq = seq })

  assert(g.turn.move_anim == nil, "move_anim should be cleared")
  local phase = g.turn.phase
  assert(phase ~= "wait_move_anim", "should resume after move anim done")
end

local function _test_move_anim_zero_distance_safe()
  local _vec3 = vec3.with_sub_length

  local start_move_called = 0
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(1, 2, 3) end },
      [2] = { get_position = function() return _vec3(1, 2, 3) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          start_move_called = start_move_called + 1
        end,
      },
    },
  }

  local total = move_anim.play_sequence(scene, {
    player_id = 1,
    from_index = 1,
    to_index = 2,
    direction = { x = 0, y = 0, z = 1 },
  })

  _assert_eq(total, 0, "zero distance should return zero duration")
  _assert_eq(start_move_called, 0, "zero distance should skip unit move")
end

local function _test_move_anim_vehicle_uses_set_position_jump()
  local _vec3 = vec3.with_sub_length

  local unit_move_called = 0
  local vehicle_set_positions = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          unit_move_called = unit_move_called + 1
        end,
      },
    },
  }

  _with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { target = runtime_constants, key = "vehicle_move_api_enabled", value = false },
    { key = "vehicle_helper", value = {
      consume_enter_delay = function()
        return 0
      end,
      forward_eca_event_set_position = function(role_id, pos)
        vehicle_set_positions[#vehicle_set_positions + 1] = { role_id = role_id, pos = pos }
      end,
    } },
  }, function()
    local total = move_anim.play_sequence(scene, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
      vehicle_id = 4001,
    })
    assert(total > 0, "vehicle move total time should be positive")
  end)

  _assert_eq(unit_move_called, 0, "vehicle jump should not call unit.start_move_by_direction")
  _assert_eq(#vehicle_set_positions, 1, "vehicle jump should forward one set_position event")
  _assert_eq(vehicle_set_positions[1].role_id, 1, "vehicle jump role id should match")
end

local function _test_move_anim_vehicle_enter_delay_once()
  local _vec3 = vec3.with_sub_length

  local consume_calls = 0
  local timeout_delays = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = { [1] = {} },
  }

  _with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { target = runtime_constants, key = "vehicle_move_api_enabled", value = false },
    { key = "SetTimeOut", value = function(delay)
      timeout_delays[#timeout_delays + 1] = delay
    end },
    { key = "vehicle_helper", value = {
      forward_eca_event_set_position = function() end,
      consume_enter_delay = function()
        consume_calls = consume_calls + 1
        if consume_calls == 1 then
          return 1.2
        end
        return 0
      end,
    } },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
      vehicle_id = 4001,
    })
    _assert_eq(#timeout_delays, 1, "first vehicle move should be delayed by enter wait")
    assert(math.abs(timeout_delays[1] - 1.2) < 0.0001, "first delay should include 1.2s enter wait")

    timeout_delays = {}
    move_anim.play_sequence(scene, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
      vehicle_id = 4001,
    })
    _assert_eq(#timeout_delays, 0, "second move should not include enter wait delay")
  end)
end

local function _test_move_anim_vehicle_move_api_enabled_uses_move_event()
  local _vec3 = vec3.with_sub_length

  local move_calls = 0
  local set_pos_calls = 0
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = { [1] = {} },
  }

  _with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { target = runtime_constants, key = "vehicle_move_api_enabled", value = true },
    { key = "vehicle_helper", value = {
      consume_enter_delay = function()
        return 0
      end,
      forward_eca_event_move = function()
        move_calls = move_calls + 1
      end,
      forward_eca_event_set_position = function()
        set_pos_calls = set_pos_calls + 1
      end,
    } },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
      vehicle_id = 4001,
    })
  end)

  _assert_eq(move_calls, 1, "move api enabled should use forward_eca_event_move")
  _assert_eq(set_pos_calls, 0, "move api enabled should not use set_position jump")
end

local function _test_board_view_vehicle_resync_uses_set_position()
  local board_view = require("src.presentation.render.BoardRuntime")

  local _vec3 = vec3.with_add

  local set_pos_calls = {}
  local unit_set_calls = 0
  local state = {
    board_scene = {
      ground = {
        get_position = function()
          return { y = 0 }
        end,
      },
    },
    tile_positions = { _vec3(5, 2, 7) },
    board_last_positions = { [1] = "1:0" },
    board_last_vehicle_resync_seq = 1,
    board_sync_pending = false,
    tile_spacing = 0,
    player_units = {
      [1] = {
        set_position = function()
          unit_set_calls = unit_set_calls + 1
        end,
      },
    },
    player_units_missing = false,
  }

  local model = {
    board = {
      players = { { id = 1, position = 1, eliminated = false, seat_id = 4001 } },
      tiles = { { id = 1, type = "start" } },
      tile_states = {},
      phase = "start",
      move_anim = nil,
      tile_count = 1,
      vehicle_resync_seq = 1,
    },
  }

  _with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
    { target = math, key = "Vector3", value = _vec3 },
    { key = "vehicle_helper", value = {
      forward_eca_event_set_position = function(role_id, pos)
        set_pos_calls[#set_pos_calls + 1] = { role_id = role_id, pos = pos }
      end,
    } },
  }, function()
    board_view.refresh(state, model, function() end, function() return "[test]" end)
    _assert_eq(#set_pos_calls, 0, "same resync seq should not force vehicle set_position")

    model.board.vehicle_resync_seq = 2
    board_view.refresh(state, model, function() end, function() return "[test]" end)
  end)

  _assert_eq(unit_set_calls, 0, "vehicle player should not call unit.set_position")
  _assert_eq(#set_pos_calls, 1, "resync seq change should trigger set_position")
  _assert_eq(set_pos_calls[1].role_id, 1, "set_position role id should match player")
end

local function _test_move_anim_step_unlocks_and_relocks()
  local _vec3 = vec3.with_sub_length

  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
      },
    },
  }

  _with_patches({
    { key = "SetTimeOut", value = function(_, cb) cb() end },
  }, function()
    local anim_ctx = {
      on_step_lock = function(enabled)
        table.insert(calls, enabled)
      end,
      direction = { x = 1, y = 0, z = 0 },
    }
    move_anim.one_step(scene, 1, 1, 2, anim_ctx)
  end)

  _assert_eq(calls[1], false, "step should unlock at begin")
  _assert_eq(calls[2], true, "step should relock at end")
end

local function _test_board_view_vehicle_disabled_uses_unit_set_position()
  local board_view = require("src.presentation.render.BoardRuntime")

  local _vec3 = vec3.with_add

  local set_pos_calls = {}
  local unit_set_calls = 0
  local state = {
    board_scene = {
      ground = {
        get_position = function()
          return { y = 0 }
        end,
      },
    },
    tile_positions = { _vec3(5, 2, 7) },
    board_last_positions = { [1] = "1:0" },
    board_last_vehicle_resync_seq = 1,
    board_sync_pending = false,
    tile_spacing = 0,
    player_units = {
      [1] = {
        set_position = function()
          unit_set_calls = unit_set_calls + 1
        end,
      },
    },
    player_units_missing = false,
  }

  local model = {
    board = {
      players = { { id = 1, position = 1, eliminated = false, seat_id = 4001 } },
      tiles = { { id = 1, type = "start" } },
      tile_states = {},
      phase = "start",
      move_anim = nil,
      tile_count = 1,
      vehicle_resync_seq = 2,
    },
  }

  _with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = false },
    { target = math, key = "Vector3", value = _vec3 },
    { key = "vehicle_helper", value = {
      forward_eca_event_set_position = function(role_id, pos)
        set_pos_calls[#set_pos_calls + 1] = { role_id = role_id, pos = pos }
      end,
    } },
  }, function()
    board_view.refresh(state, model, function() end, function() return "[test]" end)
  end)

  _assert_eq(#set_pos_calls, 0, "vehicle helper should not be called when feature disabled")
  _assert_eq(unit_set_calls, 1, "disabled vehicle should fall back to unit.set_position")
end

local function _test_ui_model_structure()
  local ui_model = require("src.presentation.state.UIModel")
  local g = _new_game()
  local player = g:current_player()
  player.inventory:add({ id = 2001 })
  local ui_state = {
    ui = {
      auto_play = false,
      item_slots = { 1, 2, 3, 4, 5 },
    },
  }
  local model = ui_model.build(g, {
    game = g,
    ui_state = ui_state,
    last_turn = g.last_turn,
    finished = g.finished,
  })
  assert(model.panel and model.panel.turn_label, "ui_model.panel.turn_label expected")
  assert(type(model.item_slots) == "table" and model.item_slots[1] == 2001, "ui_model.item_slots[1] expected")
  assert(model.board and model.board.tiles and model.board.tile_states, "ui_model.board data")
end

local function _test_ui_panel_clamps_negative_assets_to_zero()
  local ui_panel = require("src.presentation.ui.UIPanel")
  local statuses = ui_panel.build_player_statuses({
    players = {
      {
        id = 1,
        name = "P1",
        cash = -123,
        eliminated = false,
        properties = {},
      },
    },
  }, {
    board = {
      get_tile_by_id = function()
        return nil
      end,
    },
  }, 1)

  local row = statuses and statuses[1] or nil
  assert(row ~= nil, "panel row should exist")
  _assert_eq(row.cash, "现金: 0", "negative cash should render as zero")
  _assert_eq(row.total_assets, "总资产: 0", "negative total assets should render as zero")
end

local function _test_ui_model_player_slot_map_and_choice_owner()
  local ui_model = require("src.presentation.state.UIModel")
  local g = _new_game()
  g.players[1].inventory:add({ id = 2001 })
  g.players[2].inventory:add({ id = 2002 })
  g.players[1].auto = false
  g.players[2].auto = true
  g.turn.pending_choice = {
    id = 77,
    kind = "item_phase_choice",
    options = { { id = 2002, label = "用道具" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = 2 },
  }

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
  })

  assert(model.current_player_id == 1, "current_player_id expected")
  assert(model.item_choice_owner_id == 2, "item_choice_owner_id expected")
  assert(model.item_slots and model.item_slots[1] == 2001, "current player slot expected")
  assert(model.item_slots_by_player and model.item_slots_by_player[1][1] == 2001, "player1 slot map expected")
  assert(model.item_slots_by_player and model.item_slots_by_player[2][1] == 2002, "player2 slot map expected")
  assert(model.auto_enabled_by_player and model.auto_enabled_by_player[1] == false, "player1 auto expected false")
  assert(model.auto_enabled_by_player and model.auto_enabled_by_player[2] == true, "player2 auto expected true")
  assert(model.panel and model.panel.auto_label_by_player and model.panel.auto_label_by_player[1] == "自动：关",
    "player1 auto label expected")
  assert(model.panel and model.panel.auto_label_by_player and model.panel.auto_label_by_player[2] == "自动：开",
    "player2 auto label expected")
end

local function _test_ui_model_player_profile_prefers_role_api_with_fallback()
  local ui_model = require("src.presentation.state.UIModel")
  local g = _new_game()
  g.players[1].name = "本地玩家1"
  g.players[2].name = "本地玩家2"
  g.players[2].eliminated = true
  local role_by_id = {
    [1] = {
      get_name = function()
        return "远端昵称1"
      end,
      get_head_icon = function()
        return 12345
      end,
    },
    [2] = {
      get_name = function()
        error("name failed")
      end,
      get_head_icon = function()
        error("avatar failed")
      end,
    },
  }
  local model = nil
  _with_patches({
    { target = GameAPI, key = "get_role", value = function(role_id)
      return role_by_id[role_id]
    end },
  }, function()
    model = ui_model.build(g, {
      game = g,
      ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = g.last_turn,
      finished = g.finished,
    })
  end)

  local row1 = model and model.panel and model.panel.player_rows and model.panel.player_rows[1] or nil
  local row2 = model and model.panel and model.panel.player_rows and model.panel.player_rows[2] or nil
  assert(row1 and row1.name == "远端昵称1", "player1 should use role name")
  assert(row1 and row1.avatar == 12345, "player1 should use role avatar")
  assert(row2 and row2.name == "本地玩家2 (出局)", "player2 name should fallback to local name with eliminated suffix")
  assert(row2 and row2.avatar == nil, "player2 avatar should fallback to nil when role api failed")
end

local function _test_ui_model_player_profile_accepts_stringified_avatar()
  local ui_model = require("src.presentation.state.UIModel")
  local g = _new_game()
  g.players[1].name = "本地玩家1"
  local icon_obj = setmetatable({}, {
    __tostring = function()
      return "67890"
    end,
  })
  local role_by_id = {
    [1] = {
      get_name = function()
        return "远端昵称1"
      end,
      get_head_icon = function()
        return icon_obj
      end,
    },
  }
  local model = nil
  _with_patches({
    { target = GameAPI, key = "get_role", value = function(role_id)
      return role_by_id[role_id]
    end },
  }, function()
    model = ui_model.build(g, {
      game = g,
      ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = g.last_turn,
      finished = g.finished,
    })
  end)

  local row1 = model and model.panel and model.panel.player_rows and model.panel.player_rows[1] or nil
  assert(row1 and row1.avatar == 67890, "player1 avatar should parse stringified icon key")
end

local function _test_turn_dispatch_rejects_non_current_actor()
  local g = _new_game()
  local state = {
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }

  local res_auto = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = 2,
  }, {})
  assert(res_auto and res_auto.status == "applied", "auto button should allow non-current actor")
  assert(g.players[2].auto == true, "player2 auto should toggle")

  local res_next = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "next",
    actor_role_id = 2,
  }, {})
  assert(res_next and res_next.status == "rejected", "next button should reject non-current actor")
end

local function _test_turn_dispatch_rejects_choice_non_owner()
  local g = _new_game()
  local state = {
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  g.turn.pending_choice = {
    id = 9,
    kind = "market_buy",
    options = { { id = 1, label = "X" } },
    allow_cancel = true,
    meta = { player_id = 1 },
  }
  state.pending_choice = g.turn.pending_choice

  local dispatched = nil
  function g:dispatch_action(action)
    dispatched = action
    self.turn.pending_choice = nil
  end

  local res = turn_dispatch.dispatch_action(g, state, {
    type = "choice_select",
    choice_id = 9,
    option_id = 1,
    actor_role_id = 2,
  }, {})

  assert(res and res.status == "rejected", "choice_select should reject non-owner actor")
  assert(dispatched == nil, "rejected choice should not dispatch")
  assert(g.turn.pending_choice ~= nil, "rejected choice should keep pending")
end

local function _test_turn_dispatch_auto_rejects_unmapped_role()
  local g = _new_game()
  local state = {
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
    },
  }
  local before = g.players[1].auto
  local res = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = 99,
  }, {})
  assert(res and res.status == "rejected", "auto button should reject unmapped role")
  assert(g.players[1].auto == before, "mapped players auto should keep unchanged")
end

local function _test_turn_dispatch_item_slot_uses_actor_slot_map()
  local g = _new_game()
  local captured = nil
  g.turn.pending_choice = {
    id = 66,
    kind = "item_phase_choice",
    options = { { id = 3001, label = "用 3001" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = 1 },
  }
  function g:dispatch_action(action)
    captured = action
    self.turn.pending_choice = nil
  end

  local state = {
    pending_choice = g.turn.pending_choice,
    ui = {
      input_blocked = false,
      item_slot_item_ids = { [1] = 9999 },
      item_slot_item_ids_by_role = {
        [1] = { [1] = 3001 },
        [2] = { [1] = 4001 },
      },
    },
  }

  local res = turn_dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "item_slot_1",
    actor_role_id = 1,
  }, {})

  assert(res and res.status == "applied", "item slot action should apply")
  assert(captured and captured.type == "choice_select", "choice_select should dispatch")
  assert(captured and captured.option_id == 3001, "should read actor role slot mapping")
end

local function _test_ui_intent_dispatcher_market_confirm_routes_choice_select()
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

  _with_patches({}, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "market_confirm",
      choice_id = 12,
      option_id = 34,
    }, {})
  end)

  assert(captured and captured.type == "choice_select", "market_confirm should route as choice_select")
  _assert_eq(captured and captured.choice_id, 12, "market_confirm should keep choice id")
  _assert_eq(captured and captured.option_id, 34, "market_confirm should keep option id")
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
  local visible_calls = {}

  _with_patches({
    { key = "all_roles", value = { role } },
    { key = "UIManager", value = {
      client_role = nil,
      query_nodes_by_name = function()
        return { { visible = false } }
      end,
    } },
    { target = gameplay_rules, key = "debug_log_enabled", value = false },
    { target = ui_view, key = "set_debug_visible", value = function(ctx, visible)
      visible_calls[#visible_calls + 1] = visible
      ctx.ui.debug_visible = visible == true
      local active = UIManager and UIManager.client_role or nil
      if active and active.get_roleid then
        local role_id = active.get_roleid()
        ctx.ui.debug_visible_by_role[role_id] = visible == true
        ctx.ui.debug_log_enabled_by_role[role_id] = visible == true
      end
    end },
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

  _assert_eq(visible_calls[1], true, "first toggle_action_log should enable action_log")
  _assert_eq(visible_calls[2], false, "second toggle_action_log should disable action_log")
end

local function _test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game()
  local visible_calls = {}
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
    { target = ui_view, key = "set_debug_visible", value = function(ctx, visible)
      visible_calls[#visible_calls + 1] = visible
      ctx.ui.debug_visible = visible == true
      local active = UIManager and UIManager.client_role or nil
      if active and active.get_roleid then
        local role_id = active.get_roleid()
        ctx.ui.debug_visible_by_role[role_id] = visible == true
      end
    end },
  }, function()
    ui_intent_dispatcher.dispatch(state, nil, {
      type = "toggle_action_log",
      actor_role_id = 101,
    }, {})
  end)

  _assert_eq(dispatch_calls, 0, "toggle_action_log should not dispatch gameplay action")
  _assert_eq(state.ui.debug_visible_by_role[101], true, "toggle_action_log should bypass block without game")
  _assert_eq(visible_calls[1], true, "toggle_action_log should still toggle visible state")
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

local function _test_ui_intent_dispatcher_auto_button_forces_local_role_id()
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

  _assert_eq(captured and captured.actor_role_id, 1, "auto dispatch should force local role id")
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

local function _test_ui_intent_dispatcher_auto_button_toggles_local_role_during_other_turn()
  local g = _new_game()
  g.turn.current_player_index = 1
  local state = {
    turn_action_port = {
      dispatch_action = function(game, state_ctx, action, opts)
        return turn_dispatch.dispatch_action(game, state_ctx, action, opts)
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

  _assert_eq(g.players[1].auto, before_1, "other-turn auto click should not change current player auto")
  _assert_eq(g.players[2].auto, not before_2, "other-turn auto click should toggle local role auto")
end

local function _test_ui_view_render_by_role_slots_are_isolated()
  local main_view = require("src.presentation.api.UIViewService")

  local image_logs = {}
  local node_map = {}
  local touch_logs = {}
  local visible_logs = {}
  local label_logs = {}
  local button_logs = {}

  local function role_key()
    local role = UIManager and UIManager.client_role or nil
    if role and role.get_roleid then
      return role.get_roleid()
    end
    return 0
  end

  local function new_texture_node(node_name)
    local storage = {}
    return setmetatable({}, {
      __index = function(_, k)
        return storage[k]
      end,
      __newindex = function(_, k, v)
        if k == "image_texture" then
          local rk = role_key()
          image_logs[rk] = image_logs[rk] or {}
          image_logs[rk][node_name] = v
        end
        storage[k] = v
      end,
    })
  end

  for i = 1, 5 do
    local node_name = "基础_道具槽位" .. tostring(i)
    node_map[node_name] = new_texture_node(node_name)
  end
  for i = 1, 4 do
    local node_name = "基础_玩家" .. tostring(i) .. "头像"
    node_map[node_name] = new_texture_node(node_name)
  end

  local function query_nodes_by_name(name)
    local node = node_map[name]
    if not node then
      node = {}
      node_map[name] = node
    end
    return { node }
  end

  local state = {
    ui_refs = {
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
      ["2002"] = "ICON2002",
    },
    ui = {
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3", "基础_道具槽位4", "基础_道具槽位5" },
      base_hidden_nodes = {
        "基础_行动按钮",
        "基础_道具槽位1",
        "基础_道具槽位2",
        "基础_道具槽位3",
        "基础_道具槽位4",
        "基础_道具槽位5",
      },
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      set_label = function(_, name, text)
        local rk = role_key()
        label_logs[rk] = label_logs[rk] or {}
        label_logs[rk][name] = text
      end,
      set_button = function(_, name, text)
        local rk = role_key()
        button_logs[rk] = button_logs[rk] or {}
        button_logs[rk][name] = text
      end,
      set_visible = function(_, name, visible)
        local rk = role_key()
        visible_logs[rk] = visible_logs[rk] or {}
        visible_logs[rk][name] = visible
      end,
      set_touch_enabled = function(_, name, enabled)
        local rk = role_key()
        touch_logs[rk] = touch_logs[rk] or {}
        touch_logs[rk][name] = enabled
      end,
      item_slot_item_ids_by_role = {},
    },
  }

  local ui_model = {
    panel = {
      turn_label = "倒计时:0",
      auto_label = "自动：关",
      auto_label_by_player = {
        [1] = "自动：关",
        [2] = "自动：开",
      },
      player_rows = {
        { name = "P1", avatar = "AVATAR_1", cash = "现金: 1", land_count = "地块: 0", total_assets = "总资产: 1" },
        { name = "P2", avatar = nil, cash = "现金: 1", land_count = "地块: 0", total_assets = "总资产: 1" },
        { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
    item_slots_by_player = {
      [1] = { 2001 },
      [2] = { 2002 },
    },
    item_slots = { 2001 },
    current_player_id = 1,
    item_choice_owner_id = 1,
    choice = nil,
  }

  local roles = {
    { get_roleid = function() return 1 end },
    { get_roleid = function() return 2 end },
  }

  _with_patches({
    { key = "all_roles", value = roles },
    { key = "UIManager", value = { client_role = roles[1], query_nodes_by_name = query_nodes_by_name } },
  }, function()
    main_view.refresh_panel(state, ui_model)
  end)

  assert(image_logs[1] and image_logs[1]["基础_道具槽位1"] == "ICON2001", "role1 slot icon expected")
  assert(image_logs[2] and image_logs[2]["基础_道具槽位1"] == "ICON2002", "role2 slot icon expected")
  assert(image_logs[0] and image_logs[0]["基础_玩家1头像"] == "AVATAR_1", "player1 avatar should use row avatar")
  assert(image_logs[0] and image_logs[0]["基础_玩家2头像"] == "EMPTY", "player2 avatar should fallback to empty key")
  assert(touch_logs[1] and touch_logs[1]["基础_行动按钮"] == true, "current role action button should be enabled")
  assert(touch_logs[2] and touch_logs[2]["基础_行动按钮"] == false, "non-current role action button should be disabled")
  assert(touch_logs[1] and touch_logs[1]["始终显示_托管按钮"] == true, "role1 auto button should be enabled")
  assert(touch_logs[2] and touch_logs[2]["始终显示_托管按钮"] == false, "non-local role auto button should be disabled")
  assert(touch_logs[1] and touch_logs[1]["始终显示_文本"] == false, "role1 auto label should stay non-clickable")
  assert(touch_logs[2] and touch_logs[2]["始终显示_文本"] == false, "role2 auto label should stay non-clickable")
  assert(label_logs[1] and label_logs[1]["始终显示_文本"] == "自动：关", "role1 auto label should show status")
  assert(label_logs[2] and label_logs[2]["始终显示_文本"] == "自动：开", "role2 auto label should show status")
  assert(visible_logs[2] and visible_logs[2]["基础_倒计时"] == true, "non-current role countdown should be visible")
  assert(visible_logs[2] and visible_logs[2]["基础_道具槽位1"] == true, "non-current role slot should be visible")
  assert(visible_logs[2] and visible_logs[2]["始终显示_托管按钮"] == true, "auto button should stay visible")
  assert(visible_logs[2] and visible_logs[2]["始终显示_文本"] == true, "auto label should stay visible")
  assert(state.ui.item_slot_item_ids_by_role[1] and state.ui.item_slot_item_ids_by_role[1][1] == 2001, "role1 slot map expected")
  assert(state.ui.item_slot_item_ids_by_role[2] and state.ui.item_slot_item_ids_by_role[2][1] == 2002, "role2 slot map expected")
end

local function _test_ui_events_send_without_roles_no_crash()
  local ui_events = require("src.presentation.shared.UIEvents")
  ui_events.set_roles(nil)
  ui_events.send_to_all("测试事件", { ok = true })
end

local function _test_ui_nodes_validate_reports_missing()
  local nodes = require("Data.UIManagerNodes")
  local known = {}
  for _, entry in pairs(nodes) do
    if type(entry) == "table" then
      known[entry[1]] = true
    end
  end
  local required = { "不存在的节点_测试" }
  local missing = {}
  for _, name in ipairs(required) do
    if not known[name] then
      missing[#missing + 1] = name
    end
  end
  assert(#missing == 1, "validate should return missing node list")
  assert(missing[1] == "不存在的节点_测试", "missing node name should match")
end

local function _test_apply_input_lock_keeps_auto_controls_enabled()
  local touch = {}
  local visible = {}
  local state = {
    ui_model = {
      current_player_id = 1,
      item_slots_by_player = { [1] = { 2001 } },
      panel = {
        auto_label = "自动：关",
        auto_label_by_player = { [1] = "自动：关" },
      },
    },
    ui = {
      input_blocked = true,
      item_slots = { "基础_道具槽位1" },
      base_hidden_nodes = { "基础_行动按钮", "基础_道具槽位1" },
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      choice_screens = {
        player = { option_buttons = {} },
        target = { option_buttons = {}, under_button = "位置_脚下" },
        remote = { option_buttons = {}, cancel = "遥控骰子_取消" },
        building = { body = "建筑升级_文本", cancel = "建筑升级_取消", confirm = "建筑升级_确定按钮" },
      },
      set_touch_enabled = function(_, name, enabled)
        touch[name] = enabled
      end,
      set_visible = function(_, name, value)
        visible[name] = value
      end,
      set_button = function() end,
    },
  }
  local roles = {
    { get_roleid = function() return 1 end },
  }

  _with_patches({
    { key = "all_roles", value = roles },
  }, function()
    ui_view.apply_input_lock(state)
  end)

  assert(touch["基础_行动按钮"] == false, "action button should stay blocked")
  assert(touch["始终显示_托管按钮"] == true, "auto button should stay enabled")
  assert(touch["始终显示_文本"] == false, "auto label should stay non-clickable")
  assert(visible["基础_道具槽位1"] == true, "item slot should stay visible when locked")
end

local function _test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped()
  local touch = {}
  local state = {
    ui_model = {
      current_player_id = 1,
      item_slots_by_player = {},
      panel = {
        auto_label = "自动：关",
      },
    },
    ui = {
      input_blocked = true,
      item_slots = { "基础_道具槽位1" },
      base_hidden_nodes = { "基础_行动按钮", "基础_道具槽位1" },
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      choice_screens = {
        player = { option_buttons = {} },
        target = { option_buttons = {}, under_button = "位置_脚下" },
        remote = { option_buttons = {}, cancel = "遥控骰子_取消" },
        building = { body = "建筑升级_文本", cancel = "建筑升级_取消", confirm = "建筑升级_确定按钮" },
      },
      set_touch_enabled = function(_, name, enabled)
        touch[name] = enabled
      end,
      set_visible = function() end,
      set_button = function() end,
    },
  }
  local roles = {
    { get_roleid = function() return 1 end },
  }

  _with_patches({
    { key = "all_roles", value = roles },
  }, function()
    ui_view.apply_input_lock(state)
  end)

  assert(touch["始终显示_托管按钮"] == true, "auto button should stay enabled when role mapping is missing")
  assert(touch["始终显示_文本"] == false, "auto label should stay non-clickable when role mapping is missing")
end

local function _test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists()
  local main_view = require("src.presentation.api.UIViewService")
  local touch_logs = {}
  local state = {
    ui_refs = { ["Empty"] = "EMPTY", ["2001"] = "ICON2001" },
    ui = {
      item_slots = { "基础_道具槽位1" },
      base_hidden_nodes = { "基础_行动按钮", "基础_道具槽位1" },
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      item_slot_item_ids_by_role = {},
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function(_, name, enabled)
        local role = UIManager and UIManager.client_role or nil
        local role_id = role and role.get_roleid and role.get_roleid() or 0
        touch_logs[role_id] = touch_logs[role_id] or {}
        touch_logs[role_id][name] = enabled
      end,
      query_node = function()
        return {}
      end,
    },
  }
  local ui_model = {
    panel = {
      turn_label = "倒计时:0",
      auto_label = "自动：关",
      auto_label_by_player = {
        [1] = "自动：关",
      },
      player_rows = {
        { name = "P1", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P2", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P3", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P4", avatar = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
    board = { players = {} },
    current_player_id = 1,
    auto_enabled_by_player = { [1] = false },
    item_slots_by_player = { [1] = { 2001 } },
  }
  local local_role = {
    get_roleid = function()
      return 1
    end,
  }
  local unmapped_role = {
    get_roleid = function()
      return 99
    end,
  }

  _with_patches({
    { key = "all_roles", value = { local_role, unmapped_role } },
    { key = "UIManager", value = {
      client_role = local_role,
      query_nodes_by_name = function()
        return { {} }
      end,
    } },
  }, function()
    main_view.refresh_panel(state, ui_model)
  end)

  assert(touch_logs[1] and touch_logs[1]["始终显示_托管按钮"] == true, "local role auto button should stay enabled")
  assert(touch_logs[99] and touch_logs[99]["始终显示_托管按钮"] == false, "unmapped role auto button should stay disabled")
end

local function _test_ui_touch_policy_auto_controls_touch()
  local touch = {}
  local ui = {
    auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
    set_touch_enabled = function(_, name, enabled)
      touch[name] = enabled
    end,
  }

  ui_touch_policy.set_auto_controls_touch(ui, true)
  _assert_eq(touch["始终显示_托管按钮"], true, "auto button should be clickable when enabled")
  _assert_eq(touch["始终显示_文本"], false, "auto label should stay non-clickable")

  ui_touch_policy.set_auto_controls_touch(ui, false)
  _assert_eq(touch["始终显示_托管按钮"], false, "auto button should be non-clickable when disabled")
  _assert_eq(touch["始终显示_文本"], false, "auto label should stay non-clickable when disabled")
end

local function _test_ui_touch_policy_runtime_nodes_touch_enabled()
  local node1 = { disabled = true }
  local node2 = { disabled = true }

  ui_touch_policy.set_runtime_nodes_touch_enabled({ node1, node2 }, true)
  _assert_eq(node1.disabled, false, "runtime node should be enabled")
  _assert_eq(node2.disabled, false, "runtime node should be enabled")

  ui_touch_policy.set_runtime_nodes_touch_enabled({ node1, node2 }, false)
  _assert_eq(node1.disabled, true, "runtime node should be disabled")
  _assert_eq(node2.disabled, true, "runtime node should be disabled")
end

local function _test_push_popup_sets_card_image_by_image_ref()
  local last_image_key = nil
  local card_node = {
    set_texture_keep_size = function(_, image_key)
      last_image_key = image_key
    end,
  }
  local state, nodes, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, card_node)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
    ui_view.push_popup(state, {
      title = "道具卡",
      body = "测试",
      image_ref = 2001,
    })
  end)

  _assert_eq(last_image_key, "ICON2001", "popup card should use mapped image")
  _assert_eq(nodes["卡牌展示_图片"].visible, true, "popup card should be visible when image exists")
end

local function _test_push_popup_hides_card_and_clears_image_when_missing()
  local last_image_key = nil
  local card_node = {
    set_texture_keep_size = function(_, image_key)
      last_image_key = image_key
    end,
  }
  local state, nodes, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, card_node)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
    ui_view.push_popup(state, {
      title = "道具卡",
      body = "测试",
      image_ref = 2001,
    })
    ui_view.push_popup(state, {
      title = "黑市",
      body = "测试2",
    })
  end)

  _assert_eq(last_image_key, "EMPTY", "popup card should reset to empty key when image missing")
  _assert_eq(nodes["卡牌展示_图片"].visible, false, "popup card should hide when image missing")
end

local function _test_popup_hidden_for_non_current_role()
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })
  state.ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = {}, [2] = {} },
  }
  local role1_events = {}
  local role2_events = {}
  local roles = {
    _build_role_with_events(1, role1_events),
    _build_role_with_events(2, role2_events),
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = roles },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role.get_roleid()
    end },
  }, function()
    ui_view.push_popup(state, {
      title = "黑市",
      body = "测试",
    })
  end)

  assert(_has_event(role1_events, "显示卡牌展示屏"), "current role should see popup canvas")
  assert(not _has_event(role2_events, "显示卡牌展示屏"), "non-current role should not see popup canvas")
end

local function _test_popup_visible_for_all_roles_when_allowed_kind()
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })
  state.ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = {}, [2] = {} },
  }
  local role1_events = {}
  local role2_events = {}
  local roles = {
    _build_role_with_events(1, role1_events),
    _build_role_with_events(2, role2_events),
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = roles },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role.get_roleid()
    end },
  }, function()
    ui_view.push_popup(state, {
      title = "机会卡",
      body = "测试",
      kind = "chance_card",
    })
    ui_view.push_popup(state, {
      title = "道具卡",
      body = "测试",
      kind = "item_card",
    })
  end)

  assert(_has_event(role1_events, "显示卡牌展示屏"), "current role should see popup canvas")
  assert(_has_event(role2_events, "显示卡牌展示屏"), "non-current role should see popup canvas")
end

local function _test_bankruptcy_popup_visible_for_all_roles()
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })
  state.ui_model = {
    current_player_id = 1,
    item_slots_by_player = { [1] = {}, [2] = {} },
  }
  local role1_events = {}
  local role2_events = {}
  local roles = {
    _build_role_with_events(1, role1_events),
    _build_role_with_events(2, role2_events),
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = roles },
    { target = runtime_port, key = "for_each_role_or_global", value = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end },
    { target = runtime_port, key = "resolve_role_id", value = function(role)
      return role.get_roleid()
    end },
  }, function()
    ui_view.push_popup(state, {
      kind = "bankruptcy",
      text = "破产测试",
    })
  end)

  assert(_has_event(role1_events, "显示破产展示屏"), "current role should see bankruptcy canvas")
  assert(_has_event(role2_events, "显示破产展示屏"), "non-current role should see bankruptcy canvas")
end

local function _test_bankruptcy_popup_avatar_uses_native_size_path()
  local native_calls = 0
  local avatar_image_key = nil
  local state, _, query_nodes = _build_popup_view_state({
    ["Empty"] = "EMPTY",
  }, {
    set_texture_keep_size = function() end,
  })

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
    { target = runtime_port, key = "set_node_texture_native_size", value = function(_, image_key)
      native_calls = native_calls + 1
      avatar_image_key = image_key
    end },
  }, function()
    ui_view.push_popup(state, {
      kind = "bankruptcy",
      text = "破产测试",
      avatar_key = 2002,
    })
  end)

  _assert_eq(native_calls, 1, "bankruptcy popup avatar should use native-size path")
  _assert_eq(avatar_image_key, 2002, "bankruptcy popup avatar should forward payload image key")
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
    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
    ui_view.push_popup(state, {
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

local function _test_choice_modal_routes_to_new_screens()
  local state, nodes, query_nodes = _build_choice_modal_state()

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    ui_view.open_choice_modal(state, {
      id = 1,
      kind = "item_target_player",
      title = "选人",
      body = "body",
      options = {
        { id = 11, label = "玩家A" },
      },
      allow_cancel = true,
      cancel_label = "取消",
    })
    _assert_eq(state.ui.active_choice_screen_key, "player", "item_target_player should route to player screen")
    _assert_eq(nodes["玩家选择屏"].visible, true, "player screen should be visible")

    ui_view.open_choice_modal(state, {
      id = 2,
      kind = "roadblock_target",
      title = "选位置",
      body = "body",
      options = {
        { id = 1, label = "前方1格：商店" },
      },
      allow_cancel = true,
      cancel_label = "放弃",
    })
    _assert_eq(state.ui.active_choice_screen_key, "target", "roadblock_target should route to target screen")
    _assert_eq(nodes["位置选择屏"].visible, true, "target screen should be visible")

    ui_view.open_choice_modal(state, {
      id = 3,
      kind = "remote_dice_value",
      title = "遥控骰子",
      body = "body",
      options = {
        { id = 1, label = "1" },
        { id = 2, label = "2" },
        { id = 3, label = "3" },
      },
      allow_cancel = true,
      cancel_label = "放弃",
    })
    _assert_eq(state.ui.active_choice_screen_key, "remote", "remote_dice_value should route to remote screen")
    _assert_eq(nodes["遥控骰子屏"].visible, true, "remote screen should be visible")

    ui_view.open_choice_modal(state, {
      id = 4,
      kind = "landing_optional_effect",
      title = "请选择",
      body = "",
      options = {
        { id = "buy_land", label = "购买地块" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
    })
    _assert_eq(state.ui.active_choice_screen_key, "building", "buy_land optional should route to building screen")
    _assert_eq(nodes["建筑升级屏"].visible, true, "building screen should be visible")
    _assert_eq(nodes["建筑升级_标题"].text, "购买地块", "building title should follow option semantic")
    _assert_eq(nodes["建筑升级_文本"].text, "", "building body should sync from choice body")
    _assert_eq(nodes["建筑升级_确定按钮"].text, "", "building confirm text should be empty")
    _assert_eq(nodes["建筑升级_取消"].text, "", "building cancel text should be empty")

    ui_view.open_choice_modal(state, {
      id = 5,
      kind = "item_phase_choice",
      title = "行动前：使用道具？",
      body = "",
      options = {
        { id = 2001, label = "路障卡" },
      },
      allow_cancel = true,
      cancel_label = "结束阶段",
    })
    _assert_eq(state.ui.active_choice_screen_key, nil, "item_phase_choice should stay on base inline route")
    _assert_eq(nodes["位置选择屏"].visible, false, "target screen should stay hidden for item phase")
    _assert_eq(nodes["遥控骰子屏"].visible, false, "remote screen should stay hidden for item phase")

    ui_view.open_choice_modal(state, {
      id = 6,
      kind = "landing_optional_effect",
      title = "可选效果",
      body = "",
      options = {
        { id = "other_effect", label = "其他效果" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
    })
    _assert_eq(state.ui.active_choice_screen_key, nil, "non-building optional should not open dedicated screen")
    _assert_eq(nodes["位置选择屏"].visible, false, "target screen should stay hidden for base_inline route")
  end)
end

local function _test_choice_route_policy_prefers_explicit_route_metadata()
  local cases = {
    {
      label = "explicit market",
      choice = { kind = "roadblock_target", route_key = "market", requires_confirm = false },
      route = "market",
      confirm = false,
    },
    {
      label = "explicit building confirm",
      choice = { kind = "item_target_player", route_key = "building", requires_confirm = true },
      route = "building",
      confirm = true,
    },
    {
      label = "legacy fallback",
      choice = { kind = "remote_dice_value" },
      route = "remote",
      confirm = false,
    },
    {
      label = "item phase inline",
      choice = { kind = "item_phase_choice" },
      route = "base_inline",
      confirm = false,
    },
    {
      label = "unknown fallback",
      choice = { kind = "unknown_kind" },
      route = "base_inline",
      confirm = false,
    },
  }
  for _, c in ipairs(cases) do
    _assert_eq(ui_choice_route_policy.resolve(c.choice), c.route, c.label .. " route")
    _assert_eq(ui_choice_route_policy.requires_confirm(c.choice), c.confirm, c.label .. " confirm")
  end
end

local function _test_ui_event_router_player_target_click_direct_submit()
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

  local node_map = {}
  local function query_nodes_by_name(name)
    local node = node_map[name]
    if not node then
      node = new_node()
      node_map[name] = node
    end
    return { node }
  end

  local captured = {}
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        table.insert(captured, action)
      end,
      should_block_action = function()
        return false
      end,
    },
    ui = ui_view.build_ui_state(),
    ui_model = {
      choice = {
        id = 10,
        kind = "item_target_player",
        allow_cancel = true,
        options = {
          { id = 11, label = "玩家A" },
          { id = 22, label = "玩家B" },
          { id = 33, label = "玩家C" },
        },
      },
    },
    pending_choice_selected_option_id = nil,
    choice_visible_option_ids = nil,
  }

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = query_nodes_by_name,
    } },
  }, function()
    ui_event_router.bind(state, function()
      return {}
    end)
    node_map["玩家选择_槽位2"]._listener_cb({})

    state.ui_model.choice = {
      id = 20,
      kind = "roadblock_target",
      allow_cancel = true,
      options = {
        { id = 101, label = "前1" },
        { id = 102, label = "前2" },
        { id = 103, label = "前3" },
        { id = 201, label = "后1" },
        { id = 202, label = "后2" },
      },
    }
    node_map["位置_后1"]._listener_cb({})
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_select", "player click should dispatch choice_select")
  _assert_eq(captured[1] and captured[1].choice_id, 10, "player click should keep choice id")
  _assert_eq(captured[1] and captured[1].option_id, 22, "player click should submit clicked option")
  _assert_eq(captured[2] and captured[2].type, "choice_select", "target click should dispatch choice_select")
  _assert_eq(captured[2] and captured[2].choice_id, 20, "target click should keep choice id")
  _assert_eq(captured[2] and captured[2].option_id, 201, "target click should submit clicked option")
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
    ["始终显示_行动日志图标"] = new_node(),
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
  local role = {
    get_roleid = function()
      return 101
    end,
  }

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = query_nodes_by_name,
      client_role = nil,
    } },
  }, function()
    ui_event_router.bind(state, function()
      return {}
    end)

    local role_id = role.get_roleid()
    _assert_eq(state.ui.debug_visible_by_role[role_id], nil, "action_log role flag should start nil")
    assert(type(node_map["始终显示_行动日志图标"]._listener_cb) == "function", "action_log button should bind click listener")
    local before = require("src.presentation.interaction.UIEventState").resolve_debug_enabled(state)
    node_map["始终显示_行动日志图标"]._listener_cb({ role = role })
    local first_value = state.ui.debug_visible_by_role[role_id]
    _assert_eq(first_value, not before, "action_log toggle should invert role visibility")
    _assert_eq(UIManager.client_role, nil, "action_log toggle should restore client role")

    node_map["始终显示_行动日志图标"]._listener_cb({ role = role })
    local second_value = state.ui.debug_visible_by_role[role_id]
    assert(second_value ~= first_value, "action_log toggle should flip role visibility after second click")
    _assert_eq(UIManager.client_role, nil, "action_log toggle should restore client role after second click")
  end)
end

local function _test_market_selection_updates_icon_without_resize()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local option_id = entry.product_id
  local selected_node = {}
  local reset_calls = 0
  selected_node.reset_size = function()
    reset_calls = reset_calls + 1
  end
  local labels = {}
  local state = {
    ui_refs = {
      ["Empty"] = 1001,
      [tostring(option_id)] = 1002,
    },
    ui = {
      set_label = function(_, name, text)
        labels[name] = text
      end,
      query_node = function(name)
        _assert_eq(name, market_layout.selected_card, "selected card node expected")
        return selected_node
      end,
    },
  }

  market_view.refresh_market_selection(state, option_id)

  _assert_eq(selected_node.image_texture, 1002, "market selected icon should update")
  _assert_eq(reset_calls, 0, "market selected icon should not call reset_size")
  _assert_eq(labels[market_layout.price_label], "售价：" .. tostring(entry.price) .. " " .. entry.currency,
    "market price label should update")
end

local function _test_market_close_resets_icon_without_resize()
  local reset_calls = 0
  local selected_node = {
    reset_size = function()
      reset_calls = reset_calls + 1
    end,
  }
  local state = {
    choice_visible_option_ids = { 1, 2 },
    pending_choice_selected_option_id = 1,
    ui_refs = {
      ["Empty"] = 4321,
    },
    ui = {
      market_active = true,
      set_visible = function() end,
      set_label = function() end,
      set_touch_enabled = function() end,
      query_node = function(name)
        _assert_eq(name, market_layout.selected_card, "selected card node expected")
        return selected_node
      end,
    },
  }

  market_view.close_market_panel(state)

  _assert_eq(state.ui.market_active, false, "market panel should be inactive")
  _assert_eq(state.choice_visible_option_ids, nil, "market options should clear")
  _assert_eq(state.pending_choice_selected_option_id, nil, "selected market option should clear")
  _assert_eq(selected_node.image_texture, 4321, "market selected icon should reset to empty key")
  _assert_eq(reset_calls, 0, "market close should not call reset_size")
end

local function _test_item_slot_uses_keep_size_path()
  local keep_size_calls = 0
  local last_image_key = nil
  local slot_node = {
    set_texture_keep_size = function(_, image_key)
      keep_size_calls = keep_size_calls + 1
      last_image_key = image_key
    end,
  }
  local state = {
    ui_refs = {
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
    },
    ui = {
      item_slots = { "基础_道具槽位1" },
      set_touch_enabled = function() end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = {
      [1] = { 2001 },
    },
    choice = nil,
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = function() return { slot_node } end } },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = false,
    })
  end)

  _assert_eq(keep_size_calls, 1, "item slot should use keep-size texture path")
  _assert_eq(last_image_key, "ICON2001", "item slot should set expected image key")
end

local function _test_item_slot_refresh_shows_only_playable_outlines()
  local touch_state = {}
  local visible_state = {}
  local state = {
    ui_refs = {
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
      ["2002"] = "ICON2002",
      ["2003"] = "ICON2003",
    },
    ui = {
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3" },
      card_outlines = { "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3" },
      set_touch_enabled = function(_, name, enabled)
        touch_state[name] = enabled == true
      end,
      set_visible = function(_, name, visible)
        visible_state[name] = visible == true
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots = { 2001, 2002, 2003 },
    item_slots_by_player = { [1] = { 2001, 2002, 2003 } },
    choice = {
      kind = "item_phase_choice",
      options = { { id = 2001 }, { id = 2003 } },
    },
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  _assert_eq(visible_state["基础_可出牌外框1"], true, "playable slot 1 outline should be visible")
  _assert_eq(visible_state["基础_可出牌外框2"], false, "unplayable slot 2 outline should be hidden")
  _assert_eq(visible_state["基础_可出牌外框3"], true, "playable slot 3 outline should be visible")
  _assert_eq(touch_state["基础_道具槽位1"], true, "playable slot 1 should be clickable")
  _assert_eq(touch_state["基础_道具槽位2"], false, "unplayable slot 2 should be locked")
  _assert_eq(touch_state["基础_道具槽位3"], true, "playable slot 3 should be clickable")
end

local function _test_item_slot_intents_include_outline_nodes()
  local item_slot_intents = require("src.presentation.canvas.base.item_slot_intents")
  local state = {
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
    },
    ui_model = {
      choice = {
        kind = "item_phase_choice",
      },
    },
  }

  local specs = item_slot_intents.build(state)
  _assert_eq(#specs, 2, "item slot intents should include slot and outline")
  _assert_eq(specs[1].name, "基础_道具槽位1", "slot intent node expected")
  _assert_eq(specs[2].name, "基础_可出牌外框1", "outline intent node expected")
  local intent = specs[2].build_intent()
  _assert_eq(intent and intent.id, "item_slot_1", "outline click should map to slot action")
end

local function _test_tick_skips_anim_when_no_anim()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.presentation.api.UIViewService")
  local ui_model = require("src.presentation.state.UIModel")
  local board_view_mod = require("src.presentation.render.BoardRuntime")

  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function()
      return {
        set_camera_bind_mode = function() end,
        set_camera_lock_position = function() end,
      }
    end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
  }

  local game = {
    finished = false,
    winner = nil,
    players = { [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } } },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = { input_blocked = false },
  }

  local ok, err = pcall(function()
    _with_patches(patches, function()
      gameplay_loop.tick(game, state, 0.1)
    end)
  end)

  assert(ok, "tick should not error without anim: " .. tostring(err))
end

local function _test_action_anim_queue_consumes_in_order()
  local phases = {
    start = function()
      return "wait_action_anim", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  }
  local g = {
    turn = {
      phase = "start",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      action_anim = { seq = 1, kind = "item_use", player_id = 1 },
      action_anim_queue = { { seq = 2, kind = "item_use", player_id = 1 } },
    },
    dirty = { turn = false, any = false },
    board = {
      get_tile_by_id = function()
        return { level = 0, name = "" }
      end,
    },
    players = {
      [1] = {
        id = 1,
        name = "P1",
        cash = 0,
        status = { stay_turns = 0, deity = nil },
        inventory = { items = {} },
        properties = {},
      }
    },
  }
  function g:current_player()
    return self.players[self.turn.current_player_index]
  end
  function g:player_balance(player)
    return player.cash
  end
  local engine = turn_engine_cls:new(g, phases, { experimental_coroutine_turn = true })

  local state = engine:run_turn()
  _assert_eq(state, "wait_action_anim", "should wait action anim")
  _assert_eq(g.turn.action_anim.seq, 1, "current anim should be seq1")

  engine:dispatch({ type = "action_anim_done", seq = 999 })
  _assert_eq(g.turn.phase, "wait_action_anim", "wrong seq should keep wait_action_anim")
  _assert_eq(g.turn.action_anim.seq, 1, "wrong seq should keep current anim")

  engine:dispatch({ type = "action_anim_done", seq = 1 })
  _assert_eq(g.turn.phase, "wait_action_anim", "should still wait second anim")
  _assert_eq(g.turn.action_anim.seq, 2, "current anim should switch to seq2")

  engine:dispatch({ type = "action_anim_done", seq = 2 })
  assert(g.turn.phase ~= "wait_action_anim", "should leave action anim wait after queue drained")
  assert(g.turn.action_anim == nil, "action_anim should be nil after queue drained")
end

local function _test_action_anim_default_duration()
  local durations = {}
  local state = {
    game = { turn = { current_player_index = 1 }, players = { [1] = { id = 1 } } },
  }
  _with_patches({
    { key = "GlobalAPI", value = { show_tips = function(_, duration) durations[#durations + 1] = duration end } },
    { key = "SetTimeOut", value = function() end },
  }, function()
    local d1 = action_anim.play(state, { kind = "item_use", player_id = 1 })
    local d2 = action_anim.play(state, { kind = "item_use", player_id = 1, duration = 1.8 })
    _assert_eq(d1, 1.0, "default action anim duration should be 1s")
    _assert_eq(d2, 1.8, "explicit action anim duration should override")
  end)
  _assert_eq(#durations, 2, "tip should be shown twice")
end

local function _test_action_anim_no_camera_focus_side_effect()
  local follow_events = 0
  local state = {
    game = {
      turn = { current_player_index = 1 },
      players = { [1] = { id = 1 }, [2] = { id = 2 } },
    },
  }
  _with_patches({
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "TriggerCustomEvent", value = function() follow_events = follow_events + 1 end },
  }, function()
    local duration = action_anim.play(state, {
      kind = "item_use",
      player_id = 1,
      duration = 0.5,
    })
    _assert_eq(duration, 0.5, "action anim should still return duration")
  end)
  _assert_eq(follow_events, 0, "action anim should not trigger camera follow events")
end

local function _make_unit(initial_count)
  local unit = {
    count = initial_count or 0,
    add_calls = 0,
    remove_calls = 0,
  }
  function unit.get_state_count()
    return unit.count
  end
  function unit.add_state()
    unit.add_calls = unit.add_calls + 1
    unit.count = unit.count + 1
  end
  function unit.remove_state()
    unit.remove_calls = unit.remove_calls + 1
    unit.count = math.max(0, unit.count - 1)
  end
  return unit
end

local function _test_role_control_lock_add_remove_owned_only()
  local unit1 = _make_unit(0)
  local unit2 = _make_unit(2)
  local role1 = {
    get_roleid = function() return 1 end,
    get_ctrl_unit = function() return unit1 end,
  }
  local role2 = {
    get_roleid = function() return 2 end,
    get_ctrl_unit = function() return unit2 end,
  }
  local roles = { role1, role2 }
  local runtime = {
    for_each_role_or_global = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end,
    resolve_role_id = function(role)
      return role.get_roleid()
    end,
  }
  local state = { role_control_lock = { by_role = {}, warn_once = {} } }

  _with_patches({
    { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
  }, function()
    role_control_lock_policy.sync(state, true, { runtime = runtime })
    role_control_lock_policy.sync(state, false, { runtime = runtime })
  end)

  assert(unit1.add_calls == 1, "role1 should add buff when empty")
  assert(unit1.remove_calls == 1, "role1 should remove owned buff")
  assert(unit2.add_calls == 0, "role2 should not add when already locked")
  assert(unit2.remove_calls == 0, "role2 should not remove external lock")
end

local function _test_role_control_lock_unit_swap_release_old_and_lock_new()
  local unit1 = _make_unit(0)
  local unit2 = _make_unit(0)
  local current_unit = unit1
  local role = {
    get_roleid = function() return 1 end,
    get_ctrl_unit = function() return current_unit end,
  }
  local runtime = {
    for_each_role_or_global = function(fn)
      fn(role)
    end,
    resolve_role_id = function(r)
      return r.get_roleid()
    end,
  }
  local state = { role_control_lock = { by_role = {}, warn_once = {} } }

  _with_patches({
    { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
  }, function()
    role_control_lock_policy.sync(state, true, { runtime = runtime })
    current_unit = unit2
    role_control_lock_policy.sync(state, true, { runtime = runtime })
  end)

  assert(unit1.add_calls == 1, "old unit should be locked once")
  assert(unit1.remove_calls == 1, "old unit should be released on swap")
  assert(unit2.add_calls == 1, "new unit should be locked on swap")
end

local function _test_gameplay_loop_full_turn_lock_toggle()
  local calls = {}
  local ports = {
    modal = {
      close_choice_modal = function() end,
      open_choice_modal = function() end,
      close_popup = function() end,
    },
    state = {
      apply_role_control_lock = function(_, enabled)
        table.insert(calls, enabled)
      end,
      install_event_handlers = function() end,
      on_bankruptcy_tiles_cleared = function() end,
    },
    anim = {
      reset_status_3d = function() end,
      play_move_anim = function() end,
      play_action_anim = function() end,
      sync_status_3d = function() end,
    },
    ui_sync = {
      apply_input_lock = function() end,
      step_choice_timeout = function() end,
      step_modal_timeout = function() end,
      update_countdown = function() end,
      build_model = function() return {} end,
      refresh_from_dirty = function() return false end,
      get_ui_state = function(state)
        return state and state.ui or nil
      end,
      is_input_blocked = function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = function() return nil end,
      set_input_blocked = function(state, blocked)
        local ui = state and state.ui or nil
        if not ui then
          return false
        end
        if ui.input_blocked == blocked then
          return false
        end
        ui.input_blocked = blocked
        return true
      end,
    },
    debug = {
      log_status = function() end,
      sync_debug_log = function() end,
      resolve_debug_enabled = function() return false end,
    },
  }
  local state = {
    ui = { input_blocked = false },
    gameplay_loop_ports = ports,
    auto_runner = { set_enabled = function() end, reset_timer = function() end, next_action = function() end },
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    _log_once = {},
    item_name_by_id = {},
    ui_dirty = false,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    board_last_positions = {},
    countdown_last = nil,
    countdown_active_last = nil,
    action_button_elapsed = 0,
    action_button_active = false,
    role_control_lock_active = false,
  }
  local game = {
    finished = false,
    players = { [1] = { id = 1, name = "P1", auto = false } },
    turn = { current_player_index = 1, phase = "start", turn_count = 1 },
    logger = { info = function() end },
    advance_turn = function() end,
    dispatch_action = function() end,
    consume_dirty = function() return { any = false } end,
  }
  function game:pending_choice()
    return nil
  end

  _with_patches({
    { target = gameplay_rules, key = "role_control_lock_enabled", value = true },
    { target = event_handlers, key = "install", value = function() end },
    { target = paid_currency_bridge, key = "setup_for_game", value = function() end },
  }, function()
    gameplay_loop.set_game(state, game)
    gameplay_loop.tick(game, state, 0.1)
    game.finished = true
    gameplay_loop.tick(game, state, 0.1)
  end)

  _assert_eq(calls[1], false, "set_game should clear lock first")
  _assert_eq(calls[2], true, "active game should enable lock")
  _assert_eq(calls[3], false, "finished game should clear lock")
end

local function _build_status3d_test_env()
  local created_layers = {}
  local destroyed_layers = {}
  local layer_visibility = {}

  local function _set_layer_visible(layer, observer_id, visible)
    if not layer_visibility[layer] then
      layer_visibility[layer] = {}
    end
    layer_visibility[layer][observer_id] = visible == true
  end

  local observers = {
    { id = 1 },
    { id = 2 },
  }

  local layer_counter = { [1] = 0, [2] = 0 }
  local roles = {
    [1] = {
      get_ctrl_unit = function()
        return {
          create_scene_ui_bind_unit = function(layout_id, _, _, _, _, _)
            layer_counter[1] = layer_counter[1] + 1
            local layer = "layer_1_" .. tostring(layout_id)
            created_layers[#created_layers + 1] = layer
            return layer
          end,
        }
      end,
      set_label_text = function() end,
    },
    [2] = {
      get_ctrl_unit = function()
        return {
          create_scene_ui_bind_unit = function(layout_id, _, _, _, _, _)
            layer_counter[2] = layer_counter[2] + 1
            local layer = "layer_2_" .. tostring(layout_id)
            created_layers[#created_layers + 1] = layer
            return layer
          end,
        }
      end,
      set_label_text = function() end,
    },
  }

  local game_api = {
    get_role = function(player_id)
      return roles[player_id]
    end,
    get_all_valid_roles = function()
      return observers
    end,
    set_scene_ui_visible = function(layer, observer_role, visible)
      _set_layer_visible(layer, observer_role.id, visible)
    end,
    destroy_scene_ui = function(layer)
      destroyed_layers[#destroyed_layers + 1] = layer
    end,
  }

  return {
    game_api = game_api,
    created_layers = created_layers,
    destroyed_layers = destroyed_layers,
    layer_visibility = layer_visibility,
  }
end

local function _build_status3d_game(opts)
  opts = opts or {}
  local tile_type = opts.tile_type or "start"
  local player_status_1 = opts.player_status_1 or { stay_turns = 0, deity = { type = "", remaining = 0 } }
  local player_status_2 = opts.player_status_2 or { stay_turns = 0, deity = { type = "", remaining = 0 } }
  return {
    players = {
      [1] = {
        id = 1,
        position = 1,
        eliminated = false,
        status = player_status_1,
      },
      [2] = {
        id = 2,
        position = 2,
        eliminated = false,
        status = player_status_2,
      },
    },
    board = {
      get_tile = function(_, index)
        if index == 1 then
          return { type = tile_type }
        end
        return { type = "start" }
      end,
    },
    last_turn = opts.last_turn,
  }
end

local function _test_status3d_init_and_global_visibility()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game()
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true })
  end)

  _assert_eq(#env.created_layers, 12, "status3d should create 6 layers per player (2 players)")
  for _, layer in ipairs(env.created_layers) do
    _assert_eq(env.layer_visibility[layer][1], false, "observer1 should see hidden layer when player has no status")
    _assert_eq(env.layer_visibility[layer][2], false, "observer2 should see hidden layer when player has no status")
  end
end

local function _test_status3d_priority_single_status()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 2,
      deity = { type = "poor", remaining = 5 },
    },
  })
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(env.layer_visibility[hospital_layer][1], true, "hospital layer should be visible (priority over poor)")
  _assert_eq(env.layer_visibility[poor_layer][1], false, "poor layer should be hidden when hospital active")
end

local function _test_status3d_roadblock_only_current_turn()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    last_turn = {
      player_id = 1,
      move_result = { stopped_on_roadblock = true },
    },
  })
  local prefab = require("Data.Prefab")
  local roadblock_layout = prefab.scene_eui["路障状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, turn = true })
    local roadblock_layer = "layer_1_" .. tostring(roadblock_layout)
    _assert_eq(env.layer_visibility[roadblock_layer][1], true, "roadblock should show at trigger turn")

    game.last_turn = {
      player_id = 2,
      move_result = { stopped_on_roadblock = true },
    }
    ui_status_3d_layer.sync(game, state, { any = true, turn = true })
    _assert_eq(env.layer_visibility[roadblock_layer][1], false, "roadblock should hide after trigger turn")
  end)
end

local function _test_status3d_reset_destroy_layers()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game()
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true })
    ui_status_3d_layer.reset(state)
  end)

  _assert_eq(#env.destroyed_layers, 12, "reset should destroy all created layers (6 per player × 2)")
  assert(state.ui_status_3d == nil, "reset should clear state cache")
end

local function _build_turn_effect_runtime_env(role_ids)
  local active_role = nil
  local roles = {}
  for _, role_id in ipairs(role_ids or {}) do
    local captured_role_id = role_id
    roles[#roles + 1] = {
      get_roleid = function()
        return captured_role_id
      end,
    }
  end

  local per_role_nodes = {}
  for _, role_id in ipairs(role_ids or {}) do
    per_role_nodes[role_id] = {
      ["基础_星星中心爆开"] = { visible = false },
      ["基础_行动提示"] = { visible = false },
      ["基础_行动提示特效"] = { visible = false },
      ["基础_其他玩家行动提示"] = { visible = false, text = "" },
    }
  end

  local global_nodes = {
    ["基础_玩家1行动动效"] = { visible = false },
    ["基础_玩家2行动动效"] = { visible = false },
    ["基础_玩家3行动动效"] = { visible = false },
    ["基础_玩家4行动动效"] = { visible = false },
  }

  return {
    roles = roles,
    per_role_nodes = per_role_nodes,
    set_client_role = function(role)
      active_role = role
    end,
    for_each_role_or_global = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end,
    query_node = function(name)
      local global_node = global_nodes[name]
      if global_node then
        return global_node
      end
      local role_id = active_role and active_role.get_roleid and active_role.get_roleid() or nil
      assert(role_id ~= nil, "missing role_id for node: " .. tostring(name))
      local role_nodes = per_role_nodes[role_id]
      assert(role_nodes ~= nil, "missing role nodes: " .. tostring(role_id))
      local node = role_nodes[name]
      assert(node ~= nil, "missing role node: " .. tostring(name))
      return node
    end,
  }
end

local function _test_turn_effects_prompt_visibility_follows_phase_and_role()
  local env = _build_turn_effect_runtime_env({ 1, 2 })
  local state = {}
  local ui_model = {
    current_player_id = 1,
    current_player_name = "P1",
    board = {
      phase = "start",
      players = { { id = 1 }, { id = 2 } },
    },
  }

  _with_patches({
    { target = runtime_port, key = "set_client_role", value = env.set_client_role },
    { target = runtime_port, key = "for_each_role_or_global", value = env.for_each_role_or_global },
    { target = runtime_port, key = "query_node", value = env.query_node },
  }, function()
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, true, "current player should see action prompt in start phase")
    _assert_eq(env.per_role_nodes[1]["基础_行动提示特效"].visible, true, "current player should see action star in start phase")
    _assert_eq(env.per_role_nodes[2]["基础_行动提示"].visible, false, "other player should hide local action prompt")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, true, "other player should always see other-action prompt")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].text, "P1正在行动", "other prompt text should use current player name")

    ui_model.board.phase = "wait_move_anim"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, false, "current player prompt should hide after action begins")
    _assert_eq(env.per_role_nodes[1]["基础_行动提示特效"].visible, false, "current player star should hide after action begins")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, true, "other player prompt should stay visible in non-turn phase")

    ui_model.board.phase = "end_turn"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, true, "current player prompt should show in end_turn phase")

    ui_model.current_player_id = 2
    ui_model.current_player_name = "P2"
    ui_model.board.phase = "start"
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_其他玩家行动提示"].visible, true, "switched non-current player should see other-action prompt")
    _assert_eq(env.per_role_nodes[1]["基础_其他玩家行动提示"].text, "P2正在行动", "other prompt text should follow current player switch")
    _assert_eq(env.per_role_nodes[2]["基础_行动提示"].visible, true, "new current player should see local action prompt")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, false, "current player should hide other-action prompt")
  end)
end

local function _test_turn_effects_other_prompt_fallback_text()
  local env = _build_turn_effect_runtime_env({ 1, 2 })
  local state = {}
  local ui_model = {
    current_player_id = 1,
    current_player_name = nil,
    board = {
      phase = "wait_action_anim",
      players = { { id = 1 }, { id = 2 } },
    },
  }

  _with_patches({
    { target = runtime_port, key = "set_client_role", value = env.set_client_role },
    { target = runtime_port, key = "for_each_role_or_global", value = env.for_each_role_or_global },
    { target = runtime_port, key = "query_node", value = env.query_node },
  }, function()
    turn_effects.sync(state, ui_model)
    _assert_eq(env.per_role_nodes[1]["基础_行动提示"].visible, false, "current player local prompt should hide in wait_action_anim")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].visible, true, "other player prompt should show without current player name")
    _assert_eq(env.per_role_nodes[2]["基础_其他玩家行动提示"].text, "其他玩家正在行动", "other prompt should use fallback text")
  end)
end

local function _test_tick_ui_sync_turn_switch_still_follows()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.presentation.api.UIViewService")
  local ui_model = require("src.presentation.state.UIModel")
  local board_view_mod = require("src.presentation.render.BoardRuntime")
  local helper = { target_role_id = nil }
  local follow_events = 0
  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function() return {} end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
    { key = "camera_helper", value = helper },
    { key = "TriggerCustomEvent", value = function() follow_events = follow_events + 1 end },
  }
  local game = {
    finished = false,
    winner = nil,
    players = {
      [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } },
      [2] = { id = 2, name = "P2", cash = 0, eliminated = false, inventory = { items = {} } },
    },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 2,
      turn_count = 3,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    ui_dirty = true,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      },
      [2] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = ui_view.build_ui_state(),
    ui_refs = { ["Empty"] = "EMPTY" },
  }

  _with_patches(patches, function()
    runtime_event_bridge._reset_for_tests()
    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
    gameplay_loop.tick(game, state, 0.1)
    runtime_event_bridge._reset_for_tests()
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should follow current player")
  assert(follow_events >= 1, "turn switch should trigger follow event")
end

local function _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.presentation.api.UIViewService")
  local ui_model = require("src.presentation.state.UIModel")
  local board_view_mod = require("src.presentation.render.BoardRuntime")
  local helper = { target_role_id = nil }
  local follow_events = 0
  local game_api = GameAPI or {}
  local name = "j4MHTwbxEfG+CjRaYHE42T"
  local newenv = {}
  local function wrapped_trigger()
    local _ = name
    local __ = newenv
    follow_events = follow_events + 1
  end
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh", value = function() end },
    { target = main_view, key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      local _player_rows = {
        { name = "P1", cash = "0", land_count = "0", total_assets = "0" },
        { name = "P2", cash = "0", land_count = "0", total_assets = "0" },
        { name = "", cash = "", land_count = "", total_assets = "" },
        { name = "", cash = "", land_count = "", total_assets = "" },
      }
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "", player_rows = _player_rows },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function() return {} end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
    { key = "camera_helper", value = helper },
    { key = "TriggerCustomEvent", value = wrapped_trigger },
  }
  local game = {
    finished = false,
    winner = nil,
    players = {
      [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } },
      [2] = { id = 2, name = "P2", cash = 0, eliminated = false, inventory = { items = {} } },
    },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 2,
      turn_count = 3,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    ui_dirty = true,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      },
      [2] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = ui_view.build_ui_state(),
    ui_refs = { ["Empty"] = "EMPTY" },
  }

  _with_patches(patches, function()
    runtime_event_bridge._reset_for_tests()
    local ok, err = pcall(function()
      state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
      gameplay_loop.tick(game, state, 0.1)
    end)
    runtime_event_bridge._reset_for_tests()
    assert(ok == true, "turn switch should not fail when follow event is unavailable: " .. tostring(err))
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should still track current player on degraded follow event")
  _assert_eq(follow_events, 0, "degraded follow event path should avoid wrapped TriggerCustomEvent call")
end

local function _test_panel_avatar_uses_keep_size_path()
  local presenter = require("src.presentation.ui.UIPanelPresenter")
  local keep_size_calls = 0
  local state = {
    ui_refs = { ["Empty"] = "EMPTY_AVATAR" },
    ui = {
      item_slots = {},
      base_hidden_nodes = {},
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      item_slot_item_ids_by_role = {},
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    auto_enabled_by_player = { [1] = false },
    board = { players = {} },
    item_slots_by_player = {},
    panel = {
      turn_label = "倒计时:0",
      auto_label = "自动：关",
      auto_label_by_player = { [1] = "自动：关" },
      no_action_visible = false,
      no_action_text = "",
      player_rows = {
        { name = "P1", avatar = "A1", cash = "", land_count = "", total_assets = "" },
        { name = "P2", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P3", avatar = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P4", avatar = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
  }
  local runtime = {
    set_client_role = function() end,
    resolve_role_id = function() return nil end,
    for_each_role_or_global = function(fn)
      fn(nil)
    end,
    set_node_texture_keep_size = function()
      keep_size_calls = keep_size_calls + 1
    end,
  }

  presenter.refresh(state, ui_model, {
    runtime = runtime,
    refresh_item_slots = function() end,
  })

  _assert_eq(keep_size_calls, 4, "panel avatar should use keep-size path")
end

return {
  _test_move_anim_callback_and_delay,
  _test_popup_timeout_auto_confirm,
  _test_runtime_port_with_client_role_restores_nested_context,
  _test_runtime_port_native_size_prefers_native_method,
  _test_runtime_port_native_size_fallback_keep_size,
  _test_runtime_port_native_size_fallback_image_texture,
  _test_choice_timeout_supports_explicit_timeout_strategy,
  _test_tick_timeout_default_policy_isolation,
  _test_invalid_choice_option_rejected,
  _test_move_anim_wait_and_resume,
  _test_move_anim_zero_distance_safe,
  _test_move_anim_step_unlocks_and_relocks,
  _test_move_anim_vehicle_uses_set_position_jump,
  _test_move_anim_vehicle_enter_delay_once,
  _test_move_anim_vehicle_move_api_enabled_uses_move_event,
  _test_board_view_vehicle_resync_uses_set_position,
  _test_board_view_vehicle_disabled_uses_unit_set_position,
  _test_ui_model_structure,
  _test_ui_panel_clamps_negative_assets_to_zero,
  _test_ui_model_player_slot_map_and_choice_owner,
  _test_ui_model_player_profile_prefers_role_api_with_fallback,
  _test_ui_model_player_profile_accepts_stringified_avatar,
  _test_turn_dispatch_rejects_non_current_actor,
  _test_turn_dispatch_rejects_choice_non_owner,
  _test_turn_dispatch_auto_rejects_unmapped_role,
  _test_turn_dispatch_item_slot_uses_actor_slot_map,
  _test_ui_intent_dispatcher_market_confirm_routes_choice_select,
  _test_ui_intent_dispatcher_market_select_updates_ui_only,
  _test_ui_intent_dispatcher_popup_confirm_closes_popup,
  _test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context,
  _test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game,
  _test_ui_intent_dispatcher_toggle_action_log_resolves_role_via_game_api,
  _test_ui_intent_dispatcher_toggle_action_log_warns_when_role_event_channel_missing,
  _test_ui_intent_dispatcher_auto_button_forces_local_role_id,
  _test_ui_intent_dispatcher_auto_button_falls_back_to_intent_actor_when_local_missing,
  _test_ui_intent_dispatcher_auto_button_toggles_local_role_during_other_turn,
  _test_ui_view_render_by_role_slots_are_isolated,
  _test_ui_events_send_without_roles_no_crash,
  _test_ui_nodes_validate_reports_missing,
  _test_apply_input_lock_keeps_auto_controls_enabled,
  _test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped,
  _test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists,
  _test_ui_touch_policy_auto_controls_touch,
  _test_ui_touch_policy_runtime_nodes_touch_enabled,
  _test_role_control_lock_add_remove_owned_only,
  _test_role_control_lock_unit_swap_release_old_and_lock_new,
  _test_gameplay_loop_full_turn_lock_toggle,
  _test_push_popup_sets_card_image_by_image_ref,
  _test_push_popup_hides_card_and_clears_image_when_missing,
  _test_popup_hidden_for_non_current_role,
  _test_popup_visible_for_all_roles_when_allowed_kind,
  _test_bankruptcy_popup_visible_for_all_roles,
  _test_bankruptcy_popup_avatar_uses_native_size_path,
  _test_popup_timeout_closes_even_when_input_blocked,
  _test_choice_modal_routes_to_new_screens,
  _test_choice_route_policy_prefers_explicit_route_metadata,
  _test_ui_event_router_player_target_click_direct_submit,
  _test_ui_event_router_action_log_toggle_uses_role_context,
  _test_market_selection_updates_icon_without_resize,
  _test_market_close_resets_icon_without_resize,
  _test_item_slot_uses_keep_size_path,
  _test_item_slot_refresh_shows_only_playable_outlines,
  _test_item_slot_intents_include_outline_nodes,
  _test_tick_skips_anim_when_no_anim,
  _test_action_anim_queue_consumes_in_order,
  _test_action_anim_default_duration,
  _test_action_anim_no_camera_focus_side_effect,
  _test_status3d_init_and_global_visibility,
  _test_status3d_priority_single_status,
  _test_status3d_roadblock_only_current_turn,
  _test_status3d_reset_destroy_layers,
  _test_turn_effects_prompt_visibility_follows_phase_and_role,
  _test_turn_effects_other_prompt_fallback_text,
  _test_tick_ui_sync_turn_switch_still_follows,
  _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable,
  _test_panel_avatar_uses_keep_size_path,
}
