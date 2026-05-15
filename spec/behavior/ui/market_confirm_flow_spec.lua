-- luacheck: ignore 211
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local choice_openers = require("src.ui.coord.choice_openers")
local pre_confirm_flow = require("src.ui.input.dispatch.pre_confirm")
local market_modal_renderer = require("src.ui.coord.market")

describe("presentation.market_confirm_flow", function()
  it("_test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly", function()
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
          owner_role_id = 7,
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
      game = {},
      local_actor_role_id = 7,
    }
    _bind_ui_runtime(state)

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "market_confirm",
        choice_id = 12,
        option_id = 5001,
      }, {})
    end)

    _assert_eq(#dispatched, 1, "skin market_confirm should dispatch directly without pre_confirm")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select", "skin market_confirm should dispatch choice_select")
    _assert_eq(dispatched[1] and dispatched[1].option_id, 5001, "skin market_confirm should keep selected option id")
    _assert_eq(state._pre_confirm_active, nil, "skin market_confirm should not activate pre_confirm")
  end)

  it("_test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch", function()
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
  end)

  it("_test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly", function()
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
  end)

  it("_test_ui_intent_dispatcher_item_slot_dispatches_directly", function()
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
          id = 21,
          kind = "item_phase_choice",
          route_key = "base_inline",
          owner_role_id = 7,
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
          options = {
            { id = 2001, label = "路障卡" },
            { id = 2002, label = "导弹卡" },
          },
        },
      },
      ui = {
        input_blocked = false,
        active_choice_screen_key = "base_inline",
        item_slot_item_ids = { 2002, 2001 },
        item_slot_item_ids_by_role = {},
      },
      game = {},
      local_actor_role_id = 7,
    }
    _bind_ui_runtime(state)

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "ui_button",
        id = "item_slot_1",
        actor_role_id = 7,
      }, {})
    end)

    _assert_eq(#dispatched, 1, "item slot should dispatch directly without pre_confirm")
    _assert_eq(dispatched[1] and dispatched[1].type, "ui_button", "item slot should dispatch original ui_button")
    _assert_eq(state._pre_confirm_active, nil, "item slot should not activate pre_confirm")
  end)

  it("_test_ui_intent_dispatcher_remote_choice_skips_pre_confirm_when_disabled", function()
    local opened_pre_confirm = 0
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
          id = 31,
          kind = "remote_dice_value",
          route_key = "remote",
          pre_confirm_on_select = false,
          options = {
            { id = 4, label = "4" },
          },
        },
      },
      ui = {
        input_blocked = false,
        active_choice_screen_key = "remote",
        item_slot_item_ids = {},
        item_slot_item_ids_by_role = {},
      },
      game = {},
      local_actor_role_id = 7,
    }
    _bind_ui_runtime(state)
    state.ui_model.choice.owner_role_id = 7

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = choice_openers, key = "open_pre_confirm_screen", value = function()
        opened_pre_confirm = opened_pre_confirm + 1
      end },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "choice_select",
        choice_id = 31,
        option_id = 4,
        actor_role_id = 7,
      }, {})
    end)

    _assert_eq(opened_pre_confirm, 0, "remote choice with disabled pre-confirm should not open secondary confirm")
    _assert_eq(#dispatched, 1, "remote choice with disabled pre-confirm should dispatch immediately")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select",
      "remote choice with disabled pre-confirm should dispatch choice_select")
    _assert_eq(dispatched[1] and dispatched[1].option_id, 4,
      "remote choice with disabled pre-confirm should keep selected option id")
  end)

  it("_test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly_for_non_owner", function()
    local opened_pre_confirm = 0
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
          owner_role_id = 7,
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
      game = {},
      local_actor_role_id = 8,
    }
    _bind_ui_runtime(state)

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = choice_openers, key = "open_pre_confirm_screen", value = function()
        opened_pre_confirm = opened_pre_confirm + 1
      end },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "market_confirm",
        choice_id = 12,
        option_id = 5001,
      }, {})
    end)

    _assert_eq(#dispatched, 1, "non-owner market_confirm should dispatch directly")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select", "non-owner market_confirm should dispatch choice_select")
    _assert_eq(opened_pre_confirm, 0, "non-owner market_confirm should not open pre-confirm")
  end)

  it("secondary_confirm flow opens its own confirm screen and dispatches choice_select on confirm", function()
    local opened_pre_confirm = 0
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
          id = 42,
          kind = "tax_card_prompt",
          route_key = "secondary_confirm",
          requires_confirm = true,
          owner_role_id = 7,
          options = {
            { id = "use", label = "使用" },
            { id = "skip", label = "跳过" },
          },
        },
      },
      ui = {
        input_blocked = false,
        item_slot_item_ids = {},
        item_slot_item_ids_by_role = {},
        active_choice_screen_key = nil,
        set_label = function() end,
        set_button = function() end,
        choice_screens = {
          secondary_confirm = {
            root = "通用二次确认屏",
            title = "通用二次确认_标题",
            body = "通用二次确认_文本",
            confirm = "通用二次确认_确定按钮",
            cancel = "通用二次确认_取消",
          },
        },
      },
      game = {},
      local_actor_role_id = 7,
    }
    _bind_ui_runtime(state)

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = pre_confirm_flow, key = "enter", value = function()
        opened_pre_confirm = opened_pre_confirm + 1
      end },
    }, function()
      choice_openers.open_secondary_confirm_screen(state, state.ui_model.choice, state.ui_model.choice.id)
      _assert_eq(state.ui.active_choice_screen_key, "secondary_confirm", "secondary_confirm should open its own confirm screen")

      ui_intent_dispatcher.dispatch(state, {}, {
        type = "choice_select",
        choice_id = 42,
        option_id = "use",
        actor_role_id = 7,
      }, {})
    end)

    _assert_eq(opened_pre_confirm, 0, "secondary_confirm should not enter pre_confirm_flow")
    _assert_eq(#dispatched, 1, "secondary_confirm confirm should dispatch once")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select", "secondary_confirm confirm should dispatch choice_select")
    _assert_eq(dispatched[1] and dispatched[1].option_id, "use", "secondary_confirm confirm should keep selected option id")
  end)

  it("market select still requires confirm after item flatten", function()
    local dispatched = {}
    local selected_option = nil
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
          id = 88,
          kind = "market_buy",
          route_key = "market",
          owner_role_id = 7,
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

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = market_modal_renderer, key = "select_market_option", value = function(_, option_id)
        selected_option = option_id
      end },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "market_select",
        option_id = 5001,
      }, {})

      _assert_eq(selected_option, 5001, "market select should update selected option first")
      _assert_eq(#dispatched, 0, "market select should not confirm immediately after item flatten")

      ui_intent_dispatcher.dispatch(state, {}, {
        type = "market_confirm",
        choice_id = 88,
        option_id = 5001,
      }, {})
    end)

    _assert_eq(#dispatched, 1, "market confirm should dispatch once after selection")
    _assert_eq(dispatched[1] and dispatched[1].type, "choice_select", "market confirm should dispatch choice_select")
    _assert_eq(dispatched[1] and dispatched[1].option_id, 5001, "market confirm should keep selected option id")
  end)

  it("_test_ui_intent_dispatcher_item_slot_dispatches_directly_for_non_owner", function()
    local opened_pre_confirm = 0
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
          id = 21,
          kind = "item_phase_choice",
          route_key = "base_inline",
          owner_role_id = 7,
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
          options = {
            { id = 2001, label = "路障卡" },
            { id = 2002, label = "导弹卡" },
          },
        },
      },
      ui = {
        input_blocked = false,
        active_choice_screen_key = "base_inline",
        item_slot_item_ids = { 2002, 2001 },
        item_slot_item_ids_by_role = {},
      },
      game = {},
      local_actor_role_id = 8,
    }
    _bind_ui_runtime(state)

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
      { target = choice_openers, key = "open_pre_confirm_screen", value = function()
        opened_pre_confirm = opened_pre_confirm + 1
      end },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "ui_button",
        id = "item_slot_1",
        actor_role_id = 7,
      }, {})
    end)

    _assert_eq(opened_pre_confirm, 0, "non-owner item slot should not open pre-confirm")
    _assert_eq(state._pre_confirm_active, nil, "non-owner item slot should keep pre-confirm inactive")
    _assert_eq(#dispatched, 1, "non-owner item slot should continue with original action path")
    _assert_eq(dispatched[1] and dispatched[1].type, "ui_button", "non-owner item slot should dispatch original ui_button")
  end)
end)
