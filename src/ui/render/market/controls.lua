local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local runtime_state = require("src.ui.state.runtime")
local number_utils = require("src.foundation.number")
local runtime_ui = require("src.ui.render.runtime_ui")

local market_view_controls = {}

local function _resolve_runtime(state, deps)
  local resolved_deps = deps or (state and state.presentation_runtime) or {}
  return assert(resolved_deps.runtime or runtime_ui, "missing deps.runtime")
end

local _resolve_ref_key = require("src.ui.render.market.ref_key").resolve

local function _set_cancel_controls(ui, visible, enabled)
  local names = market_layout.cancel_buttons
  if type(names) == "table" and #names > 0 then
    ui_controls.set_controls_state(ui, names, { visible = visible, touch_enabled = enabled })
    return
  end
  ui_controls.set_control_state(ui, market_layout.cancel_button, { visible = visible, touch_enabled = enabled })
end

local function _resolve_market_page_value(market, key)
  local value = number_utils.to_integer(market and market[key]) or 1
  return value < 1 and 1 or value
end

local function _has_ui_method(ui, method_name)
  return ui ~= nil and type(ui[method_name]) == "function"
end

local function _set_control_text(ui, name, text)
  if not name or ui == nil then
    return
  end
  local resolved = text or ""
  if _has_ui_method(ui, "set_label") then
    ui:set_label(name, resolved)
  end
  if _has_ui_method(ui, "set_button") then
    ui:set_button(name, resolved)
  end
end

function market_view_controls.set_market_container_active(ui, active)
  ui_controls.set_control_state(ui, market_layout.container, { visible = active })
  ui.market_active = active == true
  if not active then
    ui_controls.set_controls_state(ui, market_layout.sold_out_badges, { visible = false, touch_enabled = false })
    ui_controls.set_controls_state(ui, market_layout.sold_out_labels, { visible = false, touch_enabled = false })
  end
end

function market_view_controls.set_confirm_button_state(ui, enabled)
  ui_controls.set_control_state(ui, market_layout.confirm_button, {
    visible = enabled == true,
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

local function _set_page_arrow(ui, button, label, visible, text)
  ui_controls.set_control_state(ui, button, { visible = visible, touch_enabled = visible })
  ui_controls.set_control_state(ui, label, { visible = visible, touch_enabled = false })
  _set_control_text(ui, label, visible and text or "")
end

local function _refresh_tab_gray(ui, active_tab)
  local item_active = active_tab == "item"
  ui_controls.set_controls_state(ui,
    { market_layout.tab_item_gray, market_layout.tab_item_gray_label },
    { visible = not item_active, touch_enabled = false })
end

local function _refresh_market_controls(ui, market)
  local page_index = _resolve_market_page_value(market, "page_index")
  local page_count = _resolve_market_page_value(market, "page_count")
  local prev_visible = page_count > 1 and page_index > 1
  local next_visible = page_count > 1 and page_index < page_count
  _set_page_arrow(ui, market_layout.page_prev, market_layout.page_prev_label, prev_visible, market_layout.page_prev_text)
  _set_page_arrow(ui, market_layout.page_next, market_layout.page_next_label, next_visible, market_layout.page_next_text)
  ui_controls.set_control_state(ui, market_layout.tab_item, { visible = true, touch_enabled = true })
  _refresh_tab_gray(ui, market.active_tab)
end

function market_view_controls.apply_market_common_controls(ui, market, confirm_enabled)
  _refresh_market_controls(ui, market)
  market_view_controls.set_confirm_button_state(ui, confirm_enabled)
  _set_cancel_controls(ui, market.allow_cancel, market.allow_cancel)
end

local _CLOSE_PANEL_CONTROLS = {
  market_layout.page_prev,
  market_layout.page_next,
  market_layout.page_prev_label,
  market_layout.page_next_label,
  market_layout.tab_item,
  market_layout.tab_item_gray,
  market_layout.tab_item_gray_label,
}

function market_view_controls.close_market_panel(state, deps)
  local ui = state.ui
  market_view_controls.set_market_container_active(ui, false)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.choice_visible_option_ids = nil
  ui_runtime.pending_choice_selected_option_id = nil
  market_view_controls.reset_market_preview(state, deps)
  ui_controls.set_controls_state(ui, market_layout.item_labels, { touch_enabled = false })
  ui_controls.set_controls_state(ui, market_layout.item_frames, { touch_enabled = false })
  ui_controls.set_controls_state(ui, _CLOSE_PANEL_CONTROLS, { visible = false, touch_enabled = false })
  _set_control_text(ui, market_layout.page_prev_label, "")
  _set_control_text(ui, market_layout.page_next_label, "")
  _set_cancel_controls(ui, false, false)
end

return market_view_controls

--[[ mutate4lua-manifest
version=2
projectHash=01c082e04b027be4
scope.0.id=chunk:src/ui/render/market/controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=150
scope.0.semanticHash=bcac6ad92f95ea40
scope.1.id=function:_resolve_runtime:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=12
scope.1.semanticHash=0ce63cf80cc1cd18
scope.2.id=function:_set_cancel_controls:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=23
scope.2.semanticHash=c74cb04e2e20134d
scope.3.id=function:_resolve_market_page_value:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=28
scope.3.semanticHash=4cfa09f5b6f812af
scope.4.id=function:_has_ui_method:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=69fe5b5f8a2b0f3b
scope.5.id=function:_set_control_text:34
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=45
scope.5.semanticHash=73ef0c605c555493
scope.6.id=function:market_view_controls.set_market_container_active:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=54
scope.6.semanticHash=0f952bfff9cd32a0
scope.7.id=function:market_view_controls.set_confirm_button_state:56
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=61
scope.7.semanticHash=0d5372b133a2e5d4
scope.8.id=function:market_view_controls.clear_market_selection_frames:63
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=7ca57bbfb0724945
scope.9.id=function:market_view_controls.reset_market_preview:67
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=78
scope.9.semanticHash=9b31fc4c458dcaa9
scope.10.id=function:_set_page_arrow:94
scope.10.kind=function
scope.10.startLine=94
scope.10.endLine=98
scope.10.semanticHash=ade3e2b4f82408d3
scope.11.id=function:_refresh_tab_gray:100
scope.11.kind=function
scope.11.startLine=100
scope.11.endLine=105
scope.11.semanticHash=eab38570714f49ed
scope.12.id=function:_refresh_market_controls:107
scope.12.kind=function
scope.12.startLine=107
scope.12.endLine=116
scope.12.semanticHash=8c85b875b1f44bcf
scope.13.id=function:market_view_controls.apply_market_common_controls:118
scope.13.kind=function
scope.13.startLine=118
scope.13.endLine=122
scope.13.semanticHash=3a68931916509cdf
scope.14.id=function:market_view_controls.close_market_panel:134
scope.14.kind=function
scope.14.startLine=134
scope.14.endLine=147
scope.14.semanticHash=e538291d6797f960
]]
