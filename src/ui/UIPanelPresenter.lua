local role_context = require("src.ui.UIRoleContext")

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

function panel_presenter.render_auto_controls_for_role(ui, ctx, ui_model)
  assert(ui ~= nil, "missing ui")
  local controls = ui.auto_control_nodes or { "托管按钮", "托管_文本" }
  local auto_enabled = ctx and ctx.is_player_role == true
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
    ui:set_label("托管_文本", auto_label)
  end
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
    if name == "托管按钮" then
      ui:set_touch_enabled(name, auto_enabled)
    else
      ui:set_touch_enabled(name, false)
    end
  end
end

function panel_presenter.is_base_non_player_visible(ui, ctx)
  if ui and ui.input_blocked then
    return false
  end
  return ctx and ctx.can_operate == true
end

local function _resolve_avatar_key(row, empty_avatar_key)
  if row and row.avatar ~= nil then
    return row.avatar
  end
  return empty_avatar_key
end

local function _set_player_avatar(ui, runtime, avatar_name, image_key)
  if image_key == nil then
    return
  end
  local avatar_node = ui.query_node and ui.query_node(avatar_name) or runtime.query_node(avatar_name)
  runtime.set_node_texture_auto_size(avatar_node, image_key)
end

function panel_presenter.refresh(state, ui_model, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(ui_model ~= nil and ui_model.panel ~= nil, "missing ui_model.panel")
  assert(deps ~= nil, "missing deps")
  local runtime = assert(deps.runtime, "missing deps.runtime")
  local refresh_item_slots = assert(deps.refresh_item_slots, "missing deps.refresh_item_slots")
  local ui = state.ui
  local panel = ui_model.panel

  runtime.set_client_role(nil)
  local player_rows = panel.player_rows or {}
  local refs = state.ui_refs or {}
  local empty_avatar_key = refs["空"]
  for i = 1, 4 do
    local row = player_rows[i]
    assert(row ~= nil, "missing player row: " .. tostring(i))
    ui:set_label("玩家" .. tostring(i) .. "名字", row.name)
    ui:set_label("玩家" .. tostring(i) .. "现金", row.cash)
    ui:set_label("玩家" .. tostring(i) .. "地块数量", row.land_count)
    ui:set_label("玩家" .. tostring(i) .. "总资产", row.total_assets)
    local avatar_key = _resolve_avatar_key(row, empty_avatar_key)
    _set_player_avatar(ui, runtime, "玩家" .. tostring(i) .. "头像", avatar_key)
  end

  if type(ui.item_slot_item_ids_by_role) ~= "table" then
    ui.item_slot_item_ids_by_role = {}
  end

  runtime.for_each_role_or_global(function(role)
    local ctx = role_context.resolve(role, ui_model, { runtime = runtime })
    local base_visible = panel_presenter.is_base_non_player_visible(ui, ctx)
    panel_presenter.apply_base_non_player_visibility(ui, base_visible)

    ui:set_visible("倒计时", true)
    ui:set_label("倒计时", panel.turn_label)
    ui:set_touch_enabled("行动按钮", base_visible)
    refresh_item_slots(state, ui_model, {
      role_id = ctx.role_id,
      display_player_id = ctx.display_player_id,
      allow_interact = base_visible,
    })
    panel_presenter.render_auto_controls_for_role(ui, ctx, ui_model)
  end)
  runtime.set_client_role(nil)

  local current_player_id = ui_model.current_player_id
  local by_role = ui.item_slot_item_ids_by_role
  if current_player_id and by_role and by_role[current_player_id] then
    ui.item_slot_item_ids = by_role[current_player_id]
  else
    ui.item_slot_item_ids = {}
  end
end

return panel_presenter
