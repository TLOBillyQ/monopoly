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
local ui_status_3d_layer = require("src.ui.render.status3d")
local action_anim = require("src.ui.render.action_anim")
local move_anim = require("src.ui.render.move_anim")
local runtime_cls = require("src.turn.loop.scheduler_runtime")
local turn_effects = require("src.ui.wid.turn_effects")
local popup_renderer = require("src.ui.ctl.popup")
local market_modal_renderer = require("src.ui.ctl.market")
local debug_ports_module = require("src.ui.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")
local host_runtime = require("src.host")
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

local function _make_unit(initial_count)
  local unit = {
    count = initial_count or 0,
    add_calls = 0,
    remove_calls = 0,
  }
  function unit.get_state_count()
    return unit.count
  end
  function unit.add_state()
    unit.add_calls = unit.add_calls + 1
    unit.count = unit.count + 1
  end
  function unit.remove_state()
    unit.remove_calls = unit.remove_calls + 1
    unit.count = math.max(0, unit.count - 1)
  end
  return unit
end

local function _test_item_slot_uses_keep_size_path()
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
      item_slots = { "基础_道具槽位1" },
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
end

local function _test_item_slot_refresh_shows_only_playable_outlines()
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
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3" },
      card_outlines = { "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3" },
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

  _assert_eq(visible_state["基础_可出牌外框1"], true, "playable slot 1 outline should be visible")
  _assert_eq(visible_state["基础_可出牌外框2"], false, "unplayable slot 2 outline should be hidden")
  _assert_eq(visible_state["基础_可出牌外框3"], true, "playable slot 3 outline should be visible")
  _assert_eq(touch_state["基础_道具槽位1"], true, "playable slot 1 should be clickable")
  _assert_eq(touch_state["基础_道具槽位2"], false, "unplayable slot 2 should be locked")
  _assert_eq(touch_state["基础_道具槽位3"], true, "playable slot 3 should be clickable")
end

local function _test_item_slot_intents_include_outline_nodes()
  local item_slot_intents = require("src.ui.input.canvas_route_item_slots")
  local state = {
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
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
  _assert_eq(#specs, 3, "item slot intents should include slot, outline, and continue button")
  _assert_eq(specs[1].name, "基础_道具槽位1", "slot intent node expected")
  _assert_eq(specs[2].name, "基础_可出牌外框1", "outline intent node expected")
  local intent = specs[2].build_intent()
  _assert_eq(intent and intent.id, "item_slot_1", "outline click should map to slot action")
end

local function _test_item_phase_ask_confirm_clears_highlight_suppress()
  local item_phase_ask_flow = require("src.ui.input.dispatch_item_phase_ask")
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
end

local function _test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select()
  local item_phase_ask_flow = require("src.ui.input.dispatch_item_phase_ask")
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
end

local function _test_item_phase_confirmed_skips_replay_before_slot_click()
  local ui_events = require("src.ui.ctl.ui_events")
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
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
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
end

local function _test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines()
  local ui_events = require("src.ui.ctl.ui_events")
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
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3" },
      card_outlines = { "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3" },
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
    _assert_eq(visible_state["基础_可出牌外框1"], false, "outline1 should stay hidden before delay")
    _assert_eq(visible_state["基础_可出牌外框3"], false, "outline3 should stay hidden before delay")
    _assert_eq(#timers, 1, "item_phase_ask should schedule exactly one reveal timer")

    timers[1]()
    ui_view.refresh_item_slots(state, ui_model, {
      display_player_id = 1,
      allow_interact = true,
    })

    _assert_eq(_count_event("高亮道具槽位牌1"), 1, "highlight should not replay every refresh")
    _assert_eq(_count_event("高亮道具槽位牌3"), 1, "highlight should not replay every refresh")
    _assert_eq(visible_state["基础_可出牌外框1"], true, "outline1 should show after delay")
    _assert_eq(visible_state["基础_可出牌外框3"], true, "outline3 should show after delay")
    _assert_eq(visible_state["基础_可出牌外框2"], false, "non-pickable outline should stay hidden")
  end)
end

local function _test_item_slot_refresh_resets_highlight_without_client_role()
  local ui_events = require("src.ui.ctl.ui_events")
  local events = {}
  local phase = ""

  local function _record(channel, event_name)
    events[#events + 1] = {
      phase = phase,
      channel = channel,
      event_name = event_name,
    }
  end

  local function _has_event(phase_name, event_name)
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
      item_slots = { "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3", "基础_道具槽位4", "基础_道具槽位5" },
      card_outlines = { "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3", "基础_可出牌外框4", "基础_可出牌外框5" },
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

  _assert_eq(_has_event("pre_action", "高亮道具槽位牌1"), true, "pre_action should highlight remote dice slot")
  _assert_eq(_has_event("pre_action", "重置高亮"), true, "pre_action should issue global reset before highlighting")
  _assert_eq(_has_event("suppressed_item_phase", "重置高亮"), false,
    "item_phase should suppress highlight animation while waiting for a pick")
  _assert_eq(_has_event("suppressed_item_phase", "高亮道具槽位牌1"), false,
    "item_phase suppression should block per-slot highlight events")
  _assert_eq(_has_event("remote_choice", "重置高亮"), true, "remote choice should issue global reset before slot reorder")
  _assert_eq(_has_event("remote_choice", "重置高亮道具槽位牌1"), true, "remote choice should reset slot1 highlight without client role")
  _assert_eq(_has_event("pre_action_dice_multiplier", "重置高亮"), true,
    "pre_action should issue global reset before highlighting dice multiplier slot")
  _assert_eq(_has_event("pre_action_dice_multiplier", "高亮道具槽位牌4"), true,
    "pre_action should highlight dice multiplier slot")
  _assert_eq(_has_event("pre_action_dice_multiplier", "重置高亮道具槽位牌1"), true,
    "pre_action should clear stale slot1 highlight")
end

local function _test_passive_slot_three_state_rendering()
  local touch_state = {}
  local visible_state = {}
  local events = {}
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
      item_slots = {
        "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3",
        "基础_道具槽位4", "基础_道具槽位5",
      },
      card_outlines = {
        "基础_可出牌外框1", "基础_可出牌外框2", "基础_可出牌外框3",
        "基础_可出牌外框4", "基础_可出牌外框5",
      },
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

  _assert_eq(touch_state["基础_道具槽位1"], true,  "passive: available slot 1 should be touchable")
  _assert_eq(touch_state["基础_道具槽位2"], false, "passive: unavailable slot 2 should not be touchable")
  _assert_eq(touch_state["基础_道具槽位3"], true,  "passive: available slot 3 should be touchable")
  _assert_eq(touch_state["基础_道具槽位4"], false, "passive: unavailable slot 4 should not be touchable")
  _assert_eq(touch_state["基础_道具槽位5"], false, "passive: unavailable slot 5 should not be touchable")
  _assert_eq(visible_state["基础_道具继续按钮"], true, "passive: continue button should be visible")
end

local function _test_passive_slot_bubbles_shown_for_alert_slots()
  local visible_state = {}
  local label_state = {}
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
      item_slots = {
        "基础_道具槽位1", "基础_道具槽位2", "基础_道具槽位3",
        "基础_道具槽位4", "基础_道具槽位5",
      },
      card_outlines = {},
      set_touch_enabled = function() end,
      set_visible = function(_, name, visible)
        visible_state[name] = visible == true
      end,
      set_label = function(_, name, text)
        label_state[name] = text
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_slots = { 2001, 2002, 2003, 2004, 2005 },
    item_slots_by_player = { [1] = { 2001, 2002, 2003, 2004, 2005 } },
    choice = {
      kind = "item_phase_passive",
      route_key = "item_phase_passive",
      uses_item_slots = true,
      options = { { id = 2001 }, { id = 2003 } },
      slot_states = {
        [1] = { available = true,  alert = true,  alert_text = "已充能" },
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

  _assert_eq(visible_state["基础_道具气泡1"], true,  "passive: alert slot 1 bubble should be visible")
  _assert_eq(label_state["基础_道具气泡1"], "已充能",  "passive: alert slot 1 bubble should show alert_text")
  _assert_eq(visible_state["基础_道具气泡2"], false, "passive: unavailable slot 2 bubble should be hidden")
  _assert_eq(visible_state["基础_道具气泡3"], false, "passive: available non-alert slot 3 bubble should be hidden")
  _assert_eq(visible_state["基础_道具气泡4"], false, "passive: unavailable slot 4 bubble should be hidden")
  _assert_eq(visible_state["基础_道具气泡5"], false, "passive: unavailable slot 5 bubble should be hidden")
end

local function _test_continue_button_emits_cancel()
  local item_slot_intents = require("src.ui.input.canvas_route_item_slots")
  local state = {
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
    },
    ui_model = {
      choice = {
        kind = "item_phase_passive",
        route_key = "item_phase_passive",
        uses_item_slots = true,
      },
    },
  }
  _bind_ui_runtime(state)

  local specs = item_slot_intents.build(state)
  local continue_spec = nil
  for _, spec in ipairs(specs) do
    if spec.name == "基础_道具继续按钮" then
      continue_spec = spec
      break
    end
  end

  _assert_eq(continue_spec ~= nil, true, "continue button spec should be present")
  local intent = continue_spec and continue_spec.build_intent()
  _assert_eq(intent and intent.type, "choice_cancel", "continue button click should emit choice_cancel")
end

local function _test_non_passive_choice_hides_bubbles_and_continue_button()
  local visible_state = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = "EMPTY",
      ["2001"] = "ICON2001",
    }),
    ui = {
      item_slots = { "基础_道具槽位1" },
      card_outlines = { "基础_可出牌外框1" },
      set_touch_enabled = function() end,
      set_visible = function(_, name, visible)
        visible_state[name] = visible == true
      end,
    },
  }
  local ui_model = {
    current_player_id = 1,
    item_slots = { 2001 },
    item_slots_by_player = { [1] = { 2001 } },
    choice = {
      kind = "item_phase_choice",
      route_key = "base_inline",
      uses_item_slots = true,
      options = { { id = 2001 } },
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

  _assert_eq(visible_state["基础_道具继续按钮"], false, "non-passive: continue button should be hidden")
  _assert_eq(visible_state["基础_道具气泡1"], false, "non-passive: bubble 1 should be hidden")
end

return {
  name = "presentation_item_slots",
  tests = {
    { name = "_test_item_slot_uses_keep_size_path", run = _test_item_slot_uses_keep_size_path },
    { name = "_test_item_slot_refresh_shows_only_playable_outlines", run = _test_item_slot_refresh_shows_only_playable_outlines },
    { name = "_test_item_slot_intents_include_outline_nodes", run = _test_item_slot_intents_include_outline_nodes },
    { name = "_test_item_phase_ask_confirm_clears_highlight_suppress", run = _test_item_phase_ask_confirm_clears_highlight_suppress },
    { name = "_test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select", run = _test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select },
    { name = "_test_item_phase_confirmed_skips_replay_before_slot_click", run = _test_item_phase_confirmed_skips_replay_before_slot_click },
    { name = "_test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines", run = _test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines },
    { name = "_test_item_slot_refresh_resets_highlight_without_client_role", run = _test_item_slot_refresh_resets_highlight_without_client_role },
    { name = "_test_passive_slot_three_state_rendering", run = _test_passive_slot_three_state_rendering },
    { name = "_test_passive_slot_bubbles_shown_for_alert_slots", run = _test_passive_slot_bubbles_shown_for_alert_slots },
    { name = "_test_continue_button_emits_cancel", run = _test_continue_button_emits_cancel },
    { name = "_test_non_passive_choice_hides_bubbles_and_continue_button", run = _test_non_passive_choice_hides_bubbles_and_continue_button },
  },
}
