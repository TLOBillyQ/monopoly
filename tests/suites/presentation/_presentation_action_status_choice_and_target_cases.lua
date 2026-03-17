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
local modal_presenter = require("src.ui.ctl.modal_controller")
local ui_status_3d_layer = require("src.ui.render.status3d")
local action_anim = require("src.ui.render.action_anim")
local move_anim = require("src.ui.render.move_anim")
local runtime_cls = require("src.turn.loop.scheduler_runtime")
local turn_effects = require("src.ui.wid.turn_effects")
local popup_renderer = require("src.ui.ctl.popup_controller")
local market_modal_renderer = require("src.ui.ctl.market_controller")
local debug_ports_module = require("src.ui.ctl.ports.debug_ports")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local host_runtime = require("src.host.eggy")
local runtime_state = require("src.state.state_access.runtime_state")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
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
    state.gameplay_loop_ports = require("src.ui.ctl.ports").build(state)
    modal_presenter.push_popup(state, {
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
    modal_presenter.open_choice_modal(state, {
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

    modal_presenter.open_choice_modal(state, {
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

    modal_presenter.open_choice_modal(state, {
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

    modal_presenter.open_choice_modal(state, {
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

    modal_presenter.open_choice_modal(state, {
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

    modal_presenter.open_choice_modal(state, {
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

    modal_presenter.open_choice_modal(state, {
      id = 7,
      kind = "rent_card_prompt",
      route_key = "secondary_confirm",
      requires_confirm = true,
      confirm_title = "强征卡",
      confirm_body = "支付 2800 强制购入 福州路",
      title = "是否使用强征卡",
      body = "",
      options = {
        { id = "use", label = "使用" },
        { id = "skip", label = "不用" },
      },
      allow_cancel = true,
      cancel_label = "不用",
      meta = { card_kind = "strong", tile_id = 1 },
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "strong rent prompt should route to secondary confirm")
    _assert_eq(nodes["通用二次确认屏"].visible, true, "strong rent prompt should open secondary confirm screen")
    _assert_eq(nodes["通用二次确认_标题"].text, "强征卡", "strong rent prompt should use short confirm title")
    _assert_eq(nodes["通用二次确认_文本"].text, "支付 2800 强制购入 福州路", "strong rent prompt should use explicit confirm body")
    _assert_eq(nodes["通用二次确认_取消"].visible, true, "strong rent prompt should show do-not-use action")
    _assert_eq(nodes["通用二次确认_取消"].disabled, false, "strong rent cancel should stay touchable")

    modal_presenter.open_choice_modal(state, {
      id = 8,
      kind = "rent_card_prompt",
      route_key = "secondary_confirm",
      requires_confirm = true,
      title = "是否使用免费卡",
      body = "",
      confirm_title = "免费卡",
      confirm_body = "这次要用免费卡吗？",
      options = {
        { id = "use", label = "使用" },
        { id = "skip", label = "不用" },
      },
      allow_cancel = true,
      cancel_label = "不用",
      meta = { card_kind = "free", tile_id = 1 },
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "free rent prompt should route to secondary confirm")
    _assert_eq(nodes["通用二次确认屏"].visible, true, "free rent prompt should open secondary confirm")
    _assert_eq(nodes["通用二次确认_标题"].text, "免费卡", "free rent prompt should use explicit confirm title")
    _assert_eq(nodes["通用二次确认_文本"].text, "这次要用免费卡吗？", "free rent prompt should use explicit confirm body")
    _assert_eq(nodes["通用二次确认_取消"].visible, true, "free rent prompt should expose cancel as skip")

    modal_presenter.open_choice_modal(state, {
      id = 9,
      kind = "steal_prompt",
      route_key = "secondary_confirm",
      requires_confirm = true,
      title = "是否使用偷窃卡",
      body = "",
      confirm_title = "偷窃卡",
      confirm_body = "目标：玩家A",
      options = {
        { id = "use", label = "使用" },
        { id = "skip", label = "跳过" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
      meta = { player_id = 1, target_id = 11, queue = { 11 }, index = 1 },
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "steal prompt should route to secondary confirm")
    _assert_eq(nodes["通用二次确认_标题"].text, "偷窃卡", "steal prompt should use explicit confirm title")
    _assert_eq(nodes["通用二次确认_文本"].text, "目标：玩家A", "steal prompt should use explicit confirm body")

    modal_presenter.open_choice_modal(state, {
      id = 10,
      kind = "steal_item",
      route_key = "player",
      title = "选择要偷的道具",
      body = "",
      options = {
        { id = 2001, label = "免税卡" },
        { id = 2010, label = "免费卡" },
      },
      allow_cancel = true,
      cancel_label = "取消",
      meta = { player_id = 1, target_id = 2 },
    })
    _assert_eq(state.ui.active_choice_screen_key, "player", "steal item should route to player screen")
    _assert_eq(nodes["玩家选择屏"].visible, true, "steal item should open player screen")

    modal_presenter.open_choice_modal(state, {
      id = 11,
      kind = "landing_optional_effect",
      route_key = "secondary_confirm",
      requires_confirm = true,
      title = "可选效果",
      body = "",
      options = {
        { id = "other_effect", label = "其他效果" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "single optional effect should route to secondary confirm")
    _assert_eq(nodes["通用二次确认屏"].visible, true, "single optional effect should open secondary confirm")

    modal_presenter.open_choice_modal(state, {
      id = 12,
      kind = "landing_optional_effect",
      route_key = "player",
      requires_confirm = false,
      title = "可选效果",
      body = "",
      options = {
        { id = "other_effect_a", label = "其他效果A" },
        { id = "other_effect_b", label = "其他效果B" },
      },
      allow_cancel = true,
      cancel_label = "跳过",
    })
    _assert_eq(state.ui.active_choice_screen_key, "player", "multi optional effect should route to player screen")
    _assert_eq(nodes["玩家选择屏"].visible, true, "multi optional effect should open player screen")

    modal_presenter.open_choice_modal(state, {
      id = 13,
      kind = "market_purchase_confirm",
      route_key = "secondary_confirm",
      requires_confirm = true,
      title = "请确认购买",
      body = "",
      confirm_title = "黑市购买",
      confirm_body = "商品：筋斗云\n价格：1200 金币",
      options = {
        { id = "use", label = "购买" },
        { id = "skip", label = "取消" },
      },
      allow_cancel = true,
      cancel_label = "取消",
      meta = { player_id = 1, product_id = 9001 },
    })
    _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "market purchase confirm should route to secondary confirm")
    _assert_eq(nodes["通用二次确认_标题"].text, "黑市购买", "market purchase confirm should use explicit confirm title")
    _assert_eq(nodes["通用二次确认_文本"].text, "商品：筋斗云\n价格：1200 金币",
      "market purchase confirm should use descriptive confirm body")
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
    modal_presenter.open_choice_modal(state, choice)
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

    local common = require("src.ui.ctl.choice_screens.helpers")
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
    modal_presenter.open_choice_modal(state, choice)
    _assert_eq(state.ui.active_choice_screen_key, "target", "target screen should open for unique-option roadblock choice")
    _assert_eq(nodes["位置-槽位6按钮"].visible, true, "slot6 button should stay visible for the sixth unique option")
    _assert_eq(nodes["位置-槽位6文本"].text, "郑州路", "slot6 label should match the last unique option")
    _assert_eq(nodes["位置-槽位7按钮"].visible, false, "slot7 button should hide when only six unique options exist")
    _assert_eq(nodes["位置-槽位7文本"].visible, false, "slot7 label should hide when only six unique options exist")
  end)
end

local function _test_target_screen_close_clears_confirm_and_cancel_residue()
  local state, nodes, query_nodes = _build_choice_modal_state()
  local choice = {
    id = 90,
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
    },
    allow_cancel = true,
    cancel_label = "取消",
  }

  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    modal_presenter.open_choice_modal(state, choice)
    _assert_eq(nodes["位置_确认按钮"].text, "确定", "target confirm should be populated while screen open")
    _assert_eq(nodes["位置_取消按钮"].text, "取消", "target cancel should be populated while screen open")

    modal_presenter.close_choice_modal(state)

    _assert_eq(nodes["位置选择屏"].visible, false, "target screen should hide after close")
    _assert_eq(nodes["位置_确认按钮"].visible, false, "target confirm should hide after close")
    _assert_eq(nodes["位置_取消按钮"].visible, false, "target cancel should hide after close")
    _assert_eq(nodes["位置_确认按钮"].text, "", "target confirm text should clear after close")
    _assert_eq(nodes["位置_取消按钮"].text, "", "target cancel text should clear after close")
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

local function _test_target_pick_scene_click_resolves_option_from_payload_unit()
  local env = _build_target_pick_env()
  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    local handled = target_choice_effects.on_scene_pick(env.state, nil, 1, {
      unit = { _unit_id = env.tile_unit_ids[102] },
    })
    _assert_eq(handled, true, "scene pick should accept payload.unit fallback")
    _assert_eq(env.state.target_choice_runtime.locked_option_id, 102, "payload.unit should resolve tile option id")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, 102, "payload.unit fallback should sync selected option")
  end)
end

local function _test_target_pick_owner_role_falls_back_to_current_player()
  local env = _build_target_pick_env()
  env.choice.owner_role_id = nil
  env.choice.target_picker_owner_role_id = nil
  env.game.current_player = function()
    return { id = "7" }
  end

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    _assert_eq(env.state.target_choice_runtime.owner_role_id, 7, "missing explicit owner should fall back to current player id")
    local rejected = target_choice_effects.on_scene_pick(env.state, 101, 6, {})
    local handled = target_choice_effects.on_scene_pick(env.state, 101, "7", {})
    _assert_eq(rejected, false, "mismatched actor should still be rejected under current-player fallback")
    _assert_eq(handled, true, "current-player fallback owner should accept matching actor role id")
  end)
end

local function _test_target_pick_owner_role_falls_back_to_choice_owner_role_id()
  local env = _build_target_pick_env()
  env.choice.target_picker_owner_role_id = nil
  env.choice.owner_role_id = "8"
  env.game.current_player = function()
    return { id = 3 }
  end

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    _assert_eq(env.state.target_choice_runtime.owner_role_id, 8,
      "missing target_picker_owner_role_id should fall back to choice owner_role_id")
    local rejected = target_choice_effects.on_scene_pick(env.state, 101, 7, {})
    local handled = target_choice_effects.on_scene_pick(env.state, 101, "8", {})
    _assert_eq(rejected, false, "choice owner fallback should reject mismatched actor role id")
    _assert_eq(handled, true, "choice owner fallback should accept normalized matching actor role id")
  end)
end

local function _test_target_pick_scene_click_normalizes_string_option_id()
  local env = _build_target_pick_env()

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    local handled = target_choice_effects.on_scene_pick(env.state, "102", 1, {})
    _assert_eq(handled, true, "scene pick should normalize string option ids")
    _assert_eq(env.state.target_choice_runtime.locked_option_id, 102,
      "normalized string option id should lock matching candidate")
    _assert_eq(_ui_runtime(env.state).pending_choice_selected_option_id, 102,
      "normalized string option id should sync selected option")
  end)
end

local function _test_target_pick_scene_click_rejects_payload_unit_without_mapping()
  local env = _build_target_pick_env()

  _with_target_pick_runtime(env, function()
    target_choice_effects.enter(env.state, env.choice)
    local handled = target_choice_effects.on_scene_pick(env.state, nil, 1, {
      unit = { _unit_id = 999999 },
    })
    _assert_eq(handled, false, "payload.unit without tile mapping should be ignored")
    _assert_eq(env.state.target_choice_runtime.locked_option_id, nil,
      "payload.unit without mapping should not lock any option")
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
    local before = require("src.ui.ctl.event_state").resolve_debug_enabled(state, role_id)
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
  local common = require("src.ui.ctl.choice_screens.helpers")
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
  local common = require("src.ui.ctl.choice_screens.helpers")
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
  local common = require("src.ui.ctl.choice_screens.helpers")
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
  local common = require("src.ui.ctl.choice_screens.helpers")
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
  local always_show_nodes = require("src.ui.schema.always_show_nodes")

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
  { name = "_test_popup_timeout_closes_even_when_input_blocked", run = _test_popup_timeout_closes_even_when_input_blocked },
  { name = "_test_choice_modal_routes_to_new_screens", run = _test_choice_modal_routes_to_new_screens },
  { name = "_test_target_screen_uses_labels_only_and_hides_projection_with_slots", run = _test_target_screen_uses_labels_only_and_hides_projection_with_slots },
  { name = "_test_target_screen_hides_unused_slots_when_unique_options_less_than_seven", run = _test_target_screen_hides_unused_slots_when_unique_options_less_than_seven },
  { name = "_test_target_screen_close_clears_confirm_and_cancel_residue", run = _test_target_screen_close_clears_confirm_and_cancel_residue },
  { name = "_test_target_confirm_dispatches_selected_option", run = _test_target_confirm_dispatches_selected_option },
  { name = "_test_target_pick_tick_updates_selection_on_hit_change", run = _test_target_pick_tick_updates_selection_on_hit_change },
  { name = "_test_target_pick_tick_ignores_non_candidate", run = _test_target_pick_tick_ignores_non_candidate },
  { name = "_test_target_pick_scene_click_locks_target_and_pauses_raycast", run = _test_target_pick_scene_click_locks_target_and_pauses_raycast },
  { name = "_test_target_pick_confirm_requires_lock", run = _test_target_pick_confirm_requires_lock },
  { name = "_test_target_pick_cancel_unlocks_and_resumes_raycast", run = _test_target_pick_cancel_unlocks_and_resumes_raycast },
  { name = "_test_target_pick_cancel_noop_when_unlocked", run = _test_target_pick_cancel_noop_when_unlocked },
  { name = "_test_target_pick_leave_hides_scene_units", run = _test_target_pick_leave_hides_scene_units },
  { name = "_test_target_pick_enter_spawns_candidate_markers_at_height_1_6", run = _test_target_pick_enter_spawns_candidate_markers_at_height_1_6 },
  { name = "_test_target_pick_degrades_without_raycast_api", run = _test_target_pick_degrades_without_raycast_api },
  { name = "_test_target_pick_scene_click_resolves_option_from_payload_unit", run = _test_target_pick_scene_click_resolves_option_from_payload_unit },
  { name = "_test_target_pick_owner_role_falls_back_to_current_player", run = _test_target_pick_owner_role_falls_back_to_current_player },
  { name = "_test_target_pick_owner_role_falls_back_to_choice_owner_role_id", run = _test_target_pick_owner_role_falls_back_to_choice_owner_role_id },
  { name = "_test_target_pick_scene_click_normalizes_string_option_id", run = _test_target_pick_scene_click_normalizes_string_option_id },
  { name = "_test_target_pick_scene_click_rejects_payload_unit_without_mapping", run = _test_target_pick_scene_click_rejects_payload_unit_without_mapping },
  { name = "_test_choice_route_policy_prefers_explicit_route_metadata", run = _test_choice_route_policy_prefers_explicit_route_metadata },
  { name = "_test_ui_event_router_player_target_click_direct_submit", run = _test_ui_event_router_player_target_click_direct_submit },
  { name = "_test_ui_event_router_action_log_toggle_uses_role_context", run = _test_ui_event_router_action_log_toggle_uses_role_context },
  { name = "_test_ui_event_router_rejects_action_log_without_role", run = _test_ui_event_router_rejects_action_log_without_role },
  { name = "_test_secondary_confirm_copy_item_phase_selected_option", run = _test_secondary_confirm_copy_item_phase_selected_option },
  { name = "_test_secondary_confirm_copy_land_actions", run = _test_secondary_confirm_copy_land_actions },
  { name = "_test_secondary_confirm_copy_generic_pre_confirm", run = _test_secondary_confirm_copy_generic_pre_confirm },
  { name = "_test_secondary_confirm_prefers_usecase_confirm_copy", run = _test_secondary_confirm_prefers_usecase_confirm_copy },
  { name = "_test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing", run = _test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing },
  { name = "_test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player", run = _test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player },
  { name = "_test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys", run = _test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys },
}
