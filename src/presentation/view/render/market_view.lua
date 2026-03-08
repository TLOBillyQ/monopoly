local market_layout = require("src.presentation.view.support.market_layout")
local ui_controls = require("src.presentation.view.support.ui_controls")
local modal_state = require("src.presentation.input.ui_modal_state_coordinator")
local runtime = require("src.presentation.runtime.ui_runtime_port")
local runtime_state = require("src.core.state_access.runtime_state")
local items_cfg = require("Config.generated.items")
local market_cfg = require("Config.generated.market")
local number_utils = require("src.core.utils.number_utils")
local vehicle_catalog = require("src.core.config.vehicle_catalog")

local market_view = {}
local VEHICLE_TAB_ENABLED = false

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local market_by_id = {}
for _, entry in ipairs(market_cfg) do
  market_by_id[entry.product_id] = entry
end

local function _resolve_market_entry(product_id)
  local entry = market_by_id[product_id]
  local cfg = nil
  if entry and entry.kind == "vehicle" then
    cfg = vehicle_catalog.find(product_id)
  else
    cfg = items_by_id[product_id]
  end
  return entry, cfg
end

local function _resolve_market_name(opt, product_id, entry, cfg)
  if entry and entry.name then
    return entry.name
  end
  if cfg and cfg.name then
    return cfg.name
  end
  if opt and opt.label then
    return opt.label
  end
  return tostring(product_id)
end

local function _resolve_market_level(cfg)
  local level = cfg and cfg.tier or 1
  if level < 1 then
    return 1
  end
  if level >= 3 then
    return 3
  end
  return 2
end

local function _resolve_ref_key(refs, key)
  if number_utils.is_numeric(key) then
    return key
  end
  return refs[key]
end

local function _resolve_market_icon_key(refs, product_id, entry, cfg)
  local key = tostring(product_id)
  local ref = refs[key]
  if ref then
    return ref
  end
  -- 允许配置缺失；名字也缺失时返回 nil，交给 UI 空图兜底。
  local name = (cfg and cfg.name) or (entry and entry.name)
  if name == nil or name == "" then
    return nil
  end
  return refs[name]
end

local function _set_market_slot_hidden(ui, button, label, frame)
  ui_controls.set_slot_state(ui, {
    button = button,
    label = label,
    frame = frame,
  }, {
    button = { visible = false, touch_enabled = false },
    label = { visible = false, touch_enabled = false },
    frame = { visible = false, touch_enabled = false },
  })
end

local function _set_market_container_active(ui, active)
  ui_controls.set_control_state(ui, market_layout.container, { visible = active })
  ui.market_active = active == true
end

local function _set_confirm_button_state(ui, enabled)
  ui_controls.set_control_state(ui, market_layout.confirm_button, {
    visible = true,
    touch_enabled = enabled == true,
  })
end

local function _for_each_market_slot(callback)
  local buttons = market_layout.item_buttons
  local labels = market_layout.item_labels
  local frames = market_layout.item_frames
  for idx = 1, math.max(#buttons, #labels, #frames) do
    local button, label, frame = buttons[idx], labels[idx], frames[idx]
    if button and label and frame then
      callback(idx, button, label, frame)
    end
  end
end

local function _hide_market_slots(ui)
  _for_each_market_slot(function(_, button, label, frame)
    _set_market_slot_hidden(ui, button, label, frame)
  end)
end

local function _clear_market_selection_frames(ui)
  ui_controls.set_controls_state(ui, market_layout.item_selection_frames or {}, { visible = false, touch_enabled = false })
end

local function _reset_market_preview(state)
  local ui = state.ui
  ui:set_label(market_layout.price_label, "")
  _clear_market_selection_frames(ui)
  ui_controls.set_control_state(ui, market_layout.selected_card, { touch_enabled = false })

  local image_refs = state.ui_refs and state.ui_refs.images or {}
  local empty_key = _resolve_ref_key(image_refs, market_layout.empty_ref_key)
  if empty_key == nil then
    return
  end

  local node = ui.query_node(market_layout.selected_card)
  runtime.set_node_texture_keep_size(node, empty_key)
end

local function _refresh_market_selection_frames(ui, option_ids, option_id)
  _clear_market_selection_frames(ui)
  if option_id == nil then
    return
  end
  for index, visible_option_id in pairs(option_ids or {}) do
    local name = market_layout.item_selection_frames and market_layout.item_selection_frames[index] or nil
    if visible_option_id == option_id and name then
      ui_controls.set_control_state(ui, name, { visible = true, touch_enabled = false })
      return
    end
  end
end

local function _set_market_slot_visible(ui, refs, slot, opt)
  local opt_id = opt.id or opt
  local entry, cfg = _resolve_market_entry(opt_id)
  local name = _resolve_market_name(opt, opt_id, entry, cfg)
  ui:set_label(slot.label, name)
  ui_controls.set_slot_state(ui, slot, {
    label = { visible = true, touch_enabled = false },
    button = { visible = true, touch_enabled = true },
    frame = { visible = true, touch_enabled = false },
  })
  local level = _resolve_market_level(cfg)
  local rarity_key = _resolve_ref_key(refs, market_layout.rarity_ref_keys[level])
  if rarity_key == nil then
    rarity_key = _resolve_ref_key(refs, market_layout.empty_ref_key)
  end
  if rarity_key ~= nil then
    local node = ui.query_node(slot.frame)
    runtime.set_node_texture_keep_size(node, rarity_key)
  end
  return opt_id
end

local function _contains_option_id(option_ids, option_id)
  for _, value in pairs(option_ids or {}) do
    if value == option_id then
      return option_id ~= nil
    end
  end
  return false
end

local function _set_cancel_controls(ui, visible, enabled)
  local names = market_layout.cancel_buttons
  if type(names) == "table" and #names > 0 then
    ui_controls.set_controls_state(ui, names, { visible = visible, touch_enabled = enabled })
    return
  end
  ui_controls.set_control_state(ui, market_layout.cancel_button, { visible = visible, touch_enabled = enabled })
end

local function _resolve_market_tab(market)
  local tab = market and market.active_tab or nil
  if tab == "item" or tab == "skin" or tab == "vehicle" then
    return tab
  end
  return "item"
end

local function _resolve_market_page_value(market, key)
  local value = number_utils.to_integer(market and market[key]) or 1
  if value < 1 then
    return 1
  end
  return value
end

local function _refresh_market_controls(ui, market)
  local active_tab = _resolve_market_tab(market)
  local page_index = _resolve_market_page_value(market, "page_index")
  local page_count = _resolve_market_page_value(market, "page_count")
  local paging_visible = page_count > 1
  ui_controls.set_control_state(ui, market_layout.page_prev, { visible = paging_visible, touch_enabled = paging_visible and page_index > 1 })
  ui_controls.set_control_state(ui, market_layout.page_next, { visible = paging_visible, touch_enabled = paging_visible and page_index < page_count })
  ui_controls.set_control_state(ui, market_layout.tab_item, { visible = true, touch_enabled = active_tab ~= "item" })
  ui_controls.set_control_state(ui, market_layout.tab_skin, { visible = true, touch_enabled = active_tab ~= "skin" })
  ui_controls.set_control_state(ui, market_layout.tab_vehicle, { visible = VEHICLE_TAB_ENABLED, touch_enabled = VEHICLE_TAB_ENABLED and active_tab ~= "vehicle" })
end

function market_view.refresh_market_selection(state, option_id)
  local ui = state.ui
  assert(ui ~= nil, "missing market ui")
  local image_refs = state.ui_refs and state.ui_refs.images or {}
  local icon_key = _resolve_ref_key(image_refs, market_layout.empty_ref_key)
  assert(option_id ~= nil, "missing market option_id")
  local entry, cfg = _resolve_market_entry(option_id)
  assert(entry ~= nil, "missing market entry")
  local price_text = tostring(entry.price) .. " " .. tostring(assert(entry.currency ~= nil and entry.currency ~= "" and entry.currency, "missing market currency"))
  local resolved_icon_key = _resolve_market_icon_key(image_refs, option_id, entry, cfg)
  if resolved_icon_key ~= nil then
    icon_key = resolved_icon_key
  end
  ui:set_label(market_layout.price_label, price_text)
  if icon_key ~= nil then
    runtime.set_node_texture_keep_size(ui.query_node(market_layout.selected_card), icon_key)
  end
end

function market_view.select_market_option(state, option_id)
  modal_state.select_market_option(state, option_id)
  _refresh_market_selection_frames(state.ui, runtime_state.ensure_ui_runtime(state).choice_visible_option_ids, option_id)
  market_view.refresh_market_selection(state, option_id)
end

function market_view.refresh_market(state, market)
  local ui = state.ui
  assert(market ~= nil and market.options ~= nil and ui ~= nil, "missing market data/ui")
  local options = {}
  for _, opt in ipairs(market.options) do
    local opt_id = opt and (opt.id or opt) or nil
    local entry = opt_id and market_by_id[opt_id] or nil
    if entry == nil or entry.market_enabled ~= false then
      options[#options + 1] = opt
    end
  end
  if #options == 0 then
    _set_market_container_active(ui, true)
    _hide_market_slots(ui)
    _reset_market_preview(state)
    _refresh_market_controls(ui, market)
    _set_confirm_button_state(ui, false)
    local show_cancel = market.allow_cancel
    _set_cancel_controls(ui, show_cancel, show_cancel)
    modal_state.open_market(state, market.choice_id, {}, nil)
    return true
  end

  _set_market_container_active(ui, true)

  local refs = state.ui_refs and state.ui_refs.images or {}
  local option_ids = {}
  local first_buyable = nil
  _for_each_market_slot(function(idx, button, label, frame)
    local opt = options[idx]
    if not opt then
      _set_market_slot_hidden(ui, button, label, frame)
      return
    end
    if opt.can_buy == true and first_buyable == nil then
      first_buyable = opt.id or opt
    end
    option_ids[idx] = _set_market_slot_visible(ui, refs, { button = button, label = label, frame = frame }, opt)
  end)

  ui_controls.set_control_state(ui, market_layout.selected_card, { touch_enabled = false })
  _clear_market_selection_frames(ui)
  _refresh_market_controls(ui, market)

  _set_confirm_button_state(ui, true)
  local show_cancel = market.allow_cancel
  _set_cancel_controls(ui, show_cancel, show_cancel)

  local selected = market.selected_option_id
  if not _contains_option_id(option_ids, selected) then
    selected = nil
  end
  if selected == nil or (first_buyable ~= nil and selected ~= first_buyable) then
    selected = first_buyable or option_ids[1]
  end
  modal_state.open_market(state, market.choice_id, option_ids, selected)
  market_view.select_market_option(state, selected)
  return true
end

function market_view.close_market_panel(state)
  local ui = state.ui
  assert(ui ~= nil and ui.market_active == true, "market panel not active")
  _set_market_container_active(ui, false)
  modal_state.close_choice(state)
  _reset_market_preview(state)
  ui_controls.set_controls_state(ui, market_layout.item_labels, { touch_enabled = false })
  ui_controls.set_controls_state(ui, market_layout.item_frames, { touch_enabled = false })
  ui_controls.set_controls_state(ui, {
    market_layout.page_prev,
    market_layout.page_next,
    market_layout.tab_item,
    market_layout.tab_skin,
    market_layout.tab_vehicle,
  }, { visible = false, touch_enabled = false })
  _set_cancel_controls(ui, false, false)
end

return market_view
