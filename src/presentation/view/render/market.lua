local market_layout = require("src.presentation.view.support.market_layout")
local ui_controls = require("src.presentation.view.support.ui_controls")
local modal_state = require("src.presentation.input.modal_state_coordinator")
local runtime = require("src.presentation.runtime.ui_runtime")
local runtime_state = require("src.core.state_access.runtime_state")
local market_view_slots = require("src.presentation.view.render.market_slots")
local market_view_controls = require("src.presentation.view.render.market_controls")

local market_view = {}
local VEHICLE_TAB_ENABLED = false

local function _set_market_preview_icon(state, icon_key)
  if icon_key == nil then
    return
  end
  local ui = state.ui
  runtime.set_node_texture_keep_size(ui.query_node(market_layout.selected_card), icon_key)
end

function market_view.refresh_market_selection(state, option_id)
  local ui = state.ui
  assert(ui ~= nil, "missing market ui")
  local selection = market_view_slots.resolve_selection(
    option_id,
    state.ui_refs and state.ui_refs.images or {},
    market_layout.empty_ref_key
  )
  ui:set_label(market_layout.price_label, selection.price_text)
  _set_market_preview_icon(state, selection.icon_key)
end

function market_view.select_market_option(state, option_id)
  modal_state.select_market_option(state, option_id)
  market_view_controls.refresh_market_selection_frames(
    state.ui,
    runtime_state.ensure_ui_runtime(state).choice_visible_option_ids,
    option_id
  )
  market_view.refresh_market_selection(state, option_id)
end

function market_view.refresh_market(state, market)
  local ui = state.ui
  assert(market ~= nil and market.options ~= nil and ui ~= nil, "missing market data/ui")
  local options = market_view_slots.filter_market_options(market.options)
  market_view_controls.set_market_container_active(ui, true)
  if #options == 0 then
    market_view_slots.hide_market_slots(ui)
    market_view_controls.reset_market_preview(state)
    market_view_controls.apply_market_common_controls(ui, market, false, VEHICLE_TAB_ENABLED)
    modal_state.open_market(state, market.choice_id, {}, nil)
    return true
  end
  local refs = state.ui_refs and state.ui_refs.images or {}
  local rendered = market_view_slots.populate_market_slots(ui, refs, options)
  ui_controls.set_control_state(ui, market_layout.selected_card, { touch_enabled = false })
  market_view_controls.clear_market_selection_frames(ui)
  market_view_controls.apply_market_common_controls(ui, market, true, VEHICLE_TAB_ENABLED)
  local selected = market_view_slots.resolve_selected_option(
    rendered.option_ids,
    market.selected_option_id,
    rendered.first_buyable
  )
  modal_state.open_market(state, market.choice_id, rendered.option_ids, selected)
  market_view.select_market_option(state, selected)
  return true
end

function market_view.close_market_panel(state)
  local ui = state.ui
  assert(ui ~= nil and ui.market_active == true, "market panel not active")
  modal_state.close_choice(state)
  market_view_controls.close_market_panel(state)
end

return market_view
