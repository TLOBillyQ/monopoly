local role_context = require("src.presentation.state.UIRoleContext")
local player_colors = require("src.presentation.shared.PlayerColors")
local base_nodes = require("src.presentation.canvas.base.nodes")
local always_show_nodes = require("src.presentation.canvas.always_show.nodes")
local ui_touch_policy = require("src.presentation.interaction.UITouchPolicy")
local role_id_utils = require("src.core.RoleId")

local panel_presenter = {}

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
    local label_names = {
      string.format(base_nodes.player_name, index),
      string.format(base_nodes.player_cash, index),
      string.format(base_nodes.player_land_count, index),
      string.format(base_nodes.player_total_assets, index),
    }
    for _, name in ipairs(label_names) do
      local label_node = runtime.query_node(name)
      pcall(set_label_color, role, label_node, color, 0)
    end
  end
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
  local empty_avatar_key = refs["Empty"]
  for i = 1, 4 do
    local row = player_rows[i]
    assert(row ~= nil, "missing player row: " .. tostring(i))
    ui:set_label(string.format(base_nodes.player_name, i), row.name)
    ui:set_label(string.format(base_nodes.player_cash, i), row.cash)
    ui:set_label(string.format(base_nodes.player_land_count, i), row.land_count)
    ui:set_label(string.format(base_nodes.player_total_assets, i), row.total_assets)
    local avatar_key = _resolve_avatar_key(row, empty_avatar_key)
    _set_player_avatar(ui, runtime, string.format(base_nodes.player_avatar, i), avatar_key)
  end

  if type(ui.item_slot_item_ids_by_role) ~= "table" then
    ui.item_slot_item_ids_by_role = {}
  end

  runtime.for_each_role_or_global(function(role)
    local ctx = role_context.resolve(role, ui_model, { runtime = runtime })
    local base_visible = panel_presenter.is_base_non_player_visible(ui, ctx)
    panel_presenter.apply_base_non_player_visibility(ui, base_visible)
    _force_item_slots_visible_for_player(ui, ctx)
    local auto_effect_visible = _resolve_auto_effect_visible(ui_model, ctx)
    ui:set_visible(always_show_nodes.auto_effect, auto_effect_visible)
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
