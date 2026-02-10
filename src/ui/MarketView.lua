local market_layout = require("src.ui.MarketLayout")
local modal_state = require("src.ui.UIModalStateCoordinator")
local items_cfg = require("Config.Generated.Items")
local market_cfg = require("Config.Generated.Market")
local vehicles_cfg = require("Config.Generated.Vehicles")

local market_view = {}

local vehicles_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicles_by_id[cfg.id] = cfg
end

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
    cfg = vehicles_by_id[product_id]
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
  if type(key) == "number" then
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
  local name = cfg.name or entry.name
  return refs[name]
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

local function _set_market_slot_hidden(ui, button, label, frame)
  ui:set_visible(button, false)
  ui:set_touch_enabled(button, false)
  ui:set_visible(label, false)
  ui:set_touch_enabled(label, false)
  ui:set_visible(frame, false)
  ui:set_touch_enabled(frame, false)
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
    _set_node_texture_keep_size(node, rarity_key)
  end
  return opt_id
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
  local price_text = "售价：" .. tostring(price) .. " " .. currency
  local resolved_icon_key = _resolve_market_icon_key(refs, option_id, entry, cfg)
  if resolved_icon_key ~= nil then
    icon_key = resolved_icon_key
  end
  ui:set_label(market_layout.price_label, price_text)
  if icon_key ~= nil then
    local node = ui.query_node(market_layout.selected_card)
    _set_node_texture_keep_size(node, icon_key)
  end
end

function market_view.select_market_option(state, option_id)
  modal_state.select_market_option(state, option_id)
  market_view.refresh_market_selection(state, option_id)
end

function market_view.refresh_market(state, market)
  local ui = state.ui
  assert(market ~= nil and market.options ~= nil and ui ~= nil, "missing market data/ui")
  ui:set_visible(market_layout.container, true)
  ui.market_active = true

  local refs = state.ui_refs
  local option_ids = {}
  local buttons = market_layout.item_buttons
  local labels = market_layout.item_labels
  local frames = market_layout.item_frames
  local max_slots = math.max(#buttons, #labels, #frames)
  for idx = 1, max_slots do
    local opt = market.options[idx]
    local button = buttons[idx]
    local label = labels[idx]
    local frame = frames[idx]
    if button and label and frame then
      local slot = { button = button, label = label, frame = frame }
      if opt then
        option_ids[idx] = _set_market_slot_visible(ui, refs, slot, opt)
      else
        _set_market_slot_hidden(ui, button, label, frame)
      end
    end
  end

  ui:set_touch_enabled(market_layout.selected_card, false)

  ui:set_visible(market_layout.confirm_button, true)
  ui:set_touch_enabled(market_layout.confirm_button, true)
  local show_cancel = market.allow_cancel
  ui:set_visible(market_layout.cancel_button, show_cancel)
  ui:set_touch_enabled(market_layout.cancel_button, show_cancel)

  local selected = market.selected_option_id or option_ids[1]
  modal_state.open_market(state, market.choice_id, option_ids, selected)
  market_view.select_market_option(state, selected)
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
  ui:set_touch_enabled(market_layout.selected_card, false)
  local empty_key = _resolve_ref_key(state.ui_refs, market_layout.empty_ref_key)
  local node = ui.query_node(market_layout.selected_card)
  _set_node_texture_keep_size(node, empty_key)
end

return market_view
