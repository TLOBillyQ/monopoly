-- Guard-clause regression for src.ui.render.market (init.lua):
-- assert survivors on `and→or` mutations in refresh_market (L136) and
-- close_market_panel (L152).
local lu = require("luaunit")
local luax = require("test.support.luax")
local market_view = require("src.ui.render.market")
local market_view_slots = require("src.ui.render.market.slots")
local market_view_controls = require("src.ui.render.market.controls")
local ui_controls = require("src.ui.render.support.ui_controls")
local market_layout = require("src.ui.schema.market_layout")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _bind_ui_runtime = support.bind_ui_runtime
local _with_patches = support.with_patches

-- Full-featured ui stub that survives the post-assert code path when the
-- mutant assert passes. Without the setter methods, the mutated function
-- would also crash downstream (e.g. hide_market_slots → set_visible),
-- making pcall return false for both original and mutant.
local function _full_ui_stub()
  return {
    set_label = function() end,
    set_visible = function() end,
    set_touch_enabled = function() end,
    set_image = function() end,
    query_node = function() return {} end,
    market_active = false,
  }
end

TestMarketGuard = {}

function TestMarketGuard:test_refresh_market_asserts_when_market_options_is_nil()
  -- Regression for --mutate and→or on L136 assert:
  -- `market ~= nil and market.options ~= nil and ui ~= nil` → `or`
  -- allows a market with nil options to slip through when market~=nil and ui~=nil.
  -- The full ui stub prevents the mutated version from crashing downstream
  -- (e.g. hide_market_slots needs set_visible), so only the assert guards
  -- against nil options.
  local state = { ui = _full_ui_stub() }
  _bind_ui_runtime(state)
  luax.has_error(function()
    market_view.refresh_market(state, { options = nil })
  end, "missing market data/ui")
end

function TestMarketGuard:test_refresh_market_asserts_when_ui_is_nil()
  -- Regression for --mutate and→or on L136 assert (third and):
  -- a nil ui should assert regardless of market validity.
  local state = { ui = nil }
  luax.has_error(function()
    market_view.refresh_market(state, { options = {} })
  end, "missing market data/ui")
end

function TestMarketGuard:test_close_market_panel_asserts_when_ui_is_nil()
  -- Regression for --mutate and→or on L152 assert:
  -- `ui ~= nil and ui.market_active == true` → `or`, letting nil ui
  -- short-circuit the `or` branch and crash with nil.market_active.
  local state = { ui = nil }
  luax.has_error(function()
    market_view.close_market_panel(state)
  end, "market panel not active")
end

function TestMarketGuard:test_close_market_panel_asserts_when_market_active_is_false()
  -- The second `and→or` on L152: with both `ui ~= nil` and
  -- `ui.market_active == false`, `or` may evade the guard.
  local state = { ui = _full_ui_stub() }
  _bind_ui_runtime(state)
  luax.has_error(function()
    market_view.close_market_panel(state)
  end, "market panel not active")
end

function TestMarketGuard:test_refresh_market_selection_asserts_when_ui_is_nil_262()
  -- kills L55 "missing market ui" -> nil。
  luax.has_error(function()
    market_view.refresh_market_selection({ ui = nil }, 10)
  end, "missing market ui")
end

function TestMarketGuard:test_refresh_cash_display_pins_control_visibility_and_touch_flags_262()
  -- kills set_controls_state 的 touch_enabled=false->true。
  local captured = nil
  local state = { ui = _full_ui_stub(), ui_model = { current_player_cash = 800 } }

  _with_patches({
    { target = ui_controls, key = "set_controls_state", value = function(_, names, flags)
      captured = { names = names, flags = flags }
    end },
  }, function()
    market_view.refresh_cash_display(state)
  end)

  lu.assertEvalToTrue(captured ~= nil, "cash display should update control states")
  _assert_eq(captured.flags.visible, true, "cash controls should be visible")
  _assert_eq(captured.flags.touch_enabled, false, "cash controls must not be touchable")
  _assert_eq(captured.names[1], market_layout.cash_text_label, "cash text label should lead the control list")
end

function TestMarketGuard:test_refresh_market_pins_common_control_flags_on_the_empty_and_populated_paths_262()
  -- kills apply_market_common_controls 的 false->true(空市集)与 true->false
  -- (有货市集)、set_control_state 的 touch_enabled=false->true。
  local common_calls = {}
  local selected_card_touch = nil
  local state = { ui = _full_ui_stub() }
  _bind_ui_runtime(state)

  local patches = {
    { target = market_view_slots, key = "hide_market_slots", value = function() end },
    { target = market_view_slots, key = "filter_market_options", value = function(options)
      return options
    end },
    { target = market_view_slots, key = "populate_market_slots", value = function(_, options)
      assert(options ~= nil, "populate_market_slots must receive the options")
      return { option_ids = { 10 }, first_buyable = 10 }
    end },
    { target = market_view_slots, key = "resolve_selected_option", value = function()
      return 10
    end },
    { target = market_view_slots, key = "resolve_selection", value = function()
      return { price_text = "", icon_key = nil }
    end },
    { target = market_view_controls, key = "reset_market_preview", value = function() end },
    { target = market_view_controls, key = "apply_market_common_controls", value = function(_, _, populated)
      common_calls[#common_calls + 1] = populated
    end },
    { target = market_view_controls, key = "set_market_container_active", value = function() end },
    { target = market_view_controls, key = "clear_market_selection_frames", value = function() end },
    { target = market_view_controls, key = "refresh_market_selection_frames", value = function() end },
    { target = market_view_controls, key = "set_confirm_button_state", value = function() end },
    { target = ui_controls, key = "set_control_state", value = function(_, name, flags)
      if name == market_layout.selected_card then
        selected_card_touch = flags and flags.touch_enabled
      end
    end },
    { target = ui_controls, key = "set_controls_state", value = function() end },
  }

  _with_patches(patches, function()
    market_view.refresh_market(state, { choice_id = 7, options = {} })
    market_view.refresh_market(state, { choice_id = 7, options = { { id = 10 } } })
  end)

  _assert_eq(common_calls[1], false, "an empty market should apply common controls as unpopulated")
  _assert_eq(common_calls[2], true, "a populated market should apply common controls as populated")
  _assert_eq(selected_card_touch, false, "the selected card must not be touchable")
end


return TestMarketGuard
