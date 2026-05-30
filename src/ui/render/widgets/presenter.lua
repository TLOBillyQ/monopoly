local role_context = require("src.ui.view.role_context")
local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local panel_cash_delta = require("src.ui.render.widgets.cash_delta")
local panel_player_slots = require("src.ui.render.widgets.player_slots")
local ui_touch_policy_runtime = require("src.ui.input.touch")

local panel_presenter = {}
local _role_ctx_opts = {}
local _item_slot_opts = {}

local function _set_visible_many(ui, names, visible)
  for _, name in ipairs(names or {}) do
    ui:set_visible(name, visible)
  end
end

local function _apply_base_non_player_visibility(ui, visible)
  assert(ui ~= nil, "missing ui")
  local value = visible == true
  _set_visible_many(ui, ui.base_hidden_nodes, value)
  _set_visible_many(ui, ui.base_hidden_labels, value)
end
local function _resolve_auto_label(panel, display_player_id)
  if panel == nil then
    return nil
  end
  local labels_by_player = panel.auto_label_by_player
  if labels_by_player ~= nil and display_player_id ~= nil then
    local auto_label = labels_by_player[display_player_id]
    if auto_label then
      return auto_label
    end
  end
  return panel.auto_label
end

local function _apply_auto_label(ui, panel, display_player_id)
  local auto_label = _resolve_auto_label(panel, display_player_id)
  if auto_label == nil or not ui.set_label then
    return
  end
  ui:set_label(base_nodes.auto_label, auto_label)
end

local function _show_auto_controls(ui, controls)
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
  end
end

local function _resolve_auto_controls(ui)
  return ui.auto_control_nodes or { base_nodes.auto_button, base_nodes.auto_label }
end

local function _is_player_role(ctx)
  return ctx.is_player_role == true
end

local function _render_auto_controls_for_role(_, ui, ctx, ui_model, ui_touch_policy)
  assert(ui ~= nil, "missing ui")
  local controls = _resolve_auto_controls(ui)
  local panel = ui_model and ui_model.panel or nil
  _apply_auto_label(ui, panel, ctx.display_player_id)
  _show_auto_controls(ui, controls)
  ui_touch_policy.set_auto_controls_touch(ui, _is_player_role(ctx), controls)
end
local function _is_base_non_player_visible(ui, ctx)
  if ui.input_blocked then
    return false
  end
  return ctx.can_operate == true
end

local function _auto_effect_role_id(ctx)
  if ctx.is_player_role ~= true then
    return nil
  end
  return ctx.role_id
end

local function _resolve_auto_effect_visible(ui_model, ctx)
  local role_id = _auto_effect_role_id(ctx)
  if role_id == nil then return false end
  local auto_by_player = ui_model.auto_enabled_by_player or {}
  return role_id_utils.read(auto_by_player, role_id) == true
end

local function _resolve_countdown_visible(panel)
  if panel and panel.countdown_visible ~= nil then
    return panel.countdown_visible == true
  end
  return true
end

local function _apply_countdown(ui, panel)
  local visible = _resolve_countdown_visible(panel)
  ui:set_visible(base_nodes.countdown, visible)
  ui:set_visible(base_nodes.countdown_line, visible)
  ui:set_label(base_nodes.countdown, panel.turn_label or "")
end

local function _apply_action_hint(ui, panel)
  if panel.no_action_visible == true then
    ui:set_visible(base_nodes.action_hint, true)
  end
end

local function _apply_auto_effect(ui, ui_model, ctx)
  ui:set_visible(base_nodes.auto_effect, _resolve_auto_effect_visible(ui_model, ctx))
  ui:set_touch_enabled(base_nodes.auto_effect, false)
end

local function _resolve_skin_entry_visible(ui_model, ctx)
  local current_player_id = role_id_utils.normalize(ui_model.current_player_id)
  if current_player_id == nil then
    return false
  end
  return ctx.can_operate ~= true
end

local function _apply_skin_entry_visibility(ui, visible)
  local value = visible == true
  ui:set_visible(base_nodes.skin_button, value)
  ui:set_visible(base_nodes.skin_label, value)
  ui:set_touch_enabled(base_nodes.skin_button, value)
  ui:set_touch_enabled(base_nodes.skin_label, false)
  ui_touch_policy_runtime.set_many_touch_enabled(ui, base_nodes.skin_effect_nodes, false)
end

local function _refresh_for_role(state, ui_model, runtime, role, panel, refresh_item_slots, ui_touch_policy)
  local ui = state.ui
  _role_ctx_opts.runtime = runtime
  local ctx = role_context.resolve(role, ui_model, _role_ctx_opts)
  local base_visible = _is_base_non_player_visible(ui, ctx)
  _apply_base_non_player_visibility(ui, base_visible)
  local skin_visible = _resolve_skin_entry_visible(ui_model, ctx)
  _apply_skin_entry_visibility(ui, skin_visible)
  panel_player_slots.force_item_slots_visible_for_player(ui, ctx)
  _apply_auto_effect(ui, ui_model, ctx)
  _apply_countdown(ui, panel)
  _apply_action_hint(ui, panel)
  ui:set_touch_enabled(base_nodes.action_button, base_visible)
  _item_slot_opts.role_id = ctx.role_id
  _item_slot_opts.display_player_id = ctx.display_player_id
  _item_slot_opts.allow_interact = base_visible
  refresh_item_slots(state, ui_model, _item_slot_opts)
  _render_auto_controls_for_role(state, ui, ctx, ui_model, ui_touch_policy)
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
  local refs = state.ui_refs or {}
  local image_refs = refs.images or {}
  return image_refs["Empty"]
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
projectHash=6a249a2c8ef1e67b
scope.0.id=chunk:src/ui/render/widgets/presenter.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=256
scope.0.semanticHash=7ebfadeb452c0336
scope.0.lastMutatedAt=2026-05-28T15:29:14Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=11
scope.0.lastMutationKilled=11
scope.1.id=function:_apply_base_non_player_visibility:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=23
scope.1.semanticHash=9078a2efaaabf3ff
scope.1.lastMutatedAt=2026-05-28T15:29:14Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_resolve_auto_label:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=36
scope.2.semanticHash=345047a32f2e537e
scope.2.lastMutatedAt=2026-05-28T15:29:14Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_apply_auto_label:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=44
scope.3.semanticHash=e150ea2cd88c88ec
scope.3.lastMutatedAt=2026-05-28T15:29:14Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:_resolve_auto_controls:52
scope.4.kind=function
scope.4.startLine=52
scope.4.endLine=54
scope.4.semanticHash=d09a451dac757585
scope.4.lastMutatedAt=2026-05-28T15:29:14Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_is_player_role:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=58
scope.5.semanticHash=11fa5f0f413d43c6
scope.5.lastMutatedAt=2026-05-28T15:29:14Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_render_auto_controls_for_role:60
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=67
scope.6.semanticHash=7b26ea4241076269
scope.6.lastMutatedAt=2026-05-28T15:29:14Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:_is_base_non_player_visible:68
scope.7.kind=function
scope.7.startLine=68
scope.7.endLine=73
scope.7.semanticHash=f7e49c14e1c1fecb
scope.7.lastMutatedAt=2026-05-28T15:29:14Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:_auto_effect_role_id:75
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=80
scope.8.semanticHash=650eaefacab9d2c1
scope.8.lastMutatedAt=2026-05-28T15:29:14Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=2
scope.8.lastMutationKilled=2
scope.9.id=function:_resolve_auto_effect_visible:82
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=87
scope.9.semanticHash=810d1a8f5b1b41bf
scope.9.lastMutatedAt=2026-05-28T15:29:14Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=7
scope.9.lastMutationKilled=7
scope.10.id=function:_resolve_countdown_visible:89
scope.10.kind=function
scope.10.startLine=89
scope.10.endLine=94
scope.10.semanticHash=d138d75db44c8e79
scope.10.lastMutatedAt=2026-05-28T15:29:14Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
scope.11.id=function:_apply_countdown:96
scope.11.kind=function
scope.11.startLine=96
scope.11.endLine=101
scope.11.semanticHash=d1e5f4405068ca8b
scope.11.lastMutatedAt=2026-05-28T15:29:14Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=4
scope.11.lastMutationKilled=4
scope.12.id=function:_apply_action_hint:103
scope.12.kind=function
scope.12.startLine=103
scope.12.endLine=107
scope.12.semanticHash=fac4d0e0703640c8
scope.12.lastMutatedAt=2026-05-28T15:29:14Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=2
scope.12.lastMutationKilled=2
scope.13.id=function:_apply_auto_effect:109
scope.13.kind=function
scope.13.startLine=109
scope.13.endLine=112
scope.13.semanticHash=0f3944c5c89e4293
scope.13.lastMutatedAt=2026-05-28T15:29:14Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=2
scope.13.lastMutationKilled=2
scope.14.id=function:_resolve_skin_entry_visible:114
scope.14.kind=function
scope.14.startLine=114
scope.14.endLine=120
scope.14.semanticHash=104aa3253092e8ae
scope.14.lastMutatedAt=2026-05-28T15:29:14Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=5
scope.14.lastMutationKilled=5
scope.15.id=function:_apply_skin_entry_visibility:122
scope.15.kind=function
scope.15.startLine=122
scope.15.endLine=129
scope.15.semanticHash=8f415a4de8d6d557
scope.15.lastMutatedAt=2026-05-28T15:29:14Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=7
scope.15.lastMutationKilled=7
scope.16.id=function:_refresh_for_role:131
scope.16.kind=function
scope.16.startLine=131
scope.16.endLine=150
scope.16.semanticHash=5c0cb41877a8c4c6
scope.16.lastMutatedAt=2026-05-28T15:29:14Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=12
scope.16.lastMutationKilled=12
scope.17.id=function:_resolve_ui_touch_policy:152
scope.17.kind=function
scope.17.startLine=152
scope.17.endLine=156
scope.17.semanticHash=89e782582dd35cd6
scope.17.lastMutatedAt=2026-05-28T15:29:14Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=4
scope.17.lastMutationKilled=4
scope.18.id=function:_resolve_refresh_deps:158
scope.18.kind=function
scope.18.startLine=158
scope.18.endLine=164
scope.18.semanticHash=2872f274c9b75ea8
scope.18.lastMutatedAt=2026-05-28T15:29:14Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=4
scope.18.lastMutationKilled=4
scope.19.id=function:_empty_avatar_key:166
scope.19.kind=function
scope.19.startLine=166
scope.19.endLine=170
scope.19.semanticHash=eff866e7f5a6ff25
scope.19.lastMutatedAt=2026-05-28T15:29:14Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=3
scope.19.lastMutationKilled=3
scope.20.id=function:_panel_players:172
scope.20.kind=function
scope.20.startLine=172
scope.20.endLine=175
scope.20.semanticHash=89f04736b950ef4b
scope.20.lastMutatedAt=2026-05-28T15:29:14Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=2
scope.20.lastMutationKilled=2
scope.21.id=function:_ensure_item_slot_cache:192
scope.21.kind=function
scope.21.startLine=192
scope.21.endLine=196
scope.21.semanticHash=78986820dbc53b22
scope.21.lastMutatedAt=2026-05-28T15:29:14Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=3
scope.21.lastMutationKilled=3
scope.22.id=function:_sync_item_slot_ids_for_current_player:198
scope.22.kind=function
scope.22.startLine=198
scope.22.endLine=203
scope.22.semanticHash=78144eb253fd51c7
scope.22.lastMutatedAt=2026-05-28T15:29:14Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=5
scope.22.lastMutationKilled=5
scope.23.id=function:_refresh_all_roles:220
scope.23.kind=function
scope.23.startLine=220
scope.23.endLine=236
scope.23.semanticHash=b88e1b7a2df6ce5b
scope.23.lastMutatedAt=2026-05-28T15:29:14Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:panel_presenter.refresh:238
scope.24.kind=function
scope.24.startLine=238
scope.24.endLine=254
scope.24.semanticHash=8acbb88d353b62a7
scope.24.lastMutatedAt=2026-05-28T15:29:14Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=13
scope.24.lastMutationKilled=13
]]
