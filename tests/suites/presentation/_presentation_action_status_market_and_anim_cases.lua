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
local debug_ports_module = require("src.presentation.runtime.ports.debug")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local ui_choice_route_policy = require("src.ui.input.choice_route_policy")
local logger = require("src.core.utils.logger")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local market_cfg = require("src.config.content.market")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")
local host_runtime = require("src.host.eggy")
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


local function _test_market_selection_updates_icon_without_resize()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local option_id = entry.product_id
  local selected_node = {}
  local reset_calls = 0
  selected_node.reset_size = function()
    reset_calls = reset_calls + 1
  end
  local labels = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 1001,
      [tostring(option_id)] = 1002,
    }),
    ui = {
      set_label = function(_, name, text)
        labels[name] = text
      end,
      query_node = function(name)
        _assert_eq(name, market_layout.selected_card, "selected card node expected")
        return selected_node
      end,
    },
  }

  market_view.refresh_market_selection(state, option_id)

  _assert_eq(selected_node.image_texture, 1002, "market selected icon should update")
  _assert_eq(reset_calls, 0, "market selected icon should not call reset_size")
  _assert_eq(labels[market_layout.price_label], tostring(entry.price) .. " " .. entry.currency,
    "market price label should update")
end

local function _test_market_close_resets_icon_without_resize()
  local reset_calls = 0
  local visible = {}
  local selected_node = {
    reset_size = function()
      reset_calls = reset_calls + 1
    end,
  }
  local state = {
    choice_visible_option_ids = { 1, 2 },
    pending_choice_selected_option_id = 1,
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 4321,
    }),
    ui = {
      market_active = true,
      set_visible = function(_, name, value)
        visible[name] = value == true
      end,
      set_label = function() end,
      set_touch_enabled = function() end,
      query_node = function(name)
        _assert_eq(name, market_layout.selected_card, "selected card node expected")
        return selected_node
      end,
    },
  }

  market_view.close_market_panel(state)

  _assert_eq(state.ui.market_active, false, "market panel should be inactive")
  _assert_eq(_ui_runtime(state).choice_visible_option_ids, nil, "market options should clear")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, nil, "selected market option should clear")
  _assert_eq(selected_node.image_texture, 4321, "market selected icon should reset to empty key")
  _assert_eq(reset_calls, 0, "market close should not call reset_size")
  for _, name in ipairs(market_layout.item_selection_frames) do
    _assert_eq(visible[name], false, "market close should hide selection frame")
  end
end

local function _test_market_view_default_selection_shows_matching_selection_frame()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9301,
      ["lv1"] = 9302,
      ["lv2"] = 9303,
      ["lv3"] = 9304,
      [tostring(entry_a.product_id)] = 9305,
      [tostring(entry_b.product_id)] = 9306,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 21,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_b.product_id,
  })

  _assert_eq(opened, true, "market panel should open")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_a.product_id,
    "market should still prefer first visible buyable option by default")
  _assert_eq(visible[market_layout.item_selection_frames[1]], true,
    "first selection frame should match default selected option")
  _assert_eq(visible[market_layout.item_selection_frames[2]], false,
    "non-selected frame should stay hidden")
end

local function _test_market_select_switches_selection_frame()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9401,
      ["lv1"] = 9402,
      ["lv2"] = 9403,
      ["lv3"] = 9404,
      [tostring(entry_a.product_id)] = 9405,
      [tostring(entry_b.product_id)] = 9406,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 22,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_a.product_id,
  })

  market_view.select_market_option(state, entry_b.product_id)

  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_b.product_id, "market select should update selected option")
  _assert_eq(visible[market_layout.item_selection_frames[1]], false,
    "old selection frame should hide after reselection")
  _assert_eq(visible[market_layout.item_selection_frames[2]], true,
    "new selection frame should show after reselection")
end

local function _test_market_view_refresh_preserves_manual_selection_on_same_page()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9411,
      ["lv1"] = 9412,
      ["lv2"] = 9413,
      ["lv3"] = 9414,
      [tostring(entry_a.product_id)] = 9415,
      [tostring(entry_b.product_id)] = 9416,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 22,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_a.product_id,
  })

  market_view.select_market_option(state, entry_b.product_id)

  local reopened = market_view.refresh_market(state, {
    choice_id = 22,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = _ui_runtime(state).pending_choice_selected_option_id,
  })

  _assert_eq(reopened, true, "market panel should refresh after manual selection")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_b.product_id,
    "same-page refresh should preserve the manually selected market option")
  _assert_eq(visible[market_layout.item_selection_frames[1]], false,
    "refresh should keep the previous slot unselected")
  _assert_eq(visible[market_layout.item_selection_frames[2]], true,
    "refresh should keep the manually selected slot highlighted")
end

local function _test_market_view_empty_filtered_tab_hides_selection_frames()
  local visible_entry = assert(market_cfg[1], "missing market cfg entry")
  local hidden_entry = {
    product_id = 999101,
    name = "隐藏测试商品2",
    market_enabled = false,
    currency = visible_entry.currency,
    price = visible_entry.price,
  }

  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9501,
      ["lv1"] = 9502,
      ["lv2"] = 9503,
      ["lv3"] = 9504,
      [tostring(visible_entry.product_id)] = 9505,
      [tostring(hidden_entry.product_id)] = 9506,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local market_cfg_size = #market_cfg
  local old_market_view = package.loaded["src.ui.render.market"]
  market_cfg[market_cfg_size + 1] = hidden_entry
  package.loaded["src.ui.render.market"] = nil

  local ok, err = xpcall(function()
    local test_market_view = require("src.ui.render.market")

    test_market_view.refresh_market(state, {
      choice_id = 23,
      options = {
        { id = visible_entry.product_id, label = visible_entry.name, can_buy = true },
      },
      allow_cancel = true,
      selected_option_id = visible_entry.product_id,
    })

    local reopened = test_market_view.refresh_market(state, {
      choice_id = 24,
      options = {
        { id = hidden_entry.product_id, label = hidden_entry.name, can_buy = false },
      },
      allow_cancel = true,
      selected_option_id = hidden_entry.product_id,
    })

    _assert_eq(reopened, true, "market panel should stay open when filtered tab is empty")
    _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, nil, "empty filtered tab should clear selected option")
    for _, name in ipairs(market_layout.item_selection_frames) do
      _assert_eq(visible[name], false, "empty filtered tab should hide all selection frames")
    end
  end, debug.traceback or function(e) return e end)

  market_cfg[market_cfg_size + 1] = nil
  package.loaded["src.ui.render.market"] = nil
  package.loaded["src.ui.render.market"] = old_market_view
  if not ok then
    error(err)
  end
end

local function _test_market_view_refresh_retargets_selection_frame_on_page_change()
  local entry_a = assert(market_cfg[1], "missing market cfg entry a")
  local entry_b = assert(market_cfg[2], "missing market cfg entry b")
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9601,
      ["lv1"] = 9602,
      ["lv2"] = 9603,
      ["lv3"] = 9604,
      [tostring(entry_a.product_id)] = 9605,
      [tostring(entry_b.product_id)] = 9606,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 25,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_a.product_id,
    page_index = 1,
    page_count = 2,
  })

  local reopened = market_view.refresh_market(state, {
    choice_id = 25,
    options = {
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry_b.product_id,
    page_index = 2,
    page_count = 2,
  })

  _assert_eq(reopened, true, "market panel should refresh on page change")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_b.product_id,
    "page change should retarget selected option to current visible page")
  _assert_eq(visible[market_layout.item_selection_frames[1]], true,
    "current page selected option should show selection frame")
  for index = 2, #market_layout.item_selection_frames do
    _assert_eq(visible[market_layout.item_selection_frames[index]], false,
      "non-current page frames should remain hidden after refresh")
  end
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
  _assert_eq(#specs, 2, "item slot intents should include slot and outline")
  _assert_eq(specs[1].name, "基础_道具槽位1", "slot intent node expected")
  _assert_eq(specs[2].name, "基础_可出牌外框1", "outline intent node expected")
  local intent = specs[2].build_intent()
  _assert_eq(intent and intent.id, "item_slot_1", "outline click should map to slot action")
end

local function _test_market_view_hides_market_disabled_entries()
  local visible_entry = nil
  for _, entry in ipairs(market_cfg) do
    if visible_entry == nil and entry.market_enabled ~= false then
      visible_entry = entry
    end
    if visible_entry then
      break
    end
  end
  assert(visible_entry ~= nil, "missing market visible entry for presentation test")
  local hidden_entry = {
    product_id = 999001,
    name = "隐藏测试商品",
    market_enabled = false,
    currency = visible_entry.currency,
    price = visible_entry.price,
  }

  local labels = {}
  local visible = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9001,
      ["lv1"] = 9002,
      ["lv2"] = 9003,
      ["lv3"] = 9004,
      [tostring(hidden_entry.product_id)] = 9005,
      [tostring(visible_entry.product_id)] = 9006,
    }),
    ui = {
      market_active = false,
      set_label = function(_, name, text)
        labels[name] = text
      end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local market_cfg_size = #market_cfg
  local old_market_view = package.loaded["src.ui.render.market"]
  market_cfg[market_cfg_size + 1] = hidden_entry
  package.loaded["src.ui.render.market"] = nil

  local ok, err = xpcall(function()
    local test_market_view = require("src.ui.render.market")

    local opened = test_market_view.refresh_market(state, {
      choice_id = 7,
      options = {
        { id = hidden_entry.product_id, label = hidden_entry.name, can_buy = false },
        { id = visible_entry.product_id, label = visible_entry.name, can_buy = true },
      },
      allow_cancel = true,
      selected_option_id = hidden_entry.product_id,
    })

    _assert_eq(opened, true, "market panel should open when at least one visible option exists")
    _assert_eq(labels[market_layout.item_labels[1]], visible_entry.name, "first rendered market option should skip disabled entry")
    _assert_eq(visible[market_layout.item_labels[2]], false, "second slot should remain hidden after filtering")

    local reopened = test_market_view.refresh_market(state, {
      choice_id = 8,
      options = {
        { id = hidden_entry.product_id, label = hidden_entry.name, can_buy = false },
      },
      allow_cancel = true,
      selected_option_id = hidden_entry.product_id,
    })

    _assert_eq(reopened, true, "market panel should stay open when all options are filtered out")
    _assert_eq(state.ui.market_active, true, "market panel should remain active on empty filtered tab")
    _assert_eq(visible[market_layout.item_labels[1]], false, "empty filtered tab should hide first slot label")
    _assert_eq(visible[market_layout.item_buttons[1]], false, "empty filtered tab should hide first slot button")
    _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, nil, "empty filtered tab should clear selected option")
  end, debug.traceback or function(e) return e end)

  market_cfg[market_cfg_size + 1] = nil
  package.loaded["src.ui.render.market"] = nil
  package.loaded["src.ui.render.market"] = old_market_view
  if not ok then
    error(err)
  end
end

local function _test_market_view_unbuyable_option_is_clickable()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local touch = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9001,
      ["lv1"] = 9002,
      ["lv2"] = 9003,
      ["lv3"] = 9004,
      [tostring(entry.product_id)] = 9005,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function(_, name, flag)
        touch[name] = flag == true
      end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 10,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = false },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
  })

  _assert_eq(opened, true, "market panel should open with unbuyable options")
  _assert_eq(touch[market_layout.item_buttons[1]], true, "unbuyable option button should still be clickable")
end

local function _test_market_view_hides_disabled_market_tab()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local visible = {}
  local touch = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9001,
      ["lv1"] = 9002,
      ["lv2"] = 9003,
      ["lv3"] = 9004,
      [tostring(entry.product_id)] = 9005,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function(_, name, flag)
        touch[name] = flag == true
      end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 11,
    active_tab = "item",
    page_index = 1,
    page_count = 1,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
  })

  _assert_eq(opened, true, "market panel should open for hidden tab check")
  _assert_eq(visible[market_layout.tab_vehicle], false, "disabled market tab should stay hidden")
  _assert_eq(touch[market_layout.tab_vehicle], false, "hidden market tab should not remain touch enabled")
end

local function _test_market_view_invalid_selected_option_falls_back_to_current_visible_option()
  local entry_a = nil
  local entry_b = nil
  for _, entry in ipairs(market_cfg) do
    if entry.market_enabled ~= false then
      if entry_a == nil then
        entry_a = entry
      elseif entry_b == nil and entry.product_id ~= entry_a.product_id then
        entry_b = entry
      end
    end
    if entry_a and entry_b then
      break
    end
  end
  assert(entry_a ~= nil and entry_b ~= nil, "missing visible market entries for selected fallback test")

  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9201,
      ["lv1"] = 9202,
      ["lv2"] = 9203,
      ["lv3"] = 9204,
      [tostring(entry_a.product_id)] = 9205,
      [tostring(entry_b.product_id)] = 9206,
    }),
    pending_choice_selected_option_id = nil,
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function() end,
      set_touch_enabled = function() end,
      query_node = function()
        return {}
      end,
    },
  }

  local opened = market_view.refresh_market(state, {
    choice_id = 13,
    options = {
      { id = entry_a.product_id, label = entry_a.name, can_buy = true },
      { id = entry_b.product_id, label = entry_b.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = 999999,
  })

  _assert_eq(opened, true, "market panel should open")
  _assert_eq(_ui_runtime(state).pending_choice_selected_option_id, entry_a.product_id,
    "invalid selected option should fallback to first visible buyable option")
end

local function _test_market_view_page_arrows_visibility_follows_page_count()
  local entry = assert(market_cfg[1], "missing market cfg entry")
  local visible = {}
  local touch = {}
  local state = {
    ui_refs = _wrap_ui_refs({
      ["Empty"] = 9101,
      ["lv1"] = 9102,
      ["lv2"] = 9103,
      ["lv3"] = 9104,
      [tostring(entry.product_id)] = 9105,
    }),
    ui = {
      market_active = false,
      set_label = function() end,
      set_visible = function(_, name, flag)
        visible[name] = flag == true
      end,
      set_touch_enabled = function(_, name, flag)
        touch[name] = flag == true
      end,
      query_node = function()
        return {}
      end,
    },
  }

  market_view.refresh_market(state, {
    choice_id = 11,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
    page_index = 1,
    page_count = 1,
  })

  _assert_eq(visible[market_layout.page_prev], false, "page_prev should be hidden when only one page")
  _assert_eq(visible[market_layout.page_next], false, "page_next should be hidden when only one page")

  market_view.refresh_market(state, {
    choice_id = 12,
    options = {
      { id = entry.product_id, label = entry.name, can_buy = true },
    },
    allow_cancel = true,
    selected_option_id = entry.product_id,
    page_index = 1,
    page_count = 2,
  })

  _assert_eq(visible[market_layout.page_prev], true, "page_prev should be visible when multiple pages")
  _assert_eq(visible[market_layout.page_next], true, "page_next should be visible when multiple pages")
  _assert_eq(touch[market_layout.page_prev], false, "page_prev should be disabled on first page")
  _assert_eq(touch[market_layout.page_next], true, "page_next should be enabled when next page exists")
end

local function _test_ui_model_market_payload_prefers_explicit_choice_fields()
  local ui_model = require("src.ui.pres")
  local g = _new_game()
  local current_player = g:current_player()
  g.turn.pending_choice = {
    id = 321,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = current_player.id,
    title = "黑市",
    options = {
      {
        id = 7001,
        label = "测试皮肤",
        can_buy = true,
        requires_pre_confirm = true,
        confirm_title = "请确认",
        confirm_body = "你选的是：测试皮肤",
      },
    },
    allow_cancel = true,
    cancel_label = "不买",
    active_tab = "skin",
    page_index = 2,
    page_count = 5,
    meta = {
      player_id = current_player.id,
      active_tab = "item",
      page_index = 9,
      page_count = 9,
    },
  }

  local model = ui_model.build(g, {
    game = g,
    ui_state = { ui = { item_slots = { 1, 2, 3, 4, 5 }, auto_play = false } },
    last_turn = g.last_turn,
    finished = g.finished,
  })

  _assert_eq(model.choice and model.choice.options[1] and model.choice.options[1].requires_pre_confirm, true,
    "choice view should preserve explicit option pre-confirm flag")
  _assert_eq(model.choice and model.choice.owner_role_id, current_player.id,
    "choice view should preserve explicit owner role id")
  _assert_eq(model.market and model.market.active_tab, "skin", "market payload should prefer explicit active_tab")
  _assert_eq(model.market and model.market.page_index, 2, "market payload should prefer explicit page_index")
  _assert_eq(model.market and model.market.page_count, 5, "market payload should prefer explicit page_count")
end

local function _test_target_pick_prefers_explicit_owner_role_id()
  local env = _build_target_pick_env()
  env.choice.target_picker_owner_role_id = 7
  env.choice.owner_role_id = 7
  env.choice.meta.player_id = 2
  env.state.game.current_player = function()
    return { id = 3 }
  end

  local entered = target_choice_effects.enter(env.state, env.choice)
  _assert_eq(entered, true, "target picker should still enter")
  _assert_eq(env.state.target_choice_runtime and env.state.target_choice_runtime.owner_role_id, 7,
    "target picker should use explicit owner role id before meta/current-player fallback")
  target_choice_effects.leave(env.state, "test_cleanup")
end

local function _test_modal_presenter_market_same_choice_id_still_refreshes_market_panel()
  local modal_presenter = require("src.ui.ctl.modal")
  local market_presenter = require("src.ui.ctl.market")
  local target_choice_effects_local = require("src.ui.ctl.target_choice_effects")
  local canvas_store = require("src.ui.stores.canvas_store")

  local opened = 0
  local state = {
    pending_choice_id = 21,
    ui_dirty = false,
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)
  state.ui.market_active = true
  state.ui.choice_active = false
  local choice = {
    id = 21,
    kind = "market_buy",
    route_key = "market",
    title = "黑市",
    options = {
      { id = 2001, label = "A", can_buy = true },
    },
    allow_cancel = true,
    cancel_label = "取消",
  }
  local market = {
    choice_id = 21,
    options = choice.options,
    allow_cancel = true,
    selected_option_id = 2001,
    active_tab = "skin",
    page_index = 1,
    page_count = 1,
  }

  _with_patches({
    { target = market_presenter, key = "open", value = function()
      opened = opened + 1
    end },
    { target = target_choice_effects_local, key = "leave", value = function() end },
    { target = canvas_store, key = "mark_dirty", value = function() end },
  }, function()
    modal_presenter.open_choice_modal(state, choice, market)
  end)

  _assert_eq(opened, 1, "market choice with same id should still refresh market presenter")
end

local function _test_ui_model_sync_refresh_reopens_market_modal_while_market_active()
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local ui_model = require("src.ui.pres")
  local modal_presenter = require("src.ui.ctl.modal")
  local main_view = require("src.ui.ctl.ui_runtime")

  local state = {
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)
  state.ui.market_active = true

  local choice = {
    id = 31,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = 1,
    title = "黑市",
    options = {
      { id = 5001, label = "小猪佩奇", can_buy = true },
    },
    allow_cancel = true,
    active_tab = "skin",
    page_index = 2,
    page_count = 3,
    meta = { player_id = 1 },
  }
  local market = {
    choice_id = 31,
    options = choice.options,
    allow_cancel = true,
    selected_option_id = 5001,
    active_tab = "skin",
    page_index = 2,
    page_count = 3,
  }
  local captured_choice = nil
  local captured_market = nil
  local render_calls = 0
  local game = {
    turn = {
      phase = "wait_action",
    },
  }
  local common = {
    log_once = function() end,
    build_log_prefix = function()
      return "[test]"
    end,
  }

  _with_patches({
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = choice,
        market = market,
      }
    end },
    { target = main_view, key = "render", value = function()
      render_calls = render_calls + 1
    end },
    { target = modal_presenter, key = "open_choice_modal", value = function(_, open_choice, open_market)
      captured_choice = open_choice
      captured_market = open_market
    end },
  }, function()
    local refreshed = ui_model_sync.refresh_from_dirty(game, state, { any = true }, common)
    _assert_eq(refreshed, true, "market dirty refresh should report ui refreshed")
  end)

  _assert_eq(render_calls, 1, "market dirty refresh should still render base ui once")
  _assert_eq(captured_choice, choice, "market dirty refresh should reopen modal with updated choice")
  _assert_eq(captured_market, market, "market dirty refresh should reopen modal with updated market payload")
  _assert_eq(captured_market and captured_market.active_tab, "skin", "market dirty refresh should propagate new active_tab")
  _assert_eq(captured_market and captured_market.page_index, 2, "market dirty refresh should propagate new page_index")
end

local function _test_ui_model_sync_refresh_skips_market_reopen_during_action_anim()
  local ui_model_sync = require("src.presentation.runtime.ports.ui_sync.model")
  local ui_model = require("src.ui.pres")
  local modal_presenter = require("src.ui.ctl.modal")
  local main_view = require("src.ui.ctl.ui_runtime")

  local state = {
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)
  state.ui.market_active = true

  local choice = {
    id = 32,
    kind = "market_buy",
    route_key = "market",
    owner_role_id = 1,
    title = "黑市",
    options = {
      { id = 5002, label = "小猪乔治", can_buy = true },
    },
    allow_cancel = true,
    meta = { player_id = 1 },
  }
  local reopen_calls = 0
  local render_calls = 0
  local common = {
    log_once = function() end,
    build_log_prefix = function()
      return "[test]"
    end,
  }

  _with_patches({
    { target = ui_model, key = "update", value = function()
      return {
        panel = { turn_label = "" },
        board = {},
        choice = choice,
        market = {
          choice_id = 32,
          options = choice.options,
          allow_cancel = true,
          selected_option_id = 5002,
          active_tab = "skin",
          page_index = 1,
          page_count = 1,
        },
      }
    end },
    { target = main_view, key = "render", value = function()
      render_calls = render_calls + 1
    end },
    { target = modal_presenter, key = "open_choice_modal", value = function()
      reopen_calls = reopen_calls + 1
    end },
  }, function()
    local refreshed = ui_model_sync.refresh_from_dirty({
      turn = {
        phase = "wait_action_anim",
      },
    }, state, { any = true }, common)
    _assert_eq(refreshed, true, "anim-phase market dirty refresh should still render ui")
  end)

  _assert_eq(render_calls, 1, "anim-phase market dirty refresh should still render base ui once")
  _assert_eq(reopen_calls, 0, "anim-phase market dirty refresh should not reopen market modal")
end

local function _test_ui_event_router_market_cancel_button_dispatches_choice_cancel()
  local market_nodes = require("src.ui.schema.market_nodes")

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

  local captured = {}
  local show_tip_calls = 0
  local node_map = {
    [market_nodes.cancel] = new_node(),
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
      turn_action_port = {
        dispatch_action = function(_, _, action)
          captured[#captured + 1] = action
        end,
        should_block_action = function()
          return false
        end,
      },
      ui = ui_view.build_ui_state(),
      ui_runtime = {
        ui_model = {
          current_player_id = "3",
          choice = {
            id = 12,
            kind = "market_buy",
            allow_cancel = true,
            options = { { id = 34, label = "X" } },
          },
          market = {
            choice_id = 12,
            options = { { id = 34, label = "X" } },
          },
        },
        pending_choice_selected_option_id = 34,
      },
    }
    canvas_event_router.bind(state, function()
      return {}
    end)
    node_map[market_nodes.cancel]._listener_cb({})
  end)

  _assert_eq(captured[1] and captured[1].type, "choice_cancel", "market_cancel button should dispatch choice_cancel")
  _assert_eq(captured[1] and captured[1].choice_id, 12, "market_cancel should keep choice id")
  _assert_eq(captured[1] and captured[1].actor_role_id, 3, "market_cancel should inject actor_role_id")
  _assert_eq(show_tip_calls, 0, "market_cancel should not show unadapted tip")
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

local function _test_item_phase_ask_single_item_kind_pre_confirm_dispatches_choice_select()
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
        id = 89,
        kind = "item_phase_choice",
        route_key = "base_inline",
        uses_item_slots = true,
        pre_confirm_before_slot_pick = true,
        options = {
          { id = 2002, label = "导弹卡" },
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
      actor_role_id = 6,
    }, {}, {
      dispatch_action = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
    })
  end)

  _assert_eq(handled, true, "single-item-kind item_phase_ask confirm should be handled")
  _assert_eq(closed, 1, "single-item-kind item_phase_ask should close modal once")
  _assert_eq(dispatched[1] and dispatched[1].option_id, 2002,
    "single-item-kind item_phase_ask should auto-select the only item id")
  _assert_eq(dispatched[1] and dispatched[1].actor_role_id, 6,
    "single-item-kind item_phase_ask should preserve actor role id")
end

local function _test_item_phase_ask_cancel_closes_modal_and_dispatches_choice_cancel()
  local item_phase_ask_flow = require("src.ui.input.dispatch_item_phase_ask")
  local dispatched = {}
  local closed = 0
  local state = {
    _item_phase_ask_active = true,
    _item_phase_confirmed = true,
    _suppress_item_slot_highlight_until_pick = true,
    _skip_item_slot_highlight_replay_choice_id = 88,
    gameplay_loop_ports = {
      modal = {
        close_choice_modal = function()
          closed = closed + 1
        end,
      },
    },
    ui_model = {
      choice = {
        id = 91,
        kind = "item_phase_choice",
      },
    },
    ui = ui_view.build_ui_state(),
  }
  _bind_ui_runtime(state)

  local handled = item_phase_ask_flow.dispatch(state, {}, {
    type = "choice_cancel",
    actor_role_id = 7,
  }, {
    source = "item_phase_ask_cancel",
  }, {
    dispatch_action = function(_, _, action, opts)
      dispatched[#dispatched + 1] = {
        action = action,
        opts = opts,
      }
    end,
  })

  _assert_eq(handled, true, "item_phase_ask choice_cancel should be handled")
  _assert_eq(state._item_phase_ask_active, nil, "item_phase_ask cancel should clear active flag")
  _assert_eq(state._item_phase_confirmed, nil, "item_phase_ask cancel should clear confirmed flag")
  _assert_eq(state._suppress_item_slot_highlight_until_pick, nil,
    "item_phase_ask cancel should clear highlight suppression")
  _assert_eq(state._skip_item_slot_highlight_replay_choice_id, nil,
    "item_phase_ask cancel should clear skip replay flag")
  _assert_eq(closed, 1, "item_phase_ask cancel should close modal once")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.type, "choice_cancel",
    "item_phase_ask cancel should dispatch choice_cancel")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.choice_id, 91,
    "item_phase_ask cancel should keep choice id")
  _assert_eq(dispatched[1] and dispatched[1].action and dispatched[1].action.actor_role_id, 7,
    "item_phase_ask cancel should preserve actor role id")
end

local function _test_view_command_target_lock_and_unlock_fallback_routes_to_target_effects()
  local view_command_dispatcher = require("src.ui.input.dispatch_view_command")
  local target_choice_effects_local = require("src.ui.ctl.target_choice_effects")
  local state = { ui = ui_view.build_ui_state() }
  local calls = {}

  _with_patches({
    {
      target = target_choice_effects_local,
      key = "on_scene_pick",
      value = function(_, option_id, actor_role_id, payload)
        calls[#calls + 1] = {
          kind = "lock",
          option_id = option_id,
          actor_role_id = actor_role_id,
          payload = payload,
        }
      end,
    },
    {
      target = target_choice_effects_local,
      key = "on_unlock",
      value = function()
        calls[#calls + 1] = { kind = "unlock" }
      end,
    },
  }, function()
    local locked = view_command_dispatcher.dispatch(state, {
      type = "target_lock",
      option_id = 102,
      actor_role_id = 3,
    })
    local unlocked = view_command_dispatcher.dispatch(state, {
      type = "target_unlock",
    })

    _assert_eq(locked, true, "target_lock should be handled by fallback dispatcher")
    _assert_eq(unlocked, true, "target_unlock should be handled by fallback dispatcher")
  end)

  _assert_eq(calls[1] and calls[1].kind, "lock", "target_lock should call on_scene_pick")
  _assert_eq(calls[1] and calls[1].option_id, 102, "target_lock should forward option id")
  _assert_eq(calls[1] and calls[1].actor_role_id, 3, "target_lock should forward actor role id")
  _assert_eq(calls[1] and calls[1].payload and calls[1].payload.option_id, 102,
    "target_lock should build fallback payload with option id")
  _assert_eq(calls[2] and calls[2].kind, "unlock", "target_unlock should call on_unlock")
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

local function _test_tick_skips_anim_when_no_anim()
  local dirty_tracker = require("src.core.utils.dirty_tracker")
  local main_view = require("src.ui.ctl.ui_runtime")
  local ui_model = require("src.ui.pres")
  local board_view_mod = require("src.ui.render.board")

  local game_api = GameAPI or {}
  local patches = {
    { target = main_view, key = "refresh_panel", value = function() end },
    { target = board_view_mod, key = "refresh", value = function() end },
    { target = require("src.ui.ctl.modal"), key = "open_choice_modal", value = function() end },
    { target = ui_model, key = "build", value = function(game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { target = ui_model, key = "update", value = function(_, game_ctx)
      return {
        current_player_name = "P",
        current_player_cash = 0,
        turn_count = game_ctx.turn.turn_count,
        panel = { turn_label = "" },
        board = {},
      }
    end },
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_role", value = function()
      return {
        set_camera_bind_mode = function() end,
        set_camera_lock_position = function() end,
      }
    end },
    { key = "Enums", value = { CameraBindMode = { TRACK = 0 } } },
  }

  local game = {
    finished = false,
    winner = nil,
    players = { [1] = { id = 1, name = "P1", cash = 0, eliminated = false, inventory = { items = {} } } },
    board = {
      get_overlays = function() return { roadblocks = {}, mines = {} } end,
      tile_lookup = {},
    },
    turn = {
      phase = "move",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      move_anim = nil,
      action_anim = nil,
    },
    dirty = dirty_tracker.new(),
  }
  function game:consume_dirty()
    return dirty_tracker.consume(self.dirty)
  end
  function game:current_player()
    return self.players[self.turn.current_player_index]
  end
  local state = {
    auto_runner = {
      next_action = function() return nil end,
      reset_timer = function() end,
    },
    _log_once = {},
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    player_units = {
      [1] = {
        get_position = function() return { x = 0, y = 0, z = 0 } end
      }
    },
    ui = { input_blocked = false },
  }

  local ok, err = pcall(function()
    _with_patches(patches, function()
      gameplay_loop.tick(game, state, 0.1)
    end)
  end)

  assert(ok, "tick should not error without anim: " .. tostring(err))
end

local function _test_action_anim_queue_consumes_in_order()
  local phases = {
    start = function()
      return "wait_action_anim", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  }
  local g = {
    turn = {
      phase = "start",
      current_player_index = 1,
      turn_count = 0,
      pending_choice = nil,
      action_anim = { seq = 1, kind = "item_use", player_id = 1 },
      action_anim_queue = { { seq = 2, kind = "item_use", player_id = 1 } },
    },
    dirty = { turn = false, any = false },
    board = {
      get_tile_by_id = function()
        return { level = 0, name = "" }
      end,
    },
    players = {
      [1] = {
        id = 1,
        name = "P1",
        cash = 0,
        status = { stay_turns = 0, deity = nil },
        inventory = { items = {} },
        properties = {},
      }
    },
  }
  function g:current_player()
    return self.players[self.turn.current_player_index]
  end
  function g:player_balance(player)
    return player.cash
  end
  local engine = runtime_cls:new(g, phases, { experimental_coroutine_turn = true })

  local state = engine:run_turn()
  _assert_eq(state, "wait_action_anim", "should wait action anim")
  _assert_eq(g.turn.action_anim.seq, 1, "current anim should be seq1")

  engine:dispatch({ type = "action_anim_done", seq = 999 })
  _assert_eq(g.turn.phase, "wait_action_anim", "wrong seq should keep wait_action_anim")
  _assert_eq(g.turn.action_anim.seq, 1, "wrong seq should keep current anim")

  engine:dispatch({ type = "action_anim_done", seq = 1 })
  _assert_eq(g.turn.phase, "wait_action_anim", "should still wait second anim")
  _assert_eq(g.turn.action_anim.seq, 2, "current anim should switch to seq2")

  engine:dispatch({ type = "action_anim_done", seq = 2 })
  assert(g.turn.phase ~= "wait_action_anim", "should leave action anim wait after queue drained")
  assert(g.turn.action_anim == nil, "action_anim should be nil after queue drained")
end

local function _test_action_anim_default_duration()
  local durations = {}
  local state = {
    game = { turn = { current_player_index = 1 }, players = { [1] = { id = 1 } } },
  }
  _with_patches({
    { key = "GlobalAPI", value = { show_tips = function(_, duration) durations[#durations + 1] = duration end } },
    { key = "SetTimeOut", value = function() end },
  }, function()
    local d1 = action_anim.play(state, { kind = "item_use", player_id = 1 })
    local d2 = action_anim.play(state, { kind = "item_use", player_id = 1, duration = 1.8 })
    _assert_eq(d1, timing.action_anim_default_seconds, "default action anim duration should follow gameplay rule")
    _assert_eq(d2, 1.8, "explicit action anim duration should override")
  end)
  _assert_eq(#durations, 0, "default action anim should not consume tip queue")
end

local function _test_action_anim_no_camera_focus_side_effect()
  local follow_events = 0
  local state = {
    game = {
      turn = { current_player_index = 1 },
      players = { [1] = { id = 1 }, [2] = { id = 2 } },
    },
  }
  _with_patches({
    { key = "GlobalAPI", value = { show_tips = function() end } },
    { key = "TriggerCustomEvent", value = function() follow_events = follow_events + 1 end },
  }, function()
    local duration = action_anim.play(state, {
      kind = "item_use",
      player_id = 1,
      duration = 0.5,
    })
    _assert_eq(duration, 0.5, "action anim should still return duration")
  end)
  _assert_eq(follow_events, 0, "action anim should not trigger camera follow events")
end

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

local function _test_role_control_lock_add_remove_owned_only()
  local unit1 = _make_unit(0)
  local unit2 = _make_unit(2)
  local role1 = {
    get_roleid = function() return 1 end,
    get_ctrl_unit = function() return unit1 end,
  }
  local role2 = {
    get_roleid = function() return 2 end,
    get_ctrl_unit = function() return unit2 end,
  }
  local roles = { role1, role2 }
  local runtime = {
    for_each_role_or_global = function(fn)
      for _, role in ipairs(roles) do
        fn(role)
      end
    end,
    resolve_role_id = function(role)
      return role.get_roleid()
    end,
  }
  local state = { role_control_lock = { by_role = {}, warn_once = {} } }

  _with_patches({
    { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
  }, function()
    role_control_lock_policy.sync(state, true, { runtime = runtime })
    role_control_lock_policy.sync(state, false, { runtime = runtime })
  end)

  assert(unit1.add_calls == 1, "role1 should add buff when empty")
  assert(unit1.remove_calls == 1, "role1 should remove owned buff")
  assert(unit2.add_calls == 0, "role2 should not add when already locked")
  assert(unit2.remove_calls == 0, "role2 should not remove external lock")
end

local function _test_role_control_lock_unit_swap_release_old_and_lock_new()
  local unit1 = _make_unit(0)
  local unit2 = _make_unit(0)
  local current_unit = unit1
  local role = {
    get_roleid = function() return 1 end,
    get_ctrl_unit = function() return current_unit end,
  }
  local runtime = {
    for_each_role_or_global = function(fn)
      fn(role)
    end,
    resolve_role_id = function(r)
      return r.get_roleid()
    end,
  }
  local state = { role_control_lock = { by_role = {}, warn_once = {} } }

  _with_patches({
    { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
  }, function()
    role_control_lock_policy.sync(state, true, { runtime = runtime })
    current_unit = unit2
    role_control_lock_policy.sync(state, true, { runtime = runtime })
  end)

  assert(unit1.add_calls == 1, "old unit should be locked once")
  assert(unit1.remove_calls == 1, "old unit should be released on swap")
  assert(unit2.add_calls == 1, "new unit should be locked on swap")
end

local function _test_gameplay_loop_full_turn_lock_toggle()
  local calls = {}
  local ports = {
    modal = {
      close_choice_modal = function() end,
      open_choice_modal = function() end,
      close_popup = function() end,
    },
    state = {
      apply_role_control_lock = function(_, enabled)
        table.insert(calls, enabled)
      end,
      install_event_handlers = function() end,
      on_bankruptcy_tiles_cleared = function() end,
    },
    anim = {
      reset_status_3d = function() end,
      play_move_anim = function() end,
      play_action_anim = function() end,
      sync_status_3d = function() end,
    },
    ui_sync = {
      apply_input_lock = function() end,
      step_choice_timeout = function() end,
      step_modal_timeout = function() end,
      update_countdown = function() end,
      build_model = function() return {} end,
      refresh_from_dirty = function() return false end,
      get_ui_state = function(state)
        return state and state.ui or nil
      end,
      is_input_blocked = function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = function() return nil end,
      set_input_blocked = function(state, blocked)
        local ui = state and state.ui or nil
        if not ui then
          return false
        end
        if ui.input_blocked == blocked then
          return false
        end
        ui.input_blocked = blocked
        return true
      end,
    },
    debug = {
      log_status = function() end,
      sync_debug_log = function() end,
      resolve_debug_enabled = function() return false end,
    },
  }
  local state = {
    ui = { input_blocked = false },
    gameplay_loop_ports = ports,
    auto_runner = { set_enabled = function() end, reset_timer = function() end, next_action = function() end },
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    _log_once = {},
    item_name_by_id = {},
    ui_dirty = false,
    board_last_phase = nil,
    board_sync_pending = false,
    next_turn_locked = false,
    next_turn_lock_phase = nil,
    board_last_positions = {},
    countdown_last = nil,
    countdown_active_last = nil,
    action_button_elapsed = 0,
    action_button_active = false,
    role_control_lock_active = false,
  }
  local game = {
    finished = false,
    players = { [1] = { id = 1, name = "P1", auto = false } },
    turn = { current_player_index = 1, phase = "start", turn_count = 1 },
    logger = { info = function() end },
    advance_turn = function() end,
    dispatch_action = function() end,
    consume_dirty = function() return { any = false } end,
  }
  function game:pending_choice()
    return nil
  end

  _with_patches({
    { target = gameplay_rules, key = "role_control_lock_enabled", value = true },
    { target = event_handlers, key = "install", value = function() end },
    { target = paid_currency_bridge, key = "setup_for_game", value = function() end },
  }, function()
    gameplay_loop.set_game(state, game)
    gameplay_loop.tick(game, state, 0.1)
    game.finished = true
    gameplay_loop.tick(game, state, 0.1)
  end)

  _assert_eq(calls[1], false, "set_game should clear lock first")
  _assert_eq(calls[2], true, "active game should enable lock")
  _assert_eq(calls[3], false, "finished game should clear lock")
end


return {
  { name = "_test_market_selection_updates_icon_without_resize", run = _test_market_selection_updates_icon_without_resize },
  { name = "_test_market_close_resets_icon_without_resize", run = _test_market_close_resets_icon_without_resize },
  { name = "_test_market_view_default_selection_shows_matching_selection_frame", run = _test_market_view_default_selection_shows_matching_selection_frame },
  { name = "_test_market_select_switches_selection_frame", run = _test_market_select_switches_selection_frame },
  { name = "_test_market_view_refresh_preserves_manual_selection_on_same_page", run = _test_market_view_refresh_preserves_manual_selection_on_same_page },
  { name = "_test_market_view_empty_filtered_tab_hides_selection_frames", run = _test_market_view_empty_filtered_tab_hides_selection_frames },
  { name = "_test_market_view_refresh_retargets_selection_frame_on_page_change", run = _test_market_view_refresh_retargets_selection_frame_on_page_change },
  { name = "_test_item_slot_uses_keep_size_path", run = _test_item_slot_uses_keep_size_path },
  { name = "_test_item_slot_refresh_shows_only_playable_outlines", run = _test_item_slot_refresh_shows_only_playable_outlines },
  { name = "_test_item_slot_intents_include_outline_nodes", run = _test_item_slot_intents_include_outline_nodes },
  { name = "_test_market_view_hides_market_disabled_entries", run = _test_market_view_hides_market_disabled_entries },
  { name = "_test_market_view_unbuyable_option_is_clickable", run = _test_market_view_unbuyable_option_is_clickable },
  { name = "_test_market_view_hides_disabled_market_tab", run = _test_market_view_hides_disabled_market_tab },
  { name = "_test_market_view_invalid_selected_option_falls_back_to_current_visible_option", run = _test_market_view_invalid_selected_option_falls_back_to_current_visible_option },
  { name = "_test_market_view_page_arrows_visibility_follows_page_count", run = _test_market_view_page_arrows_visibility_follows_page_count },
  { name = "_test_ui_model_market_payload_prefers_explicit_choice_fields", run = _test_ui_model_market_payload_prefers_explicit_choice_fields },
  { name = "_test_target_pick_prefers_explicit_owner_role_id", run = _test_target_pick_prefers_explicit_owner_role_id },
  { name = "_test_modal_presenter_market_same_choice_id_still_refreshes_market_panel", run = _test_modal_presenter_market_same_choice_id_still_refreshes_market_panel },
  { name = "_test_ui_model_sync_refresh_reopens_market_modal_while_market_active", run = _test_ui_model_sync_refresh_reopens_market_modal_while_market_active },
  { name = "_test_ui_model_sync_refresh_skips_market_reopen_during_action_anim", run = _test_ui_model_sync_refresh_skips_market_reopen_during_action_anim },
  { name = "_test_ui_event_router_market_cancel_button_dispatches_choice_cancel", run = _test_ui_event_router_market_cancel_button_dispatches_choice_cancel },
  { name = "_test_item_phase_ask_confirm_clears_highlight_suppress", run = _test_item_phase_ask_confirm_clears_highlight_suppress },
  { name = "_test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select", run = _test_item_phase_ask_single_option_pre_confirm_dispatches_choice_select },
  { name = "_test_item_phase_ask_single_item_kind_pre_confirm_dispatches_choice_select", run = _test_item_phase_ask_single_item_kind_pre_confirm_dispatches_choice_select },
  { name = "_test_item_phase_ask_cancel_closes_modal_and_dispatches_choice_cancel", run = _test_item_phase_ask_cancel_closes_modal_and_dispatches_choice_cancel },
  { name = "_test_view_command_target_lock_and_unlock_fallback_routes_to_target_effects", run = _test_view_command_target_lock_and_unlock_fallback_routes_to_target_effects },
  { name = "_test_item_phase_confirmed_skips_replay_before_slot_click", run = _test_item_phase_confirmed_skips_replay_before_slot_click },
  { name = "_test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines", run = _test_item_slot_refresh_item_phase_ask_replays_highlight_then_reveals_outlines },
  { name = "_test_item_slot_refresh_resets_highlight_without_client_role", run = _test_item_slot_refresh_resets_highlight_without_client_role },
  { name = "_test_tick_skips_anim_when_no_anim", run = _test_tick_skips_anim_when_no_anim },
  { name = "_test_action_anim_queue_consumes_in_order", run = _test_action_anim_queue_consumes_in_order },
  { name = "_test_action_anim_default_duration", run = _test_action_anim_default_duration },
  { name = "_test_action_anim_no_camera_focus_side_effect", run = _test_action_anim_no_camera_focus_side_effect },
  { name = "_test_role_control_lock_add_remove_owned_only", run = _test_role_control_lock_add_remove_owned_only },
  { name = "_test_role_control_lock_unit_swap_release_old_and_lock_new", run = _test_role_control_lock_unit_swap_release_old_and_lock_new },
  { name = "_test_gameplay_loop_full_turn_lock_toggle", run = _test_gameplay_loop_full_turn_lock_toggle },
}
