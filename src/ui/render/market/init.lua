local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local runtime_state = require("src.ui.state.runtime")
local market_view_slots = require("src.ui.render.market.slots")
local market_view_controls = require("src.ui.render.market.controls")
local runtime_ui = require("src.ui.render.runtime_ui")

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
    state.ui_refs or {},
    market_layout.empty_ref_key
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

local function _resolve_cash_display(state)
  local ui = state and state.ui or nil
  if not ui then
    return nil, nil
  end
  local ui_model = runtime_state.get_ui_model(state)
  local amount = ui_model and ui_model.current_player_cash or 0
  return ui, amount
end

function market_view.refresh_cash_display(state)
  local ui, amount = _resolve_cash_display(state)
  if not ui then
    return
  end
  local text = tostring(amount)
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
  local refs = state.ui_refs or {}
  local rendered = market_view_slots.populate_market_slots(ui, refs, options, resolved_deps)
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
version=2
projectHash=58fc4be6f102bccf
scope.0.id=chunk:src/ui/render/market/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=156
scope.0.semanticHash=2965ea90eecc3df4
scope.0.lastMutatedAt=2026-05-31T13:03:23Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=6
scope.0.lastMutationKilled=6
scope.1.id=function:anonymous@12:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=17
scope.1.semanticHash=422bc2daec2eb55b
scope.1.lastMutatedAt=2026-05-31T13:03:23Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:anonymous@18:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=76d869723d99fbda
scope.2.lastMutatedAt=2026-05-31T13:03:23Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:anonymous@21:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=25
scope.3.semanticHash=18f8ebedab49ea39
scope.3.lastMutatedAt=2026-05-31T13:03:23Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:_fallback_modal_state:10
scope.4.kind=function
scope.4.startLine=10
scope.4.endLine=27
scope.4.semanticHash=680c12d60695113a
scope.4.lastMutatedAt=2026-05-31T13:03:23Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:_resolve_deps:29
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=39
scope.5.semanticHash=965fc9270a798048
scope.5.lastMutatedAt=2026-05-31T13:03:23Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:_set_market_preview_icon:41
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=49
scope.6.semanticHash=823c2c1c4bff5237
scope.6.lastMutatedAt=2026-05-31T13:03:23Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:market_view.refresh_market_selection:51
scope.7.kind=function
scope.7.startLine=51
scope.7.endLine=61
scope.7.semanticHash=8e69ec56b9b8a9bd
scope.7.lastMutatedAt=2026-05-31T13:03:23Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:market_view.select_market_option:63
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=75
scope.8.semanticHash=4611ac56235dcf55
scope.8.lastMutatedAt=2026-05-31T13:03:23Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=8
scope.8.lastMutationKilled=8
scope.9.id=function:_resolve_cash_display:77
scope.9.kind=function
scope.9.startLine=77
scope.9.endLine=85
scope.9.semanticHash=712425b284d3a0bb
scope.9.lastMutatedAt=2026-05-31T13:03:23Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=7
scope.9.lastMutationKilled=7
scope.10.id=function:market_view.refresh_cash_display:87
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=103
scope.10.semanticHash=cf9d214414c2e1e5
scope.10.lastMutatedAt=2026-05-31T13:03:23Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=6
scope.10.lastMutationKilled=6
scope.11.id=function:_refresh_empty_market:105
scope.11.kind=function
scope.11.startLine=105
scope.11.endLine=111
scope.11.semanticHash=26801a40fd25e24b
scope.11.lastMutatedAt=2026-05-31T13:03:23Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=5
scope.11.lastMutationKilled=5
scope.12.id=function:_refresh_populated_market:113
scope.12.kind=function
scope.12.startLine=113
scope.12.endLine=128
scope.12.semanticHash=21fb71e7c302f567
scope.12.lastMutatedAt=2026-05-31T13:03:23Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=12
scope.12.lastMutationKilled=12
scope.13.id=function:market_view.refresh_market:130
scope.13.kind=function
scope.13.startLine=130
scope.13.endLine=144
scope.13.semanticHash=1ef6d3e7d464c583
scope.13.lastMutatedAt=2026-05-31T13:03:23Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=13
scope.13.lastMutationKilled=13
scope.14.id=function:market_view.close_market_panel:146
scope.14.kind=function
scope.14.startLine=146
scope.14.endLine=153
scope.14.semanticHash=5200b8c3fa80b2df
scope.14.lastMutatedAt=2026-05-31T13:03:23Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=6
scope.14.lastMutationKilled=6
]]
