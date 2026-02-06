local market_ui = require("src.ui.MarketUI")
local items_cfg = require("Config.Generated.Items")
local market_cfg = require("Config.Generated.Market")
local vehicles_cfg = require("Config.Generated.Vehicles")

local eggy_layer_market = {}

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

function eggy_layer_market.refresh_market_selection(state, option_id)
  local ui = state.ui
  assert(ui ~= nil, "missing market ui")
  local price_text = ""
  local refs = state.ui_refs
  local icon_key = _resolve_ref_key(refs, market_ui.empty_ref_key)
  assert(option_id ~= nil, "missing market option_id")
  local entry, cfg = _resolve_market_entry(option_id)
  local price = _resolve_market_price(entry)
  local currency = _resolve_market_currency(entry)
  price_text = "售价：" .. tostring(price) .. " " .. currency
  local resolved_icon_key = _resolve_market_icon_key(refs, option_id, entry, cfg)
  if resolved_icon_key ~= nil then
    icon_key = resolved_icon_key
  end
  ui:set_label(market_ui.price_label, price_text)
  if icon_key ~= nil then
    local node = ui.query_node(market_ui.selected_card)
    node.image_texture = icon_key
    if node.reset_size then
      node:reset_size()
    end
  end
end

function eggy_layer_market.select_market_option(state, option_id)
  state.pending_choice_selected_option_id = option_id
  eggy_layer_market.refresh_market_selection(state, option_id)
end

function eggy_layer_market.refresh_market(state, market)
  local ui = state.ui
  assert(market ~= nil and market.options ~= nil and ui ~= nil, "missing market data/ui")
  ui:set_visible(market_ui.container, true)
  ui.market_active = true

  local refs = state.ui_refs
  local option_ids = {}
  local buttons = market_ui.item_buttons
  local labels = market_ui.item_labels
  local frames = market_ui.item_frames
  local max_slots = #buttons
  for idx = 1, max_slots do
    local opt = market.options[idx]
    local button = buttons[idx]
    local label = labels[idx]
    local frame = frames[idx]
    if opt then
      local opt_id = opt.id or opt
      option_ids[idx] = opt_id
      local entry, cfg = _resolve_market_entry(opt_id)
      local name = _resolve_market_name(opt, opt_id, entry, cfg)
      ui:set_label(label, name)
      ui:set_visible(label, true)
      ui:set_visible(button, true)
      ui:set_touch_enabled(button, true)
      ui:set_visible(frame, true)
      local level = _resolve_market_level(cfg)
      local rarity_key = _resolve_ref_key(refs, market_ui.rarity_ref_keys[level])
      if rarity_key == nil then
        rarity_key = _resolve_ref_key(refs, market_ui.empty_ref_key)
      end
      if rarity_key ~= nil then
        local node = ui.query_node(frame)
        node.image_texture = rarity_key
      end
    else
      ui:set_visible(button, false)
      ui:set_touch_enabled(button, false)
      ui:set_visible(label, false)
      ui:set_visible(frame, false)
    end
  end

  ui:set_visible(market_ui.confirm_button, true)
  ui:set_touch_enabled(market_ui.confirm_button, true)
  local show_cancel = market.allow_cancel
  ui:set_visible(market_ui.cancel_button, show_cancel)
  ui:set_touch_enabled(market_ui.cancel_button, show_cancel)

  state.market_choice_option_ids = option_ids
  local selected = market.selected_option_id or option_ids[1]
  eggy_layer_market.select_market_option(state, selected)
  state.pending_choice_elapsed = 0
  state.pending_choice_id = market.choice_id
  return true
end

function eggy_layer_market.close_market_panel(state)
  local ui = state.ui
  assert(ui ~= nil and ui.market_active == true, "market panel not active")
  ui:set_visible(market_ui.container, false)
  ui.market_active = false
  state.market_choice_option_ids = nil
  state.pending_choice_selected_option_id = nil
  ui:set_label(market_ui.price_label, "")
  local empty_key = _resolve_ref_key(state.ui_refs, market_ui.empty_ref_key)
  local node = ui.query_node(market_ui.selected_card)
  node.image_texture = empty_key
  if node.reset_size then
    node:reset_size()
  end
end

return eggy_layer_market
