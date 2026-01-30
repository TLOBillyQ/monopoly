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
  local currency = entry and entry.currency
  if currency == nil or currency == "" then
    return "金币"
  end
  return currency
end

local function resolve_market_price(entry)
  return entry and entry.price or 0
end

local function resolve_market_level(cfg)
  local level = cfg and cfg.tier or 1
  if level < 1 then
    return 1
  end
  if level >= 3 then
    return 3
  end
  return 2
end

local function resolve_ref_key(key)
  if key == nil then
    return nil
  end
  if type(key) == "number" then
    return key
  end
  if G and G.refs then
    return G.refs[key]
  end
  return nil
end

local function resolve_market_icon_key(product_id, entry, cfg)
  if not (G and G.refs) then
    return nil
  end
  local key = tostring(product_id)
  if G.refs[key] ~= nil then
    return G.refs[key]
  end
  local name = (cfg and cfg.name) or (entry and entry.name)
  if name and G.refs[name] ~= nil then
    return G.refs[name]
  end
  return nil
end

function EggyLayerMarket.refresh_market_selection(layer, option_id)
  local ui = layer.ui
  if not ui then
    return
  end
  local price_text = ""
  local icon_key = resolve_ref_key(MarketUI.empty_ref_key)
  if option_id then
    local entry, cfg = resolve_market_entry(option_id)
    local price = resolve_market_price(entry)
    local currency = resolve_market_currency(entry)
    price_text = "售价：" .. tostring(price) .. " " .. currency
    icon_key = resolve_market_icon_key(option_id, entry, cfg) or icon_key
  end
  if MarketUI.price_label then
    ui:set_label(MarketUI.price_label, price_text)
  end
  if MarketUI.selected_card and icon_key then
    local node = ui.query_node(MarketUI.selected_card)
    if node and node.image_texture ~= nil then
      node.image_texture = icon_key
      if node.reset_size then
        node:reset_size()
      end
    end
  end
end

function EggyLayerMarket.select_market_option(layer, option_id)
  layer.pending_choice_selected_option_id = option_id
  EggyLayerMarket.refresh_market_selection(layer, option_id)
end

function EggyLayerMarket.open_market_panel(layer, pending)
  local ui = layer.ui
  if not (pending and pending.options and ui) then
    return false
  end
  ui:set_visible(MarketUI.container, true)
  ui.market_active = true

  local option_ids = {}
  local buttons = MarketUI.item_buttons or {}
  local labels = MarketUI.item_labels or {}
  local frames = MarketUI.item_frames or {}
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
      if label then
        ui:set_label(label, name)
        ui:set_visible(label, true)
      end
      if button then
        ui:set_visible(button, true)
        ui:set_touch_enabled(button, true)
      end
      if frame then
        ui:set_visible(frame, true)
        local level = resolve_market_level(cfg)
        local rarity_key = resolve_ref_key((MarketUI.rarity_ref_keys or {})[level])
        if rarity_key then
          local node = ui.query_node(frame)
          if node and node.image_texture ~= nil then
            node.image_texture = rarity_key
          end
        end
      end
    else
      if button then
        ui:set_visible(button, false)
        ui:set_touch_enabled(button, false)
      end
      if label then
        ui:set_visible(label, false)
      end
      if frame then
        ui:set_visible(frame, false)
      end
    end
  end

  if MarketUI.confirm_button then
    ui:set_visible(MarketUI.confirm_button, true)
    ui:set_touch_enabled(MarketUI.confirm_button, true)
  end
  if MarketUI.cancel_button then
    local show_cancel = pending.allow_cancel ~= false
    ui:set_visible(MarketUI.cancel_button, show_cancel)
    ui:set_touch_enabled(MarketUI.cancel_button, show_cancel)
  end

  layer.market_choice_option_ids = option_ids
  EggyLayerMarket.select_market_option(layer, option_ids[1])
  layer.pending_choice_elapsed = 0
  layer.pending_choice_id = pending.id
  return true
end

function EggyLayerMarket.close_market_panel(layer)
  local ui = layer.ui
  if not (ui and ui.market_active) then
    return
  end
  ui:set_visible(MarketUI.container, false)
  ui.market_active = false
  layer.market_choice_option_ids = nil
  layer.pending_choice_selected_option_id = nil
  if MarketUI.price_label then
    ui:set_label(MarketUI.price_label, "")
  end
  local empty_key = resolve_ref_key(MarketUI.empty_ref_key)
  if MarketUI.selected_card and empty_key then
    local node = ui.query_node(MarketUI.selected_card)
    if node and node.image_texture ~= nil then
      node.image_texture = empty_key
      if node.reset_size then
        node:reset_size()
      end
    end
  end
end

return EggyLayerMarket
