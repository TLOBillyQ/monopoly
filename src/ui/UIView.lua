local market_view = require("src.ui.MarketView")
local board_view = require("src.ui.BoardView")
local market_ui = require("src.ui.MarketLayout")
local ui_aliases = require("src.ui.UIAliases")
local ui_events = require("src.ui.UIEvents")
local logger = require("src.core.Logger")

local ui_view = {}

local CANVAS_BASE = "基础屏"
local CANVAS_CHOICE = "通用选择屏"
local CANVAS_MARKET = "黑市屏"
local CANVAS_POPUP = "弹窗屏"
local CANVAS_DEBUG = "调试屏"
local unmapped_role_warned = {}

local function _set_client_role(role)
  if not UIManager then
    return
  end
  UIManager.client_role = role
end

local function _resolve_role_id(role)
  if not role or not role.get_roleid then
    return nil
  end
  local ok, role_id = pcall(role.get_roleid)
  if not ok then
    return nil
  end
  return role_id
end

local function _with_client_role(role, fn)
  _set_client_role(role)
  local ok, err = pcall(fn)
  _set_client_role(nil)
  if not ok then
    error(err)
  end
end

local function _for_each_role_or_global(fn)
  local roles = all_roles
  if roles and #roles > 0 then
    for _, role in ipairs(roles) do
      _with_client_role(role, function()
        fn(role)
      end)
    end
    return
  end
  _with_client_role(nil, function()
    fn(nil)
  end)
end

local function _resolve_role_render_ctx(role, ui_model)
  local current_player_id = ui_model and ui_model.current_player_id or nil
  local role_id = _resolve_role_id(role)
  local by_player = ui_model and ui_model.item_slots_by_player or nil
  local mapped = role_id ~= nil and by_player ~= nil and by_player[role_id] ~= nil
  if role_id == nil and role == nil then
    return {
      role_id = nil,
      display_player_id = current_player_id,
      can_operate = true,
      is_player_role = true,
    }
  end
  if mapped then
    return {
      role_id = role_id,
      display_player_id = role_id,
      can_operate = role_id == current_player_id,
      is_player_role = true,
    }
  end
  if role_id ~= nil and not unmapped_role_warned[role_id] then
    unmapped_role_warned[role_id] = true
    logger.warn(
      "role->player 映射失败，按观战回退:",
      "role_id=" .. tostring(role_id),
      "current_player_id=" .. tostring(current_player_id)
    )
  end
  return {
    role_id = role_id,
    display_player_id = current_player_id,
    can_operate = false,
    is_player_role = false,
  }
end

local function _query_node(name)
  assert(name ~= nil, "missing ui node name")
  local resolved = ui_aliases.resolve(name)
  local list = UIManager.query_nodes_by_name(resolved)
  assert(list ~= nil and list[1] ~= nil, "missing ui node: " .. tostring(name))
  return list[1]
end

local function _set_node_texture_keep_size(node, image_key)
  assert(node ~= nil, "missing image node")
  assert(image_key ~= nil, "missing image key")
  if node.set_texture_keep_size then
    node:set_texture_keep_size(image_key)
    return
  end
  node.image_texture = image_key
end

local function set_item_slot_image(slot_name, image_key)
  assert(slot_name ~= nil, "missing slot name")
  assert(image_key ~= nil, "missing image key for slot: " .. tostring(slot_name))
  local resolved = ui_aliases.resolve(slot_name)
  local nodes = UIManager.query_nodes_by_name(resolved)
  assert(nodes ~= nil and nodes[1] ~= nil, "missing ui nodes for slot: " .. tostring(slot_name))
  for _, node in ipairs(nodes) do
    _set_node_texture_keep_size(node, image_key)
  end
end

local function _resolve_popup_image_key(state, payload)
  if not payload then
    return nil
  end
  if payload.image_key ~= nil then
    return payload.image_key
  end
  local image_ref = payload.image_ref
  if image_ref == nil then
    return nil
  end
  local refs = state and state.ui_refs
  if not refs then
    return nil
  end
  return refs[tostring(image_ref)] or refs[image_ref]
end

local function _set_popup_card_image(state, payload)
  local ui = state and state.ui
  if not ui or not ui.popup or not ui.popup.card then
    return
  end
  local card_name = ui.popup.card
  local card_node = ui.query_node(card_name)
  local image_key = _resolve_popup_image_key(state, payload)
  if image_key ~= nil then
    _set_node_texture_keep_size(card_node, image_key)
    ui:set_visible(card_name, true)
    return
  end
  local refs = state and state.ui_refs or nil
  local empty_key = refs and refs["空"] or nil
  if empty_key ~= nil then
    _set_node_texture_keep_size(card_node, empty_key)
  end
  ui:set_visible(card_name, false)
end

local function _set_text(_, name, text)
  local node = _query_node(name)
  node.text = text or ""
end

local function _set_visible(_, name, visible)
  local node = _query_node(name)
  node.visible = visible == true
end

local function _set_touch_enabled(_, name, enabled)
  local node = _query_node(name)
  node.disabled = not enabled
end

local function _set_debug_log(_, text)
  _set_text(nil, "日志", text)
end

local function _set_debug_visible(ui, visible)
  if ui then
    ui.debug_visible = visible == true
  end
  _set_visible(nil, CANVAS_DEBUG, visible)
end

local function _switch_canvas(ui, target)
  assert(ui ~= nil, "missing ui state")
  local target_name = target or CANVAS_BASE
  for _, name in ipairs(ui_events.canvas_names) do
    local keep_debug = name == CANVAS_DEBUG and ui.debug_visible == true
    if name ~= CANVAS_BASE and name ~= target_name and not keep_debug then
      local hide_event = ui_events.hide[name]
      if hide_event then
        ui_events.send_to_all(hide_event, {})
      end
    end
  end
  local base_event = ui_events.show[CANVAS_BASE]
  if base_event then
    ui_events.send_to_all(base_event, {})
  end
  if target_name ~= CANVAS_BASE then
    local target_event = ui_events.show[target_name]
    if target_event then
      ui_events.send_to_all(target_event, {})
    end
  end
end

local function _apply_base_non_player_visibility(ui, visible)
  local value = visible == true
  local base_nodes = ui and ui.base_hidden_nodes or {}
  local base_labels = ui and ui.base_hidden_labels or {}
  for _, name in ipairs(base_nodes) do
    ui:set_visible(name, value)
  end
  for _, name in ipairs(base_labels) do
    ui:set_visible(name, value)
  end
end

local function _render_auto_controls_for_role(ui, role_ctx, ui_model)
  local controls = ui and ui.auto_control_nodes or { "托管按钮", "自动控制按钮" }
  local auto_enabled = role_ctx and role_ctx.is_player_role == true
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
    ui:set_touch_enabled(name, auto_enabled)
  end
end

local function _is_base_non_player_visible(ui, role_ctx)
  if ui and ui.input_blocked then
    return false
  end
  return role_ctx and role_ctx.can_operate == true
end

function ui_view.build_ui_state()
  local item_slots = {
    "道具槽位1",
    "道具槽位2",
    "道具槽位3",
    "道具槽位4",
    "道具槽位5",
  }
  local base_hidden_nodes = { "行动按钮" }
  for _, name in ipairs(item_slots) do
    table.insert(base_hidden_nodes, name)
  end
  return {
    auto_play = false,
    auto_interval = 0.1,
    input_blocked = false,
    debug_visible = false,
    item_slots = item_slots,
    base_hidden_nodes = base_hidden_nodes,
    base_hidden_labels = {
      "倒计时",
    },
    auto_control_nodes = {
      "托管按钮",
      "自动控制按钮",
    },
    market_active = false,
    choice = {
      root = "通用选择屏",
      title = "通用选择_标题",
      body = "通用选择_正文",
      cancel = "通用选择_取消",
      option_buttons = {
        "通用选择_选项_01",
        "通用选择_选项_02",
        "通用选择_选项_03",
        "通用选择_选项_04",
        "通用选择_选项_05",
        "通用选择_选项_06",
      },
    },
    popup = {
      root = "弹窗屏",
      title = "弹窗标题",
      body = "弹窗正文",
      confirm = "弹窗确认",
      card = "弹窗卡牌",
    },
    popup_seq = 0,
    popup_return_canvas = nil,
    item_slot_item_ids_by_role = {},
    query_node = _query_node,
    set_label = _set_text,
    set_button = _set_text,
    set_visible = _set_visible,
    set_touch_enabled = _set_touch_enabled,
    set_debug_log = _set_debug_log,
    set_debug_visible = _set_debug_visible,
  }
end

function ui_view.init_ui_assets(state)
  assert(state ~= nil, "missing state")
  local refs = require("Config.RuntimeRefs")
  state.ui_refs = refs

  _for_each_role_or_global(function()
    for i = 1, 5 do
      local num = 3000 + i
      local image_key = refs[tostring(num)]
      assert(image_key ~= nil, "missing item icon: " .. tostring(num))
      set_item_slot_image("道具槽位" .. tostring(i), image_key)
    end
  end)
end

function ui_view.refresh_panel(state, ui_model)
  local ui = state.ui
  local panel = assert(ui_model.panel, "missing ui_model.panel")

  _set_client_role(nil)
  local player_rows = panel.player_rows or {}
  for i = 1, 4 do
    local row = player_rows[i]
    assert(row ~= nil, "missing player row: " .. tostring(i))
    ui:set_label("玩家" .. tostring(i) .. "名字", row.name)
    ui:set_label("玩家" .. tostring(i) .. "现金", row.cash)
    ui:set_label("玩家" .. tostring(i) .. "地块数量", row.land_count)
    ui:set_label("玩家" .. tostring(i) .. "总资产", row.total_assets)
  end

  if type(ui.item_slot_item_ids_by_role) ~= "table" then
    ui.item_slot_item_ids_by_role = {}
  end

  _for_each_role_or_global(function(role)
    local ctx = _resolve_role_render_ctx(role, ui_model)
    local base_visible = _is_base_non_player_visible(ui, ctx)
    _apply_base_non_player_visibility(ui, base_visible)

    ui:set_label("倒计时", panel.turn_label)
    ui:set_touch_enabled("行动按钮", base_visible)
    ui_view.refresh_item_slots(state, ui_model, {
      role_id = ctx.role_id,
      display_player_id = ctx.display_player_id,
      allow_interact = base_visible,
    })
    _render_auto_controls_for_role(ui, ctx, ui_model)
  end)
  _set_client_role(nil)

  local current_player_id = ui_model.current_player_id
  local by_role = ui.item_slot_item_ids_by_role
  if current_player_id and by_role and by_role[current_player_id] then
    ui.item_slot_item_ids = by_role[current_player_id]
  else
    ui.item_slot_item_ids = {}
  end
end

function ui_view.refresh_turn_label(state, label_text)
  local ui = state.ui
  if not ui or not ui.set_label then
    return
  end
  _for_each_role_or_global(function()
    ui:set_label("倒计时", label_text)
  end)
  _set_client_role(nil)
end

function ui_view.refresh_item_slots(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}

  local slots = ui.item_slots
  local item_ids = {}
  local role_id = opts.role_id
  local display_player_id = opts.display_player_id or ui_model.current_player_id
  local allow_interact = opts.allow_interact ~= false
  local by_player = ui_model.item_slots_by_player or {}
  local items = by_player[display_player_id] or ui_model.item_slots or {}
  local allow_use = ui_model and ui_model.choice and ui_model.choice.kind == "item_phase_choice"
  local choice_owner_id = ui_model and ui_model.item_choice_owner_id or ui_model.current_player_id
  local refs = state.ui_refs
  local empty_key = refs["空"]
  local allow_slot_click = allow_use == true
    and allow_interact == true
    and display_player_id ~= nil
    and choice_owner_id == display_player_id

  for i, slot_name in ipairs(slots) do
    local item_id = items[i]
    if item_id then
      local ref_key = refs[tostring(item_id)] or refs[item_id]
      local image_key = ref_key or empty_key
      set_item_slot_image(slot_name, image_key)
      ui:set_touch_enabled(slot_name, allow_slot_click)
      item_ids[i] = item_id
    else
      set_item_slot_image(slot_name, empty_key)
      ui:set_touch_enabled(slot_name, false)
    end
  end

  if role_id ~= nil then
    if type(ui.item_slot_item_ids_by_role) ~= "table" then
      ui.item_slot_item_ids_by_role = {}
    end
    ui.item_slot_item_ids_by_role[role_id] = item_ids
  end
  ui.item_slot_item_ids = item_ids
end

function ui_view.apply_input_lock(state)
  local ui = state.ui
  if not ui or not ui.set_touch_enabled then
    return
  end

  if not ui.input_blocked then
    if ui.popup_active and ui.popup and ui.popup.confirm then
      ui:set_touch_enabled(ui.popup.confirm, true)
    end
    return
  end

  local model = state.ui_model or {}
  _for_each_role_or_global(function(role)
    local ctx = _resolve_role_render_ctx(role, model)
    _apply_base_non_player_visibility(ui, false)
    _render_auto_controls_for_role(ui, ctx, model)
  end)
  _set_client_role(nil)

  ui:set_touch_enabled("行动按钮", false)

  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_touch_enabled(slot_name, false)
  end

  if ui.choice then
    local option_nodes = ui.choice.option_buttons or {}
    for _, name in ipairs(option_nodes) do
      ui:set_touch_enabled(name, false)
    end
    if ui.choice.cancel then
      ui:set_touch_enabled(ui.choice.cancel, false)
    end
  end

  local market_buttons = market_ui.item_buttons or {}
  for _, name in ipairs(market_buttons) do
    ui:set_touch_enabled(name, false)
  end
  if market_ui.confirm_button then
    ui:set_touch_enabled(market_ui.confirm_button, false)
  end
  if market_ui.cancel_button then
    ui:set_touch_enabled(market_ui.cancel_button, false)
  end

  if ui.popup and ui.popup.confirm then
    ui:set_touch_enabled(ui.popup.confirm, false)
  end
end

function ui_view.render(state, ui_model, log_once, build_log_prefix)
  ui_view.refresh_panel(state, ui_model)
  board_view.refresh_board(state, ui_model, log_once, build_log_prefix)
end

function ui_view.set_debug_log(state, text)
  local ui = state and state.ui
  if not ui or not ui.set_debug_log then
    return
  end
  ui:set_debug_log(text or "")
end

function ui_view.set_debug_visible(state, visible)
  local ui = state and state.ui
  if not ui or not ui.set_debug_visible then
    return
  end
  ui:set_debug_visible(visible == true)
end

function ui_view.select_market_option(state, option_id)
  if not option_id then
    logger.warn("select_market_option missing option_id")
    return
  end
  market_view.select_market_option(state, option_id)
end

local function _open_market_panel(state, choice, choice_id, market)
  _switch_canvas(state.ui, CANVAS_MARKET)
  if state.ui.choice_active then
    state.ui:set_visible(state.ui.choice.root, false)
    state.ui.choice_active = false
  end
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = state.pending_choice_selected_option_id,
  }
  market_view.refresh_market(state, market_payload)
end

local function _open_generic_choice(state, choice, choice_id)
  if state.ui.market_active then
    market_view.close_market_panel(state)
  end

  _switch_canvas(state.ui, CANVAS_CHOICE)
  state.ui:set_label(state.ui.choice.title, choice.title)
  state.ui:set_label(state.ui.choice.body, choice.body)
  state.ui:set_visible(state.ui.choice.root, true)

  local option_nodes = state.ui.choice.option_buttons
  for idx, name in ipairs(option_nodes) do
    local opt = choice.options[idx]
    if opt then
      state.ui:set_button(name, opt.label)
      state.ui:set_visible(name, true)
      state.ui:set_touch_enabled(name, true)
    else
      state.ui:set_visible(name, false)
      state.ui:set_touch_enabled(name, false)
    end
  end

  if not choice.allow_cancel then
    state.ui:set_visible(state.ui.choice.cancel, false)
    state.ui:set_touch_enabled(state.ui.choice.cancel, false)
  else
    state.ui:set_button(state.ui.choice.cancel, choice.cancel_label)
    state.ui:set_visible(state.ui.choice.cancel, true)
    state.ui:set_touch_enabled(state.ui.choice.cancel, true)
  end

  state.ui.choice_active = true
  state.pending_choice_elapsed = 0
  state.pending_choice_id = choice_id
end

function ui_view.open_choice_modal(state, choice, market)
  if not choice then
    logger.warn("open_choice_modal missing choice")
    return
  end
  if not choice.id then
    logger.warn("open_choice_modal missing choice id")
    return
  end
  local choice_id = choice.id
  if state.pending_choice_id == choice_id
      and (state.ui.choice_active or state.ui.market_active) then
    return
  end
  state.ui_dirty = true

  if choice.kind == "market_buy" and market_ui.is_panel_ready() then
    _open_market_panel(state, choice, choice_id, market)
  else
    _open_generic_choice(state, choice, choice_id)
  end
end

function ui_view.close_choice_modal(state)
  if state.ui.choice_active then
    state.ui:set_visible(state.ui.choice.root, false)
    state.ui.choice_active = false
  end
  if state.ui.market_active then
    market_view.close_market_panel(state)
  end
  state.market_choice_option_ids = nil
  state.pending_choice_selected_option_id = nil
  if state.ui.popup_active then
    _switch_canvas(state.ui, CANVAS_POPUP)
  else
    _switch_canvas(state.ui, CANVAS_BASE)
  end
  state.ui_dirty = true
end

function ui_view.push_popup(state, payload)
  assert(payload ~= nil, "missing popup payload")
  if state.ui.market_active then
    state.ui.popup_return_canvas = CANVAS_MARKET
  elseif state.ui.choice_active then
    state.ui.popup_return_canvas = CANVAS_CHOICE
  else
    state.ui.popup_return_canvas = CANVAS_BASE
  end
  _switch_canvas(state.ui, CANVAS_POPUP)
  state.ui:set_label(state.ui.popup.title, payload.title)
  state.ui:set_label(state.ui.popup.body, payload.body)
  state.ui:set_button(state.ui.popup.confirm, payload.button_text or "确认")
  _set_popup_card_image(state, payload)
  state.ui:set_visible(state.ui.popup.root, true)
  state.ui.popup_active = true
  state.ui.popup_payload = payload
  state.ui.popup_seq = state.ui.popup_seq + 1
  state.ui_dirty = true
  return true
end

function ui_view.close_popup(state)
  if not (state.ui and state.ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  state.ui:set_visible(state.ui.popup.root, false)
  state.ui.popup_active = false
  state.ui.popup_payload = nil
  _set_popup_card_image(state, nil)
  local target = state.ui.popup_return_canvas
  state.ui.popup_return_canvas = nil
  if target == CANVAS_MARKET and state.ui.market_active then
    _switch_canvas(state.ui, CANVAS_MARKET)
  elseif target == CANVAS_CHOICE and state.ui.choice_active then
    _switch_canvas(state.ui, CANVAS_CHOICE)
  else
    _switch_canvas(state.ui, CANVAS_BASE)
  end
  state.ui_dirty = true
end

return ui_view
