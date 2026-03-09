local support = require("TestSupport")
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
    { target = dispatch, key = "dispatch_action", value = function(_, _, action)
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
    route_key = "market",
    owner_role_id = g:current_player().id,
    options = { { id = 1, label = "X" } },
    meta = { player_id = g:current_player().id },
  })
  choice_resolver.resolve(g, choice, { option_id = 999 })
  assert(_get_choice(g) ~= nil, "invalid option should keep choice")
end

local function _test_move_anim_wait_and_resume()
  local g = _new_game()
  g.anim_gate_port = {
    wait_move_anim = true,
    wait_action_anim = false,
  }
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
  g.turn_engine = runtime_cls:new(g, phases, { experimental_coroutine_turn = true })

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

local function _test_ui_model_structure()
  local ui_model = require("src.presentation.model")
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
  local ui_panel = require("src.presentation.view.widgets.panel")
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
  _assert_eq(row.cash_value, 0, "negative cash_value should normalize as zero")
  _assert_eq(row.cash, "现金: 0", "negative cash should render as zero")
  _assert_eq(row.total_assets_value, 0, "negative total_assets_value should normalize as zero")
  _assert_eq(row.total_assets, "总资产: 0", "negative total assets should render as zero")
end

local function _test_ui_model_player_slot_map_and_choice_owner()
  local ui_model = require("src.presentation.model")
  local g = _new_game()
  g.players[1].inventory:add({ id = 2001 })
  g.players[2].inventory:add({ id = 2002 })
  g.players[1].auto = false
  g.players[2].auto = true
  g.turn.pending_choice = {
    id = 77,
    kind = "item_phase_choice",
    route_key = "base_inline",
    owner_role_id = "2",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    options = { { id = 2002, label = "用道具" } },
    allow_cancel = true,
    cancel_label = "取消",
    meta = { player_id = "2" },
  }

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
  })

  assert(model.current_player_id == 1, "current_player_id expected")
  assert(model.item_choice_owner_id == 2, "item_choice_owner_id should normalize choice owner role id")
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
  local ui_model = require("src.presentation.model")
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
  local ui_model = require("src.presentation.model")
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

local function _test_ui_model_player_profile_uses_slot_avatar_for_synthetic_ai()
  local ui_model = require("src.presentation.model")
  local runtime_ports = require("src.core.ports.runtime_ports")
  local runtime_refs = require("Config.runtime_refs")
  local g = _new_game()
  g.players[3] = g.players[3] or {
    id = 3,
    name = "AI3",
    cash = 0,
    eliminated = false,
    inventory = { items = {} },
    properties = {},
    status = { stay_turns = 0, deity = nil },
  }
  g.players[4] = g.players[4] or {
    id = 4,
    name = "AI4",
    cash = 0,
    eliminated = false,
    inventory = { items = {} },
    properties = {},
    status = { stay_turns = 0, deity = nil },
  }
  g.players[1].name = "本地玩家1"
  g.players[2].name = "AI2"
  g.players[3].name = "AI3"
  g.players[4].name = "AI4"

  local avatar_ai_2 = runtime_refs.images.AI2
  local avatar_ai_3 = runtime_refs.images.AI3
  local avatar_ai_4 = runtime_refs.images.AI4
  local model = nil
  _with_patches({
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function(player_id)
        if player_id == 1 then
          return {
            get_name = function()
              return "远端昵称1"
            end,
            get_head_icon = function()
              return 12345
            end,
          }
        end
        if player_id == 2 then
          return {
            get_name = function()
              return "AI2"
            end,
            get_head_icon = function()
              return avatar_ai_2
            end,
          }
        end
        if player_id == 3 then
          return {
            get_name = function()
              return "AI3"
            end,
            get_head_icon = function()
              return avatar_ai_3
            end,
          }
        end
        if player_id == 4 then
          return {
            get_name = function()
              return "AI4"
            end,
            get_head_icon = function()
              return avatar_ai_4
            end,
          }
        end
        return nil
      end,
    },
  }, function()
    model = ui_model.build(g, {
      game = g,
      ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
      last_turn = g.last_turn,
      finished = g.finished,
    })
  end)

  local player_rows = model and model.panel and model.panel.player_rows or nil
  local row1 = player_rows and player_rows[1] or nil
  local row2 = player_rows and player_rows[2] or nil
  local row3 = player_rows and player_rows[3] or nil
  local row4 = player_rows and player_rows[4] or nil
  assert(row1 and row1.avatar == 12345, "player1 should keep real role avatar")
  assert(row2 and row2.avatar == avatar_ai_2, "player2 should use slot-mapped AI2 avatar")
  assert(row3 and row3.avatar == avatar_ai_3, "player3 should use slot-mapped AI3 avatar")
  assert(row4 and row4.avatar == avatar_ai_4, "player4 should use slot-mapped AI4 avatar")
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

  local res_auto = dispatch.dispatch_action(g, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = 2,
  }, {})
  assert(res_auto and res_auto.status == "applied", "auto button should allow non-current actor")
  assert(g.players[2].auto == true, "player2 auto should toggle")

  local res_next = dispatch.dispatch_action(g, state, {
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
    route_key = "market",
    owner_role_id = "1",
    options = { { id = 1, label = "X" } },
    allow_cancel = true,
    meta = { player_id = "1" },
  }
  state.pending_choice = g.turn.pending_choice

  local dispatched = nil
  function g:dispatch_action(action)
    dispatched = action
    self.turn.pending_choice = nil
  end

  local res = dispatch.dispatch_action(g, state, {
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
  local res = dispatch.dispatch_action(g, state, {
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
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
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
  _bind_ui_runtime(state)

  local res = dispatch.dispatch_action(g, state, {
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

local function _test_ui_view_render_by_role_slots_are_isolated()
  local main_view = require("src.presentation.runtime.view")

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
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
      ["2002"] = "ICON2002",
    }),
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
    auto_enabled_by_player = {
      [1] = false,
      [2] = true,
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
  assert(touch_logs[2] and touch_logs[2]["始终显示_托管按钮"] == true, "player role auto button should stay enabled")
  assert(touch_logs[1] and touch_logs[1]["始终显示_文本"] == false, "role1 auto label should stay non-clickable")
  assert(touch_logs[2] and touch_logs[2]["始终显示_文本"] == false, "role2 auto label should stay non-clickable")
  assert(touch_logs[1] and touch_logs[1]["始终显示_托管按钮特效"] == false, "role1 auto effect should stay non-clickable")
  assert(touch_logs[2] and touch_logs[2]["始终显示_托管按钮特效"] == false, "role2 auto effect should stay non-clickable")
  assert(label_logs[1] and label_logs[1]["始终显示_文本"] == "自动：关", "role1 auto label should show status")
  assert(label_logs[2] and label_logs[2]["始终显示_文本"] == "自动：开", "role2 auto label should show status")
  assert(visible_logs[2] and visible_logs[2]["基础_倒计时"] == true, "non-current role countdown should be visible")
  assert(visible_logs[2] and visible_logs[2]["基础_道具槽位1"] == true, "non-current role slot should be visible")
  assert(visible_logs[2] and visible_logs[2]["始终显示_托管按钮"] == true, "auto button should stay visible")
  assert(visible_logs[2] and visible_logs[2]["始终显示_文本"] == true, "auto label should stay visible")
  assert(visible_logs[1] and visible_logs[1]["始终显示_托管按钮特效"] == false, "role1 auto effect should hide when auto off")
  assert(visible_logs[2] and visible_logs[2]["始终显示_托管按钮特效"] == true, "role2 auto effect should show when auto on")
  assert(state.ui.item_slot_item_ids_by_role[1] and state.ui.item_slot_item_ids_by_role[1][1] == 2001, "role1 slot map expected")
  assert(state.ui.item_slot_item_ids_by_role[2] and state.ui.item_slot_item_ids_by_role[2][1] == 2002, "role2 slot map expected")
end

local function _test_ui_events_send_without_roles_no_crash()
  local ui_events = require("src.presentation.runtime.events")
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
        target = {},
        remote = { option_buttons = {} },
        secondary_confirm = { body = "通用二次确认_文本", cancel = "通用二次确认_取消", confirm = "通用二次确认_确定按钮" },
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
        target = {},
        remote = { option_buttons = {} },
        secondary_confirm = { body = "通用二次确认_文本", cancel = "通用二次确认_取消", confirm = "通用二次确认_确定按钮" },
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

local function _test_apply_input_lock_disables_always_show_controls_when_market_active()
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
      market_active = true,
      item_slots = { "基础_道具槽位1" },
      base_hidden_nodes = { "基础_行动按钮", "基础_道具槽位1" },
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      choice_screens = {
        player = { option_buttons = {} },
        target = {},
        remote = { option_buttons = {} },
        secondary_confirm = { body = "通用二次确认_文本", cancel = "通用二次确认_取消", confirm = "通用二次确认_确定按钮" },
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

  assert(touch["始终显示_托管按钮"] == false, "auto button should yield touch priority while market is active")
  assert(touch["始终显示_文本"] == false, "auto label should stay non-clickable while market is active")
  assert(touch["始终显示_行动日志图标"] == false, "action log toggle should yield touch priority while market is active")
end

local function _test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists()
  local main_view = require("src.presentation.runtime.view")
  local touch_logs = {}
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY", ["2001"] = "ICON2001" }),
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
  _assert_eq(touch["始终显示_托管按钮特效"], false, "auto effect should stay non-clickable")

  ui_touch_policy.set_auto_controls_touch(ui, false)
  _assert_eq(touch["始终显示_托管按钮"], false, "auto button should be non-clickable when disabled")
  _assert_eq(touch["始终显示_文本"], false, "auto label should stay non-clickable when disabled")
  _assert_eq(touch["始终显示_托管按钮特效"], false, "auto effect should stay non-clickable when disabled")
end

local function _test_ui_intent_dispatcher_market_confirm_skin_opens_pre_confirm_then_dispatches()
  local opened_pre_confirm = nil
  local dispatched = {}
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      should_block_action = function()
        return false
      end,
    },
    ui_model = {
      choice = {
        id = 12,
        kind = "market_buy",
        route_key = "market",
        options = {
          { id = 5001, label = "海绵宝宝皮肤", requires_pre_confirm = true, pre_confirm_kind = "market_skin_purchase" },
        },
      },
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
      active_choice_screen_key = "market",
    },
    game = {},
  }
  _bind_ui_runtime(state)
  local game = {}

  _with_patches({
    { target = choice_openers, key = "open_pre_confirm_screen", value = function(_, _, option_id, title, body)
      opened_pre_confirm = {
        option_id = option_id,
        title = title,
        body = body,
      }
    end },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "market_confirm",
      choice_id = 12,
      option_id = 5001,
    }, {})
    _assert_eq(#dispatched, 0, "skin market_confirm should wait for secondary confirm before dispatch")
    _assert_eq(opened_pre_confirm and opened_pre_confirm.option_id, 5001,
      "skin market_confirm should open pre confirm with selected skin option")

    ui_intent_dispatcher.dispatch(state, game, {
      type = "choice_select",
      choice_id = 12,
      option_id = 5001,
    }, {})
  end)

  _assert_eq(#dispatched, 1, "pre-confirm choice_select should dispatch exactly once")
  _assert_eq(dispatched[1] and dispatched[1].type, "choice_select", "pre-confirm should dispatch choice_select")
  _assert_eq(dispatched[1] and dispatched[1].choice_id, 12, "pre-confirm should keep market choice id")
  _assert_eq(dispatched[1] and dispatched[1].option_id, 5001, "pre-confirm should keep selected skin option id")
end

local function _test_ui_intent_dispatcher_market_confirm_skin_cancel_restores_market()
  local opened_pre_confirm = 0
  local reopened_choice = nil
  local state = {
    turn_action_port = {
      dispatch_action = function() end,
      should_block_action = function()
        return false
      end,
    },
    ui_model = {
      choice = {
        id = 12,
        kind = "market_buy",
        route_key = "market",
        options = {
          { id = 5001, label = "海绵宝宝皮肤", requires_pre_confirm = true, pre_confirm_kind = "market_skin_purchase" },
        },
      },
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
      active_choice_screen_key = "market",
    },
    game = {},
  }
  _bind_ui_runtime(state)
  local game = {}

  _with_patches({
    { target = choice_openers, key = "open_pre_confirm_screen", value = function()
      opened_pre_confirm = opened_pre_confirm + 1
    end },
    { target = ui_view, key = "open_choice_modal", value = function(_, choice)
      reopened_choice = choice
    end },
  }, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "market_confirm",
      choice_id = 12,
      option_id = 5001,
    }, {})
    ui_intent_dispatcher.dispatch(state, game, {
      type = "choice_cancel",
      choice_id = 12,
    }, {})
  end)

  _assert_eq(opened_pre_confirm, 1, "skin market_confirm should enter pre-confirm once")
  _assert_eq(reopened_choice and reopened_choice.kind, "market_buy", "pre-confirm cancel should reopen market choice")
end

local function _test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch()
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
    ui_model = {
      choice = {
        id = 12,
        kind = "market_buy",
        route_key = "market",
        options = {
          { id = 2001, label = "路障卡" },
        },
      },
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
      option_id = 2001,
    }, {})
  end)

  _assert_eq(captured and captured.type, "choice_select", "non-skin market_confirm should dispatch choice_select directly")
  _assert_eq(captured and captured.choice_id, 12, "non-skin market_confirm should keep choice id")
  _assert_eq(captured and captured.option_id, 2001, "non-skin market_confirm should keep option id")
end

local function _test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly()
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
    ui_model = {
      choice = {
        id = 12,
        kind = "market_buy",
        route_key = "market",
        options = {
          { id = 5001, label = "海绵宝宝皮肤" },
        },
      },
    },
    ui = {
      input_blocked = false,
      item_slot_item_ids = {},
      item_slot_item_ids_by_role = {},
      active_choice_screen_key = "market",
    },
  }
  local game = {}

  _with_patches({}, function()
    ui_intent_dispatcher.dispatch(state, game, {
      type = "market_confirm",
      choice_id = 12,
      option_id = 5001,
    }, {})
  end)

  _assert_eq(captured and captured.type, "choice_select",
    "market_confirm without explicit pre-confirm flag should dispatch directly")
  _assert_eq(captured and captured.choice_id, 12,
    "direct dispatch should keep market choice id when pre-confirm flag missing")
  _assert_eq(captured and captured.option_id, 5001,
    "direct dispatch should keep selected option id when pre-confirm flag missing")
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
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
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
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
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
  _bind_ui_runtime(state)

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
  _bind_ui_runtime(state)
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
  _bind_ui_runtime(state)
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
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
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
  state.game = {
    board = {
      get_tile_by_id = function(_, tile_id)
        if tile_id == 1001 then
          return { name = "彩虹大道" }
        end
        return nil
      end,
    },
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    ui_view.open_choice_modal(state, {
      id = 1,
      kind = "item_target_player",
      route_key = "player",
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
      route_key = "target",
      owner_role_id = 1,
      uses_target_picker = true,
      target_picker_owner_role_id = 1,
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
      route_key = "remote",
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
      route_key = "secondary_confirm",
      requires_confirm = true,
      title = "请选择",
      body = "",
      options = {
        { id = "buy_land", label = "购买地块", confirm_title = "买地", confirm_body = "地块：彩虹大道。要买吗？" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
      meta = { tile_id = 1001 },
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "buy_land optional should route to building screen")
    _assert_eq(nodes["通用二次确认屏"].visible, true, "building screen should be visible")
    _assert_eq(nodes["通用二次确认_标题"].text, "买地", "building title should be short for kids")
    _assert_eq(nodes["通用二次确认_文本"].text, "地块：彩虹大道。要买吗？", "building body should include tile and action")
    _assert_eq(nodes["通用二次确认_确定按钮"].text, "", "building confirm text should be empty")
    _assert_eq(nodes["通用二次确认_取消"].text, "", "building cancel text should be empty")

    ui_view.open_choice_modal(state, {
      id = 5,
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      title = "行动前：使用道具？",
      body = "",
      confirm_title = "行动前",
      confirm_body = "可用道具：路障卡、遥控骰子卡",
      options = {
        { id = 2001, label = "路障卡", confirm_title = "行动前", confirm_body = "将使用：路障卡" },
        { id = 2002, label = "遥控骰子卡", confirm_title = "行动前", confirm_body = "将使用：遥控骰子卡" },
      },
      allow_cancel = true,
      cancel_label = "结束阶段",
      meta = { phase = "pre_action" },
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "item_phase_choice should first ask via secondary confirm")
    _assert_eq(nodes["通用二次确认屏"].visible, true, "secondary confirm should be visible for item phase ask")
    _assert_eq(nodes["通用二次确认_标题"].text, "行动前", "item phase ask title should be short phase text")
    _assert_eq(nodes["通用二次确认_文本"].text, "可用道具：路障卡、遥控骰子卡", "item phase ask body should include all cards")
    _assert_eq(nodes["通用二次确认_确定按钮"].disabled, false, "confirm button must be touchable for item phase ask")
    _assert_eq(nodes["位置选择屏"].visible, false, "target screen should stay hidden for item phase")
    _assert_eq(nodes["遥控骰子屏"].visible, false, "remote screen should stay hidden for item phase")

    ui_view.open_choice_modal(state, {
      id = 6,
      kind = "tax_card_prompt",
      route_key = "secondary_confirm",
      requires_confirm = true,
      confirm_title = "税务局",
      confirm_body = "这次要用免税卡吗？",
      title = "是否使用免税卡",
      body = "",
      options = {
        { id = "use", label = "使用" },
        { id = "skip", label = "不用" },
      },
      allow_cancel = true,
      cancel_label = "不用",
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "tax_card_prompt should route to secondary confirm")
    _assert_eq(nodes["通用二次确认屏"].visible, true, "tax prompt should open secondary confirm screen")
    _assert_eq(nodes["通用二次确认_标题"].text, "税务局", "tax prompt title should stay short")
    _assert_eq(nodes["通用二次确认_文本"].text, "这次要用免税卡吗？", "tax prompt body should explain the choice")
    _assert_eq(nodes["通用二次确认_取消"].visible, true, "tax prompt should show cancel as do-not-use")
    _assert_eq(nodes["通用二次确认_取消"].disabled, false, "tax prompt cancel should stay touchable")

    ui_view.open_choice_modal(state, {
      id = 7,
      kind = "landing_optional_effect",
      route_key = "base_inline",
      requires_confirm = false,
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

local function _test_target_screen_uses_labels_only_and_hides_projection_with_slots()
  local state, nodes, query_nodes = _build_choice_modal_state()
  local choice = {
    id = 88,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = 1,
    uses_target_picker = true,
    target_picker_owner_role_id = 1,
    title = "路障卡：选择位置",
    body = "body",
    options = {
      { id = 101, label = "福州路" },
      { id = 102, label = "台北路" },
      { id = 103, label = "黑市" },
      { id = 104, label = "武汉路" },
      { id = 201, label = "南京路" },
      { id = 202, label = "上海路" },
      { id = 203, label = "香港路" },
    },
    allow_cancel = true,
    cancel_label = "放弃",
  }

  nodes["位置-槽位1投影"].visible = true
  nodes["位置-槽位1投影"].disabled = false
  nodes["位置-槽位7投影"].visible = true
  nodes["位置-槽位7投影"].disabled = false

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    ui_view.open_choice_modal(state, choice)
    _assert_eq(state.ui.active_choice_screen_key, "target", "roadblock_target should open target screen")
    _assert_eq(nodes["位置-槽位1按钮"].text, "", "slot1 button text should stay empty")
    _assert_eq(nodes["位置-槽位7按钮"].text, "", "slot7 button text should stay empty")
    _assert_eq(nodes["位置-槽位1文本"].text, "福州路", "slot1 label should show tile name")
    _assert_eq(nodes["位置-槽位4文本"].text, "武汉路", "slot4 label should show current tile name")
    _assert_eq(nodes["位置-槽位7文本"].text, "香港路", "slot7 label should show tile name")
    _assert_eq(nodes["位置-槽位7按钮"].visible, true, "slot7 button should be visible when seven candidates exist")
    _assert_eq(nodes["位置-槽位7文本"].visible, true, "slot7 label should be visible when seven candidates exist")
    _assert_eq(nodes["位置-槽位1投影"].visible, true, "slot projection should be visible with populated slot")
    _assert_eq(nodes["位置-槽位1投影"].disabled, true, "slot projection should stay non-interactive")
    _assert_eq(nodes["位置-槽位7投影"].visible, true, "slot7 projection should be visible with populated slot")
    _assert_eq(nodes["位置-槽位7投影"].disabled, true, "slot7 projection should stay non-interactive")

    local common = require("src.presentation.view.widgets.choice_screen_service.common")
    common.hide_choice_screens(state.ui)

    _assert_eq(nodes["位置-槽位1文本"].visible, false, "hide_choice_screens should hide slot label")
    _assert_eq(nodes["位置-槽位1按钮"].disabled, true, "hide_choice_screens should disable slot button")
    _assert_eq(nodes["位置-槽位1投影"].visible, false, "hide_choice_screens should hide slot projection")
    _assert_eq(nodes["位置-槽位1投影"].disabled, true, "hide_choice_screens should disable slot projection")
  end)
end

local function _test_target_screen_hides_unused_slots_when_unique_options_less_than_seven()
  local state, nodes, query_nodes = _build_choice_modal_state()
  local choice = {
    id = 89,
    kind = "roadblock_target",
    route_key = "target",
    owner_role_id = 1,
    uses_target_picker = true,
    target_picker_owner_role_id = 1,
    title = "路障卡：选择位置",
    body = "body",
    options = {
      { id = 101, label = "机会卡" },
      { id = 102, label = "济南路" },
      { id = 103, label = "南京路" },
      { id = 104, label = "上海路" },
      { id = 105, label = "合肥路" },
      { id = 106, label = "郑州路" },
    },
    allow_cancel = true,
    cancel_label = "放弃",
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    ui_view.open_choice_modal(state, choice)
    _assert_eq(state.ui.active_choice_screen_key, "target", "target screen should open for unique-option roadblock choice")
    _assert_eq(nodes["位置-槽位6按钮"].visible, true, "slot6 button should stay visible for the sixth unique option")
    _assert_eq(nodes["位置-槽位6文本"].text, "郑州路", "slot6 label should match the last unique option")
    _assert_eq(nodes["位置-槽位7按钮"].visible, false, "slot7 button should hide when only six unique options exist")
    _assert_eq(nodes["位置-槽位7文本"].visible, false, "slot7 label should hide when only six unique options exist")
  end)
end

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

local function _test_target_confirm_dispatches_selected_option()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.on_scene_pick(env.state, 102, 1, {})
    env.nodes["位置_确认按钮"]._listener_cb({})
    _assert_eq(#env.state.turn_action_port.dispatched, 1, "confirm should dispatch one action")
    _assert_eq(env.state.turn_action_port.dispatched[1].type, "choice_select", "confirm should dispatch choice_select")
    _assert_eq(env.state.turn_action_port.dispatched[1].option_id, 102, "confirm should dispatch locked option")
  end)
end

local function _test_target_pick_tick_updates_selection_on_hit_change()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    runtime.set_hit(env.tile_unit_ids[102], env.tile_positions[102])
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.hover_option_id, nil, "hover should wait for external pick")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, nil, "hover should not lock selected option")
    _assert_eq(env.arrow.visible, false, "arrow should stay hidden before lock")
  end)
end

local function _test_target_pick_tick_ignores_non_candidate()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    runtime.set_hit(9999, vec3.with_sub_length(999, 0, 0))
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.hover_option_id, nil, "non-candidate ray hit should be ignored")
  end)
end

local function _test_target_pick_scene_click_locks_target_and_pauses_raycast()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.on_scene_pick(env.state, 103, 1, {})
    runtime.set_hit(env.tile_unit_ids[102], env.tile_positions[102])
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.locked_option_id, 103, "scene pick should lock option")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, 103, "locked option should sync selected option")
    _assert_eq(env.state.target_choice_runtime.hover_option_id, 103, "locked option should drive hover")
  end)
end

local function _test_target_pick_confirm_requires_lock()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    env.nodes["位置_确认按钮"]._listener_cb({})
    _assert_eq(#env.state.turn_action_port.dispatched, 0, "confirm should not dispatch without lock")
    target_choice_effects.on_scene_pick(env.state, 101, 1, {})
    env.nodes["位置_确认按钮"]._listener_cb({})
    _assert_eq(#env.state.turn_action_port.dispatched, 1, "confirm should dispatch after lock")
    _assert_eq(env.state.turn_action_port.dispatched[1].option_id, 101, "confirm should use locked option")
  end)
end

local function _test_target_pick_cancel_unlocks_and_resumes_raycast()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.on_scene_pick(env.state, 103, 1, {})
    env.nodes["位置_取消按钮"]._listener_cb({})
    _assert_eq(env.state.target_choice_runtime.locked_option_id, nil, "cancel should clear lock")
    runtime.set_hit(env.tile_unit_ids[102], env.tile_positions[102])
    target_choice_effects.step(env.game, env.state, 0.1)
    _assert_eq(env.state.target_choice_runtime.hover_option_id, nil, "unlock should wait for next external pick")
  end)
end

local function _test_target_pick_cancel_noop_when_unlocked()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    target_choice_effects.enter(env.state, env.choice)
    env.nodes["位置_取消按钮"]._listener_cb({})
    _assert_eq(env.state.target_choice_runtime.locked_option_id, nil, "cancel should stay noop when unlocked")
    _assert_eq(#env.state.turn_action_port.dispatched, 0, "cancel should not dispatch game action")
  end)
end

local function _test_target_pick_leave_hides_scene_units()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    target_choice_effects.leave(env.state, "test")
    _assert_eq(env.arrow.visible, false, "leave should hide arrow")
    _assert_eq(#runtime.created_markers, 0, "leave should not depend on spawned markers")
  end)
end

local function _test_target_pick_enter_spawns_candidate_markers_at_height_1_6()
  local env = _build_target_pick_env()
  local old_height = gameplay_rules.target_pick.marker_height_offset
  gameplay_rules.target_pick.marker_height_offset = 1.6
  _with_target_pick_runtime(env, function(runtime)
    target_choice_effects.enter(env.state, env.choice)
    _assert_eq(#runtime.created_markers, 0, "enter should wait external event and skip marker spawn")
  end)
  gameplay_rules.target_pick.marker_height_offset = old_height
end

local function _test_target_pick_degrades_without_raycast_api()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    canvas_event_router.bind(env.state, function()
      return env.game
    end)
    _with_patches({
      { target = host_runtime, key = "build_camera_ray", value = function()
        return nil, "missing"
      end },
    }, function()
      target_choice_effects.enter(env.state, env.choice)
      target_choice_effects.step(env.game, env.state, 0.1)
      target_choice_effects.on_scene_pick(env.state, 102, 1, {})
      env.nodes["位置_确认按钮"]._listener_cb({})
      _assert_eq(#env.state.turn_action_port.dispatched, 1, "confirm should still work when raycast unavailable")
      _assert_eq(env.state.turn_action_port.dispatched[1].option_id, 102, "confirm should use locked option")
    end)
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
      choice = { kind = "item_target_player", route_key = "secondary_confirm", requires_confirm = true },
      route = "secondary_confirm",
      confirm = true,
    },
    {
      label = "explicit tax confirm",
      choice = { kind = "tax_card_prompt", route_key = "secondary_confirm", requires_confirm = true },
      route = "secondary_confirm",
      confirm = true,
    },
    {
      label = "explicit landing confirm",
      choice = { kind = "landing_optional_effect", route_key = "secondary_confirm", requires_confirm = true },
      route = "secondary_confirm",
      confirm = true,
    },
    {
      label = "legacy fallback",
      choice = { kind = "remote_dice_value", route_key = "remote" },
      route = "remote",
      confirm = false,
    },
    {
      label = "item phase inline",
      choice = { kind = "item_phase_choice", route_key = "base_inline", uses_item_slots = true, pre_confirm_before_slot_pick = true },
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
      current_player_id = 1,
      choice = {
        id = 10,
        kind = "item_target_player",
        route_key = "player",
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
  _bind_ui_runtime(state)

  _with_patches({
    { key = "all_roles", value = nil },
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "UIManager", value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = query_nodes_by_name,
    } },
  }, function()
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map["玩家选择_槽位2"]._listener_cb({})

    state.ui_model.choice = {
      id = 20,
      kind = "roadblock_target",
      route_key = "target",
      owner_role_id = 1,
      uses_target_picker = true,
      target_picker_owner_role_id = 1,
      allow_cancel = true,
      options = {
        { id = 101, label = "前1" },
        { id = 102, label = "前2" },
        { id = 103, label = "前3" },
        { id = 201, label = "后1" },
        { id = 202, label = "后2" },
      },
    }
    -- target_choice 现在是事件驱动，不再通过 UI 点击触发
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_select", "player click should dispatch choice_select")
  _assert_eq(captured[1] and captured[1].choice_id, 10, "player click should keep choice id")
  _assert_eq(captured[1] and captured[1].option_id, 22, "player click should submit clicked option")
  _assert_eq(captured[1] and captured[1].actor_role_id, 1, "player click should inject fallback actor_role_id")
  _assert_eq(captured[2], nil, "target choice should not dispatch from legacy UI slot click path")
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
    canvas_event_router.bind(state, function()
      return {}
    end)

    local role_id = role.get_roleid()
    _assert_eq(state.ui.debug_visible_by_role[role_id], nil, "action_log role flag should start nil")
    assert(type(node_map["始终显示_行动日志图标"]._listener_cb) == "function", "action_log button should bind click listener")
    local before = require("src.presentation.input.event_state").resolve_debug_enabled(state, role_id)
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
    ["始终显示_行动日志图标"] = new_node(),
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
      ui = ui_view.build_ui_state(),
      ui_model = { choice = nil },
      pending_choice_selected_option_id = nil,
      choice_visible_option_ids = nil,
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map["始终显示_行动日志图标"]._listener_cb({})
    _assert_eq(state.ui.debug_visible_by_role[101], nil, "missing role click should not mutate role debug state")
  end)

  _assert_eq(show_tip_calls, 1, "missing role click should show tip once")
end

local function _test_secondary_confirm_copy_item_phase_selected_option()
  local common = require("src.presentation.view.widgets.choice_screen_service.common")
  local choice = {
    kind = "item_phase_choice",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    confirm_title = "行动前",
    title = "行动前：使用道具？",
    options = {
      { id = 2001, label = "路障卡", confirm_title = "行动前", confirm_body = "将使用：路障卡" },
      { id = 2002, label = "遥控骰子卡", confirm_title = "行动前", confirm_body = "将使用：遥控骰子卡" },
    },
    confirm_body = "可用道具：路障卡、遥控骰子卡",
    meta = { phase = "pre_action" },
  }
  local title = common.resolve_secondary_confirm_title(choice, nil, "base_inline", 2002)
  local body = common.resolve_secondary_confirm_body(choice, nil, "base_inline", 2002, "遥控骰子卡")
  _assert_eq(title, "行动前", "selected item_phase title should keep short phase label")
  _assert_eq(body, "将使用：遥控骰子卡", "selected item_phase body should show chosen card")
end

local function _test_secondary_confirm_copy_land_actions()
  local common = require("src.presentation.view.widgets.choice_screen_service.common")
  local choice = {
    kind = "landing_optional_effect",
    options = {
      { id = "buy_land", label = "购买地块", confirm_title = "买地", confirm_body = "地块：星光街。要买吗？" },
      { id = "upgrade_land", label = "加盖建筑", confirm_title = "加盖", confirm_body = "地块：星光街。要加盖吗？" },
    },
    meta = { tile_id = 77 },
  }
  local game = {
    board = {
      get_tile_by_id = function(_, tile_id)
        if tile_id == 77 then
          return { name = "星光街" }
        end
        return nil
      end,
    },
  }
  _assert_eq(
    common.resolve_secondary_confirm_title(choice, game, "secondary_confirm", "buy_land"),
    "买地",
    "buy land title should be short"
  )
  _assert_eq(
    common.resolve_secondary_confirm_body(choice, game, "secondary_confirm", "buy_land", "购买地块"),
    "地块：星光街。要买吗？",
    "buy land body should include tile and action"
  )
  _assert_eq(
    common.resolve_secondary_confirm_title(choice, game, "secondary_confirm", "upgrade_land"),
    "加盖",
    "upgrade title should be short"
  )
  _assert_eq(
    common.resolve_secondary_confirm_body(choice, game, "secondary_confirm", "upgrade_land", "加盖建筑"),
    "地块：星光街。要加盖吗？",
    "upgrade body should include tile and action"
  )
end

local function _test_secondary_confirm_copy_generic_pre_confirm()
  local common = require("src.presentation.view.widgets.choice_screen_service.common")
  local choice = {
    kind = "remote_dice_value",
    title = "遥控骰子",
    options = {
      { id = 3, label = "点数3" },
    },
  }
  local title = common.resolve_secondary_confirm_title(choice, nil, "remote", 3)
  local body = common.resolve_secondary_confirm_body(choice, nil, "remote", 3, "点数3")
  _assert_eq(title, "请确认", "generic pre-confirm title should be brief")
  _assert_eq(body, "你选的是：点数3", "generic pre-confirm body should show selected option")
end

local function _test_secondary_confirm_prefers_usecase_confirm_copy()
  local common = require("src.presentation.view.widgets.choice_screen_service.common")
  local choice = {
    kind = "landing_optional_effect",
    confirm_title = "不会被读取",
    confirm_body = "不会被读取",
    options = {
      {
        id = "buy_land",
        label = "购买地块",
        confirm_title = "买地",
        confirm_body = "地块：星光街。要买吗？",
      },
    },
  }
  local title = common.resolve_secondary_confirm_title(choice, nil, "secondary_confirm", "buy_land")
  local body = common.resolve_secondary_confirm_body(choice, nil, "secondary_confirm", "buy_land", "购买地块")
  _assert_eq(title, "买地", "secondary confirm should prefer option confirm title from use-case output")
  _assert_eq(body, "地块：星光街。要买吗？", "secondary confirm should prefer option confirm body from use-case output")
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
    ["始终显示_行动日志图标"] = new_node(),
  }
  local local_role = {
    get_roleid = function()
      return "101"
    end,
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
      ui = ui_view.build_ui_state(),
      ui_model = {
        current_player_id = 2,
      },
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map["始终显示_行动日志图标"]._listener_cb({ role = local_role })
    _assert_eq(state.ui.debug_visible_by_role[101], true, "first click should enable local debug")
    node_map["始终显示_行动日志图标"]._listener_cb({})
    _assert_eq(state.ui.debug_visible_by_role[101], false, "second click without role should use cached local role")
    _assert_eq(state.ui.debug_visible_by_role[2], nil, "action_log should not fall back to current_player_id")
  end)

  _assert_eq(show_tip_calls, 0, "cached local role should avoid missing context tip")
end

local function _test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player()
  local always_show_nodes = require("src.presentation.view.canvas.always_show.nodes")

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

  local enabled_by_int = require("src.presentation.input.event_state").resolve_debug_enabled(state, 1)
  local enabled_by_string = require("src.presentation.input.event_state").resolve_debug_enabled(state, "1")

  _assert_eq(enabled_by_int, true, "debug_enabled should read string key by int role_id")
  _assert_eq(enabled_by_string, true, "debug_enabled should read string key by string role_id")
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
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 1001,
      [tostring(option_id)] = 1002,
    }),
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
  _assert_eq(labels[market_layout.price_label], tostring(entry.price) .. " " .. entry.currency,
    "market price label should update")
end

local function _test_market_close_resets_icon_without_resize()
  local reset_calls = 0
  local visible = {}
  local selected_node = {
    reset_size = function()
      reset_calls = reset_calls + 1
    end,
  }
  local state = {
    choice_visible_option_ids = { 1, 2 },
    pending_choice_selected_option_id = 1,
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 4321,
    }),
    ui = {
      market_active = true,
      set_visible = function(_, name, value)
        visible[name] = value == true
      end,
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
  _assert_eq(_ui_runtime(state).choice_visible_option_ids, nil, "market options should clear")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, nil, "selected market option should clear")
  _assert_eq(selected_node.image_texture, 4321, "market selected icon should reset to empty key")
  _assert_eq(reset_calls, 0, "market close should not call reset_size")
  for _, name in ipairs(market_layout.item_selection_frames) do
    _assert_eq(visible[name], false, "market close should hide selection frame")
  end
end

local function _test_market_view_default_selection_shows_matching_selection_frame()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9301,
      ["lv1"] = 9302,
      ["lv2"] = 9303,
      ["lv3"] = 9304,
      [tostring(entry_a.product_id)] = 9305,
      [tostring(entry_b.product_id)] = 9306,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 21,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_b.product_id,
  })

  _assert_eq(opened, true, "market panel should open")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_a.product_id,
    "market should still prefer first visible buyable option by default")
  _assert_eq(visible[market_layout.item_selection_frames[1]], true,
    "first selection frame should match default selected option")
  _assert_eq(visible[market_layout.item_selection_frames[2]], false,
    "non-selected frame should stay hidden")
end

local function _test_market_select_switches_selection_frame()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9401,
      ["lv1"] = 9402,
      ["lv2"] = 9403,
      ["lv3"] = 9404,
      [tostring(entry_a.product_id)] = 9405,
      [tostring(entry_b.product_id)] = 9406,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 22,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_a.product_id,
  })

  market_view.select_market_option(state, entry_b.product_id)

  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_b.product_id, "market select should update selected option")
  _assert_eq(visible[market_layout.item_selection_frames[1]], false,
    "old selection frame should hide after reselection")
  _assert_eq(visible[market_layout.item_selection_frames[2]], true,
    "new selection frame should show after reselection")
end

local function _test_market_view_empty_filtered_tab_hides_selection_frames()
  local visible_entry = assert(market_cfg[1], "missing market cfg entry")
  local hidden_entry = {
    product_id = 999101,
    name = "隐藏测试商品2",
    market_enabled = false,
    currency = visible_entry.currency,
    price = visible_entry.price,
  }

  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9501,
      ["lv1"] = 9502,
      ["lv2"] = 9503,
      ["lv3"] = 9504,
      [tostring(visible_entry.product_id)] = 9505,
      [tostring(hidden_entry.product_id)] = 9506,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local market_cfg_size = #market_cfg
  local old_market_view = package.loaded["src.presentation.view.render.market"]
  market_cfg[market_cfg_size + 1] = hidden_entry
  package.loaded["src.presentation.view.render.market"] = nil

  local ok, err = xpcall(function()
    local test_market_view = require("src.presentation.view.render.market")

    test_market_view.refresh_market(state, {
      choice_id = 23,
      options = {
        { id = visible_entry.product_id, label = visible_entry.name, can_buy = true },
      },
      allow_cancel = true,
      selected_option_id = visible_entry.product_id,
    })

    local reopened = test_market_view.refresh_market(state, {
      choice_id = 24,
      options = {
        { id = hidden_entry.product_id, label = hidden_entry.name, can_buy = false },
      },
      allow_cancel = true,
      selected_option_id = hidden_entry.product_id,
    })

    _assert_eq(reopened, true, "market panel should stay open when filtered tab is empty")
    _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, nil, "empty filtered tab should clear selected option")
    for _, name in ipairs(market_layout.item_selection_frames) do
      _assert_eq(visible[name], false, "empty filtered tab should hide all selection frames")
    end
  end, debug.traceback or function(e) return e end)

  market_cfg[market_cfg_size + 1] = nil
  package.loaded["src.presentation.view.render.market"] = nil
  package.loaded["src.presentation.view.render.market"] = old_market_view
  if not ok then
    error(err)
  end
end

local function _test_market_view_refresh_retargets_selection_frame_on_page_change()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9601,
      ["lv1"] = 9602,
      ["lv2"] = 9603,
      ["lv3"] = 9604,
      [tostring(entry_a.product_id)] = 9605,
      [tostring(entry_b.product_id)] = 9606,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 25,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_a.product_id,
    page_index = 1,
    page_count = 2,
  })

  local reopened = market_view.refresh_market(state, {
    choice_id = 25,
    options = {
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_b.product_id,
    page_index = 2,
    page_count = 2,
  })

  _assert_eq(reopened, true, "market panel should refresh on page change")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_b.product_id,
    "page change should retarget selected option to current visible page")
  _assert_eq(visible[market_layout.item_selection_frames[1]], true,
    "current page selected option should show selection frame")
  for index = 2, #market_layout.item_selection_frames do
    _assert_eq(visible[market_layout.item_selection_frames[index]], false,
      "non-current page frames should remain hidden after refresh")
  end
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
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
    }),
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
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
      ["2002"] = "ICON2002",
      ["2003"] = "ICON2003",
    }),
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
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
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
  local item_slot_intents = require("src.presentation.view.canvas.base.item_slot_intents")
  local state = {
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
    },
    ui_model = {
      choice = {
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
      },
    },
  }
  _bind_ui_runtime(state)

  local specs = item_slot_intents.build(state)
  _assert_eq(#specs, 2, "item slot intents should include slot and outline")
  _assert_eq(specs[1].name, "基础_道具槽位1", "slot intent node expected")
  _assert_eq(specs[2].name, "基础_可出牌外框1", "outline intent node expected")
  local intent = specs[2].build_intent()
  _assert_eq(intent and intent.id, "item_slot_1", "outline click should map to slot action")
end

local function _test_market_view_hides_market_disabled_entries()
  local visible_entry = nil
  for _, entry in ipairs(market_cfg) do
    if visible_entry == nil and entry.market_enabled ~= false then
      visible_entry = entry
    end
    if visible_entry then
      break
    end
  end
  assert(visible_entry ~= nil, "missing market visible entry for presentation test")
  local hidden_entry = {
    product_id = 999001,
    name = "隐藏测试商品",
    market_enabled = false,
    currency = visible_entry.currency,
    price = visible_entry.price,
  }

  local labels = {}
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9001,
      ["lv1"] = 9002,
      ["lv2"] = 9003,
      ["lv3"] = 9004,
      [tostring(hidden_entry.product_id)] = 9005,
      [tostring(visible_entry.product_id)] = 9006,
    }),
    ui = {
      market_active = false,
      set_label = function(_, name, text)
        labels[name] = text
      end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local market_cfg_size = #market_cfg
  local old_market_view = package.loaded["src.presentation.view.render.market"]
  market_cfg[market_cfg_size + 1] = hidden_entry
  package.loaded["src.presentation.view.render.market"] = nil

  local ok, err = xpcall(function()
    local test_market_view = require("src.presentation.view.render.market")

    local opened = test_market_view.refresh_market(state, {
      choice_id = 7,
      options = {
        { id = hidden_entry.product_id, label = hidden_entry.name, can_buy = false },
        { id = visible_entry.product_id, label = visible_entry.name, can_buy = true },
      },
      allow_cancel = true,
      selected_option_id = hidden_entry.product_id,
    })

    _assert_eq(opened, true, "market panel should open when at least one visible option exists")
    _assert_eq(labels[market_layout.item_labels[1]], visible_entry.name, "first rendered market option should skip disabled entry")
    _assert_eq(visible[market_layout.item_labels[2]], false, "second slot should remain hidden after filtering")

    local reopened = test_market_view.refresh_market(state, {
      choice_id = 8,
      options = {
        { id = hidden_entry.product_id, label = hidden_entry.name, can_buy = false },
      },
      allow_cancel = true,
      selected_option_id = hidden_entry.product_id,
    })

    _assert_eq(reopened, true, "market panel should stay open when all options are filtered out")
    _assert_eq(state.ui.market_active, true, "market panel should remain active on empty filtered tab")
    _assert_eq(visible[market_layout.item_labels[1]], false, "empty filtered tab should hide first slot label")
    _assert_eq(visible[market_layout.item_buttons[1]], false, "empty filtered tab should hide first slot button")
    _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, nil, "empty filtered tab should clear selected option")
  end, debug.traceback or function(e) return e end)

  market_cfg[market_cfg_size + 1] = nil
  package.loaded["src.presentation.view.render.market"] = nil
  package.loaded["src.presentation.view.render.market"] = old_market_view
  if not ok then
    error(err)
  end
end

local function _test_market_view_unbuyable_option_is_clickable()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local touch = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9001,
      ["lv1"] = 9002,
      ["lv2"] = 9003,
      ["lv3"] = 9004,
      [tostring(entry.product_id)] = 9005,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function(_, name, flag)
        touch[name] = flag == true
      end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 10,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = false },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
  })

  _assert_eq(opened, true, "market panel should open with unbuyable options")
  _assert_eq(touch[market_layout.item_buttons[1]], true, "unbuyable option button should still be clickable")
end

local function _test_market_view_hides_disabled_market_tab()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local visible = {}
  local touch = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9001,
      ["lv1"] = 9002,
      ["lv2"] = 9003,
      ["lv3"] = 9004,
      [tostring(entry.product_id)] = 9005,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function(_, name, flag)
        touch[name] = flag == true
      end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 11,
    active_tab = "item",
    page_index = 1,
    page_count = 1,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
  })

  _assert_eq(opened, true, "market panel should open for hidden tab check")
  _assert_eq(visible[market_layout.tab_vehicle], false, "disabled market tab should stay hidden")
  _assert_eq(touch[market_layout.tab_vehicle], false, "hidden market tab should not remain touch enabled")
end

local function _test_market_view_invalid_selected_option_falls_back_to_current_visible_option()
  local entry_a = nil
  local entry_b = nil
  for _, entry in ipairs(market_cfg) do
    if entry.market_enabled ~= false then
      if entry_a == nil then
        entry_a = entry
      elseif entry_b == nil and entry.product_id ~= entry_a.product_id then
        entry_b = entry
      end
    end
    if entry_a and entry_b then
      break
    end
  end
  assert(entry_a ~= nil and entry_b ~= nil, "missing visible market entries for selected fallback test")

  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9201,
      ["lv1"] = 9202,
      ["lv2"] = 9203,
      ["lv3"] = 9204,
      [tostring(entry_a.product_id)] = 9205,
      [tostring(entry_b.product_id)] = 9206,
    }),
    pending_choice_selected_option_id = nil,
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 13,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = 999999,
  })

  _assert_eq(opened, true, "market panel should open")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_a.product_id,
    "invalid selected option should fallback to first visible buyable option")
end

local function _test_market_view_page_arrows_visibility_follows_page_count()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local visible = {}
  local touch = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9101,
      ["lv1"] = 9102,
      ["lv2"] = 9103,
      ["lv3"] = 9104,
      [tostring(entry.product_id)] = 9105,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function(_, name, flag)
        touch[name] = flag == true
      end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 11,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
    page_index = 1,
    page_count = 1,
  })

  _assert_eq(visible[market_layout.page_prev], false, "page_prev should be hidden when only one page")
  _assert_eq(visible[market_layout.page_next], false, "page_next should be hidden when only one page")

  market_view.refresh_market(state, {
    choice_id = 12,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
    page_index = 1,
    page_count = 2,
  })

  _assert_eq(visible[market_layout.page_prev], true, "page_prev should be visible when multiple pages")
  _assert_eq(visible[market_layout.page_next], true, "page_next should be visible when multiple pages")
  _assert_eq(touch[market_layout.page_prev], false, "page_prev should be disabled on first page")
  _assert_eq(touch[market_layout.page_next], true, "page_next should be enabled when next page exists")
end

local function _test_ui_model_market_payload_prefers_explicit_choice_fields()
  local ui_model = require("src.presentation.model")
  local g = _new_game()
  local current_player = g:current_player()
  g.turn.pending_choice = {
    id = 321,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = current_player.id,
    title = "黑市",
    options = {
      {
        id = 7001,
        label = "测试皮肤",
        can_buy = true,
        requires_pre_confirm = true,
        confirm_title = "请确认",
        confirm_body = "你选的是：测试皮肤",
      },
    },
    allow_cancel = true,
    cancel_label = "不买",
    active_tab = "skin",
    page_index = 2,
    page_count = 5,
    meta = {
      player_id = current_player.id,
      active_tab = "item",
      page_index = 9,
      page_count = 9,
    },
  }

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
  })

  _assert_eq(model.choice and model.choice.options[1] and model.choice.options[1].requires_pre_confirm, true,
    "choice view should preserve explicit option pre-confirm flag")
  _assert_eq(model.choice and model.choice.owner_role_id, current_player.id,
    "choice view should preserve explicit owner role id")
  _assert_eq(model.market and model.market.active_tab, "skin", "market payload should prefer explicit active_tab")
  _assert_eq(model.market and model.market.page_index, 2, "market payload should prefer explicit page_index")
  _assert_eq(model.market and model.market.page_count, 5, "market payload should prefer explicit page_count")
end

local function _test_target_pick_prefers_explicit_owner_role_id()
  local env = _build_target_pick_env()
  env.choice.target_picker_owner_role_id = 7
  env.choice.owner_role_id = 7
  env.choice.meta.player_id = 2
  env.state.game.current_player = function()
    return { id = 3 }
  end

  local entered = target_choice_effects.enter(env.state, env.choice)
  _assert_eq(entered, true, "target picker should still enter")
  _assert_eq(env.state.target_choice_runtime and env.state.target_choice_runtime.owner_role_id, 7,
    "target picker should use explicit owner role id before meta/current-player fallback")
  target_choice_effects.leave(env.state, "test_cleanup")
end

local function _test_modal_presenter_market_same_choice_id_still_refreshes_market_panel()
  local modal_presenter = require("src.presentation.view.widgets.modal_presenter")
  local market_presenter = require("src.presentation.view.canvas.market.presenter")
  local target_choice_effects_local = require("src.presentation.view.render.target_choice_effects")
  local canvas_store = require("src.presentation.runtime.canvas_store")

  local opened = 0
  local state = {
    pending_choice_id = 21,
    ui_dirty = false,
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)
  state.ui.market_active = true
  state.ui.choice_active = false
  local choice = {
    id = 21,
    kind = "market_buy",
    route_key = "market",
    title = "黑市",
    options = {
      { id = 2001, label = "A", can_buy = true },
    },
    allow_cancel = true,
    cancel_label = "取消",
  }
  local market = {
    choice_id = 21,
    options = choice.options,
    allow_cancel = true,
    selected_option_id = 2001,
    active_tab = "skin",
    page_index = 1,
    page_count = 1,
  }

  _with_patches({
    { target = market_presenter, key = "open", value = function()
      opened = opened + 1
    end },
    { target = target_choice_effects_local, key = "leave", value = function() end },
    { target = canvas_store, key = "mark_dirty", value = function() end },
  }, function()
    modal_presenter.open_choice_modal(state, choice, market)
  end)

  _assert_eq(opened, 1, "market choice with same id should still refresh market presenter")
end

local function _test_ui_event_router_market_cancel_button_dispatches_choice_cancel()
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
  local show_tip_calls = 0
  local node_map = {
    [market_nodes.cancel] = new_node(),
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
      ui_runtime = {
        ui_model = {
          current_player_id = "3",
          choice = {
            id = 12,
            kind = "market_buy",
            allow_cancel = true,
            options = { { id = 34, label = "X" } },
          },
          market = {
            choice_id = 12,
            options = { { id = 34, label = "X" } },
          },
        },
        pending_choice_selected_option_id = 34,
      },
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map[market_nodes.cancel]._listener_cb({})
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_cancel", "market_cancel button should dispatch choice_cancel")
  _assert_eq(captured[1] and captured[1].choice_id, 12, "market_cancel should keep choice id")
  _assert_eq(captured[1] and captured[1].actor_role_id, 3, "market_cancel should inject actor_role_id")
  _assert_eq(show_tip_calls, 0, "market_cancel should not show unadapted tip")
end

local function _test_item_phase_ask_confirm_clears_highlight_suppress()
  local item_phase_ask_flow = require("src.presentation.input.intent_dispatch.item_phase_ask")
  local closed = 0
  local state = {
    _item_phase_ask_active = true,
    _item_phase_confirmed = nil,
    _suppress_item_slot_highlight_until_pick = true,
    ui_model = {
      choice = { id = 66, kind = "item_phase_choice", route_key = "base_inline", uses_item_slots = true, pre_confirm_before_slot_pick = true },
      
    },
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)

  local handled = false
  _with_patches({
    {
      target = ui_view,
      key = "close_choice_modal",
      value = function()
        closed = closed + 1
      end,
    },
  }, function()
    handled = item_phase_ask_flow.dispatch(state, {}, { type = "choice_select" }, {}, {
      dispatch_action = function()
        error("choice_select on item_phase_ask should not dispatch action directly")
      end,
    })
  end)

  _assert_eq(handled, true, "item_phase_ask choice_select should be handled")
  _assert_eq(state._item_phase_ask_active, nil, "item_phase_ask_active should clear after confirm")
  _assert_eq(state._item_phase_confirmed, true, "item_phase_confirmed should become true after confirm")
  _assert_eq(state._suppress_item_slot_highlight_until_pick, nil,
    "highlight suppression should clear after item_phase ask confirm")
  _assert_eq(state._skip_item_slot_highlight_replay_choice_id, 66,
    "item_phase ask confirm should skip highlight replay before slot click")
  _assert_eq(closed, 1, "item_phase ask confirm should close modal once")
end

local function _test_item_phase_confirmed_skips_replay_before_slot_click()
  local ui_events = require("src.presentation.runtime.events")
  local events = {}
  local state = {
    _item_phase_ask_active = nil,
    _item_phase_confirmed = true,
    _skip_item_slot_highlight_replay_choice_id = 77,
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2002"] = "ICON2002",
    }),
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
      set_touch_enabled = function() end,
      set_visible = function() end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = { [1] = { 2002 } },
    choice = {
      id = 77,
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2002 } },
    },
  }

  _with_patches({
    {
      key = "UIManager",
      value = {
        client_role = nil,
        query_nodes_by_name = function()
          return { { set_texture_keep_size = function() end } }
        end,
      },
    },
    {
      target = ui_events,
      key = "send_to_all",
      value = function(event_name)
        events[#events + 1] = event_name
      end,
    },
    {
      target = ui_events,
      key = "send_to_role",
      value = function(_, event_name)
        events[#events + 1] = event_name
      end,
    },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  _assert_eq(_has_event(events, "高亮道具槽位牌1"), false,
    "confirmed item phase should not replay slot highlight before click")
  _assert_eq(_has_event(events, "重置高亮"), false,
    "confirmed item phase should not replay global highlight reset before click")
  _assert_eq(state._skip_item_slot_highlight_replay_choice_id, 77,
    "skip replay flag should remain until slot click")
end

local function _test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines()
  local ui_events = require("src.presentation.runtime.events")
  local events = {}
  local visible_state = {}
  local timers = {}

  local state = {
    _item_phase_ask_active = true,
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2002"] = "ICON2002",
      ["2003"] = "ICON2003",
    }),
    ui = {
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3" },
      card_outlines = { "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3" },
      set_touch_enabled = function() end,
      set_visible = function(_, name, visible)
        visible_state[name] = visible == true
      end,
    },
  }

  local ui_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2002, nil, 2003 },
    },
    choice = {
      id = 99,
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2002 }, { id = 2003 } },
    },
  }

  local function _count_event(event_name)
    local count = 0
    for _, value in ipairs(events) do
      if value == event_name then
        count = count + 1
      end
    end
    return count
  end

  _with_patches({
    {
      key = "UIManager",
      value = {
        client_role = nil,
        query_nodes_by_name = function()
          return { { set_texture_keep_size = function() end } }
        end,
      },
    },
    {
      target = ui_events,
      key = "send_to_all",
      value = function(event_name)
        events[#events + 1] = event_name
      end,
    },
    {
      target = ui_events,
      key = "send_to_role",
      value = function(_, event_name)
        events[#events + 1] = event_name
      end,
    },
    {
      key = "SetTimeOut",
      value = function(_, cb)
        timers[#timers + 1] = cb
      end,
    },
  }, function()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    _assert_eq(_count_event("高亮道具槽位牌1"), 1, "item_phase_ask should emit highlight for slot1 once")
    _assert_eq(_count_event("高亮道具槽位牌3"), 1, "item_phase_ask should emit highlight for slot3 once")
    _assert_eq(_count_event("重置高亮"), 1, "item_phase_ask should emit global reset once")
    _assert_eq(visible_state["基础_可出牌外框1"], false, "outline1 should stay hidden before delay")
    _assert_eq(visible_state["基础_可出牌外框3"], false, "outline3 should stay hidden before delay")
    _assert_eq(#timers, 1, "item_phase_ask should schedule exactly one reveal timer")

    timers[1]()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    _assert_eq(_count_event("高亮道具槽位牌1"), 1, "highlight should not replay every refresh")
    _assert_eq(_count_event("高亮道具槽位牌3"), 1, "highlight should not replay every refresh")
    _assert_eq(visible_state["基础_可出牌外框1"], true, "outline1 should show after delay")
    _assert_eq(visible_state["基础_可出牌外框3"], true, "outline3 should show after delay")
    _assert_eq(visible_state["基础_可出牌外框2"], false, "non-pickable outline should stay hidden")
  end)
end

local function _test_item_slot_refresh_resets_highlight_without_client_role()
  local ui_events = require("src.presentation.runtime.events")
  local events = {}
  local phase = ""

  local function _record(channel, event_name)
    events[#events + 1] = {
      phase = phase,
      channel = channel,
      event_name = event_name,
    }
  end

  local function _has_event(phase_name, event_name)
    for _, entry in ipairs(events) do
      if entry.phase == phase_name and entry.event_name == event_name then
        return true
      end
    end
    return false
  end

  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2002"] = "ICON2002",
      ["2003"] = "ICON2003",
      ["2004"] = "ICON2004",
      ["2007"] = "ICON2007",
      ["2008"] = "ICON2008",
    }),
    ui = {
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3", "基础_道具槽位4", "基础_道具槽位5" },
      card_outlines = { "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3", "基础_可出牌外框4", "基础_可出牌外框5" },
      set_touch_enabled = function() end,
      set_visible = function() end,
    },
  }

  local pre_action_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2002, 2004, 2007, 2008, 2003 },
    },
    choice = {
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2002 } },
    },
  }

  local remote_choice_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2002, 2004, 2007, 2008, 2003 },
    },
    choice = {
      kind = "remote_dice_value",
      route_key = "remote",
      options = { { id = 1 }, { id = 2 } },
    },
  }

  local pre_move_model = {
    current_player_id = 1,
    item_choice_owner_id = 1,
    item_slots_by_player = {
      [1] = { 2004, 2007, 2008, 2003, nil },
    },
    choice = {
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = true,
      options = { { id = 2003 } },
    },
  }

  _with_patches({
    {
      key = "UIManager",
      value = {
        client_role = nil,
        query_nodes_by_name = function()
          return { { set_texture_keep_size = function() end } }
        end,
      },
    },
    {
      target = ui_events,
      key = "send_to_all",
      value = function(event_name)
        _record("all", event_name)
      end,
    },
    {
      target = ui_events,
      key = "send_to_role",
      value = function(_, event_name)
        _record("role", event_name)
      end,
    },
  }, function()
    phase = "pre_action"
    ui_view.refresh_item_slots(state, pre_action_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    state._suppress_item_slot_highlight_until_pick = true
    phase = "suppressed_item_phase"
    ui_view.refresh_item_slots(state, pre_action_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    phase = "remote_choice"
    ui_view.refresh_item_slots(state, remote_choice_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    state._suppress_item_slot_highlight_until_pick = nil
    phase = "pre_move"
    ui_view.refresh_item_slots(state, pre_move_model, {
      display_player_id = 1,
      allow_interact = true,
    })
  end)

  _assert_eq(_has_event("pre_action", "高亮道具槽位牌1"), true, "pre_action should highlight remote dice slot")
  _assert_eq(_has_event("pre_action", "重置高亮"), true, "pre_action should issue global reset before highlighting")
  _assert_eq(_has_event("suppressed_item_phase", "重置高亮"), false,
    "item_phase should suppress highlight animation while waiting for a pick")
  _assert_eq(_has_event("suppressed_item_phase", "高亮道具槽位牌1"), false,
    "item_phase suppression should block per-slot highlight events")
  _assert_eq(_has_event("remote_choice", "重置高亮"), true, "remote choice should issue global reset before slot reorder")
  _assert_eq(_has_event("remote_choice", "重置高亮道具槽位牌1"), true, "remote choice should reset slot1 highlight without client role")
  _assert_eq(_has_event("pre_move", "重置高亮"), true, "pre_move should issue global reset before highlighting playable slots")
  _assert_eq(_has_event("pre_move", "高亮道具槽位牌4"), true, "pre_move should highlight dice multiplier slot")
  _assert_eq(_has_event("pre_move", "重置高亮道具槽位牌1"), true, "pre_move should clear stale slot1 highlight")
end

local function _test_tick_skips_anim_when_no_anim()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local board_view_mod = require("src.presentation.view.render.board")

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
  local engine = runtime_cls:new(g, phases, { experimental_coroutine_turn = true })

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
    _assert_eq(d1, gameplay_rules.action_anim_default_seconds, "default action anim duration should follow gameplay rule")
    _assert_eq(d2, 1.8, "explicit action anim duration should override")
  end)
  _assert_eq(#durations, 0, "default action anim should not consume tip queue")
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
    turn = opts.turn,
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

local function _test_status3d_hospital_visible_when_no_action_notice_even_if_stay_turns_zero()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "poor", remaining = 5 },
    },
    turn = {
      phase = "end_turn",
      detained_wait_active = false,
      no_action_notice_active = true,
      no_action_notice_player_id = 1,
      no_action_notice_text = "本回合无法行动",
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 0,
      note = "被扣留",
    },
  })
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true, turn = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(env.layer_visibility[hospital_layer][1], true,
    "hospital layer should stay visible during no-action notice when stay_turns is zero")
  _assert_eq(env.layer_visibility[poor_layer][1], false,
    "deity layer should be hidden when hospital no-action notice is active")
end

local function _test_status3d_mountain_visible_when_no_action_notice_even_if_stay_turns_zero()
  local env = _build_status3d_test_env()
  local state = {}
  local game = _build_status3d_game({
    tile_type = "mountain",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "rich", remaining = 5 },
    },
    turn = {
      phase = "end_turn",
      detained_wait_active = false,
      no_action_notice_active = true,
      no_action_notice_player_id = 1,
      no_action_notice_text = "本回合无法行动",
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 0,
      note = "被扣留",
    },
  })
  local prefab = require("Data.Prefab")
  local mountain_layout = prefab.scene_eui["深山状态"]
  local rich_layout = prefab.scene_eui["财神状态"]
  _with_patches({
    { key = "GameAPI", value = env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(game, state, { any = true, players = true, turn = true })
  end)

  local mountain_layer = "layer_1_" .. tostring(mountain_layout)
  local rich_layer = "layer_1_" .. tostring(rich_layout)
  _assert_eq(env.layer_visibility[mountain_layer][1], true,
    "mountain layer should stay visible during no-action notice when stay_turns is zero")
  _assert_eq(env.layer_visibility[rich_layer][1], false,
    "deity layer should be hidden when mountain no-action notice is active")
end

local function _test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero()
  local prefab = require("Data.Prefab")
  local hospital_layout = prefab.scene_eui["医院状态"]
  local mountain_layout = prefab.scene_eui["深山状态"]
  local poor_layout = prefab.scene_eui["穷神状态"]
  local rich_layout = prefab.scene_eui["财神状态"]

  local hospital_env = _build_status3d_test_env()
  local hospital_state = {}
  local hospital_game = _build_status3d_game({
    tile_type = "hospital",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "poor", remaining = 5 },
    },
    turn = {
      phase = "start",
      detained_wait_active = false,
    },
  })
  _with_patches({
    { key = "GameAPI", value = hospital_env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(hospital_game, hospital_state, { any = true, players = true, turn = true })
  end)

  local hospital_layer = "layer_1_" .. tostring(hospital_layout)
  local poor_layer = "layer_1_" .. tostring(poor_layout)
  _assert_eq(hospital_env.layer_visibility[hospital_layer][1], false,
    "hospital layer should stay hidden when stay_turns is zero and turn is not detained")
  _assert_eq(hospital_env.layer_visibility[poor_layer][1], true,
    "deity layer should be visible when hospital detained status is inactive")

  local mountain_env = _build_status3d_test_env()
  local mountain_state = {}
  local mountain_game = _build_status3d_game({
    tile_type = "mountain",
    player_status_1 = {
      stay_turns = 0,
      deity = { type = "rich", remaining = 5 },
    },
    turn = {
      phase = "start",
      detained_wait_active = false,
    },
  })
  _with_patches({
    { key = "GameAPI", value = mountain_env.game_api },
    { key = "Enums", value = { ModelSocket = { socket_head = 7 } } },
  }, function()
    ui_status_3d_layer.sync(mountain_game, mountain_state, { any = true, players = true, turn = true })
  end)

  local mountain_layer = "layer_1_" .. tostring(mountain_layout)
  local rich_layer = "layer_1_" .. tostring(rich_layout)
  _assert_eq(mountain_env.layer_visibility[mountain_layer][1], false,
    "mountain layer should stay hidden when stay_turns is zero and turn is not detained")
  _assert_eq(mountain_env.layer_visibility[rich_layer][1], true,
    "deity layer should be visible when mountain detained status is inactive")
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

local function _test_turn_effects_sync_restores_client_role_nil()
  local env = _build_turn_effect_runtime_env({ 1, 2 })
  local manager = { client_role = { marker = "seed" } }
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
    { key = "UIManager", value = manager },
    { target = runtime_port, key = "set_client_role", value = function(role)
      env.set_client_role(role)
      manager.client_role = role
    end },
    { target = runtime_port, key = "for_each_role_or_global", value = env.for_each_role_or_global },
    { target = runtime_port, key = "query_node", value = env.query_node },
    { target = runtime_port, key = "with_client_role", value = function(role, fn)
      local prev = manager.client_role
      manager.client_role = role
      env.set_client_role(role)
      local ok, err = pcall(fn)
      env.set_client_role(prev)
      manager.client_role = prev
      if not ok then
        error(err)
      end
    end },
  }, function()
    turn_effects.sync(state, ui_model)
  end)

  _assert_eq(manager.client_role, nil, "turn_effects.sync should restore client_role to nil")
end

local function _test_tick_ui_sync_turn_switch_still_follows()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local board_view_mod = require("src.presentation.view.render.board")
  local helper = { target_role_id = nil }
  local follow_events = 0
  local follow_event_name = nil
  local follow_event_payload = nil
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
    { key = "TriggerCustomEvent", value = function(event_name, payload)
      follow_events = follow_events + 1
      follow_event_name = event_name
      follow_event_payload = payload
    end },
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
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
  }
  _bind_ui_runtime(state)

  _with_patches(patches, function()
    runtime_event_bridge._reset_for_tests()
    state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
    gameplay_loop.tick(game, state, 0.1)
    runtime_event_bridge._reset_for_tests()
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should follow current player")
  assert(follow_events >= 1, "turn switch should trigger follow event")
  _assert_eq(follow_event_name, "follow_camera", "turn switch should emit follow_camera event")
  assert(type(follow_event_payload) == "table", "turn switch follow event should include payload table")
  _assert_eq(follow_event_payload.target_role_id, nil, "turn switch follow event should not carry target_role_id payload")
end

local function _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local board_view_mod = require("src.presentation.view.render.board")
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
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
  }
  _bind_ui_runtime(state)

  _with_patches(patches, function()
    runtime_event_bridge._reset_for_tests()
    local ok, err = pcall(function()
      state.gameplay_loop_ports = require("src.presentation.runtime.ports").build(state)
      gameplay_loop.tick(game, state, 0.1)
    end)
    runtime_event_bridge._reset_for_tests()
    assert(ok == true, "turn switch should not fail when follow event is unavailable: " .. tostring(err))
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should still track current player on degraded follow event")
  _assert_eq(follow_events, 0, "degraded follow event path should avoid wrapped TriggerCustomEvent call")
end

local function _test_ui_sync_defers_choice_modal_during_wait_action_anim()
  local ui_view_service = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.ui_model_sync")
  local opened = 0
  local game = {
      turn = {
        phase = "wait_action_anim",
        current_player_index = 1,
        turn_count = 1,
        pending_choice = {
          id = 7,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
        body_lines = { "A" },
        options = { { id = 1, label = "A" } },
        allow_cancel = true,
        cancel_label = "取消",
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
  }
  _with_patches({
    { target = ui_view_service, key = "render", value = function() end },
    { target = ui_view_service, key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 7, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 7, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 7, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 7, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)
  _assert_eq(opened, 0, "wait_action_anim should defer opening choice modal")
end

local function _test_ui_sync_opens_choice_modal_after_wait_action_anim()
  local ui_view_service = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.ui_model_sync")
  local opened = 0
  local game = {
    turn = {
      phase = "wait_action_anim",
      current_player_index = 1,
      turn_count = 1,
        pending_choice = {
          id = 8,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
        body_lines = { "A" },
        options = { { id = 1, label = "A" } },
        allow_cancel = true,
        cancel_label = "取消",
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
  }
  _with_patches({
    { target = ui_view_service, key = "render", value = function() end },
    { target = ui_view_service, key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 8, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 8, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 8, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 8, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
    _assert_eq(opened, 0, "choice modal should remain deferred during wait_action_anim")
    game.turn.phase = "wait_choice"
    state.ui_dirty = true
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)
  _assert_eq(opened, 1, "choice modal should open once after leaving wait_action_anim")
end

local function _test_ui_sync_defers_choice_modal_during_wait_move_anim()
  local ui_view_service = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.ui_model_sync")
  local opened = 0
  local game = {
    turn = {
      phase = "wait_move_anim",
      current_player_index = 1,
      turn_count = 1,
        pending_choice = {
          id = 9,
          kind = "market_buy",
          route_key = "market",
          title = "黑市",
        body_lines = { "A" },
        options = { { id = 1, label = "A" } },
        allow_cancel = true,
        cancel_label = "取消",
      },
    },
    players = {
      [1] = { id = 1, name = "P1", cash = 0, inventory = { items = {} }, eliminated = false },
    },
  }
  local state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
  }
  _with_patches({
    { target = ui_view_service, key = "render", value = function() end },
    { target = ui_view_service, key = "open_choice_modal", value = function()
      opened = opened + 1
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 9, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 9, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = { id = 9, kind = "market_buy", route_key = "market", options = { { id = 1, label = "A" } }, allow_cancel = true },
        market = { choice_id = 9, options = { { id = 1, label = "A" } }, allow_cancel = true },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)
  _assert_eq(opened, 0, "wait_move_anim should defer opening choice modal")
end

local function _test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop()
  local ui_view_service = require("src.presentation.runtime.view")
  local ui_model = require("src.presentation.model")
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.ui_model_sync")
  local anchors = require("src.presentation.view.render.board.anchors")
  local startup_render = require("src.presentation.view.render.board.startup_render")
  local player_units = require("src.presentation.view.render.board.player_units")
  local base_presenter = require("src.presentation.view.canvas.base.presenter")
  local turn_effects = require("src.presentation.view.widgets.turn_effects")
  local fixed_zero = { kind = "fixed_zero", value = 0 }
  local calls = {}
  local game = {
    turn = {
      phase = "start",
      current_player_index = 1,
      turn_count = 1,
    },
    players = {
      [1] = { id = 1, name = "P1", position = 1, seat_id = nil, eliminated = false, inventory = { items = {} }, cash = 0 },
    },
  }
  local state
  state = {
    ui = ui_view_service.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
    ui_dirty = true,
    ui_model = nil,
    board_scene = {
      ground = {
        get_position = function()
          return { y = 0 }
        end,
      },
    },
    tile_positions = {
      [1] = vec3.with_add(10, 0, 20),
    },
    tile_spacing = 0,
    player_units = {
      [1] = {
        ai_command_stop_move = function(duration)
          _assert_eq(duration, fixed_zero, "refresh_from_dirty should pass Fix32 zero into ai stop")
          calls[#calls + 1] = "ai_command_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
        set_position = function(pos)
          calls[#calls + 1] = "set_position"
          state._last_target_pos = pos
        end,
      },
    },
  }

  _with_patches({
    { target = anchors, key = "ensure_tile_anchors", value = function() end },
    { target = startup_render, key = "apply", value = function() end },
    { target = player_units, key = "ensure_player_units", value = function() end },
    { target = base_presenter, key = "refresh", value = function() end },
    { target = turn_effects, key = "sync", value = function() end },
    { target = math, key = "tofixed", value = function(value)
      _assert_eq(value, 0, "refresh_from_dirty should only request zero stop duration")
      return fixed_zero
    end },
    { target = ui_model, key = "build", value = function()
      return {
        panel = { turn_label = "" },
        board = {
          phase = "start",
          move_anim = nil,
          move_followup_pending = false,
          vehicle_resync_seq = 0,
          tile_count = 1,
          tiles = { { id = 1 } },
          players = {
            { id = 1, name = "P1", position = 1, seat_id = nil, eliminated = false },
          },
        },
      }
    end },
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {
          phase = "start",
          move_anim = nil,
          move_followup_pending = false,
          vehicle_resync_seq = 0,
          tile_count = 1,
          tiles = { { id = 1 } },
          players = {
            { id = 1, name = "P1", position = 1, seat_id = nil, eliminated = false },
          },
        },
      }
    end },
  }, function()
    ui_model_sync.refresh_from_dirty(game, state, { any = true, turn = true }, {
      log_once = function() end,
      build_log_prefix = function() return "[test]" end,
    })
  end)

  _assert_eq(calls[1], "ai_command_stop_move", "refresh_from_dirty should reach ai stop fallback")
  _assert_eq(calls[2], "stop_anim", "refresh_from_dirty should stop anim after ai stop")
  _assert_eq(calls[3], "set_position", "refresh_from_dirty should still place the player")
  _assert_eq(state._last_target_pos.x, 10, "refresh_from_dirty should preserve tile x during board render")
  _assert_eq(state._last_target_pos.y, 0.5, "refresh_from_dirty should clamp player y during board render")
  _assert_eq(state._last_target_pos.z, 20, "refresh_from_dirty should preserve tile z during board render")
end

local function _test_popup_defer_policy_queues_and_replays_in_order()
  local modal_presenter = require("src.presentation.view.widgets.modal_presenter")
  local popup_presenter = require("src.presentation.view.canvas.popup.presenter")
  local canvas = require("src.presentation.input.canvas_coordinator")
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
  local canvas = require("src.presentation.input.canvas_coordinator")
  local role_ctx = require("src.presentation.model.role_context")
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
  local canvas = require("src.presentation.input.canvas_coordinator")
  local role_ctx = require("src.presentation.model.role_context")
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
  local ui_event_state = require("src.presentation.input.event_state")
  local ui_view_service = require("src.presentation.runtime.view")
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

local function _test_panel_avatar_uses_native_size_path()
  local presenter = require("src.presentation.view.widgets.panel_presenter")
  local native_size_calls = 0
  local client_role = { stale = true }
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY_AVATAR" }),
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
    set_client_role = function(role)
      client_role = role
    end,
    resolve_role_id = function() return nil end,
    for_each_role_or_global = function(fn)
      fn(nil)
    end,
    set_node_texture_native_size = function()
      native_size_calls = native_size_calls + 1
    end,
  }

  presenter.refresh(state, ui_model, {
    runtime = runtime,
    refresh_item_slots = function() end,
  })

  _assert_eq(native_size_calls, 4, "panel avatar should use native-size path")
  _assert_eq(client_role, nil, "panel presenter should restore client_role to nil")
end

local function _new_cash_delta_presenter_env(opts)
  opts = opts or {}
  local presenter = require("src.presentation.view.widgets.panel_presenter")
  local number_utils = require("src.core.utils.number_utils")
  local state = {
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY_AVATAR" }),
    ui = {
      item_slots = {},
      base_hidden_nodes = {},
      base_hidden_labels = {},
      auto_control_nodes = { "始终显示_托管按钮", "始终显示_文本" },
      item_slot_item_ids_by_role = {},
      labels = {},
      visible = {},
      set_label = function(self, name, text)
        if opts.missing_delta_node and string.match(name, "^基础%-玩家%d消耗金币显示$") then
          error("missing node")
        end
        self.labels[name] = text
      end,
      set_visible = function(self, name, value)
        if opts.missing_delta_node and string.match(name, "^基础%-玩家%d消耗金币显示$") then
          error("missing node")
        end
        self.visible[name] = value
      end,
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
        { name = "P1", avatar = nil, eliminated = false, cash_value = 0, total_assets_value = 0, cash = "现金: 0", land_count = "", total_assets = "总资产: 0" },
        { name = "P2", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P3", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
        { name = "P4", avatar = nil, eliminated = false, cash_value = nil, total_assets_value = nil, cash = "", land_count = "", total_assets = "" },
      },
    },
  }
  local runtime = {
    set_client_role = function() end,
    resolve_role_id = function() return nil end,
    for_each_role_or_global = function(fn)
      fn(nil)
    end,
    query_node = function()
      return {}
    end,
    set_node_texture_native_size = function() end,
  }
  local function set_cash(index, value)
    local row = ui_model.panel.player_rows[index]
    row.cash_value = value
    if value == nil then
      row.cash = ""
    else
      row.cash = "现金: " .. number_utils.format_integer_part(value)
    end
  end
  local function set_total_assets(index, value)
    local row = ui_model.panel.player_rows[index]
    row.total_assets_value = value
    if value == nil then
      row.total_assets = ""
    else
      row.total_assets = "总资产: " .. number_utils.format_integer_part(value)
    end
  end
  local function set_eliminated(index, value)
    local row = ui_model.panel.player_rows[index]
    row.eliminated = value == true
  end
  local function refresh()
    presenter.refresh(state, ui_model, {
      runtime = runtime,
      refresh_item_slots = function() end,
    })
  end
  return {
    state = state,
    ui_model = ui_model,
    refresh = refresh,
    set_cash = set_cash,
    set_total_assets = set_total_assets,
    set_eliminated = set_eliminated,
  }
end

local function _test_panel_cash_delta_shows_negative_and_auto_hides()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local gameplay_rules = require("src.core.config.gameplay_rules")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 100)
    env.refresh()
    env.set_cash(1, 80)
    env.refresh()
  end)

  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "-20", "cash delta should render negative text")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "cash delta label should be visible")
  _assert_eq(#scheduled, 1, "cash delta should schedule hide once")
  _assert_eq(scheduled[1].delay, gameplay_rules.panel_cash_delta_visible_seconds,
    "cash delta hide duration should follow dedicated gameplay rule")
  scheduled[1].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "cash delta label should clear after timeout")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "cash delta label should hide after timeout")
end

local function _test_panel_cash_delta_shows_positive_and_auto_hides()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 80)
    env.refresh()
    env.set_cash(1, 120)
    env.refresh()
  end)

  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40", "cash delta should render positive text")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "cash delta label should be visible")
  _assert_eq(#scheduled, 1, "cash delta should schedule hide once")
  scheduled[1].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "cash delta label should clear after timeout")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "cash delta label should hide after timeout")
end

local function _test_panel_cash_delta_keeps_latest_when_changes_are_continuous()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 100)
    env.refresh()
    env.set_cash(1, 80)
    env.refresh()
    env.set_cash(1, 120)
    env.refresh()
  end)

  _assert_eq(#scheduled, 2, "continuous changes should schedule two hides")
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40", "latest cash delta text should win")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "latest cash delta should stay visible")
  scheduled[1].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "+40", "old timer should not clear latest delta")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], true, "old timer should not hide latest delta")
  scheduled[2].cb()
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "latest timer should clear latest delta")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "latest timer should hide latest delta")
end

local function _test_panel_cash_delta_hides_when_value_unchanged()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env()
  local scheduled = {}

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, cb)
      scheduled[#scheduled + 1] = { delay = delay, cb = cb }
    end },
  }, function()
    env.set_cash(1, 100)
    env.refresh()
    env.set_cash(1, 100)
    env.refresh()
  end)

  _assert_eq(#scheduled, 0, "unchanged cash should not schedule hide")
  _assert_eq(env.state.ui.labels["基础-玩家1消耗金币显示"], "", "unchanged cash should keep delta label empty")
  _assert_eq(env.state.ui.visible["基础-玩家1消耗金币显示"], false, "unchanged cash should keep delta label hidden")
end

local function _test_panel_cash_delta_missing_node_is_safe()
  local runtime_ports = require("src.core.ports.runtime_ports")
  local env = _new_cash_delta_presenter_env({ missing_delta_node = true })
  local scheduled = {}
  local ok, err = pcall(function()
    _with_patches({
      { target = runtime_ports, key = "schedule", value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, cb = cb }
      end },
    }, function()
      env.set_cash(1, 100)
      env.refresh()
      env.set_cash(1, 80)
      env.refresh()
    end)
  end)

  assert(ok, "missing cash delta node should not crash: " .. tostring(err))
  _assert_eq(#scheduled, 0, "missing cash delta node should skip hide scheduling")
  _assert_eq(env.state.ui.labels["基础_玩家1现金"], "现金: 80", "base cash label should still update")
end

local function _test_panel_crown_shows_for_top_total_assets_and_ties()
  local env = _new_cash_delta_presenter_env()
  env.set_total_assets(1, 100)
  env.set_total_assets(2, 120)
  env.set_total_assets(3, 120)
  env.set_total_assets(4, 80)

  env.refresh()

  _assert_eq(env.state.ui.visible["基础_玩家1皇冠"], false, "player1 crown should hide when not top")
  _assert_eq(env.state.ui.visible["基础_玩家2皇冠"], true, "player2 crown should show when tied top")
  _assert_eq(env.state.ui.visible["基础_玩家3皇冠"], true, "player3 crown should show when tied top")
  _assert_eq(env.state.ui.visible["基础_玩家4皇冠"], false, "player4 crown should hide when not top")
end

local function _test_panel_crown_excludes_eliminated_players()
  local env = _new_cash_delta_presenter_env()
  env.set_total_assets(1, 80)
  env.set_total_assets(2, 200)
  env.set_total_assets(3, 100)
  env.set_total_assets(4, 60)
  env.set_eliminated(2, true)

  env.refresh()

  _assert_eq(env.state.ui.visible["基础_玩家1皇冠"], false, "player1 crown should hide when not top among active players")
  _assert_eq(env.state.ui.visible["基础_玩家2皇冠"], false, "eliminated player crown should hide")
  _assert_eq(env.state.ui.visible["基础_玩家3皇冠"], true, "active top player crown should show")
  _assert_eq(env.state.ui.visible["基础_玩家4皇冠"], false, "player4 crown should hide")
end

suite = {
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
  _test_ui_model_structure,
  _test_ui_panel_clamps_negative_assets_to_zero,
  _test_ui_model_player_slot_map_and_choice_owner,
  _test_ui_model_player_profile_prefers_role_api_with_fallback,
  _test_ui_model_player_profile_accepts_stringified_avatar,
  _test_ui_model_player_profile_uses_slot_avatar_for_synthetic_ai,
  _test_turn_dispatch_rejects_non_current_actor,
  _test_turn_dispatch_rejects_choice_non_owner,
  _test_turn_dispatch_auto_rejects_unmapped_role,
  _test_turn_dispatch_item_slot_uses_actor_slot_map,
  _test_ui_intent_dispatcher_market_confirm_routes_choice_select,
  _test_ui_intent_dispatcher_market_confirm_skin_opens_pre_confirm_then_dispatches,
  _test_ui_intent_dispatcher_market_confirm_skin_cancel_restores_market,
  _test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch,
  _test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly,
  _test_ui_intent_dispatcher_market_select_updates_ui_only,
  _test_ui_intent_dispatcher_popup_confirm_closes_popup,
  _test_ui_intent_dispatcher_toggle_action_log_uses_actor_role_context,
  _test_ui_intent_dispatcher_toggle_action_log_ignores_block_without_game,
  _test_ui_intent_dispatcher_toggle_action_log_resolves_role_via_game_api,
  _test_ui_intent_dispatcher_toggle_action_log_warns_when_role_event_channel_missing,
  _test_ui_intent_dispatcher_auto_button_keeps_intent_actor_role_id,
  _test_ui_intent_dispatcher_auto_button_falls_back_to_intent_actor_when_local_missing,
  _test_ui_intent_dispatcher_auto_button_rejects_when_actor_missing,
  _test_ui_intent_dispatcher_auto_button_honors_intent_actor_during_other_turn,
  _test_ui_view_render_by_role_slots_are_isolated,
  _test_ui_events_send_without_roles_no_crash,
  _test_ui_nodes_validate_reports_missing,
  _test_apply_input_lock_keeps_auto_controls_enabled,
  _test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped,
  _test_apply_input_lock_disables_always_show_controls_when_market_active,
}

suite_more = {
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
  _test_target_screen_uses_labels_only_and_hides_projection_with_slots,
  _test_target_screen_hides_unused_slots_when_unique_options_less_than_seven,
  _test_secondary_confirm_copy_item_phase_selected_option,
  _test_secondary_confirm_copy_land_actions,
  _test_secondary_confirm_copy_generic_pre_confirm,
  _test_secondary_confirm_prefers_usecase_confirm_copy,
  _test_choice_route_policy_prefers_explicit_route_metadata,
  _test_ui_event_router_player_target_click_direct_submit,
  _test_ui_event_router_action_log_toggle_uses_role_context,
  _test_ui_event_router_rejects_action_log_without_role,
  _test_market_selection_updates_icon_without_resize,
  _test_market_close_resets_icon_without_resize,
  _test_market_view_hides_market_disabled_entries,
  _test_market_view_invalid_selected_option_falls_back_to_current_visible_option,
  _test_item_slot_uses_keep_size_path,
  _test_item_slot_refresh_shows_only_playable_outlines,
  _test_item_slot_intents_include_outline_nodes,
  _test_item_phase_ask_confirm_clears_highlight_suppress,
  _test_item_phase_confirmed_skips_replay_before_slot_click,
  _test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines,
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
}

suite_tail = {
  _test_tick_ui_sync_turn_switch_still_follows,
  _test_tick_ui_sync_turn_switch_skip_follow_when_trigger_unavailable,
  _test_ui_sync_defers_choice_modal_during_wait_action_anim,
  _test_ui_sync_opens_choice_modal_after_wait_action_anim,
  _test_ui_sync_defers_choice_modal_during_wait_move_anim,
  _test_ui_sync_refresh_from_dirty_renders_board_with_fix32_ai_stop,
  _test_popup_defer_policy_queues_and_replays_in_order,
  _test_panel_avatar_uses_native_size_path,
  _test_panel_cash_delta_shows_negative_and_auto_hides,
  _test_panel_cash_delta_shows_positive_and_auto_hides,
  _test_panel_cash_delta_keeps_latest_when_changes_are_continuous,
  _test_panel_cash_delta_hides_when_value_unchanged,
  _test_panel_cash_delta_missing_node_is_safe,
  _test_panel_crown_shows_for_top_total_assets_and_ties,
  _test_panel_crown_excludes_eliminated_players,
  _test_item_slot_refresh_resets_highlight_without_client_role,
  _test_target_confirm_dispatches_selected_option,
  _test_target_pick_tick_updates_selection_on_hit_change,
  _test_target_pick_tick_ignores_non_candidate,
  _test_target_pick_scene_click_locks_target_and_pauses_raycast,
  _test_target_pick_confirm_requires_lock,
  _test_target_pick_cancel_unlocks_and_resumes_raycast,
  _test_target_pick_cancel_noop_when_unlocked,
  _test_target_pick_leave_hides_scene_units,
  _test_target_pick_enter_spawns_candidate_markers_at_height_1_6,
  _test_target_pick_degrades_without_raycast_api,
  _test_target_pick_prefers_explicit_owner_role_id,
  _test_ui_event_router_injects_actor_for_next_with_current_player_fallback,
  _test_ui_event_router_injects_actor_for_market_confirm_and_cancel,
  _test_ui_event_router_rejects_next_without_actor_context,
  _test_turn_effects_sync_restores_client_role_nil,
  _test_popup_renderer_switch_popup_canvas_restores_client_role_nil,
  _test_market_modal_renderer_open_restores_client_role_nil,
  _test_debug_ports_sync_restores_client_role_nil,
  _test_status3d_hospital_visible_when_no_action_notice_even_if_stay_turns_zero,
  _test_status3d_mountain_visible_when_no_action_notice_even_if_stay_turns_zero,
  _test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero,
  _test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing,
  _test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player,
  _test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys,
  _test_market_view_unbuyable_option_is_clickable,
  _test_market_view_hides_disabled_market_tab,
  _test_market_view_page_arrows_visibility_follows_page_count,
  _test_ui_model_market_payload_prefers_explicit_choice_fields,
  _test_modal_presenter_market_same_choice_id_still_refreshes_market_panel,
  _test_ui_event_router_market_cancel_button_dispatches_choice_cancel,
  _test_market_view_default_selection_shows_matching_selection_frame,
  _test_market_select_switches_selection_frame,
  _test_market_view_empty_filtered_tab_hides_selection_frames,
  _test_market_view_refresh_retargets_selection_frame_on_page_change,
}

for _, test_case in ipairs(suite_more) do
  suite[#suite + 1] = test_case
end

for _, test_case in ipairs(suite_tail) do
  suite[#suite + 1] = test_case
end

return suite
