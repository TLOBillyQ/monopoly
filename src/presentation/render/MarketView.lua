local market_layout = require("src.presentation.shared.MarketLayout")
local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local runtime = require("src.presentation.api.UIRuntimePort")
local items_cfg = require("Config.Generated.Items")
local market_cfg = require("Config.Generated.Market")
local number_utils = require("src.core.NumberUtils")
local vehicle_catalog = require("src.core.config.VehicleCatalog")
local logger = require("src.core.Logger")

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

local function _resolve_market_currency(entry)
  assert(entry ~= nil, "missing market entry")
  assert(entry.currency ~= nil and entry.currency ~= "", "missing market currency")
  return entry.currency
end

local function _resolve_market_price(entry)
  assert(entry ~= nil, "missing market entry")
  return entry.price
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
  ui:set_visible(button, false)
  ui:set_touch_enabled(button, false)
  ui:set_visible(label, false)
  ui:set_touch_enabled(label, false)
  ui:set_visible(frame, false)
  ui:set_touch_enabled(frame, false)
end

local function _clear_market_selection_frames(ui)
  local selection_frames = market_layout.item_selection_frames or {}
  for _, name in ipairs(selection_frames) do
    ui:set_visible(name, false)
    ui:set_touch_enabled(name, false)
  end
end

local function _refresh_market_selection_frames(ui, option_ids, option_id)
  _clear_market_selection_frames(ui)
  if option_id == nil then
    return
  end
  for index, visible_option_id in pairs(option_ids or {}) do
    if visible_option_id == option_id then
      local name = market_layout.item_selection_frames and market_layout.item_selection_frames[index] or nil
      if name then
        ui:set_visible(name, true)
        ui:set_touch_enabled(name, false)
      end
      return
    end
  end
end

local function _set_market_slot_visible(ui, refs, slot, opt)
  local opt_id = opt.id or opt
  local entry, cfg = _resolve_market_entry(opt_id)
  local name = _resolve_market_name(opt, opt_id, entry, cfg)
  ui:set_label(slot.label, name)
  ui:set_visible(slot.label, true)
  ui:set_touch_enabled(slot.label, false)
  ui:set_visible(slot.button, true)
  ui:set_touch_enabled(slot.button, true)
  ui:set_visible(slot.frame, true)
  ui:set_touch_enabled(slot.frame, false)
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

local function _set_control_visible(ui, name, visible, enabled)
  if not name then
    return
  end
  ui:set_visible(name, visible == true)
  ui:set_touch_enabled(name, enabled == true)
end

local function _contains_option_id(option_ids, option_id)
  if option_id == nil then
    return false
  end
  for _, value in pairs(option_ids or {}) do
    if value == option_id then
      return true
    end
  end
  return false
end

local function _set_cancel_controls(ui, visible, enabled)
  local names = market_layout.cancel_buttons
  if type(names) == "table" and #names > 0 then
    for _, name in ipairs(names) do
      _set_control_visible(ui, name, visible, enabled)
    end
    return
  end
  _set_control_visible(ui, market_layout.cancel_button, visible, enabled)
end

local function _resolve_market_tab(market)
  local tab = market and market.active_tab or nil
  if tab == "item" or tab == "skin" or tab == "vehicle" then
    return tab
  end
  return "item"
end

local function _resolve_market_page_index(market)
  local page_index = number_utils.to_integer(market and market.page_index) or 1
  if page_index < 1 then
    return 1
  end
  return page_index
end

local function _resolve_market_page_count(market)
  local page_count = number_utils.to_integer(market and market.page_count) or 1
  if page_count < 1 then
    return 1
  end
  return page_count
end

local function _refresh_market_controls(ui, market)
  local active_tab = _resolve_market_tab(market)
  local page_index = _resolve_market_page_index(market)
  local page_count = _resolve_market_page_count(market)
  local paging_visible = page_count > 1
  _set_control_visible(ui, market_layout.page_prev, paging_visible, paging_visible and page_index > 1)
  _set_control_visible(ui, market_layout.page_next, paging_visible, paging_visible and page_index < page_count)
  _set_control_visible(ui, market_layout.tab_item, true, active_tab ~= "item")
  _set_control_visible(ui, market_layout.tab_skin, true, active_tab ~= "skin")
  _set_control_visible(ui, market_layout.tab_vehicle, VEHICLE_TAB_ENABLED, VEHICLE_TAB_ENABLED and active_tab ~= "vehicle")
end

function market_view.refresh_market_selection(state, option_id)
  local ui = state.ui
  assert(ui ~= nil, "missing market ui")
  local refs = state.ui_refs
  local icon_key = _resolve_ref_key(refs, market_layout.empty_ref_key)
  assert(option_id ~= nil, "missing market option_id")
  local entry, cfg = _resolve_market_entry(option_id)
  local price = _resolve_market_price(entry)
  local currency = _resolve_market_currency(entry)
  local price_text = tostring(price) .. " " .. currency
  local resolved_icon_key = _resolve_market_icon_key(refs, option_id, entry, cfg)
  if resolved_icon_key ~= nil then
    icon_key = resolved_icon_key
  end
  ui:set_label(market_layout.price_label, price_text)
  if icon_key ~= nil then
    local node = ui.query_node(market_layout.selected_card)
    runtime.set_node_texture_keep_size(node, icon_key)
  end
end

function market_view.select_market_option(state, option_id)
  modal_state.select_market_option(state, option_id)
  _refresh_market_selection_frames(state.ui, state.choice_visible_option_ids, option_id)
  market_view.refresh_market_selection(state, option_id)
end

function market_view.refresh_market(state, market)
  local ui = state.ui
  assert(market ~= nil and market.options ~= nil and ui ~= nil, "missing market data/ui")
  logger.warn(
    "[MarketDebug] view_refresh begin",
    "choice_id=" .. tostring(market.choice_id),
    "active_tab=" .. tostring(market.active_tab),
    "page_index=" .. tostring(market.page_index),
    "page_count=" .. tostring(market.page_count),
    "raw_options_count=" .. tostring(#market.options)
  )

  local options = {}
  for _, opt in ipairs(market.options) do
    local opt_id = opt and (opt.id or opt) or nil
    local entry = opt_id and market_by_id[opt_id] or nil
    if entry == nil or entry.market_enabled ~= false then
      options[#options + 1] = opt
    end
  end
  logger.warn(
    "[MarketDebug] view_refresh filtered",
    "choice_id=" .. tostring(market.choice_id),
    "filtered_options_count=" .. tostring(#options)
  )

  if #options == 0 then
    logger.warn(
      "[MarketDebug] view_refresh empty_tab",
      "choice_id=" .. tostring(market.choice_id),
      "active_tab=" .. tostring(market.active_tab)
    )
    ui:set_visible(market_layout.container, true)
    ui.market_active = true

    local buttons = market_layout.item_buttons
    local labels = market_layout.item_labels
    local frames = market_layout.item_frames
    local max_slots = math.max(#buttons, #labels, #frames)
    for idx = 1, max_slots do
      local button = buttons[idx]
      local label = labels[idx]
      local frame = frames[idx]
      if button and label and frame then
        _set_market_slot_hidden(ui, button, label, frame)
      end
    end

    ui:set_label(market_layout.price_label, "")
    _clear_market_selection_frames(ui)
    local empty_key = _resolve_ref_key(state.ui_refs, market_layout.empty_ref_key)
    if empty_key ~= nil then
      local node = ui.query_node(market_layout.selected_card)
      runtime.set_node_texture_keep_size(node, empty_key)
    end
    _refresh_market_controls(ui, market)
    ui:set_visible(market_layout.confirm_button, true)
    ui:set_touch_enabled(market_layout.confirm_button, false)
    local show_cancel = market.allow_cancel
    _set_cancel_controls(ui, show_cancel, show_cancel)
    modal_state.open_market(state, market.choice_id, {}, nil)
    logger.warn("[MarketDebug] view_refresh done empty_tab")
    return true
  end

  ui:set_visible(market_layout.container, true)
  ui.market_active = true

  local refs = state.ui_refs
  local option_ids = {}
  local buttons = market_layout.item_buttons
  local labels = market_layout.item_labels
  local frames = market_layout.item_frames
  local max_slots = math.max(#buttons, #labels, #frames)
  local first_buyable = nil
  for idx = 1, max_slots do
    local opt = options[idx]
    local button = buttons[idx]
    local label = labels[idx]
    local frame = frames[idx]
    if button and label and frame then
      local slot = { button = button, label = label, frame = frame }
      if opt then
        if opt.can_buy == true and first_buyable == nil then
          first_buyable = opt.id or opt
        end
        option_ids[idx] = _set_market_slot_visible(ui, refs, slot, opt)
      else
        _set_market_slot_hidden(ui, button, label, frame)
      end
    end
  end

  ui:set_touch_enabled(market_layout.selected_card, false)
  _clear_market_selection_frames(ui)
  _refresh_market_controls(ui, market)

  ui:set_visible(market_layout.confirm_button, true)
  ui:set_touch_enabled(market_layout.confirm_button, true)
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
  logger.warn(
    "[MarketDebug] view_refresh done",
    "choice_id=" .. tostring(market.choice_id),
    "selected_option_id=" .. tostring(selected),
    "first_buyable=" .. tostring(first_buyable),
    "visible_slots=" .. tostring(#option_ids)
  )
  return true
end

function market_view.close_market_panel(state)
  local ui = state.ui
  assert(ui ~= nil and ui.market_active == true, "market panel not active")
  ui:set_visible(market_layout.container, false)
  ui.market_active = false
  modal_state.close_choice(state)
  ui:set_label(market_layout.price_label, "")
  for _, name in ipairs(market_layout.item_labels) do
    ui:set_touch_enabled(name, false)
  end
  for _, name in ipairs(market_layout.item_frames) do
    ui:set_touch_enabled(name, false)
  end
  _clear_market_selection_frames(ui)
  ui:set_touch_enabled(market_layout.selected_card, false)
  _set_control_visible(ui, market_layout.page_prev, false, false)
  _set_control_visible(ui, market_layout.page_next, false, false)
  _set_control_visible(ui, market_layout.tab_item, false, false)
  _set_control_visible(ui, market_layout.tab_skin, false, false)
  _set_control_visible(ui, market_layout.tab_vehicle, false, false)
  _set_cancel_controls(ui, false, false)
  local empty_key = _resolve_ref_key(state.ui_refs, market_layout.empty_ref_key)
  local node = ui.query_node(market_layout.selected_card)
  runtime.set_node_texture_keep_size(node, empty_key)
end

return market_view
