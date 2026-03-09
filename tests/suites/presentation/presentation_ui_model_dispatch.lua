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


return {
  name = "presentation_ui.model_dispatch",
  tests = {
    { name = "_test_ui_model_structure", run = _test_ui_model_structure },
    { name = "_test_ui_panel_clamps_negative_assets_to_zero", run = _test_ui_panel_clamps_negative_assets_to_zero },
    { name = "_test_ui_model_player_slot_map_and_choice_owner", run = _test_ui_model_player_slot_map_and_choice_owner },
    { name = "_test_ui_model_player_profile_prefers_role_api_with_fallback", run = _test_ui_model_player_profile_prefers_role_api_with_fallback },
    { name = "_test_ui_model_player_profile_accepts_stringified_avatar", run = _test_ui_model_player_profile_accepts_stringified_avatar },
    { name = "_test_ui_model_player_profile_uses_slot_avatar_for_synthetic_ai", run = _test_ui_model_player_profile_uses_slot_avatar_for_synthetic_ai },
    { name = "_test_turn_dispatch_rejects_non_current_actor", run = _test_turn_dispatch_rejects_non_current_actor },
    { name = "_test_turn_dispatch_rejects_choice_non_owner", run = _test_turn_dispatch_rejects_choice_non_owner },
    { name = "_test_turn_dispatch_auto_rejects_unmapped_role", run = _test_turn_dispatch_auto_rejects_unmapped_role },
    { name = "_test_turn_dispatch_item_slot_uses_actor_slot_map", run = _test_turn_dispatch_item_slot_uses_actor_slot_map },
    { name = "_test_ui_intent_dispatcher_market_confirm_routes_choice_select", run = _test_ui_intent_dispatcher_market_confirm_routes_choice_select },
  },
}
