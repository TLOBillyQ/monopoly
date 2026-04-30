-- luacheck: ignore 211
local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local choice_openers = require("src.ui.coord.choice_screens.openers")
local ui_view = require("src.ui.coord.ui_runtime")
local modal_presenter = require("src.ui.coord.modal")

local function _test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly()
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

local function _test_ui_intent_dispatcher_item_slot_dispatches_directly()
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
end

local function _test_ui_intent_dispatcher_remote_choice_skips_pre_confirm_when_disabled()
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
end

local function _test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly_for_non_owner()
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
end

local function _test_ui_intent_dispatcher_item_slot_dispatches_directly_for_non_owner()
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
end

return {
  name = "presentation.market_confirm_flow",
  tests = {
    { name = "_test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly", run = _test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly },
    { name = "_test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch", run = _test_ui_intent_dispatcher_market_confirm_non_skin_still_direct_dispatch },
    { name = "_test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly", run = _test_ui_intent_dispatcher_market_confirm_without_pre_confirm_flag_dispatches_directly },
    { name = "_test_ui_intent_dispatcher_item_slot_dispatches_directly", run = _test_ui_intent_dispatcher_item_slot_dispatches_directly },
    { name = "_test_ui_intent_dispatcher_remote_choice_skips_pre_confirm_when_disabled", run = _test_ui_intent_dispatcher_remote_choice_skips_pre_confirm_when_disabled },
    { name = "_test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly_for_non_owner", run = _test_ui_intent_dispatcher_market_confirm_skin_dispatches_directly_for_non_owner },
    { name = "_test_ui_intent_dispatcher_item_slot_dispatches_directly_for_non_owner", run = _test_ui_intent_dispatcher_item_slot_dispatches_directly_for_non_owner },
  },
}
