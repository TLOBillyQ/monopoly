local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local ui_touch_policy_runtime = require("src.ui.input.touch")

local panel_controls = {}

local function _set_visible_many(ui, names, visible)
  for _, name in ipairs(names or {}) do
    ui:set_visible(name, visible)
  end
end

function panel_controls.apply_base_non_player_visibility(ui, visible)
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

function panel_controls.render_auto_controls_for_role(ui, ctx, ui_model, ui_touch_policy)
  assert(ui ~= nil, "missing ui")
  local controls = _resolve_auto_controls(ui)
  local panel = ui_model and ui_model.panel or nil
  _apply_auto_label(ui, panel, ctx.display_player_id)
  _show_auto_controls(ui, controls)
  ui_touch_policy.set_auto_controls_touch(ui, _is_player_role(ctx), controls)
end

function panel_controls.is_base_non_player_visible(ui, ctx)
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

function panel_controls.apply_auto_effect(ui, ui_model, ctx)
  ui:set_visible(base_nodes.auto_effect, _resolve_auto_effect_visible(ui_model, ctx))
  ui:set_touch_enabled(base_nodes.auto_effect, false)
end

local function _resolve_countdown_visible(panel)
  if panel and panel.countdown_visible ~= nil then
    return panel.countdown_visible == true
  end
  return true
end

function panel_controls.apply_countdown(ui, panel)
  local visible = _resolve_countdown_visible(panel)
  ui:set_visible(base_nodes.countdown, visible)
  ui:set_visible(base_nodes.countdown_line, visible)
  ui:set_label(base_nodes.countdown, panel.turn_label or "")
end

function panel_controls.apply_action_hint(ui, panel)
  if panel.no_action_visible == true then
    ui:set_visible(base_nodes.action_hint, true)
  end
end

local function _is_optional_action_choice(choice)
  local kind = choice and choice.kind or nil
  return (kind == "item_phase_passive" or kind == "landing_optional_effect")
    and choice.allow_cancel ~= false
end

local function _set_button_label(ui, name, text)
  if ui.set_button then
    ui:set_button(name, text)
    return
  end
  if ui.set_label then
    ui:set_label(name, text)
  end
end

function panel_controls.apply_base_action_controls(ui, ui_model, base_visible)
  local end_visible = base_visible == true
    and _is_optional_action_choice(ui_model and ui_model.choice) == true
  local action_visible = base_visible == true and not end_visible
  ui:set_visible(base_nodes.action_button, action_visible)
  ui:set_touch_enabled(base_nodes.action_button, action_visible)
  ui:set_visible(base_nodes.end_button, end_visible)
  ui:set_touch_enabled(base_nodes.end_button, end_visible)
  if end_visible then
    _set_button_label(ui, base_nodes.end_button, "结束")
  end
end

function panel_controls.resolve_skin_entry_visible(ui_model, ctx)
  local current_player_id = role_id_utils.normalize(ui_model.current_player_id)
  if current_player_id == nil then
    return false
  end
  return ctx.can_operate ~= true
end

function panel_controls.apply_skin_entry_visibility(ui, visible)
  local value = visible == true
  ui:set_visible(base_nodes.skin_button, value)
  ui:set_visible(base_nodes.skin_label, value)
  ui:set_touch_enabled(base_nodes.skin_button, value)
  ui:set_touch_enabled(base_nodes.skin_label, false)
  ui_touch_policy_runtime.set_many_touch_enabled(ui, base_nodes.skin_effect_nodes, false)
end

return panel_controls
