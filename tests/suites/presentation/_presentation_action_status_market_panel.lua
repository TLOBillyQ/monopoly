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

local function _test_ui_event_router_market_cancel_button_dispatches_choice_cancel()
  local market_nodes = require("src.ui.schema.market")

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

return {
  name = "presentation_market_panel",
  tests = {
    { name = "_test_market_selection_updates_icon_without_resize", run = _test_market_selection_updates_icon_without_resize },
    { name = "_test_market_close_resets_icon_without_resize", run = _test_market_close_resets_icon_without_resize },
    { name = "_test_market_view_default_selection_shows_matching_selection_frame", run = _test_market_view_default_selection_shows_matching_selection_frame },
    { name = "_test_market_select_switches_selection_frame", run = _test_market_select_switches_selection_frame },
    { name = "_test_market_view_refresh_preserves_manual_selection_on_same_page", run = _test_market_view_refresh_preserves_manual_selection_on_same_page },
    { name = "_test_market_view_empty_filtered_tab_hides_selection_frames", run = _test_market_view_empty_filtered_tab_hides_selection_frames },
    { name = "_test_market_view_refresh_retargets_selection_frame_on_page_change", run = _test_market_view_refresh_retargets_selection_frame_on_page_change },
    { name = "_test_market_view_hides_market_disabled_entries", run = _test_market_view_hides_market_disabled_entries },
    { name = "_test_market_view_unbuyable_option_is_clickable", run = _test_market_view_unbuyable_option_is_clickable },
    { name = "_test_market_view_hides_disabled_market_tab", run = _test_market_view_hides_disabled_market_tab },
    { name = "_test_market_view_invalid_selected_option_falls_back_to_current_visible_option", run = _test_market_view_invalid_selected_option_falls_back_to_current_visible_option },
    { name = "_test_market_view_page_arrows_visibility_follows_page_count", run = _test_market_view_page_arrows_visibility_follows_page_count },
    { name = "_test_ui_model_market_payload_prefers_explicit_choice_fields", run = _test_ui_model_market_payload_prefers_explicit_choice_fields },
    { name = "_test_modal_presenter_market_same_choice_id_still_refreshes_market_panel", run = _test_modal_presenter_market_same_choice_id_still_refreshes_market_panel },
    { name = "_test_ui_event_router_market_cancel_button_dispatches_choice_cancel", run = _test_ui_event_router_market_cancel_button_dispatches_choice_cancel },
  },
}
