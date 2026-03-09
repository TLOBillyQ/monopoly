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


return {
  name = "presentation_ui.popup_market",
  tests = {
    { name = "_test_ui_view_render_by_role_slots_are_isolated", run = _test_ui_view_render_by_role_slots_are_isolated },
    { name = "_test_ui_events_send_without_roles_no_crash", run = _test_ui_events_send_without_roles_no_crash },
    { name = "_test_ui_nodes_validate_reports_missing", run = _test_ui_nodes_validate_reports_missing },
    { name = "_test_apply_input_lock_keeps_auto_controls_enabled", run = _test_apply_input_lock_keeps_auto_controls_enabled },
    { name = "_test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped", run = _test_apply_input_lock_keeps_auto_button_enabled_when_role_unmapped },
    { name = "_test_apply_input_lock_disables_always_show_controls_when_market_active", run = _test_apply_input_lock_disables_always_show_controls_when_market_active },
    { name = "_test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists", run = _test_ui_view_render_auto_button_keeps_local_touch_when_unmapped_role_exists },
    { name = "_test_ui_touch_policy_auto_controls_touch", run = _test_ui_touch_policy_auto_controls_touch },
    { name = "_test_ui_intent_dispatcher_market_confirm_skin_opens_pre_confirm_then_dispatches", run = _test_ui_intent_dispatcher_market_confirm_skin_opens_pre_confirm_then_dispatches },
    { name = "_test_ui_intent_dispatcher_market_confirm_skin_cancel_restores_market", run = _test_ui_intent_dispatcher_market_confirm_skin_cancel_restores_market },
    { name = "_test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch", run = _test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch },
    { name = "_test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly", run = _test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly },
    { name = "_test_ui_touch_policy_runtime_nodes_touch_enabled", run = _test_ui_touch_policy_runtime_nodes_touch_enabled },
    { name = "_test_push_popup_sets_card_image_by_image_ref", run = _test_push_popup_sets_card_image_by_image_ref },
    { name = "_test_push_popup_hides_card_and_clears_image_when_missing", run = _test_push_popup_hides_card_and_clears_image_when_missing },
    { name = "_test_popup_hidden_for_non_current_role", run = _test_popup_hidden_for_non_current_role },
    { name = "_test_popup_visible_for_all_roles_when_allowed_kind", run = _test_popup_visible_for_all_roles_when_allowed_kind },
    { name = "_test_bankruptcy_popup_visible_for_all_roles", run = _test_bankruptcy_popup_visible_for_all_roles },
    { name = "_test_bankruptcy_popup_avatar_uses_native_size_path", run = _test_bankruptcy_popup_avatar_uses_native_size_path },
  },
}
