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
local turn_flow = support.turn_flow
local turn_move = support.turn_move
local turn_dispatch = require("src.game.turn.TurnDispatch")
local runtime_port = require("src.ui.UIRuntimePort")
local market_view = require("src.ui.MarketView")
local market_layout = require("src.ui.MarketLayout")
local ui_event_router = require("src.ui.UIEventRouter")
local ui_view = require("src.ui.UIView")
local action_anim = require("src.ui.ActionAnim")
local move_anim = require("src.ui.MoveAnim")
local market_cfg = require("Config.Generated.Market")
local runtime_constants = require("Config.RuntimeConstants")

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
    ui_refs = refs or { ["空"] = "EMPTY" },
  }
  state.ui.choice_active = false
  state.ui.market_active = false
  local nodes = {
    ["卡牌展示屏"] = new_node(),
    ["卡牌展示_标题"] = new_node(),
    ["取消按钮"] = new_node(),
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
    ui_refs = { ["空"] = "EMPTY" },
  }
  local names = {
    "玩家选择屏", "玩家选择_标题", "玩家选择_副标题",
    "玩家选择_槽位1", "玩家选择_槽位2", "玩家选择_槽位3",
    "位置选择屏", "位置_副标题", "位置_放置文本",
    "位置前1", "位置前2", "位置前3", "位置后1", "位置后2", "位置后3", "位置脚下",
    "遥控骰子屏", "遥控骰子_标题", "遥控骰子_正文",
    "遥控骰子_选项_01", "遥控骰子_选项_02", "遥控骰子_选项_03",
    "遥控骰子_选项_04", "遥控骰子_选项_05", "遥控骰子_选项_06", "遥控骰子_取消",
    "建筑升级屏", "建筑升级_标题", "建筑升级_文本", "建筑升级_确定按钮", "建筑升级_取消",
    "卡牌展示屏", "卡牌展示_标题", "卡牌展示_图片", "取消按钮",
    "黑市屏", "黑市购买按钮", "关闭", "售价：100", "选中卡牌",
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
  g.turn_flow = turn_flow:new(g, phases)

  local res = g.turn_flow:run_until_wait()
  assert(res == "wait_move_anim", "should wait for move anim")
  local seq = g.turn.move_anim and g.turn.move_anim.seq
  assert(seq, "move_anim seq should be set")

  g:dispatch_action({ type = "move_anim_done", seq = seq })

  assert(g.turn.move_anim == nil, "move_anim should be cleared")
  local phase = g.turn.phase
  assert(phase ~= "wait_move_anim", "should resume after move anim done")
end

local function _test_move_anim_zero_distance_safe()
  local function _vec3(x, y, z)
    local vector_mt = {}
    vector_mt.__sub = function(a, b)
      return _vec3(a.x - b.x, a.y - b.y, a.z - b.z)
    end
    local vector = setmetatable({ x = x, y = y, z = z }, vector_mt)
    function vector:length()
      local sum = self.x * self.x + self.y * self.y + self.z * self.z
      return math.sqrt(sum)
    end
    return vector
  end

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
  local function _vec3(x, y, z)
    local vector_mt = {}
    vector_mt.__sub = function(a, b)
      return _vec3(a.x - b.x, a.y - b.y, a.z - b.z)
    end
    local vector = setmetatable({ x = x, y = y, z = z }, vector_mt)
    function vector:length()
      local sum = self.x * self.x + self.y * self.y + self.z * self.z
      return math.sqrt(sum)
    end
    return vector
  end

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
  local function _vec3(x, y, z)
    local vector_mt = {}
    vector_mt.__sub = function(a, b)
      return _vec3(a.x - b.x, a.y - b.y, a.z - b.z)
    end
    local vector = setmetatable({ x = x, y = y, z = z }, vector_mt)
    function vector:length()
      local sum = self.x * self.x + self.y * self.y + self.z * self.z
      return math.sqrt(sum)
    end
    return vector
  end

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
  local function _vec3(x, y, z)
    local vector_mt = {}
    vector_mt.__sub = function(a, b)
      return _vec3(a.x - b.x, a.y - b.y, a.z - b.z)
    end
    local vector = setmetatable({ x = x, y = y, z = z }, vector_mt)
    function vector:length()
      local sum = self.x * self.x + self.y * self.y + self.z * self.z
      return math.sqrt(sum)
    end
    return vector
  end

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
  local board_view = require("src.ui.BoardView")

  local function _vec3(x, y, z)
    local vector_mt = {}
    vector_mt.__add = function(a, b)
      return _vec3(a.x + b.x, a.y + b.y, a.z + b.z)
    end
    return setmetatable({ x = x, y = y, z = z }, vector_mt)
  end

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
    { target = math, key = "Vector3", value = _vec3 },
    { key = "vehicle_helper", value = {
      forward_eca_event_set_position = function(role_id, pos)
        set_pos_calls[#set_pos_calls + 1] = { role_id = role_id, pos = pos }
      end,
    } },
  }, function()
    board_view.refresh_board(state, model, function() end, function() return "[test]" end)
    _assert_eq(#set_pos_calls, 0, "same resync seq should not force vehicle set_position")

    model.board.vehicle_resync_seq = 2
    board_view.refresh_board(state, model, function() end, function() return "[test]" end)
  end)

  _assert_eq(unit_set_calls, 0, "vehicle player should not call unit.set_position")
  _assert_eq(#set_pos_calls, 1, "resync seq change should trigger set_position")
  _assert_eq(set_pos_calls[1].role_id, 1, "set_position role id should match player")
end

local function _test_ui_model_structure()
  local ui_model = require("src.ui.UIModel")
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

local function _test_ui_model_player_slot_map_and_choice_owner()
  local ui_model = require("src.ui.UIModel")
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
  local ui_model = require("src.ui.UIModel")
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
        return "HEAD_ICON_1"
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
  assert(row1 and row1.avatar == "HEAD_ICON_1", "player1 should use role avatar")
  assert(row2 and row2.name == "本地玩家2 (出局)", "player2 name should fallback to local name with eliminated suffix")
  assert(row2 and row2.avatar == nil, "player2 avatar should fallback to nil when role api failed")
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

local function _test_ui_view_render_by_role_slots_are_isolated()
  local main_view = require("src.ui.UIView")

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
    local node_name = "道具槽位" .. tostring(i)
    node_map[node_name] = new_texture_node(node_name)
  end
  for i = 1, 4 do
    local node_name = "玩家" .. tostring(i) .. "头像"
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
      ["空"] = "EMPTY",
      ["2001"] = "ICON2001",
      ["2002"] = "ICON2002",
    },
    ui = {
      item_slots = { "道具槽位1", "道具槽位2", "道具槽位3", "道具槽位4", "道具槽位5" },
      base_hidden_nodes = { "行动按钮", "道具槽位1", "道具槽位2", "道具槽位3", "道具槽位4", "道具槽位5" },
      base_hidden_labels = { "倒计时" },
      auto_control_nodes = { "托管按钮", "托管_文本" },
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
      turn_label = "回合: 1",
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
    { key = "UIManager", value = { client_role = nil, query_nodes_by_name = query_nodes_by_name } },
  }, function()
    main_view.refresh_panel(state, ui_model)
  end)

  assert(image_logs[1] and image_logs[1]["道具槽位1"] == "ICON2001", "role1 slot icon expected")
  assert(image_logs[2] and image_logs[2]["道具槽位1"] == "ICON2002", "role2 slot icon expected")
  assert(image_logs[0] and image_logs[0]["玩家1头像"] == "AVATAR_1", "player1 avatar should use row avatar")
  assert(image_logs[0] and image_logs[0]["玩家2头像"] == "EMPTY", "player2 avatar should fallback to empty key")
  assert(touch_logs[1] and touch_logs[1]["行动按钮"] == true, "current role action button should be enabled")
  assert(touch_logs[2] and touch_logs[2]["行动按钮"] == false, "non-current role action button should be disabled")
  assert(touch_logs[1] and touch_logs[1]["托管按钮"] == true, "role1 auto button should be enabled")
  assert(touch_logs[2] and touch_logs[2]["托管按钮"] == true, "role2 auto button should be enabled")
  assert(touch_logs[1] and touch_logs[1]["托管_文本"] == false, "role1 auto label should stay non-clickable")
  assert(touch_logs[2] and touch_logs[2]["托管_文本"] == false, "role2 auto label should stay non-clickable")
  assert(label_logs[1] and label_logs[1]["托管_文本"] == "自动：关", "role1 auto label should show status")
  assert(label_logs[2] and label_logs[2]["托管_文本"] == "自动：开", "role2 auto label should show status")
  assert(visible_logs[2] and visible_logs[2]["倒计时"] == false, "non-current role countdown should be hidden")
  assert(visible_logs[2] and visible_logs[2]["道具槽位1"] == false, "non-current role slot should be hidden")
  assert(visible_logs[2] and visible_logs[2]["托管按钮"] == true, "auto button should stay visible")
  assert(visible_logs[2] and visible_logs[2]["托管_文本"] == true, "auto label should stay visible")
  assert(state.ui.item_slot_item_ids_by_role[1] and state.ui.item_slot_item_ids_by_role[1][1] == 2001, "role1 slot map expected")
  assert(state.ui.item_slot_item_ids_by_role[2] and state.ui.item_slot_item_ids_by_role[2][1] == 2002, "role2 slot map expected")
end

local function _test_apply_input_lock_keeps_auto_controls_enabled()
  local touch = {}
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
      item_slots = { "道具槽位1" },
      base_hidden_nodes = { "行动按钮", "道具槽位1" },
      base_hidden_labels = { "倒计时" },
      auto_control_nodes = { "托管按钮", "托管_文本" },
      choice_screens = {
        player = { option_buttons = {}, cancel = "取消按钮" },
        target = { option_buttons = {}, under_button = "位置脚下", cancel = "取消按钮" },
        remote = { option_buttons = {}, cancel = "遥控骰子_取消" },
        building = { body = "建筑升级_文本", cancel = "建筑升级_取消", confirm = "建筑升级_确定按钮" },
      },
      popup_screen = { confirm = "取消按钮" },
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

  assert(touch["行动按钮"] == false, "action button should stay blocked")
  assert(touch["托管按钮"] == true, "auto button should stay enabled")
  assert(touch["托管_文本"] == false, "auto label should stay non-clickable")
end

local function _test_push_popup_sets_card_image_by_image_ref()
  local last_image_key = nil
  local card_node = {
    set_texture_keep_size = function(_, image_key)
      last_image_key = image_key
    end,
  }
  local state, nodes, query_nodes = _build_popup_view_state({
    ["空"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, card_node)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
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
    ["空"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, card_node)

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
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

local function _test_popup_timeout_closes_even_when_input_blocked()
  local state, nodes, query_nodes = _build_popup_view_state({
    ["空"] = "EMPTY",
    ["2001"] = "ICON2001",
  }, {
    set_texture_keep_size = function() end,
  })

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
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
      kind = "landing_optional_effect",
      title = "可选效果",
      body = "",
      options = {
        { id = "other_effect", label = "其他效果" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
    })
    _assert_eq(state.ui.active_choice_screen_key, "target", "non-building optional should fallback to target screen")
  end)
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
    { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action)
      table.insert(captured, action)
    end },
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
    node_map["位置后1"]._listener_cb({})
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_select", "player click should dispatch choice_select")
  _assert_eq(captured[1] and captured[1].choice_id, 10, "player click should keep choice id")
  _assert_eq(captured[1] and captured[1].option_id, 22, "player click should submit clicked option")
  _assert_eq(captured[2] and captured[2].type, "choice_select", "target click should dispatch choice_select")
  _assert_eq(captured[2] and captured[2].choice_id, 20, "target click should keep choice id")
  _assert_eq(captured[2] and captured[2].option_id, 201, "target click should submit clicked option")
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
      ["空"] = 1001,
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
      ["空"] = 4321,
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
      ["空"] = "EMPTY",
      ["2001"] = "ICON2001",
    },
    ui = {
      item_slots = { "道具槽位1" },
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

local function _test_tick_skips_anim_when_no_anim()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.ui.UIView")
  local ui_model = require("src.ui.UIModel")
  local board_view_mod = require("src.ui.BoardView")

  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh_board", value = function() end },
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
      return "wait_action_anim", { resume_state = "done", resume_args = {} }
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
  g.turn_flow = turn_flow:new(g, phases)

  local state = g.turn_flow:run_until_wait()
  _assert_eq(state, "wait_action_anim", "should wait action anim")
  _assert_eq(g.turn.action_anim.seq, 1, "current anim should be seq1")

  g.turn_flow:dispatch({ type = "action_anim_done", seq = 1 })
  _assert_eq(g.turn.phase, "wait_action_anim", "should still wait second anim")
  _assert_eq(g.turn.action_anim.seq, 2, "current anim should switch to seq2")

  g.turn_flow:dispatch({ type = "action_anim_done", seq = 2 })
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

local function _test_tick_ui_sync_turn_switch_still_follows()
  local dirty_tracker = require("src.core.DirtyTracker")
  local main_view = require("src.ui.UIView")
  local ui_model = require("src.ui.UIModel")
  local board_view_mod = require("src.ui.BoardView")
  local helper = { target_role_id = nil }
  local follow_events = 0
  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh_board", value = function() end },
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
    ui = { input_blocked = false },
  }

  _with_patches(patches, function()
    gameplay_loop.tick(game, state, 0.1)
  end)

  _assert_eq(helper.target_role_id, 2, "turn switch should follow current player")
  assert(follow_events >= 1, "turn switch should trigger follow event")
end

return {
  _test_move_anim_callback_and_delay,
  _test_popup_timeout_auto_confirm,
  _test_runtime_port_with_client_role_restores_nested_context,
  _test_choice_timeout_supports_explicit_timeout_strategy,
  _test_tick_timeout_default_policy_isolation,
  _test_invalid_choice_option_rejected,
  _test_move_anim_wait_and_resume,
  _test_move_anim_zero_distance_safe,
  _test_move_anim_vehicle_uses_set_position_jump,
  _test_move_anim_vehicle_enter_delay_once,
  _test_move_anim_vehicle_move_api_enabled_uses_move_event,
  _test_board_view_vehicle_resync_uses_set_position,
  _test_ui_model_structure,
  _test_ui_model_player_slot_map_and_choice_owner,
  _test_ui_model_player_profile_prefers_role_api_with_fallback,
  _test_turn_dispatch_rejects_non_current_actor,
  _test_turn_dispatch_auto_rejects_unmapped_role,
  _test_turn_dispatch_item_slot_uses_actor_slot_map,
  _test_ui_view_render_by_role_slots_are_isolated,
  _test_apply_input_lock_keeps_auto_controls_enabled,
  _test_push_popup_sets_card_image_by_image_ref,
  _test_push_popup_hides_card_and_clears_image_when_missing,
  _test_popup_timeout_closes_even_when_input_blocked,
  _test_choice_modal_routes_to_new_screens,
  _test_ui_event_router_player_target_click_direct_submit,
  _test_market_selection_updates_icon_without_resize,
  _test_market_close_resets_icon_without_resize,
  _test_item_slot_uses_keep_size_path,
  _test_tick_skips_anim_when_no_anim,
  _test_action_anim_queue_consumes_in_order,
  _test_action_anim_default_duration,
  _test_action_anim_no_camera_focus_side_effect,
  _test_tick_ui_sync_turn_switch_still_follows,
}
