local role_context = require("src.presentation.model.ui_role_context")
local player_colors = require("src.presentation.view.support.player_colors")
local base_nodes = require("src.presentation.view.canvas.base.nodes")
local always_show_nodes = require("src.presentation.view.canvas.always_show.nodes")
local ui_touch_policy = require("src.presentation.input.ui_touch_policy")
local role_id_utils = require("src.core.utils.role_id")
local runtime_ports = require("src.core.ports.runtime_ports")
local gameplay_rules = require("src.core.config.gameplay_rules")
local number_utils = require("src.core.utils.number_utils")
local panel_presenter = {}
local player_label_patterns = {
  base_nodes.player_name,
  base_nodes.player_cash,
  base_nodes.player_cash_delta,
  base_nodes.player_land_count,
  base_nodes.player_total_assets,
}
local function _safe_ui_call(ui, method_name, ...)
  if not ui or type(ui[method_name]) ~= "function" then
    return false
  end
  local ok = pcall(ui[method_name], ui, ...)
  return ok
end
local function _set_label_safe(ui, name, value)
  return _safe_ui_call(ui, "set_label", name, value)
end
local function _set_visible_safe(ui, name, visible)
  return _safe_ui_call(ui, "set_visible", name, visible)
end
function panel_presenter.apply_base_non_player_visibility(ui, visible)
  assert(ui ~= nil, "missing ui")
  local value = visible == true
  local base_nodes = ui.base_hidden_nodes or {}
  local base_labels = ui.base_hidden_labels or {}
  for _, name in ipairs(base_nodes) do
    ui:set_visible(name, value)
  end
  for _, name in ipairs(base_labels) do
    ui:set_visible(name, value)
  end
end
function panel_presenter.render_auto_controls_for_role(state, ui, ctx, ui_model)
  assert(ui ~= nil, "missing ui")
  local controls = ui.auto_control_nodes or { always_show_nodes.auto_button, always_show_nodes.auto_label }
  local auto_enabled = ctx and ctx.is_player_role == true or false
  local panel = ui_model and ui_model.panel or nil
  local labels_by_player = panel and panel.auto_label_by_player or nil
  local display_player_id = ctx and ctx.display_player_id or nil
  local auto_label = nil
  if labels_by_player and display_player_id ~= nil then
    auto_label = labels_by_player[display_player_id]
  end
  if not auto_label then
    auto_label = panel and panel.auto_label or nil
  end
  if auto_label and ui.set_label then
    ui:set_label(always_show_nodes.auto_label, auto_label)
  end
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
  end
  local allow_touch = auto_enabled
  ui_touch_policy.set_auto_controls_touch(ui, allow_touch, controls)
end
function panel_presenter.is_base_non_player_visible(ui, ctx)
  if ui and ui.input_blocked then
    return false
  end
  return ctx and ctx.can_operate == true
end
local function _force_item_slots_visible_for_player(ui, ctx)
  if not ui or not ui.set_visible then
    return
  end
  if not ctx or ctx.is_player_role ~= true then
    return
  end
  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_visible(slot_name, true)
  end
end
local function _resolve_avatar_key(row, empty_avatar_key)
  if row and row.avatar ~= nil then
    return row.avatar
  end
  return empty_avatar_key
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
local function _set_player_avatar(ui, runtime, avatar_name, image_key)
  if image_key == nil then
    return
  end
  local avatar_node = ui.query_node and ui.query_node(avatar_name) or runtime.query_node(avatar_name)
  runtime.set_node_texture_native_size(avatar_node, image_key)
end
local function _resolve_integer_field(row, key)
  if not row then
    return nil
  end
  return number_utils.to_integer(row[key])
end
local function _ensure_cash_delta_state(ui)
  if type(ui.player_cash_value_cache_by_index) ~= "table" then
    ui.player_cash_value_cache_by_index = {}
  end
  if type(ui.player_cash_delta_hide_token_by_index) ~= "table" then
    ui.player_cash_delta_hide_token_by_index = {}
  end
end
local function _set_cash_delta_label(ui, index, text, visible)
  local label_name = string.format(base_nodes.player_cash_delta, index)
  local shown = _set_label_safe(ui, label_name, text or "")
  if shown or visible ~= nil then
    _set_visible_safe(ui, label_name, visible == true)
  end
  return shown
end
local function _clear_cash_delta_label(ui, index)
  _set_cash_delta_label(ui, index, "", false)
end
local function _schedule_hide_cash_delta(ui, index)
  local token = (ui.player_cash_delta_hide_token_by_index[index] or 0) + 1
  ui.player_cash_delta_hide_token_by_index[index] = token
  runtime_ports.schedule(gameplay_rules.action_anim_default_seconds or 1.0, function()
    if not ui.player_cash_delta_hide_token_by_index then
      return
    end
    if ui.player_cash_delta_hide_token_by_index[index] ~= token then
      return
    end
    _clear_cash_delta_label(ui, index)
  end)
end
local function _refresh_cash_delta_label(ui, index, row)
  local cash_value = _resolve_integer_field(row, "cash_value")
  local prev_cash_value = ui.player_cash_value_cache_by_index[index]
  if cash_value == nil then
    _clear_cash_delta_label(ui, index)
    ui.player_cash_value_cache_by_index[index] = nil
    return
  end
  if prev_cash_value == nil then
    _clear_cash_delta_label(ui, index)
    ui.player_cash_value_cache_by_index[index] = cash_value
    return
  end
  local delta = cash_value - prev_cash_value
  ui.player_cash_value_cache_by_index[index] = cash_value
  if delta == 0 then
    _clear_cash_delta_label(ui, index)
    return
  end
  local sign = "+"
  if delta < 0 then
    sign = "-"
    delta = -delta
  end
  local text = sign .. number_utils.format_integer_part(delta)
  local shown = _set_cash_delta_label(ui, index, text, true)
  if shown then
    _schedule_hide_cash_delta(ui, index)
  end
end
local function _refresh_player_crowns(ui, player_rows)
  local top_total_assets = nil
  for i = 1, 4 do
    local row = player_rows[i]
    local total_assets_value = _resolve_integer_field(row, "total_assets_value")
    if row and row.eliminated ~= true and total_assets_value ~= nil
        and (top_total_assets == nil or total_assets_value > top_total_assets) then
      top_total_assets = total_assets_value
    end
  end
  for i = 1, 4 do
    local row = player_rows[i]
    local total_assets_value = _resolve_integer_field(row, "total_assets_value")
    local visible = row and row.eliminated ~= true and top_total_assets ~= nil
        and total_assets_value ~= nil and total_assets_value == top_total_assets
    _set_visible_safe(ui, string.format(base_nodes.player_crown, i), visible == true)
  end
end
local function _for_each_player_label_name(index, callback)
  for _, pattern in ipairs(player_label_patterns) do
    callback(string.format(pattern, index))
  end
end
local function _apply_player_colors(role, runtime, player, index)
  if not role then
    return
  end
  local set_image_color = role.set_image_color
  local set_label_color = role.set_label_color
  if not set_image_color and not set_label_color then
    return
  end
  local player_id = player and player.id or nil
  local color = player_colors.resolve_owner_color(player_id)
  if set_image_color then
    local image_node = runtime.query_node(string.format(base_nodes.player_color, index))
    pcall(set_image_color, role, image_node, color, 0)
  end
  if set_label_color then
    _for_each_player_label_name(index, function(name)
      local ok, label_node = pcall(runtime.query_node, name)
      if ok then
        pcall(set_label_color, role, label_node, color, 0)
      end
    end)
  end
end
local function _render_player_slot(ui, runtime, row, index, empty_avatar_key)
  assert(row ~= nil, "missing player row: " .. tostring(index))
  ui:set_label(string.format(base_nodes.player_name, index), row.name)
  ui:set_label(string.format(base_nodes.player_cash, index), row.cash)
  ui:set_label(string.format(base_nodes.player_land_count, index), row.land_count)
  ui:set_label(string.format(base_nodes.player_total_assets, index), row.total_assets)
  _refresh_cash_delta_label(ui, index, row)
  _set_player_avatar(ui, runtime, string.format(base_nodes.player_avatar, index), _resolve_avatar_key(row, empty_avatar_key))
end
local function _render_role_view(state, ui_model, runtime, role, panel, refresh_item_slots)
  local ui = state.ui
  local ctx = role_context.resolve(role, ui_model, { runtime = runtime })
  local base_visible = panel_presenter.is_base_non_player_visible(ui, ctx)
  panel_presenter.apply_base_non_player_visibility(ui, base_visible)
  _force_item_slots_visible_for_player(ui, ctx)
  ui:set_visible(always_show_nodes.auto_effect, _resolve_auto_effect_visible(ui_model, ctx))
  ui:set_touch_enabled(always_show_nodes.auto_effect, false)
  ui:set_visible(base_nodes.countdown, true)
  ui:set_label(base_nodes.countdown, panel.turn_label)
  if panel.no_action_visible == true then
    ui:set_visible(base_nodes.action_hint, true)
  end
  ui:set_touch_enabled(base_nodes.action_button, base_visible)
  refresh_item_slots(state, ui_model, {
    role_id = ctx.role_id,
    display_player_id = ctx.display_player_id,
    allow_interact = base_visible,
  })
  panel_presenter.render_auto_controls_for_role(state, ui, ctx, ui_model)
  return ctx
end
function panel_presenter.refresh(state, ui_model, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(ui_model ~= nil and ui_model.panel ~= nil, "missing ui_model.panel")
  assert(deps ~= nil, "missing deps")
  local runtime = assert(deps.runtime, "missing deps.runtime")
  local refresh_item_slots = assert(deps.refresh_item_slots, "missing deps.refresh_item_slots")
  local ui = state.ui
  local panel = ui_model.panel
  local players = ui_model.board and ui_model.board.players or {}
  runtime.set_client_role(nil)
  local player_rows = panel.player_rows or {}
  local refs = state.ui_refs or {}
  local image_refs = refs.images or {}
  local empty_avatar_key = image_refs["Empty"]
  _ensure_cash_delta_state(ui)
  for i = 1, 4 do
    _render_player_slot(ui, runtime, player_rows[i], i, empty_avatar_key)
  end
  _refresh_player_crowns(ui, player_rows)
  if type(ui.item_slot_item_ids_by_role) ~= "table" then
    ui.item_slot_item_ids_by_role = {}
  end
  runtime.for_each_role_or_global(function(role)
    _render_role_view(state, ui_model, runtime, role, panel, refresh_item_slots)
    for i = 1, 4 do
      _apply_player_colors(role, runtime, players[i], i)
    end
  end)
  runtime.set_client_role(nil)
  local current_player_id = role_id_utils.normalize(ui_model.current_player_id)
  local by_role = ui.item_slot_item_ids_by_role
  if current_player_id and by_role and role_id_utils.read(by_role, current_player_id) then
    ui.item_slot_item_ids = role_id_utils.read(by_role, current_player_id)
  else
    ui.item_slot_item_ids = {}
  end
end
return panel_presenter
