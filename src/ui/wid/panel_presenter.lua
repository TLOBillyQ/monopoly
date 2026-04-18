local role_context = require("src.ui.pres.role_context")
local base_nodes = require("src.ui.schema.base")
local always_show_nodes = require("src.ui.schema.always_show")
local role_id_utils = require("src.core.utils.role_id")
local panel_cash_delta = require("src.ui.wid.panel_cash_delta")
local panel_player_slots = require("src.ui.wid.panel_player_slots")
local ui_touch_policy_runtime = require("src.ui.input.touch_policy")

local panel_presenter = {}

function panel_presenter.apply_base_non_player_visibility(ui, visible)
  assert(ui ~= nil, "missing ui")
  local value = visible == true
  local hidden_nodes = ui.base_hidden_nodes or {}
  local base_labels = ui.base_hidden_labels or {}
  for _, name in ipairs(hidden_nodes) do
    ui:set_visible(name, value)
  end
  for _, name in ipairs(base_labels) do
    ui:set_visible(name, value)
  end
end
local function _resolve_auto_label(panel, display_player_id)
  local labels_by_player = panel and panel.auto_label_by_player or nil
  if labels_by_player and display_player_id ~= nil then
    return labels_by_player[display_player_id]
  end
  return nil
end

local function _apply_auto_label(ui, panel, display_player_id)
  local auto_label = _resolve_auto_label(panel, display_player_id)
  if not auto_label then
    auto_label = panel and panel.auto_label or nil
  end
  if auto_label and ui.set_label then
    ui:set_label(always_show_nodes.auto_label, auto_label)
  end
end

local function _show_auto_controls(ui, controls)
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
  end
end

function panel_presenter.render_auto_controls_for_role(state, ui, ctx, ui_model, ui_touch_policy)
  assert(ui ~= nil, "missing ui")
  local controls = ui.auto_control_nodes or { always_show_nodes.auto_button, always_show_nodes.auto_label }
  local auto_enabled = ctx and ctx.is_player_role == true or false
  local panel = ui_model and ui_model.panel or nil
  local display_player_id = ctx and ctx.display_player_id or nil
  _apply_auto_label(ui, panel, display_player_id)
  _show_auto_controls(ui, controls)
  ui_touch_policy.set_auto_controls_touch(ui, auto_enabled, controls)
end
function panel_presenter.is_base_non_player_visible(ui, ctx)
  if ui and ui.input_blocked then
    return false
  end
  return ctx and ctx.can_operate == true
end

local function _resolve_auto_effect_visible(ui_model, ctx)
  if not ui_model or not ctx then
    return false
  end
  local role_id = ctx.role_id
  if role_id == nil then
    return false
  end
  if ctx.is_player_role ~= true then
    return false
  end
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
  ui:set_visible(always_show_nodes.auto_effect, _resolve_auto_effect_visible(ui_model, ctx))
  ui:set_touch_enabled(always_show_nodes.auto_effect, false)
end

local function _refresh_for_role(state, ui_model, runtime, role, panel, refresh_item_slots, ui_touch_policy)
  local ui = state.ui
  local ctx = role_context.resolve(role, ui_model, { runtime = runtime })
  local base_visible = panel_presenter.is_base_non_player_visible(ui, ctx)
  panel_presenter.apply_base_non_player_visibility(ui, base_visible)
  panel_player_slots.force_item_slots_visible_for_player(ui, ctx)
  _apply_auto_effect(ui, ui_model, ctx)
  _apply_countdown(ui, panel)
  _apply_action_hint(ui, panel)
  ui:set_touch_enabled(base_nodes.action_button, base_visible)
  refresh_item_slots(state, ui_model, {
    role_id = ctx.role_id,
    display_player_id = ctx.display_player_id,
    allow_interact = base_visible,
  })
  panel_presenter.render_auto_controls_for_role(state, ui, ctx, ui_model, ui_touch_policy)
  return ctx
end

local function _resolve_ui_touch_policy(state, deps)
  return deps.ui_touch_policy
    or state and state.presentation_runtime and state.presentation_runtime.ui_touch_policy
    or ui_touch_policy_runtime
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
  if current_player_id and by_role and role_id_utils.read(by_role, current_player_id) then
    ui.item_slot_item_ids = role_id_utils.read(by_role, current_player_id)
  else
    ui.item_slot_item_ids = {}
  end
end

local function _refresh_all_roles(state, ui_model, runtime, panel, refresh_item_slots, ui_touch_policy, players)
  runtime.for_each_role_or_global(function(role)
    _refresh_for_role(state, ui_model, runtime, role, panel, refresh_item_slots, ui_touch_policy)
    for i = 1, 4 do
      panel_player_slots.apply_player_colors(role, runtime, players[i], i)
    end
  end)
end

function panel_presenter.refresh(state, ui_model, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(ui_model ~= nil and ui_model.panel ~= nil, "missing ui_model.panel")
  assert(deps ~= nil, "missing deps")
  local runtime = assert(deps.runtime, "missing deps.runtime")
  local refresh_item_slots = assert(deps.refresh_item_slots, "missing deps.refresh_item_slots")
  local ui_touch_policy = _resolve_ui_touch_policy(state, deps)
  assert(ui_touch_policy, "missing deps.ui_touch_policy")
  local ui = state.ui
  local panel = ui_model.panel
  local players = ui_model.board and ui_model.board.players or {}
  local refs = state.ui_refs or {}
  local image_refs = refs.images or {}
  local empty_avatar_key = image_refs["Empty"]
  runtime.set_client_role(nil)
  panel_cash_delta.ensure_state(ui)
  _render_player_slots(ui, runtime, panel, empty_avatar_key)
  _ensure_item_slot_cache(ui)
  _refresh_all_roles(state, ui_model, runtime, panel, refresh_item_slots, ui_touch_policy, players)
  runtime.set_client_role(nil)
  _sync_item_slot_ids_for_current_player(ui, ui_model)
end
return panel_presenter
