local role_context = require("src.ui.view.role_context")
local role_id_utils = require("src.foundation.identity")
local panel_cash_delta = require("src.ui.render.widgets.cash_delta")
local panel_player_slots = require("src.ui.render.widgets.player_slots")
local panel_controls = require("src.ui.render.widgets.panel_controls")
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
  panel_controls.apply_action_hint(ui, panel)
  panel_controls.apply_base_action_controls(ui, ui_model, base_visible)
  _item_slot_opts.role_id = ctx.role_id
  _item_slot_opts.display_player_id = ctx.display_player_id
  _item_slot_opts.allow_interact = base_visible
  refresh_item_slots(state, ui_model, _item_slot_opts)
  panel_controls.render_auto_controls_for_role(ui, ctx, ui_model, ui_touch_policy)
  return ctx
end

local function _resolve_ui_touch_policy(state, deps)
  return deps.ui_touch_policy
    or state and state.presentation_runtime and state.presentation_runtime.ui_touch_policy
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
  local image = runtime_assets.empty_image({
    refs = state and state.ui_refs or nil,
  })
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

local function _ensure_item_slot_cache(ui)
  if type(ui.item_slot_item_ids_by_role) ~= "table" then
    ui.item_slot_item_ids_by_role = {}
  end
end

local function _sync_item_slot_ids_for_current_player(ui, ui_model)
  local current_player_id = role_id_utils.normalize(ui_model.current_player_id)
  local by_role = ui.item_slot_item_ids_by_role
  local cached = current_player_id and by_role and role_id_utils.read(by_role, current_player_id)
  ui.item_slot_item_ids = cached or {}
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
  _ensure_item_slot_cache(ui)
  _refresh_all_roles(state, ui_model, runtime, panel, refresh_item_slots, ui_touch_policy, players)
  runtime.set_client_role(nil)
  _sync_item_slot_ids_for_current_player(ui, ui_model)
end
return panel_presenter

--[[ mutate4lua-manifest
version=2
projectHash=01b96e3608673565
scope.0.id=chunk:src/ui/render/widgets/presenter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=390183f65a7ba024
scope.0.lastMutatedAt=2026-06-23T03:24:37Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:_refresh_for_role:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=31
scope.1.semanticHash=ed0f7f9c3f6b916a
scope.1.lastMutatedAt=2026-06-23T03:24:37Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=12
scope.1.lastMutationKilled=12
scope.2.id=function:_resolve_ui_touch_policy:33
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=37
scope.2.semanticHash=89e782582dd35cd6
scope.2.lastMutatedAt=2026-06-23T03:24:37Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_resolve_refresh_deps:39
scope.3.kind=function
scope.3.startLine=39
scope.3.endLine=45
scope.3.semanticHash=2872f274c9b75ea8
scope.3.lastMutatedAt=2026-06-23T03:24:37Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_empty_avatar_key:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=51
scope.4.semanticHash=eff866e7f5a6ff25
scope.4.lastMutatedAt=2026-06-23T03:24:37Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:_panel_players:53
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=56
scope.5.semanticHash=89f04736b950ef4b
scope.5.lastMutatedAt=2026-06-23T03:24:37Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_ensure_item_slot_cache:73
scope.6.kind=function
scope.6.startLine=73
scope.6.endLine=77
scope.6.semanticHash=78986820dbc53b22
scope.6.lastMutatedAt=2026-06-23T03:24:37Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:_sync_item_slot_ids_for_current_player:79
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=84
scope.7.semanticHash=78144eb253fd51c7
scope.7.lastMutatedAt=2026-06-23T03:24:37Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:_refresh_all_roles:101
scope.8.kind=function
scope.8.startLine=101
scope.8.endLine=117
scope.8.semanticHash=b88e1b7a2df6ce5b
scope.8.lastMutatedAt=2026-06-23T03:24:37Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:panel_presenter.refresh:119
scope.9.kind=function
scope.9.startLine=119
scope.9.endLine=135
scope.9.semanticHash=8acbb88d353b62a7
scope.9.lastMutatedAt=2026-06-23T03:24:37Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=13
scope.9.lastMutationKilled=13
]]
