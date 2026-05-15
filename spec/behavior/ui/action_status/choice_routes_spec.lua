local P = require("spec.support.ui_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local _build_choice_modal_state = P.build_choice_modal_state
local _bind_ui_runtime = P.bind_ui_runtime
local modal_presenter = require("src.ui.coord.modal")
local ui_choice_route_policy = require("src.ui.input.choice_route")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local pre_confirm_flow = require("src.ui.input.dispatch.pre_confirm")
local choice_openers = require("src.ui.coord.choice_openers")

describe("presentation_choice_routes", function()
  it("_test_choice_modal_routes_to_new_screens", function()
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
        id = 10,
        kind = "item_target_player",
        route_key = "player",
        title = "偷窃卡：选择目标玩家",
        body = "",
        options = {
          { id = 2, label = "玩家A" },
        },
        allow_cancel = true,
        cancel_label = "取消",
        meta = { player_id = 1, item_id = 2007 },
      })
      _assert_eq(state.ui.active_choice_screen_key, "player", "steal target should route to player screen")
      _assert_eq(nodes["玩家选择屏"].visible, true, "steal target should open player screen")

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
  end)

  it("item_target_player applies seat aligned layout to player slots", function()
    local state, nodes, query_nodes = _build_choice_modal_state()
    local choice = {
      id = 101,
      kind = "item_target_player",
      route_key = "player",
      title = "选人",
      body = "body",
      options = {
        { id = 22, label = "玩家2" },
        { id = 33, label = "玩家3" },
      },
      target_slot_layout = { 2, 3 },
      allow_cancel = true,
      cancel_label = "取消",
    }

    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = query_nodes } },
      { key = "all_roles", value = nil },
    }, function()
      modal_presenter.open_choice_modal(state, choice)
    end)

    _assert_eq(nodes["玩家选择_槽位1"].visible, false, "slot 1 should stay hidden when player 1 is not selectable")
    _assert_eq(nodes["玩家选择_槽位2"].visible, true, "slot 2 should show player 2")
    _assert_eq(nodes["玩家选择_槽位2"].text, "玩家2", "slot 2 should render player 2")
    _assert_eq(nodes["玩家选择_槽位3"].visible, true, "slot 3 should show player 3")
    _assert_eq(nodes["玩家选择_槽位3"].text, "玩家3", "slot 3 should render player 3")
    _assert_eq(nodes["玩家选择_槽位4"].visible, false, "slot 4 should stay hidden when player 4 is not selectable")

    local ui_runtime = P.ui_runtime(state)
    _assert_eq(ui_runtime.choice_visible_option_ids[1], nil, "slot 1 should not dispatch a player option")
    _assert_eq(ui_runtime.choice_visible_option_ids[2], 22, "slot 2 should dispatch player 2")
    _assert_eq(ui_runtime.choice_visible_option_ids[3], 33, "slot 3 should dispatch player 3")
    _assert_eq(ui_runtime.choice_visible_option_ids[4], nil, "slot 4 should not dispatch a player option")
  end)

  it("_test_choice_route_policy_prefers_explicit_route_metadata", function()
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
  end)

  it("_test_secondary_confirm_copy_item_phase_selected_option", function()
    local common = require("src.ui.coord.choice_helpers")
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
  end)

  it("_test_secondary_confirm_copy_land_actions", function()
    local common = require("src.ui.coord.choice_helpers")
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
  end)

  it("_test_secondary_confirm_copy_generic_pre_confirm", function()
    local common = require("src.ui.coord.choice_helpers")
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
  end)

  it("_test_secondary_confirm_prefers_usecase_confirm_copy", function()
    local common = require("src.ui.coord.choice_helpers")
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
  end)

  it("_test_passive_kind_no_modal", function()
    local state, _, query_nodes = _build_choice_modal_state()
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
    end)
  end)

  it("_test_pre_confirm_skipped_for_passive_kind", function()
    local choice_support = require("src.ui.view.choice_support")
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
  end)

  local function _build_active_item_phase_dispatch_env(phase)
    local enter_calls = 0
    local opened_pre_confirm = 0
    local dispatched = {}
    local choice = {
      id = 555,
      kind = "item_phase_choice",
      route_key = "base_inline",
      owner_role_id = 7,
      uses_item_slots = true,
      pre_confirm_before_slot_pick = false,
      options = {
        { id = 2001, label = "路障卡" },
        { id = 2002, label = "遥控骰子卡" },
      },
      allow_cancel = true,
      cancel_label = "完成",
      meta = { player_id = 7, phase = phase },
    }
    local state = {
      turn_action_port = {
        dispatch_action = function(_, _, action)
          dispatched[#dispatched + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui_model = { choice = choice, current_player_id = 7 },
      ui = {
        input_blocked = false,
        active_choice_screen_key = nil,
        item_slot_item_ids = { 2001, 2002 },
        item_slot_item_ids_by_role = {},
      },
      game = {},
      local_actor_role_id = 7,
    }
    _bind_ui_runtime(state)
    return state, choice, dispatched, function() return enter_calls end, function() return opened_pre_confirm end,
      function() enter_calls = enter_calls + 1; return true end,
      function() opened_pre_confirm = opened_pre_confirm + 1 end
  end

  local function _run_active_item_phase_flat_dispatch(phase)
    local state, choice, dispatched, enter_count, opened_count, enter_spy, opener_spy =
      _build_active_item_phase_dispatch_env(phase)
    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = pre_confirm_flow, key = "enter", value = enter_spy },
      { target = choice_openers, key = "open_pre_confirm_screen", value = opener_spy },
    }, function()
      ui_intent_dispatcher.dispatch(state, state.game, {
        type = "choice_select",
        choice_id = choice.id,
        option_id = 2001,
        actor_role_id = 7,
      }, {})
    end)
    _assert_eq(#dispatched, 1, phase .. ": dispatch_action should receive exactly one intent")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
      phase .. ": dispatch_action should receive choice_select intent")
    _assert_eq(dispatched[1] and dispatched[1].option_id, 2001,
      phase .. ": dispatch_action should keep selected option id")
    _assert_eq(enter_count(), 0, phase .. ": pre_confirm_flow.enter must not be called")
    _assert_eq(opened_count(), 0, phase .. ": modal.open_pre_confirm_screen must not be called")
    _assert_eq(state._pre_confirm_active, nil, phase .. ": _pre_confirm_active must stay unset")
  end

  it("active item_phase choice flat-dispatches in pre_action phase", function()
    _run_active_item_phase_flat_dispatch("pre_action")
  end)

  it("active item_phase choice flat-dispatches in pre_move phase", function()
    _run_active_item_phase_flat_dispatch("pre_move")
  end)

  it("active item_phase choice flat-dispatches in post_action phase", function()
    _run_active_item_phase_flat_dispatch("post_action")
  end)
end)
