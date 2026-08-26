local role_context = require("src.ui.view.role_context")
local panel_cash_delta = require("src.ui.render.widgets.cash_delta")
local panel_player_slots = require("src.ui.render.widgets.player_slots")
local panel_controls = require("src.ui.render.widgets.panel_controls")
local market_view_controls = require("src.ui.render.market.controls")
local ui_touch_policy_runtime = require("src.ui.input.touch")
local runtime_assets = require("src.config.runtime_assets")

local panel_presenter = {}
local _role_ctx_opts = {}
local _item_slot_opts = {}

local function _refresh_for_role(state, ui_model, runtime, role, panel, refresh_item_slots, ui_touch_policy)
  local ui = state.ui
  _role_ctx_opts.runtime = runtime
  local ctx = role_context.resolve(role, ui_model, _role_ctx_opts)
  local base_visible = panel_controls.is_base_non_player_visible(ui, ctx)
  panel_controls.apply_base_non_player_visibility(ui, base_visible)
  local skin_visible = panel_controls.resolve_skin_entry_visible(ui_model, ctx)
  panel_controls.apply_skin_entry_visibility(ui, skin_visible)
  panel_player_slots.force_item_slots_visible_for_player(ui, ctx)
  panel_controls.apply_auto_effect(ui, ui_model, ctx)
  panel_controls.apply_countdown(ui, panel)
  -- 黑市打开期间整帧渲染不走每秒滴答的窄路,黑市屏倒计时在这里同步首帧与脏渲染
  market_view_controls.apply_market_countdown(ui, panel.turn_label, panel.countdown_visible)
  panel_controls.apply_action_hint(ui, panel)
  panel_controls.apply_base_action_controls(ui, ui_model, base_visible,
    panel_controls.is_base_cancel_allowed(ui, ctx))
  _item_slot_opts.role_id = ctx.role_id
  _item_slot_opts.display_player_id = ctx.display_player_id
  _item_slot_opts.allow_interact = panel_controls.is_slot_touch_allowed(ui)
  refresh_item_slots(state, ui_model, _item_slot_opts)
  panel_controls.render_auto_controls_for_role(ui, ctx, ui_model, ui_touch_policy)
  return ctx
end

local function _resolve_presentation_runtime_policy(state)
  return state and state.presentation_runtime and state.presentation_runtime.ui_touch_policy
end

local function _resolve_ui_touch_policy(state, deps)
  return deps.ui_touch_policy
    or _resolve_presentation_runtime_policy(state)
    or ui_touch_policy_runtime
end

local function _resolve_refresh_deps(state, deps)
  local runtime = assert(deps.runtime, "missing deps.runtime")
  local refresh_item_slots = assert(deps.refresh_item_slots, "missing deps.refresh_item_slots")
  local ui_touch_policy = _resolve_ui_touch_policy(state, deps)
  assert(ui_touch_policy, "missing deps.ui_touch_policy")
  return runtime, refresh_item_slots, ui_touch_policy
end

local function _empty_avatar_key(state)
  local image = runtime_assets.empty_image(runtime_assets.asset_context(state))
  return image.image_key
end

local function _panel_players(ui_model)
  local board = ui_model.board or {}
  return board.players or {}
end

local function _render_player_slots(ui, runtime, panel, empty_avatar_key)
  local player_rows = panel.player_rows or {}
  for i = 1, 4 do
    panel_player_slots.render_player_slot(
      ui,
      runtime,
      player_rows[i],
      i,
      empty_avatar_key,
      panel_cash_delta.refresh_cash_delta_label
    )
  end
  panel_player_slots.refresh_player_crowns(ui, player_rows)
end

local _rar_state
local _rar_ui_model
local _rar_runtime
local _rar_panel
local _rar_refresh_item_slots
local _rar_ui_touch
local _rar_players

local function _refresh_all_roles_callback(role)
  _refresh_for_role(_rar_state, _rar_ui_model, _rar_runtime, role, _rar_panel, _rar_refresh_item_slots, _rar_ui_touch)
  for i = 1, 4 do
    panel_player_slots.apply_player_colors(role, _rar_runtime, _rar_players[i], i)
  end
end

local function _refresh_all_roles(state, ui_model, runtime, panel, refresh_item_slots, ui_touch_policy, players)
  _rar_state = state
  _rar_ui_model = ui_model
  _rar_runtime = runtime
  _rar_panel = panel
  _rar_refresh_item_slots = refresh_item_slots
  _rar_ui_touch = ui_touch_policy
  _rar_players = players
  runtime.for_each_role_or_global(_refresh_all_roles_callback)
  _rar_state = nil
  _rar_ui_model = nil
  _rar_runtime = nil
  _rar_panel = nil
  _rar_refresh_item_slots = nil
  _rar_ui_touch = nil
  _rar_players = nil
end

function panel_presenter.refresh(state, ui_model, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(ui_model ~= nil and ui_model.panel ~= nil, "missing ui_model.panel")
  assert(deps ~= nil, "missing deps")
  local runtime, refresh_item_slots, ui_touch_policy = _resolve_refresh_deps(state, deps)
  local ui = state.ui
  local panel = ui_model.panel
  local players = _panel_players(ui_model)
  local empty_avatar_key = _empty_avatar_key(state)
  runtime.set_client_role(nil)
  panel_cash_delta.ensure_state(ui)
  _render_player_slots(ui, runtime, panel, empty_avatar_key)
  _refresh_all_roles(state, ui_model, runtime, panel, refresh_item_slots, ui_touch_policy, players)
  runtime.set_client_role(nil)
end
return panel_presenter

--[[ mutate4lua-manifest
version=4
projectHash=55101cc35f616faf
scope.0.id=chunk:src/ui/render/widgets/presenter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=129
scope.0.semanticHash=f19110b378a991d2
scope.1.id=function:_refresh_for_role
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=35
scope.1.semanticHash=61060765d3a18758
scope.2.id=function:_resolve_presentation_runtime_policy
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=39
scope.2.semanticHash=4124418157cabcda
scope.3.id=function:_resolve_ui_touch_policy
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=45
scope.3.semanticHash=bb977adce035f3a9
scope.4.id=function:_resolve_refresh_deps
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=53
scope.4.semanticHash=2c40060cb933b202
scope.5.id=function:_empty_avatar_key
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=58
scope.5.semanticHash=9c6021e57ee5f072
scope.6.id=function:_panel_players
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=63
scope.6.semanticHash=778936289f68dba7
scope.7.id=function:_render_player_slots
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=78
scope.7.semanticHash=01eb3ac787756047
scope.8.id=function:_refresh_all_roles_callback
scope.8.kind=function
scope.8.startLine=88
scope.8.endLine=93
scope.8.semanticHash=eff7a5211d3a5490
scope.9.id=function:_refresh_all_roles
scope.9.kind=function
scope.9.startLine=95
scope.9.endLine=111
scope.9.semanticHash=027a64eac0465f87
scope.10.id=function:panel_presenter.refresh
scope.10.kind=function
scope.10.startLine=113
scope.10.endLine=127
scope.10.semanticHash=34c8eedcdbaba0cd
]]
