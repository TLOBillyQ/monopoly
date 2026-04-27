-- luacheck: ignore 211
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
local debug_ports_module = require("src.ui.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock")
local ui_touch_policy = require("src.ui.input.touch")
local ui_choice_route_policy = require("src.ui.input.choice_route")
local logger = require("src.core.utils.logger")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local target_pick = require("src.config.gameplay.target_pick")
local host_runtime = require("src.host")
local host_runtime_bridge = require("src.ui.host_bridge")
local runtime_state = require("src.ui.state")
local target_choice_effects = require("src.ui.ctl.target_choice_effects")
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

local function _test_passive_kind_no_modal()
  local state, _, query_nodes = _build_choice_modal_state()
  local choice_support = require("src.ui.pres.choice_support")
  _with_patches({
    { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
    { key = "all_roles", value = nil },
  }, function()
    modal_presenter.open_choice_modal(state, {
      id = 101,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      uses_item_slots = true,
      pre_confirm_before_slot_pick = false,
      title = "行动：被动道具",
      body = "",
      options = {
        { id = 2005, label = "移动加速" },
      },
      allow_cancel = true,
      cancel_label = "继续",
      meta = { phase = "action" },
    })
    _assert_eq(state.ui.choice_active, false, "passive kind must not open any modal")
    _assert_eq(state.ui.active_choice_screen_key, nil, "passive kind must not set active choice screen")
    _assert_eq(choice_support.is_passive_item_phase({ kind = "item_phase_passive" }), true, "is_passive_item_phase should return true for passive kind")
    _assert_eq(choice_support.is_passive_item_phase({ kind = "item_phase_choice" }), false, "is_passive_item_phase should return false for non-passive kind")
    _assert_eq(choice_support.is_passive_item_phase(nil), false, "is_passive_item_phase should return false for nil")
  end)
end

local function _test_pre_confirm_skipped_for_passive_kind()
  local choice_support = require("src.ui.pres.choice_support")
  local passive_choice = {
    id = 102,
    kind = "item_phase_passive",
    route_key = "item_phase_passive",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = false,
    options = { { id = 2005, label = "移动加速" } },
  }
  _assert_eq(choice_support.requires_item_slot_pre_confirm(passive_choice), false,
    "passive kind with pre_confirm_before_slot_pick=false must skip pre-confirm")
  local active_choice = {
    kind = "item_phase_choice",
    pre_confirm_before_slot_pick = true,
    options = { { id = 2001, label = "路障卡" } },
  }
  _assert_eq(choice_support.requires_item_slot_pre_confirm(active_choice), true,
    "active item phase with pre_confirm_before_slot_pick=true must require pre-confirm")
end

return {
  name = "presentation_choice_routes",
  tests = {
    { name = "_test_choice_modal_routes_to_new_screens", run = _test_choice_modal_routes_to_new_screens },
    { name = "_test_choice_route_policy_prefers_explicit_route_metadata", run = _test_choice_route_policy_prefers_explicit_route_metadata },
    { name = "_test_secondary_confirm_copy_item_phase_selected_option", run = _test_secondary_confirm_copy_item_phase_selected_option },
    { name = "_test_secondary_confirm_copy_land_actions", run = _test_secondary_confirm_copy_land_actions },
    { name = "_test_secondary_confirm_copy_generic_pre_confirm", run = _test_secondary_confirm_copy_generic_pre_confirm },
    { name = "_test_secondary_confirm_prefers_usecase_confirm_copy", run = _test_secondary_confirm_prefers_usecase_confirm_copy },
    { name = "_test_passive_kind_no_modal", run = _test_passive_kind_no_modal },
    { name = "_test_pre_confirm_skipped_for_passive_kind", run = _test_pre_confirm_skipped_for_passive_kind },
  },
}
