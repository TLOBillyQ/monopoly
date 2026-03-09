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


return {
  name = "presentation_ui.timing_anim",
  tests = {
    { name = "_test_move_anim_callback_and_delay", run = _test_move_anim_callback_and_delay },
    { name = "_test_popup_timeout_auto_confirm", run = _test_popup_timeout_auto_confirm },
    { name = "_test_runtime_port_with_client_role_restores_nested_context", run = _test_runtime_port_with_client_role_restores_nested_context },
    { name = "_test_runtime_port_native_size_prefers_native_method", run = _test_runtime_port_native_size_prefers_native_method },
    { name = "_test_runtime_port_native_size_fallback_keep_size", run = _test_runtime_port_native_size_fallback_keep_size },
    { name = "_test_runtime_port_native_size_fallback_image_texture", run = _test_runtime_port_native_size_fallback_image_texture },
    { name = "_test_choice_timeout_supports_explicit_timeout_strategy", run = _test_choice_timeout_supports_explicit_timeout_strategy },
    { name = "_test_tick_timeout_default_policy_isolation", run = _test_tick_timeout_default_policy_isolation },
    { name = "_test_invalid_choice_option_rejected", run = _test_invalid_choice_option_rejected },
    { name = "_test_move_anim_wait_and_resume", run = _test_move_anim_wait_and_resume },
    { name = "_test_move_anim_zero_distance_safe", run = _test_move_anim_zero_distance_safe },
    { name = "_test_move_anim_step_unlocks_and_relocks", run = _test_move_anim_step_unlocks_and_relocks },
  },
}
