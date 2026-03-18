local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local runtime_state = require("src.ui.runtime.state")
local number_utils = require("src.core.utils.number_utils")

local market_view_controls = {}

local function _resolve_runtime(state, deps)
  local resolved_deps = deps or (state and state.presentation_runtime) or {}
  return assert(resolved_deps.runtime or package.loaded["src.ui.render.runtime_ui"], "missing deps.runtime")
end

local function _resolve_ref_key(refs, key)
  if number_utils.is_numeric(key) then
    return key
  end
  return refs[key]
end

local function _set_cancel_controls(ui, visible, enabled)
  local names = market_layout.cancel_buttons
  if type(names) == "table" and #names > 0 then
    ui_controls.set_controls_state(ui, names, { visible = visible, touch_enabled = enabled })
    return
  end
  ui_controls.set_control_state(ui, market_layout.cancel_button, { visible = visible, touch_enabled = enabled })
end

local function _resolve_market_tab(market)
  local tab = market and market.active_tab or nil
  if tab == "item" or tab == "skin" or tab == "vehicle" then
    return tab
  end
  return "item"
end

local function _resolve_market_page_value(market, key)
  local value = number_utils.to_integer(market and market[key]) or 1
  if value < 1 then
    return 1
  end
  return value
end

function market_view_controls.set_market_container_active(ui, active)
  ui_controls.set_control_state(ui, market_layout.container, { visible = active })
  ui.market_active = active == true
end

function market_view_controls.set_confirm_button_state(ui, enabled)
  ui_controls.set_control_state(ui, market_layout.confirm_button, {
    visible = true,
    touch_enabled = enabled == true,
  })
end

function market_view_controls.clear_market_selection_frames(ui)
  ui_controls.set_controls_state(ui, market_layout.item_selection_frames or {}, { visible = false, touch_enabled = false })
end

function market_view_controls.reset_market_preview(state, deps)
  local runtime = _resolve_runtime(state, deps)
  local ui = state.ui
  ui:set_label(market_layout.price_label, "")
  market_view_controls.clear_market_selection_frames(ui)
  ui_controls.set_control_state(ui, market_layout.selected_card, { touch_enabled = false })
  local image_refs = state.ui_refs and state.ui_refs.images or {}
  local empty_key = _resolve_ref_key(image_refs, market_layout.empty_ref_key)
  if empty_key ~= nil then
    runtime.set_node_texture_keep_size(ui.query_node(market_layout.selected_card), empty_key)
  end
end

function market_view_controls.refresh_market_selection_frames(ui, option_ids, option_id)
  market_view_controls.clear_market_selection_frames(ui)
  if option_id == nil then
    return
  end
  for index, visible_option_id in pairs(option_ids or {}) do
    local name = market_layout.item_selection_frames and market_layout.item_selection_frames[index] or nil
    if visible_option_id == option_id and name then
      ui_controls.set_control_state(ui, name, { visible = true, touch_enabled = false })
      return
    end
  end
end

function market_view_controls.refresh_market_controls(ui, market, vehicle_tab_enabled)
  local active_tab = _resolve_market_tab(market)
  local page_index = _resolve_market_page_value(market, "page_index")
  local page_count = _resolve_market_page_value(market, "page_count")
  local paging_visible = page_count > 1
  ui_controls.set_control_state(ui, market_layout.page_prev, {
    visible = paging_visible,
    touch_enabled = paging_visible and page_index > 1,
  })
  ui_controls.set_control_state(ui, market_layout.page_next, {
    visible = paging_visible,
    touch_enabled = paging_visible and page_index < page_count,
  })
  ui_controls.set_control_state(ui, market_layout.tab_item, { visible = true, touch_enabled = active_tab ~= "item" })
  ui_controls.set_control_state(ui, market_layout.tab_skin, { visible = true, touch_enabled = active_tab ~= "skin" })
  ui_controls.set_control_state(ui, market_layout.tab_vehicle, {
    visible = vehicle_tab_enabled == true,
    touch_enabled = vehicle_tab_enabled == true and active_tab ~= "vehicle",
  })
end

function market_view_controls.apply_market_common_controls(ui, market, confirm_enabled, vehicle_tab_enabled)
  market_view_controls.refresh_market_controls(ui, market, vehicle_tab_enabled)
  market_view_controls.set_confirm_button_state(ui, confirm_enabled)
  _set_cancel_controls(ui, market.allow_cancel, market.allow_cancel)
end

function market_view_controls.close_market_panel(state, deps)
  local ui = state.ui
  market_view_controls.set_market_container_active(ui, false)
  runtime_state.ensure_ui_runtime(state).choice_visible_option_ids = nil
  runtime_state.ensure_ui_runtime(state).pending_choice_selected_option_id = nil
  market_view_controls.reset_market_preview(state, deps)
  ui_controls.set_controls_state(ui, market_layout.item_labels, { touch_enabled = false })
  ui_controls.set_controls_state(ui, market_layout.item_frames, { touch_enabled = false })
  ui_controls.set_controls_state(ui, {
    market_layout.page_prev,
    market_layout.page_next,
    market_layout.tab_item,
    market_layout.tab_skin,
    market_layout.tab_vehicle,
  }, { visible = false, touch_enabled = false })
  _set_cancel_controls(ui, false, false)
end

return market_view_controls
