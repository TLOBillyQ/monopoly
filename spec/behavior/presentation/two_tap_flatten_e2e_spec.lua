-- luacheck: ignore 211
-- Spec-driven end-to-end QA for the two-tap flatten effort.
-- Covers four scenarios:
--   A. Item phase single-tap dispatches choice_select directly (no pre_confirm).
--   B. target_choice second tap on the locked option emits choice_select via build_intent.
--   C. target_choice with a single option auto-dispatches choice_select on first tap
--      without going through _lock_option (locked_option_id stays nil).
--   D. Market still requires the two-step (market_select then market_confirm).
local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _bind_ui_runtime = support.bind_ui_runtime
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local pre_confirm_flow = require("src.ui.input.dispatch.pre_confirm")
local choice_openers = require("src.ui.coord.choice_openers")
local item_slot_intents = require("src.ui.input.canvas_route.item_slots")
local target_choice_intents = require("src.ui.input.canvas_route.target_choice")
local market_intents = require("src.ui.input.canvas_route.market")
local market_modal_renderer = require("src.ui.coord.market")
local runtime_state = require("src.ui.state.runtime")

describe("two_tap_flatten_e2e", function()
  it("Scenario A0: item slot tap uses pending choice when ui_model is stale", function()
    local choice = {
      id = 554,
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      owner_role_id = 7,
      uses_item_slots = true,
      pre_confirm_before_slot_pick = false,
      slot_states = {
        [1] = { item_id = 2002, available = true },
      },
      options = {
        { id = 2002, label = "遥控骰子卡" },
      },
      allow_cancel = true,
      cancel_label = "完成",
      meta = { player_id = 7, phase = "pre_action" },
    }
    local state = {
      ui_model = { choice = nil, current_player_id = 7 },
      ui = {
        item_slots = { "道具槽位_1" },
        card_outlines = { "道具槽位_1_外框" },
        item_slot_item_ids = { 2002 },
        item_slot_item_ids_by_role = {},
      },
      game = {
        turn = {
          pending_choice = choice,
        },
      },
    }
    _bind_ui_runtime(state)
    runtime_state.set_pending_choice(state, choice)
    runtime_state.set_ui_model(state, { choice = nil, current_player_id = 7 })

    local specs = item_slot_intents.build(state)
    local intent = specs[1].build_intent()

    _assert_eq(intent and intent.type, "ui_button",
      "Scenario A0: stale ui_model should not swallow the first item slot tap")
    _assert_eq(intent and intent.id, "item_slot_1",
      "Scenario A0: first tap should still produce the item slot action")
  end)

  it("Scenario A: item phase single tap directly dispatches choice_select", function()
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
        item_slot_item_ids = { 2001, 2002 },
        item_slot_item_ids_by_role = {},
      },
      game = {},
      local_actor_role_id = 7,
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
    _assert_eq(state._item_phase_ask_active, nil,
      "Scenario A: _item_phase_ask_active must stay unset")
    _assert_eq(state._pre_confirm_active, nil,
      "Scenario A: _pre_confirm_active must stay unset")
  end)

  it("Scenario B: target_choice second tap on locked option emits choice_select", function()
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

    local target_specs = target_choice_intents.build(state)
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
  end)

  it("Scenario C: target_choice unique target auto-dispatches choice_select on first tap", function()
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

    local target_specs = target_choice_intents.build(state)
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
  end)

  it("Scenario D: market still requires two-step (market_select then market_confirm)", function()
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
            { id = 5001, label = "海绵宝宝皮肤" },
          },
        },
        market = {
          choice_id = 88,
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
      local_actor_role_id = 7,
    }
    _bind_ui_runtime(state)

    -- Step 1: build market item intent (simulating market_button[1] click).
    local market_item_specs = market_intents.build_items(state)
    local select_intent = market_item_specs[1].build_intent()
    _assert_eq(select_intent and select_intent.type, "market_select",
      "Scenario D: first market button click should build market_select intent")
    _assert_eq(select_intent and select_intent.option_id, 5001,
      "Scenario D: market_select should carry product option id")

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = market_modal_renderer, key = "select_market_option",
        value = function(_, option_id) selected_option = option_id end },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, select_intent, {})
      _assert_eq(selected_option, 5001,
        "Scenario D: market_select must update selected option in renderer")
      _assert_eq(#dispatched, 0,
        "Scenario D: market_select must NOT emit choice_select immediately")

      state.ui_runtime.pending_choice_selected_option_id = 5001

      local market_control_specs = market_intents.build_controls(state)
      local confirm_intent = market_control_specs[1].build_intent()
      _assert_eq(confirm_intent and confirm_intent.type, "market_confirm",
        "Scenario D: confirm button should build market_confirm intent")
      _assert_eq(confirm_intent and confirm_intent.option_id, 5001,
        "Scenario D: market_confirm should keep selected option id")

      ui_intent_dispatcher.dispatch(state, {}, confirm_intent, {})
    end)

    _assert_eq(#dispatched, 1,
      "Scenario D: market_confirm should dispatch exactly one intent")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
      "Scenario D: market_confirm dispatcher path should emit choice_select")
    _assert_eq(dispatched[1] and dispatched[1].option_id, 5001,
      "Scenario D: market_confirm dispatched intent should keep option id")
  end)
end)
