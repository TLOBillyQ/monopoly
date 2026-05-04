local P = require("support.presentation_action_status_prelude")
local _assert_eq = P.assert_eq
local _bind_ui_runtime = P.bind_ui_runtime
local _with_patches = P.with_patches
local _wrap_ui_refs = P.wrap_ui_refs
local _has_event = P.has_event
local ui_view = require("src.ui.coord.ui_runtime")
local ui_intent_dispatcher = require("src.ui.input.intent_dispatcher")
local ids = require("fixtures.item_slot_ids")

describe("presentation_item_slots", function()
  it("_test_item_slot_uses_keep_size_path", function()
    local keep_size_calls = 0
    local last_image_key = nil
    local slot_node = {
      set_texture_keep_size = function(_, image_key)
        keep_size_calls = keep_size_calls + 1
        last_image_key = image_key
      end,
    }
    local state = {
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
      }),
      ui = {
        item_slots = ids.slots(1),
        set_touch_enabled = function() end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      item_slots = { 2001 },
      item_slots_by_player = {
        [1] = { 2001 },
      },
      choice = nil,
    }

    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return { slot_node } end } },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = false,
      })
    end)

    _assert_eq(keep_size_calls, 1, "item slot should use keep-size texture path")
    _assert_eq(last_image_key, "ICON2001", "item slot should set expected image key")
  end)

  it("_test_item_slot_refresh_shows_only_playable_outlines", function()
    local touch_state = {}
    local visible_state = {}
    local state = {
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
        ["2002"] = "ICON2002",
        ["2003"] = "ICON2003",
      }),
      ui = {
        item_slots = ids.slots(3),
        card_outlines = ids.outlines(3),
        set_touch_enabled = function(_, name, enabled)
          touch_state[name] = enabled == true
        end,
        set_visible = function(_, name, visible)
          visible_state[name] = visible == true
        end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001, 2002, 2003 },
      item_slots_by_player = { [1] = { 2001, 2002, 2003 } },
      choice = {
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = { { id = 2001 }, { id = 2003 } },
      },
    }

    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(visible_state[ids.outline[1]], true, "playable slot 1 outline should be visible")
    _assert_eq(visible_state[ids.outline[2]], false, "unplayable slot 2 outline should be hidden")
    _assert_eq(visible_state[ids.outline[3]], true, "playable slot 3 outline should be visible")
    _assert_eq(touch_state[ids.slot[1]], true, "playable slot 1 should be clickable")
    _assert_eq(touch_state[ids.slot[2]], false, "unplayable slot 2 should be locked")
    _assert_eq(touch_state[ids.slot[3]], true, "playable slot 3 should be clickable")
  end)

  it("_test_item_slot_intents_include_outline_nodes", function()
    local item_slot_intents = require("src.ui.input.canvas_route.item_slots")
    local state = {
      ui = {
        item_slots = ids.slots(1),
        card_outlines = ids.outlines(1),
      },
      ui_model = {
        choice = {
          kind = "item_phase_choice",
          route_key = "base_inline",
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
        },
      },
    }
    _bind_ui_runtime(state)

    local specs = item_slot_intents.build(state)
    _assert_eq(#specs, 2, "item slot intents should include slot and outline")
    _assert_eq(specs[1].name, ids.slot[1], "slot intent node expected")
    _assert_eq(specs[2].name, ids.outline[1], "outline intent node expected")
    local intent = specs[2].build_intent()
    _assert_eq(intent and intent.id, "item_slot_1", "outline click should map to slot action")
  end)

  it("_test_item_phase_ask_confirm_clears_highlight_suppress", function()
     local item_phase_ask_flow = require("src.ui.input.dispatch.item_phase_ask")
    local closed = 0
    local state = {
      _item_phase_ask_active = true,
      _item_phase_confirmed = nil,
      _suppress_item_slot_highlight_until_pick = true,
      gameplay_loop_ports = {
        modal = {
          close_choice_modal = function()
            closed = closed + 1
          end,
        },
      },
      ui_model = {
        choice = { id = 66, kind = "item_phase_choice", route_key = "base_inline", uses_item_slots = true, pre_confirm_before_slot_pick = true },
      },
      ui = ui_view.build_ui_state(),
    }
    _bind_ui_runtime(state)

    local handled = false
    _with_patches({}, function()
      handled = item_phase_ask_flow.dispatch(state, {}, { type = "choice_select" }, {}, {
        dispatch_action = function()
          error("choice_select on item_phase_ask should not dispatch action directly")
        end,
      })
    end)

    _assert_eq(handled, true, "item_phase_ask choice_select should be handled")
    _assert_eq(state._item_phase_ask_active, nil, "item_phase_ask_active should clear after confirm")
    _assert_eq(state._item_phase_confirmed, true, "item_phase_confirmed should become true after confirm")
    _assert_eq(state._suppress_item_slot_highlight_until_pick, nil,
      "highlight suppression should clear after item_phase ask confirm")
    _assert_eq(state._skip_item_slot_highlight_replay_choice_id, 66,
      "item_phase ask confirm should skip highlight replay before slot click")
    _assert_eq(closed, 1, "item_phase ask confirm should close modal once")
  end)

  it("_test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select", function()
     local item_phase_ask_flow = require("src.ui.input.dispatch.item_phase_ask")
    local dispatched = {}
    local closed = 0
    local state = {
      _item_phase_ask_active = true,
      _item_phase_confirmed = nil,
      _suppress_item_slot_highlight_until_pick = true,
      gameplay_loop_ports = {
        modal = {
          close_choice_modal = function()
            closed = closed + 1
          end,
        },
      },
      ui_model = {
        choice = {
          id = 88,
          kind = "item_phase_choice",
          route_key = "base_inline",
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
          options = {
            { id = 2002, label = "导弹卡" },
          },
        },
      },
      ui = ui_view.build_ui_state(),
    }
    _bind_ui_runtime(state)

    local handled = false
    _with_patches({}, function()
      handled = item_phase_ask_flow.dispatch(state, {}, {
        type = "choice_select",
        actor_role_id = 5,
      }, {
        source = "item_phase_ask",
      }, {
        dispatch_action = function(_, _, action, opts)
          dispatched[#dispatched + 1] = {
            action = action,
            opts = opts,
          }
        end,
      })
    end)

    _assert_eq(handled, true, "single-option item_phase_ask confirm should be handled")
    _assert_eq(state._item_phase_ask_active, nil, "single-option item_phase_ask should clear active flag")
    _assert_eq(state._item_phase_confirmed, true, "single-option item_phase_ask should mark confirmed")
    _assert_eq(closed, 1, "single-option item_phase_ask should close modal once")
    _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.type, "choice_select",
      "single-option item_phase_ask should dispatch choice_select directly")
    _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.choice_id, 88,
      "single-option item_phase_ask should keep choice id")
    _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.option_id, 2002,
      "single-option item_phase_ask should select the only option")
    _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.actor_role_id, 5,
      "single-option item_phase_ask should preserve actor role id")
  end)

  it("_test_item_phase_confirmed_skips_replay_before_slot_click", function()
    local ui_events = require("src.ui.coord.ui_events")
    local events = {}
    local state = {
      _item_phase_ask_active = nil,
      _item_phase_confirmed = true,
      _skip_item_slot_highlight_replay_choice_id = 77,
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2002"] = "ICON2002",
      }),
      ui = {
        item_slots = ids.slots(1),
        card_outlines = ids.outlines(1),
        set_touch_enabled = function() end,
        set_visible = function() end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = { [1] = { 2002 } },
      choice = {
        id = 77,
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = { { id = 2002 } },
      },
    }

    _with_patches({
      {
        key = "UIManager",
        value = {
          client_role = nil,
          query_nodes_by_name = function()
            return { { set_texture_keep_size = function() end } }
          end,
        },
      },
      {
        target = ui_events,
        key = "send_to_all",
        value = function(event_name)
          events[#events + 1] = event_name
        end,
      },
      {
        target = ui_events,
        key = "send_to_role",
        value = function(_, event_name)
          events[#events + 1] = event_name
        end,
      },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(_has_event(events, "高亮道具槽位牌1"), false,
      "confirmed item phase should not replay slot highlight before click")
    _assert_eq(_has_event(events, "重置高亮"), false,
      "confirmed item phase should not replay global highlight reset before click")
    _assert_eq(state._skip_item_slot_highlight_replay_choice_id, 77,
      "skip replay flag should remain until slot click")
  end)

  it("_test_slot_click_clears_skip_and_emits_reset_on_next_refresh", function()
    local ui_events = require("src.ui.coord.ui_events")
    local events = {}
    local dispatched = {}
    local state = {
      _item_phase_ask_active = nil,
      _item_phase_confirmed = true,
      _suppress_item_slot_highlight_until_pick = nil,
      _skip_item_slot_highlight_replay_choice_id = 77,
      _pre_confirm_active = nil,
      _pre_confirm_source_screen = nil,
      turn_action_port = {
        dispatch_action = function(_, _, action)
          dispatched[#dispatched + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2002"] = "ICON2002",
      }),
      ui = {
        item_slots = ids.slots(1),
        card_outlines = ids.outlines(1),
        item_slot_item_ids = { 2002 },
        item_slot_item_ids_by_role = {},
        active_choice_screen_key = "base_inline",
        set_touch_enabled = function() end,
        set_visible = function() end,
      },
      ui_model = {
        current_player_id = 1,
        item_choice_owner_id = 1,
        item_slots_by_player = { [1] = { 2002 } },
        choice = {
          id = 77,
          kind = "item_phase_choice",
          route_key = "base_inline",
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
          options = { { id = 2002 } },
        },
      },
    }
    _bind_ui_runtime(state)

    _with_patches({
      {
        key = "UIManager",
        value = {
          client_role = nil,
          query_nodes_by_name = function()
            return { { set_texture_keep_size = function() end } }
          end,
        },
      },
      {
        target = ui_events,
        key = "send_to_all",
        value = function(event_name)
          events[#events + 1] = event_name
        end,
      },
      {
        target = ui_events,
        key = "send_to_role",
        value = function(_, event_name)
          events[#events + 1] = event_name
        end,
      },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "ui_button",
        id = "item_slot_1",
        actor_role_id = 1,
      }, {})

      ui_view.refresh_item_slots(state, state.ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(state._skip_item_slot_highlight_replay_choice_id, nil,
      "slot click should clear skip flag so next refresh can emit reset")
    _assert_eq(_has_event(events, "重置高亮"), true,
      "next refresh after slot click should emit global reset to stop slot animation")
  end)

  it("flat single-tap leaves no residual item_phase_ask state", function()
    local dispatched = {}
    local state = {
      _item_phase_ask_active = nil,
      _item_phase_confirmed = nil,
      _suppress_item_slot_highlight_until_pick = nil,
      _skip_item_slot_highlight_replay_choice_id = nil,
      _pre_confirm_active = nil,
      _pre_confirm_source_screen = nil,
      turn_action_port = {
        dispatch_action = function(_, _, action)
          dispatched[#dispatched + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2002"] = "ICON2002",
      }),
      ui = {
        item_slots = ids.slots(1),
        card_outlines = ids.outlines(1),
        item_slot_item_ids = { 2002 },
        item_slot_item_ids_by_role = {},
        active_choice_screen_key = "base_inline",
        set_touch_enabled = function() end,
        set_visible = function() end,
      },
      ui_model = {
        current_player_id = 1,
        item_choice_owner_id = 1,
        item_slots_by_player = {
          [1] = { 2002 },
        },
        choice = {
          id = 66,
          kind = "item_phase_choice",
          route_key = "base_inline",
          uses_item_slots = true,
          pre_confirm_before_slot_pick = false,
          options = { { id = 2002 } },
        },
      },
    }
    _bind_ui_runtime(state)

    _with_patches({
      { key = "UIManager", value = { client_role = nil } },
    }, function()
      ui_intent_dispatcher.dispatch(state, {}, {
        type = "ui_button",
        id = "item_slot_1",
        actor_role_id = 1,
      }, {})
    end)

    _assert_eq(#dispatched, 1, "flat single-tap should dispatch the original ui_button once")
    _assert_eq(dispatched[1] and dispatched[1].type, "ui_button", "flat single-tap should keep the ui_button path")

    local fields = {
      "_item_phase_ask_active",
      "_item_phase_confirmed",
      "_suppress_item_slot_highlight_until_pick",
      "_skip_item_slot_highlight_replay_choice_id",
      "_pre_confirm_active",
      "_pre_confirm_source_screen",
    }
    for _, field in ipairs(fields) do
      _assert_eq(state[field], nil, field .. " should be nil after flat single-tap dispatch")
    end
  end)

  it("_test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines", function()
    local ui_events = require("src.ui.coord.ui_events")
    local events = {}
    local visible_state = {}
    local timers = {}

    local state = {
      _item_phase_ask_active = true,
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2002"] = "ICON2002",
        ["2003"] = "ICON2003",
      }),
      ui = {
        item_slots = ids.slots(3),
        card_outlines = ids.outlines(3),
        set_touch_enabled = function() end,
        set_visible = function(_, name, visible)
          visible_state[name] = visible == true
        end,
      },
    }

    local ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = {
        [1] = { 2002, nil, 2003 },
      },
      choice = {
        id = 99,
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = { { id = 2002 }, { id = 2003 } },
      },
    }

    local function _count_event(event_name)
      local count = 0
      for _, value in ipairs(events) do
        if value == event_name then
          count = count + 1
        end
      end
      return count
    end

    _with_patches({
      {
        key = "UIManager",
        value = {
          client_role = nil,
          query_nodes_by_name = function()
            return { { set_texture_keep_size = function() end } }
          end,
        },
      },
      {
        target = ui_events,
        key = "send_to_all",
        value = function(event_name)
          events[#events + 1] = event_name
        end,
      },
      {
        target = ui_events,
        key = "send_to_role",
        value = function(_, event_name)
          events[#events + 1] = event_name
        end,
      },
      {
        key = "SetTimeOut",
        value = function(_, cb)
          timers[#timers + 1] = cb
        end,
      },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })

      _assert_eq(_count_event("高亮道具槽位牌1"), 1, "item_phase_ask should emit highlight for slot1 once")
      _assert_eq(_count_event("高亮道具槽位牌3"), 1, "item_phase_ask should emit highlight for slot3 once")
      _assert_eq(_count_event("重置高亮"), 1, "item_phase_ask should emit global reset once")
      _assert_eq(visible_state[ids.outline[1]], false, "outline1 should stay hidden before delay")
      _assert_eq(visible_state[ids.outline[3]], false, "outline3 should stay hidden before delay")
      _assert_eq(#timers, 1, "item_phase_ask should schedule exactly one reveal timer")

      timers[1]()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })

      _assert_eq(_count_event("高亮道具槽位牌1"), 1, "highlight should not replay every refresh")
      _assert_eq(_count_event("高亮道具槽位牌3"), 1, "highlight should not replay every refresh")
      _assert_eq(visible_state[ids.outline[1]], true, "outline1 should show after delay")
      _assert_eq(visible_state[ids.outline[3]], true, "outline3 should show after delay")
      _assert_eq(visible_state[ids.outline[2]], false, "non-pickable outline should stay hidden")
    end)
  end)

  it("_test_item_slot_refresh_resets_highlight_without_client_role", function()
    local ui_events = require("src.ui.coord.ui_events")
    local events = {}
    local phase = ""

    local function _record(channel, event_name)
      events[#events + 1] = {
        phase = phase,
        channel = channel,
        event_name = event_name,
      }
    end

    local function _local_has_event(phase_name, event_name)
      for _, entry in ipairs(events) do
        if entry.phase == phase_name and entry.event_name == event_name then
          return true
        end
      end
      return false
    end

    local state = {
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2002"] = "ICON2002",
        ["2003"] = "ICON2003",
        ["2004"] = "ICON2004",
        ["2007"] = "ICON2007",
        ["2008"] = "ICON2008",
      }),
      ui = {
        item_slots = ids.slots(5),
        card_outlines = ids.outlines(5),
        set_touch_enabled = function() end,
        set_visible = function() end,
      },
    }

    local pre_action_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = {
        [1] = { 2002, 2004, 2007, 2008, 2003 },
      },
      choice = {
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = { { id = 2002 } },
      },
    }

    local remote_choice_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots_by_player = {
        [1] = { 2002, 2004, 2007, 2008, 2003 },
      },
      choice = {
        kind = "remote_dice_value",
        route_key = "remote",
        options = { { id = 1 }, { id = 2 } },
      },
    }

    _with_patches({
      {
        key = "UIManager",
        value = {
          client_role = nil,
          query_nodes_by_name = function()
            return { { set_texture_keep_size = function() end } }
          end,
        },
      },
      {
        target = ui_events,
        key = "send_to_all",
        value = function(event_name)
          _record("all", event_name)
        end,
      },
      {
        target = ui_events,
        key = "send_to_role",
        value = function(_, event_name)
          _record("role", event_name)
        end,
      },
    }, function()
      phase = "pre_action"
      ui_view.refresh_item_slots(state, pre_action_model, {
        display_player_id = 1,
        allow_interact = true,
      })

      state._suppress_item_slot_highlight_until_pick = true
      phase = "suppressed_item_phase"
      ui_view.refresh_item_slots(state, pre_action_model, {
        display_player_id = 1,
        allow_interact = true,
      })

      phase = "remote_choice"
      ui_view.refresh_item_slots(state, remote_choice_model, {
        display_player_id = 1,
        allow_interact = true,
      })

      state._suppress_item_slot_highlight_until_pick = nil
      phase = "pre_action_dice_multiplier"
      ui_view.refresh_item_slots(state, {
        current_player_id = 1,
        item_choice_owner_id = 1,
        item_slots_by_player = {
          [1] = { 2004, 2007, 2008, 2003, nil },
        },
        choice = {
          kind = "item_phase_choice",
          route_key = "base_inline",
          uses_item_slots = true,
          pre_confirm_before_slot_pick = true,
          options = { { id = 2003 } },
        },
      }, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(_local_has_event("pre_action", "高亮道具槽位牌1"), true, "pre_action should highlight remote dice slot")
    _assert_eq(_local_has_event("pre_action", "重置高亮"), true, "pre_action should issue global reset before highlighting")
    _assert_eq(_local_has_event("suppressed_item_phase", "重置高亮"), false,
      "item_phase should suppress highlight animation while waiting for a pick")
    _assert_eq(_local_has_event("suppressed_item_phase", "高亮道具槽位牌1"), false,
      "item_phase suppression should block per-slot highlight events")
    _assert_eq(_local_has_event("remote_choice", "重置高亮"), true, "remote choice should issue global reset before slot reorder")
    _assert_eq(_local_has_event("remote_choice", "重置高亮道具槽位牌1"), true, "remote choice should reset slot1 highlight without client role")
    _assert_eq(_local_has_event("pre_action_dice_multiplier", "重置高亮"), true,
      "pre_action should issue global reset before highlighting dice multiplier slot")
    _assert_eq(_local_has_event("pre_action_dice_multiplier", "高亮道具槽位牌4"), true,
      "pre_action should highlight dice multiplier slot")
    _assert_eq(_local_has_event("pre_action_dice_multiplier", "重置高亮道具槽位牌1"), true,
      "pre_action should clear stale slot1 highlight")
  end)

  it("_test_passive_slot_three_state_rendering", function()
    local touch_state = {}
    local state = {
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
        ["2002"] = "ICON2002",
        ["2003"] = "ICON2003",
        ["2004"] = "ICON2004",
        ["2005"] = "ICON2005",
      }),
      ui = {
        item_slots = ids.slots(5),
        card_outlines = ids.outlines(5),
        set_touch_enabled = function(_, name, enabled)
          touch_state[name] = enabled == true
        end,
        set_visible = function() end,
        set_label = function() end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001, 2002, 2003, 2004, 2005 },
      item_slots_by_player = { [1] = { 2001, 2002, 2003, 2004, 2005 } },
      choice = {
        kind = "item_phase_passive",
        route_key = "item_phase_passive",
        uses_item_slots = true,
        options = { { id = 2001 }, { id = 2003 } },
        slot_states = {
          [1] = { available = true,  alert = false },
          [2] = { available = false, alert = false },
          [3] = { available = true,  alert = false },
          [4] = { available = false, alert = false },
          [5] = { available = false, alert = false },
        },
      },
    }

    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(touch_state[ids.slot[1]], true,  "passive: available slot 1 should be touchable")
    _assert_eq(touch_state[ids.slot[2]], false, "passive: unavailable slot 2 should not be touchable")
    _assert_eq(touch_state[ids.slot[3]], true,  "passive: available slot 3 should be touchable")
    _assert_eq(touch_state[ids.slot[4]], false, "passive: unavailable slot 4 should not be touchable")
    _assert_eq(touch_state[ids.slot[5]], false, "passive: unavailable slot 5 should not be touchable")
  end)

  it("_test_passive_outlines_highlight_available_slots", function()
    local touch_state = {}
    local visible_state = {}
    local state = {
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
        ["2002"] = "ICON2002",
        ["2003"] = "ICON2003",
        ["2004"] = "ICON2004",
        ["2005"] = "ICON2005",
      }),
      ui = {
        item_slots = ids.slots(5),
        card_outlines = ids.outlines(5),
        set_touch_enabled = function(_, name, enabled)
          touch_state[name] = enabled == true
        end,
        set_visible = function(_, name, visible)
          visible_state[name] = visible == true
        end,
        set_label = function() end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001, 2002, 2003, 2004, 2005 },
      item_slots_by_player = { [1] = { 2001, 2002, 2003, 2004, 2005 } },
      choice = {
        kind = "item_phase_passive",
        route_key = "item_phase_passive",
        uses_item_slots = true,
        options = { { id = 2001 }, { id = 2003 } },
        slot_states = {
          [1] = { available = true,  alert = false },
          [2] = { available = false, alert = false },
          [3] = { available = true,  alert = false },
          [4] = { available = false, alert = false },
          [5] = { available = false, alert = false },
        },
      },
    }

    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(visible_state[ids.outline[1]], true,  "passive: available outline 1 should be visible")
    _assert_eq(visible_state[ids.outline[2]], false, "passive: unavailable outline 2 should be hidden")
    _assert_eq(visible_state[ids.outline[3]], true,  "passive: available outline 3 should be visible")
    _assert_eq(visible_state[ids.outline[4]], false, "passive: unavailable outline 4 should be hidden")
    _assert_eq(visible_state[ids.outline[5]], false, "passive: unavailable outline 5 should be hidden")
    _assert_eq(touch_state[ids.outline[1]], true,  "passive: available outline 1 should be touchable")
    _assert_eq(touch_state[ids.outline[3]], true,  "passive: available outline 3 should be touchable")
  end)

  it("_test_passive_highlight_dedupes_consecutive_refresh", function()
    local ui_events = require("src.ui.coord.ui_events")
    local events = {}
    local state = {
      ui_refs = _wrap_ui_refs({
        ["Empty"] = "EMPTY",
        ["2001"] = "ICON2001",
        ["2002"] = "ICON2002",
      }),
      ui = {
        item_slots = ids.slots(2),
        card_outlines = ids.outlines(2),
        set_touch_enabled = function() end,
        set_visible = function() end,
        set_label = function() end,
      },
    }
    local ui_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001, 2002 },
      item_slots_by_player = { [1] = { 2001, 2002 } },
      choice = {
        id = 333,
        kind = "item_phase_passive",
        route_key = "item_phase_passive",
        uses_item_slots = true,
        options = { { id = 2001 } },
        slot_states = {
          [1] = { available = true, alert = false },
          [2] = { available = false, alert = false },
        },
      },
    }

    local function _count_event(event_name)
      local count = 0
      for _, value in ipairs(events) do
        if value == event_name then
          count = count + 1
        end
      end
      return count
    end

    _with_patches({
      {
        key = "UIManager",
        value = {
          client_role = nil,
          query_nodes_by_name = function()
            return { { set_texture_keep_size = function() end } }
          end,
        },
      },
      {
        target = ui_events,
        key = "send_to_all",
        value = function(event_name)
          events[#events + 1] = event_name
        end,
      },
      {
        target = ui_events,
        key = "send_to_role",
        value = function(_, event_name)
          events[#events + 1] = event_name
        end,
      },
    }, function()
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
      ui_view.refresh_item_slots(state, ui_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)

    _assert_eq(_count_event("重置高亮"), 1,
      "passive highlight should emit global reset once for identical consecutive refreshes")
    _assert_eq(_count_event("高亮道具槽位牌1"), 1,
      "passive highlight should emit slot highlight once for identical consecutive refreshes")
  end)

  it("_test_action_button_label_never_written", function()
    local label_state = {}
    local state = {
      ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY", ["2001"] = "ICON2001" }),
      ui = {
        item_slots = ids.slots(1),
        card_outlines = ids.outlines(1),
        set_touch_enabled = function() end,
        set_visible = function() end,
        set_label = function(_, name, text)
          label_state[name] = text
        end,
      },
    }

    -- passive 场景
    local passive_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001 },
      item_slots_by_player = { [1] = { 2001 } },
      choice = {
        kind = "item_phase_passive",
        route_key = "item_phase_passive",
        uses_item_slots = true,
        options = { { id = 2001 } },
        slot_states = { [1] = { available = true, alert = false } },
      },
    }
    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
    }, function()
      ui_view.refresh_item_slots(state, passive_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)
    _assert_eq(label_state["基础_行动按钮"], nil, "guard: passive should not write action button label")

    -- 非 passive 场景
    local non_passive_model = {
      current_player_id = 1,
      item_choice_owner_id = 1,
      item_slots = { 2001 },
      item_slots_by_player = { [1] = { 2001 } },
      choice = {
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        options = { { id = 2001 } },
      },
    }
    label_state = {}
    _with_patches({
      { key = "UIManager", value = { query_nodes_by_name = function() return { { set_texture_keep_size = function() end } } end } },
    }, function()
      ui_view.refresh_item_slots(state, non_passive_model, {
        display_player_id = 1,
        allow_interact = true,
      })
    end)
    _assert_eq(label_state["基础_行动按钮"], nil, "guard: non-passive should not write action button label")
  end)
end)
