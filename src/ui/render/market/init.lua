local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local runtime_state = require("src.ui.state.runtime")
local market_view_slots = require("src.ui.render.market.slots")
local market_view_controls = require("src.ui.render.market.controls")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local runtime_assets = require("src.config.runtime_assets")
local number_utils = require("src.foundation.number")

local market_view = {}

local function _fallback_modal_state()
  return {
    open_market = function(state, choice_id, option_ids, selected_option_id)
      runtime_state.set_pending_choice_id(state, choice_id)
      local ui_runtime = runtime_state.ensure_ui_runtime(state)
      ui_runtime.choice_visible_option_ids = option_ids
      ui_runtime.pending_choice_selected_option_id = selected_option_id
    end,
    select_market_option = function(state, option_id)
      runtime_state.ensure_ui_runtime(state).pending_choice_selected_option_id = option_id
    end,
    close_choice = function(state)
      local ui_runtime = runtime_state.ensure_ui_runtime(state)
      ui_runtime.choice_visible_option_ids = nil
      ui_runtime.pending_choice_selected_option_id = nil
    end,
  }
end

local function _resolve_deps(state, deps)
  if deps then
    return deps
  end
  if state and state.presentation_runtime then
    return state.presentation_runtime
  end
  return {
    runtime = runtime_ui,
  }
end

local function _set_market_preview_icon(state, icon_key, deps)
  if icon_key == nil then
    return
  end
  local resolved_deps = _resolve_deps(state, deps)
  local runtime = assert(resolved_deps.runtime, "missing deps.runtime")
  local ui = state.ui
  runtime.set_node_texture_keep_size(ui.query_node(market_layout.selected_card), icon_key)
end

function market_view.refresh_market_selection(state, option_id, deps)
  local ui = state.ui
  assert(ui ~= nil, "missing market ui")
  local selection = market_view_slots.resolve_selection(
    option_id,
    runtime_assets.asset_context(state)
  )
  ui:set_label(market_layout.price_label, selection.price_text)
  _set_market_preview_icon(state, selection.icon_key, deps)
end

function market_view.select_market_option(state, option_id, deps)
  local resolved_deps = _resolve_deps(state, deps)
  local resolved_modal = resolved_deps.modal_state or _fallback_modal_state()
  resolved_modal.select_market_option(state, option_id)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  market_view_controls.refresh_market_selection_frames(
    state.ui,
    ui_runtime.choice_visible_option_ids,
    option_id
  )
  market_view.refresh_market_selection(state, option_id, resolved_deps)
  market_view_controls.set_confirm_button_state(state.ui, true)
end

local function _current_cash_amount(state)
  local ui_model = runtime_state.get_ui_model(state)
  return ui_model and ui_model.current_player_cash or 0
end

local function _resolve_cash_display(state)
  local ui = state and state.ui or nil
  if not ui then
    return nil, nil
  end
  return ui, _current_cash_amount(state)
end

function market_view.refresh_cash_display(state)
  local ui, amount = _resolve_cash_display(state)
  if not ui then
    return
  end
  local text = number_utils.format_integer_part(amount)
  if ui.set_label then
    ui:set_label(market_layout.cash_text_label, "现金")
    ui:set_label(market_layout.cash_amount_label, text)
  end
  ui_controls.set_controls_state(ui, {
    market_layout.cash_text_label,
    market_layout.cash_amount_label,
    market_layout.cash_icon,
    market_layout.cash_background,
  }, { visible = true, touch_enabled = false })
end

local function _refresh_empty_market(state, market, resolved_deps, resolved_modal, ui)
  market_view_slots.hide_market_slots(ui)
  market_view_controls.reset_market_preview(state, resolved_deps)
  market_view_controls.apply_market_common_controls(ui, market, false)
  resolved_modal.open_market(state, market.choice_id, {}, nil)
  market_view.refresh_cash_display(state)
end

local function _refresh_populated_market(state, market, resolved_deps, resolved_modal, options, ui, was_market_active)
  local rendered = market_view_slots.populate_market_slots(ui, options)
  ui_controls.set_control_state(ui, market_layout.selected_card, { touch_enabled = false })
  market_view_controls.clear_market_selection_frames(ui)
  market_view_controls.apply_market_common_controls(ui, market, true)
  local selected_option_id = was_market_active and market.selected_option_id or nil
  local selected = market_view_slots.resolve_selected_option(
    rendered.option_ids,
    selected_option_id,
    rendered.first_buyable
  )
  resolved_modal.open_market(state, market.choice_id, rendered.option_ids, selected)
  market_view.select_market_option(state, selected, resolved_deps)
  market_view.refresh_cash_display(state)
end

function market_view.refresh_market(state, market, deps)
  local resolved_deps = _resolve_deps(state, deps)
  local resolved_modal = resolved_deps.modal_state or _fallback_modal_state()
  local ui = state.ui
  assert(market ~= nil and market.options ~= nil and ui ~= nil, "missing market data/ui")
  local was_market_active = ui.market_active == true
  local options = market_view_slots.filter_market_options(market.options)
  market_view_controls.set_market_container_active(ui, true)
  if #options == 0 then
    _refresh_empty_market(state, market, resolved_deps, resolved_modal, ui)
  else
    _refresh_populated_market(state, market, resolved_deps, resolved_modal, options, ui, was_market_active)
  end
  return true
end

function market_view.close_market_panel(state, deps)
  local resolved_deps = _resolve_deps(state, deps)
  local resolved_modal = resolved_deps.modal_state or _fallback_modal_state()
  local ui = state.ui
  assert(ui ~= nil and ui.market_active == true, "market panel not active")
  resolved_modal.close_choice(state)
  market_view_controls.close_market_panel(state, resolved_deps)
end

return market_view

--[[ mutate4lua-manifest
version=4
projectHash=fbc2c44969a95969
scope.0.id=chunk:src/ui/render/market/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=159
scope.0.semanticHash=840b42eb137165ea
scope.1.id=function:_fallback_modal_state
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=29
scope.1.semanticHash=dba847b31dd77a4b
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=19
scope.2.semanticHash=bea56b1f12443032
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=22
scope.3.semanticHash=92a7fe8120c81b48
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=27
scope.4.semanticHash=dd071a6e6b4133f9
scope.5.id=function:_resolve_deps
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=41
scope.5.semanticHash=3f2faf6ccffd2eb5
scope.6.id=function:_set_market_preview_icon
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=51
scope.6.semanticHash=8ba51d6c1012f30d
scope.7.id=function:market_view.refresh_market_selection
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=62
scope.7.semanticHash=8d32f33c5ceab044
scope.8.id=function:market_view.select_market_option
scope.8.kind=function
scope.8.startLine=64
scope.8.endLine=76
scope.8.semanticHash=50cc2b4b493cdeea
scope.9.id=function:_current_cash_amount
scope.9.kind=function
scope.9.startLine=78
scope.9.endLine=81
scope.9.semanticHash=1de52c97d509d667
scope.10.id=function:_resolve_cash_display
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=89
scope.10.semanticHash=74891b3208d57539
scope.11.id=function:market_view.refresh_cash_display
scope.11.kind=function
scope.11.startLine=91
scope.11.endLine=107
scope.11.semanticHash=e8e6f9606a73d2fa
scope.12.id=function:_refresh_empty_market
scope.12.kind=function
scope.12.startLine=109
scope.12.endLine=115
scope.12.semanticHash=d973080e73fc3df6
scope.13.id=function:_refresh_populated_market
scope.13.kind=function
scope.13.startLine=117
scope.13.endLine=131
scope.13.semanticHash=ce6ef6c8686fce10
scope.14.id=function:market_view.refresh_market
scope.14.kind=function
scope.14.startLine=133
scope.14.endLine=147
scope.14.semanticHash=3f4caf6fb6e2cd60
scope.15.id=function:market_view.close_market_panel
scope.15.kind=function
scope.15.startLine=149
scope.15.endLine=156
scope.15.semanticHash=641e7d45775e7fab
]]
