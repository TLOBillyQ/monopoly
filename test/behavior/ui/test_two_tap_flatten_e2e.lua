-- luacheck: ignore 211
-- Spec-driven end-to-end QA for the two-tap flatten effort.
-- Covers five scenarios:
--   A0. 第一次点击不被吞：ui_model 过期时道具槽点击仍一路走到 choice_select。
--       展示层不再读 choice（route 只报「谁点了第几个槽」），裁定独占 turn 层，
--       所以过期 ui_model 在链路上已无处吞点击——本条走真实链路钉住这一点。
--   A. Item phase single-tap dispatches choice_select directly (no pre_confirm).
--   B. target_choice second tap on the locked option emits choice_select via build_intent.
--   C. target_choice with a single option auto-dispatches choice_select on first tap
--      without going through _lock_option (locked_option_id stays nil).
--   D. Market still requires the two-step (market_select then market_confirm).
--
-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):describe/it 拍平为文件级 Test*
-- 类,用例数与改写前一一对应(5 例)。it 名含冒号/空格,方法用字符串 key 注册。
local lu = require("luaunit")
local pending_confirmation = require("src.state.pending_confirmation")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _bind_ui_runtime = support.bind_ui_runtime
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local pre_confirm_flow = require("src.ui.input.pre_confirm")
local choice_openers = require("src.ui.coord.choice_openers")
local item_slot_intents = require("src.ui.input.route_item_slots")
local target_choice_screen = require("src.ui.screens.target_choice")
local market_intents = require("src.ui.screens.market")
local market_modal_renderer = require("src.ui.screens.market")
local runtime_state = require("src.ui.state.runtime")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local item_phase = require("src.rules.items.phase")
local item_ids = require("src.config.gameplay.item_ids")

-- 真实 pre_action 道具窗：真游戏 + 真背包 + 真 item_phase.run，
-- 不手搓 choice，免得钉的是测试自己捏的形状。
local function _open_real_pre_action_item_window()
  local game = support.new_game({ players = { "P1", "P2" }, ai = {} })
  local player = game:current_player()
  player.inventory:add({ id = item_ids.remote_dice })
  local phase_res = item_phase.run({ game = game }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  assert(type(phase_res) == "table" and phase_res.waiting == true,
    "Scenario A0: pre_action passive should wait on the item choice")
  local choice = assert(game.turn.pending_choice, "Scenario A0: pre_action passive should open a pending choice")
  return game, player, choice
end

-- 生产装配（src/app/gameplay_start）的同款端口：state 挂真 turn 派发器。
local function _real_turn_action_port()
  return {
    dispatch_action = function(game, state, action, opts)
      return turn_dispatch.dispatch_action(game, state, action, opts)
    end,
    should_block_action = function(state, action_or_type)
      return turn_dispatch.should_block_action(state, action_or_type)
    end,
  }
end

TestTwoTapFlattenE2e = {}

TestTwoTapFlattenE2e["test_Scenario A0: stale ui_model still lets the first item slot tap reach choice_select"] = function(self)
  local game, player, choice = _open_real_pre_action_item_window()

  -- 规则落地不是本条的射程：在 game 的派发边界上截获，钉「点击真的走到了这里」。
  local dispatched = {}
  game.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
    return true
  end
  local tips = {}
  game.tip_output_port = { enqueue = function(_, intent) tips[#tips + 1] = intent return true end }

  local state = {
    ui = {
      input_blocked = false,
      item_slots = { "道具槽位_1" },
    },
    turn_action_port = _real_turn_action_port(),
  }
  _bind_ui_runtime(state)
  -- 过期的 ui_model：窗已开，但视图模型还没刷到（真机上就是这一帧的窗口期）。
  runtime_state.set_ui_model(state, { choice = nil, current_player_id = player.id })

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    local specs = item_slot_intents.build(state)
    -- 身份随事件数据携带(#341:匿名事件不再回落缓存;#601 缓存整体退役)。
    local intent = specs[1].build_intent({ role = { get_roleid = function() return player.id end } })

    _assert_eq(intent and intent.type, "item_slot_click",
      "Scenario A0: route should report the raw click fact regardless of ui_model freshness")
    _assert_eq(intent and intent.slot_index, 1,
      "Scenario A0: route should carry the tapped slot index")
    _assert_eq(intent and intent.actor_role_id, player.id,
      "Scenario A0: route should carry the clicking role")

    ui_intent_dispatcher.dispatch(state, game, intent, {})
  end)

  _assert_eq(#dispatched, 1, "Scenario A0: the first tap must reach the game exactly once")
  _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
    "Scenario A0: stale ui_model should not swallow the first item slot tap")
  _assert_eq(dispatched[1] and dispatched[1].choice_id, choice.id,
    "Scenario A0: adjudicated select should bind the live pending choice")
  _assert_eq(dispatched[1] and dispatched[1].option_id, item_ids.remote_dice,
    "Scenario A0: slot 1 should resolve to the only card in the bag")
  _assert_eq(#tips, 0, "Scenario A0: an admitted tap must not raise a denial tip")
end

TestTwoTapFlattenE2e["test_Scenario A: item phase single tap directly dispatches choice_select"] = function(self)
  local enter_calls = 0
  local opened_pre_confirm = 0
  local dispatched = {}
  local choice = {
    id = 555,
    kind = "item_phase_passive",
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
    meta = { player_id = 7, phase = "pre_action" },
  }
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      should_block_action = function() return false end,
    },
    ui_model = { choice = choice, current_player_id = 7 },
    ui = {
      input_blocked = false,
      active_choice_screen_key = nil,
    },
    game = {},
  }
  _bind_ui_runtime(state)

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
    { target = pre_confirm_flow, key = "enter", value = function()
      enter_calls = enter_calls + 1
      return true
    end },
    { target = choice_openers, key = "open_pre_confirm_screen", value = function()
      opened_pre_confirm = opened_pre_confirm + 1
    end },
  }, function()
    ui_intent_dispatcher.dispatch(state, state.game, {
      type = "choice_select",
      choice_id = choice.id,
      option_id = 2001,
      actor_role_id = 7,
    }, {})
  end)

  _assert_eq(#dispatched, 1, "Scenario A: dispatch_action should receive exactly one intent")
  _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
    "Scenario A: dispatch_action should receive choice_select intent")
  _assert_eq(dispatched[1] and dispatched[1].option_id, 2001,
    "Scenario A: dispatched intent should keep selected option id")
  _assert_eq(enter_calls, 0, "Scenario A: pre_confirm_flow.enter must not be called")
  _assert_eq(opened_pre_confirm, 0, "Scenario A: open_pre_confirm_screen must not be called")
  _assert_eq(pending_confirmation.is_active(state), false,
    "Scenario A: no pending confirmation may be active")
end

TestTwoTapFlattenE2e["test_Scenario B: target_choice second tap on locked option emits choice_select"] = function(self)
  local dispatched = {}
  local state = {
    ui = {},
    ui_model = {
      choice = {
        id = 7,
        options = {
          { id = "tile_5", label = "A" },
          { id = "tile_8", label = "B" },
        },
      },
    },
    target_choice_runtime = {
      locked_option_id = "tile_5",
    },
    turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      should_block_action = function() return false end,
    },
  }
  _bind_ui_runtime(state)
  state.ui_runtime.pending_choice_selected_option_id = "tile_5"

  local target_specs = target_choice_screen.build_route_specs(state)
  -- specs[3] is the first slot button (specs[1]=confirm, specs[2]=cancel, specs[3..]=slot buttons)
  local intent = target_specs[3].build_intent()

  _assert_eq(intent and intent.type, "choice_select",
    "Scenario B: build_intent on locked slot should emit choice_select")
  _assert_eq(intent and intent.option_id, "tile_5",
    "Scenario B: build_intent should resolve to locked option id")
  _assert_eq(intent and intent.choice_id, 7,
    "Scenario B: choice_select should carry choice id")

  -- Now actually dispatch and assert dispatch_action received choice_select.
  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
  }, function()
    ui_intent_dispatcher.dispatch(state, {}, intent, {})
  end)

  _assert_eq(#dispatched, 1, "Scenario B: dispatch_action should receive exactly one intent")
  _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
    "Scenario B: dispatch_action should receive choice_select")
  _assert_eq(dispatched[1] and dispatched[1].option_id, "tile_5",
    "Scenario B: dispatched intent should keep tile_5 option id")
end

TestTwoTapFlattenE2e["test_Scenario C: target_choice unique target auto-dispatches choice_select on first tap"] = function(self)
  local state = {
    ui = {},
    ui_model = {
      choice = {
        id = 11,
        options = {
          { id = "tile_only", label = "A" },
        },
      },
    },
    target_choice_runtime = nil,
  }
  _bind_ui_runtime(state)

  local target_specs = target_choice_screen.build_route_specs(state)
  local intent = target_specs[3].build_intent()

  _assert_eq(intent and intent.type, "choice_select",
    "Scenario C: single-option slot tap should short-circuit to choice_select")
  _assert_eq(intent and intent.option_id, "tile_only",
    "Scenario C: build_intent should resolve to the only option id")
  _assert_eq(intent and intent.choice_id, 11,
    "Scenario C: choice_select should carry choice id")
  -- Critical: unique-target path must NOT have routed through _lock_option.
  _assert_eq(state.target_choice_runtime, nil,
    "Scenario C: target_choice_runtime must remain nil (no _lock_option side-effect)")
end

TestTwoTapFlattenE2e["test_Scenario D: market still requires two-step (market_select then market_confirm)"] = function(self)
  local dispatched = {}
  local selected_option = nil
  local state = {
    turn_action_port = {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      should_block_action = function() return false end,
    },
    ui_model = {
      choice = {
        id = 88,
        kind = "market_buy",
        route_key = "market",
        owner_role_id = 7,
        options = {
          { id = 2001, label = "路障卡" },
        },
      },
      market = {
        choice_id = 88,
        options = {
          { id = 2001, label = "路障卡" },
        },
      },
    },
    ui = {
      input_blocked = false,
      active_choice_screen_key = "market",
      set_label = function() end,
      set_button = function() end,
      choice_screens = {
        market = {
          root = "market",
          title = "market_title",
          body = "market_body",
          confirm = "market_confirm",
          cancel = "market_cancel",
        },
      },
    },
    game = {},
  }
  _bind_ui_runtime(state)

  -- Step 1: build market item intent (simulating market_button[1] click).
  local market_item_specs = market_intents.build_items(state)
  local select_intent = market_item_specs[1].build_intent()
  _assert_eq(select_intent and select_intent.type, "market_select",
    "Scenario D: first market button click should build market_select intent")
  _assert_eq(select_intent and select_intent.option_id, 2001,
    "Scenario D: market_select should carry product option id")

  _with_patches({
    { key = "UIManager", value = { client_role = nil } },
    { target = market_modal_renderer, key = "select_market_option",
      value = function(_, option_id) selected_option = option_id end },
  }, function()
    ui_intent_dispatcher.dispatch(state, {}, select_intent, {})
    _assert_eq(selected_option, 2001,
      "Scenario D: market_select must update selected option in renderer")
    _assert_eq(#dispatched, 0,
      "Scenario D: market_select must NOT emit choice_select immediately")

    state.ui_runtime.pending_choice_selected_option_id = 2001

    local market_control_specs = market_intents.build_controls(state)
    local confirm_intent = market_control_specs[1].build_intent()
    _assert_eq(confirm_intent and confirm_intent.type, "market_confirm",
      "Scenario D: confirm button should build market_confirm intent")
    _assert_eq(confirm_intent and confirm_intent.option_id, 2001,
      "Scenario D: market_confirm should keep selected option id")

    ui_intent_dispatcher.dispatch(state, {}, confirm_intent, {})
  end)

  _assert_eq(#dispatched, 1,
    "Scenario D: market_confirm should dispatch exactly one intent")
  _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
    "Scenario D: market_confirm dispatcher path should emit choice_select")
  _assert_eq(dispatched[1] and dispatched[1].option_id, 2001,
    "Scenario D: market_confirm dispatched intent should keep option id")
end


return TestTwoTapFlattenE2e
