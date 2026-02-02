local MarketUI = require("Manager.MarketManager.GUI.MarketUI")
local items_cfg = require("Config.Generated.Items")
local market_cfg = require("Config.Generated.Market")
local vehicles_cfg = require("Config.Generated.Vehicles")

local EggyLayerMarket = {}

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

local function resolve_market_entry(product_id)
  local entry = market_by_id[product_id]
  local cfg = nil
  if entry and entry.kind == "vehicle" then
    cfg = vehicles_by_id[product_id]
  else
    cfg = items_by_id[product_id]
  end
  return entry, cfg
end

local function resolve_market_name(opt, product_id, entry, cfg)
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

local function resolve_market_currency(entry)
  assert(entry ~= nil, "missing market entry")
  assert(entry.currency ~= nil and entry.currency ~= "", "missing market currency")
  return entry.currency
end

local function resolve_market_price(entry)
  assert(entry ~= nil, "missing market entry")
  return entry.price
end

local function resolve_market_level(cfg)
  assert(cfg ~= nil, "missing market cfg")
  local level = cfg.tier
  if level < 1 then
    return 1
  end
  if level >= 3 then
    return 3
  end
  return 2
end

local function resolve_ref_key(refs, key)
  if type(key) == "number" then
    return key
  end
  return refs[key]
end

local function resolve_market_icon_key(refs, product_id, entry, cfg)
  local key = tostring(product_id)
  local ref = refs[key]
  if ref then
    return ref
  end
  local name = cfg.name or entry.name
  return refs[name]
end

function EggyLayerMarket.refresh_market_selection(layer, option_id)
  local ui = layer.ui
  assert(ui ~= nil, "missing market ui")
  local price_text = ""
  local refs = layer.ui_refs
  local icon_key = resolve_ref_key(refs, MarketUI.empty_ref_key)
  assert(option_id ~= nil, "missing market option_id")
  local entry, cfg = resolve_market_entry(option_id)
  local price = resolve_market_price(entry)
  local currency = resolve_market_currency(entry)
  price_text = "售价：" .. tostring(price) .. " " .. currency
  icon_key = resolve_market_icon_key(refs, option_id, entry, cfg)
  ui:set_label(MarketUI.price_label, price_text)
  local node = ui.query_node(MarketUI.selected_card)
  node.image_texture = icon_key
  if node.reset_size then
    node:reset_size()
  end
end

function EggyLayerMarket.select_market_option(layer, option_id)
  layer.pending_choice_selected_option_id = option_id
  EggyLayerMarket.refresh_market_selection(layer, option_id)
end

function EggyLayerMarket.open_market_panel(layer, pending)
  local ui = layer.ui
  assert(pending ~= nil and pending.options ~= nil and ui ~= nil, "missing market pending/ui")
  ui:set_visible(MarketUI.container, true)
  ui.market_active = true

  local refs = layer.ui_refs
  local option_ids = {}
  local buttons = MarketUI.item_buttons
  local labels = MarketUI.item_labels
  local frames = MarketUI.item_frames
  local max_slots = #buttons
  for idx = 1, max_slots do
    local opt = pending.options[idx]
    local button = buttons[idx]
    local label = labels[idx]
    local frame = frames[idx]
    if opt then
      local opt_id = opt.id or opt
      option_ids[idx] = opt_id
      local entry, cfg = resolve_market_entry(opt_id)
      local name = resolve_market_name(opt, opt_id, entry, cfg)
      ui:set_label(label, name)
      ui:set_visible(label, true)
      ui:set_visible(button, true)
      ui:set_touch_enabled(button, true)
      ui:set_visible(frame, true)
      local level = resolve_market_level(cfg)
      local rarity_key = resolve_ref_key(refs, MarketUI.rarity_ref_keys[level])
      local node = ui.query_node(frame)
      node.image_texture = rarity_key
    else
      ui:set_visible(button, false)
      ui:set_touch_enabled(button, false)
      ui:set_visible(label, false)
      ui:set_visible(frame, false)
    end
  end

  ui:set_visible(MarketUI.confirm_button, true)
  ui:set_touch_enabled(MarketUI.confirm_button, true)
  local show_cancel = pending.allow_cancel
  ui:set_visible(MarketUI.cancel_button, show_cancel)
  ui:set_touch_enabled(MarketUI.cancel_button, show_cancel)

  layer.market_choice_option_ids = option_ids
  EggyLayerMarket.select_market_option(layer, option_ids[1])
  layer.pending_choice_elapsed = 0
  layer.pending_choice_id = pending.id
  return true
end

function EggyLayerMarket.close_market_panel(layer)
  local ui = layer.ui
  assert(ui ~= nil and ui.market_active == true, "market panel not active")
  ui:set_visible(MarketUI.container, false)
  ui.market_active = false
  layer.market_choice_option_ids = nil
  layer.pending_choice_selected_option_id = nil
  ui:set_label(MarketUI.price_label, "")
  local empty_key = resolve_ref_key(layer.ui_refs, MarketUI.empty_ref_key)
  local node = ui.query_node(MarketUI.selected_card)
  node.image_texture = empty_key
  if node.reset_size then
    node:reset_size()
  end
end

return EggyLayerMarket
