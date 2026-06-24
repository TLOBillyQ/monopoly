local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local items_cfg = require("src.config.content.items")
local market_catalog = require("src.config.content.market_catalog")
local runtime_ui = require("src.ui.render.runtime_ui")
local runtime_assets = require("src.config.runtime_assets")

local market_view_slots = {}

local function _resolve_runtime(deps)
  return assert((deps and deps.runtime) or runtime_ui, "missing deps.runtime")
end

local _items_cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  _items_cfg_by_id[cfg.id] = cfg
end

local function _item_cfg_by_id(product_id)
  return _items_cfg_by_id[product_id]
end

local _market_entry_by_id = market_catalog.entry_by_id

local function _resolve_market_entry(product_id)
  local entry = _market_entry_by_id(product_id)
  local cfg = _item_cfg_by_id(product_id)
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

local function _asset_opts(refs)
  if type(refs) == "table" and type(refs.images) ~= "table" then
    return { refs = { images = refs } }
  end
  return { refs = refs }
end

local function _resolve_market_icon_key(refs, product_id, entry, cfg)
  local name = (cfg and cfg.name) or (entry and entry.name)
  local image = runtime_assets.image_for_market_item(product_id, name, _asset_opts(refs))
  return image.ok == true and image.image_key or nil
end

local function _resolve_market_rarity_key(refs, level)
  local image = runtime_assets.image_for_market_rarity(market_layout.rarity_ref_keys[level], _asset_opts(refs))
  if image.ok == true then
    return image.image_key
  end
  local empty = runtime_assets.empty_image(_asset_opts(refs))
  return empty.image_key
end

local function _set_market_slot_hidden(ui, slot)
  ui_controls.set_slot_state(ui, slot, {
    button = { visible = false, touch_enabled = false },
    label = { visible = false, touch_enabled = false },
    frame = { visible = false, touch_enabled = false },
    sold_out_badge = { visible = false, touch_enabled = false },
    sold_out_label = { visible = false, touch_enabled = false },
  })
end

local function _for_each_market_slot(callback)
  local buttons = market_layout.item_buttons
  local labels = market_layout.item_labels
  local frames = market_layout.item_frames
  for index = 1, math.max(#buttons, #labels, #frames) do
    local button = buttons[index]
    local label = labels[index]
    local frame = frames[index]
    if button and label and frame then
      callback(index, {
        button = button,
        label = label,
        frame = frame,
        sold_out_badge = market_layout.sold_out_badges[index],
        sold_out_label = market_layout.sold_out_labels[index],
      })
    end
  end
end

local function _set_market_slot_visible(ui, refs, slot, opt, deps)
  local runtime = _resolve_runtime(deps)
  local opt_id = opt.id or opt
  local entry, cfg = _resolve_market_entry(opt_id)
  local name = _resolve_market_name(opt, opt_id, entry, cfg)
  ui:set_label(slot.label, name)
  ui_controls.set_slot_state(ui, slot, {
    label = { visible = true, touch_enabled = false },
    button = { visible = true, touch_enabled = true },
    frame = { visible = true, touch_enabled = false },
    sold_out_badge = { visible = opt.sold_out == true, touch_enabled = false },
    sold_out_label = { visible = opt.sold_out == true, touch_enabled = false },
  })
  local level = _resolve_market_level(cfg)
  local rarity_key = _resolve_market_rarity_key(refs, level)
  if rarity_key ~= nil then
    runtime.set_node_texture_keep_size(ui.query_node(slot.frame), rarity_key)
  end
  return opt_id
end

local function _set_market_slot(ui, refs, slot, opt, deps)
  if not opt then
    _set_market_slot_hidden(ui, slot)
    return nil
  end
  return _set_market_slot_visible(ui, refs, slot, opt, deps)
end

local function _has_option_id(option_ids, option_id)
  for _, value in pairs(option_ids or {}) do
    if value == option_id then
      return true
    end
  end
  return false
end

function market_view_slots.filter_market_options(options)
  local visible_options = {}
  for _, opt in ipairs(options or {}) do
    local opt_id = opt and (opt.id or opt) or nil
    local entry = opt_id and _market_entry_by_id(opt_id) or nil
    if entry == nil or entry.market_enabled ~= false then
      visible_options[#visible_options + 1] = opt
    end
  end
  return visible_options
end

function market_view_slots.hide_market_slots(ui)
  _for_each_market_slot(function(_, slot)
    _set_market_slot_hidden(ui, slot)
  end)
end

function market_view_slots.populate_market_slots(ui, refs, options, deps)
  local option_ids = {}
  local first_buyable = nil
  _for_each_market_slot(function(index, slot)
    local opt = options[index]
    if opt and opt.can_buy == true and first_buyable == nil then
      first_buyable = opt.id or opt
    end
    local opt_id = _set_market_slot(ui, refs, slot, opt, deps)
    option_ids[index] = opt_id
  end)
  return {
    option_ids = option_ids,
    first_buyable = first_buyable,
  }
end

function market_view_slots.resolve_selected_option(option_ids, selected_option_id, first_buyable)
  local selected = selected_option_id
  if not _has_option_id(option_ids, selected) then
    selected = nil
  end
  if selected == nil then
    return first_buyable or option_ids[1]
  end
  return selected
end

function market_view_slots.resolve_selection(option_id, image_refs, empty_ref_key)
  assert(option_id ~= nil, "missing market option_id")
  local entry, cfg = _resolve_market_entry(option_id)
  assert(entry ~= nil, "missing market entry")
  local price_text = tostring(entry.price) .. " "
      .. tostring(assert(entry.currency ~= nil and entry.currency ~= "" and entry.currency, "missing market currency"))
  local icon_key = _resolve_market_icon_key(image_refs, option_id, entry, cfg)
    or runtime_assets.image_for_market_rarity(empty_ref_key, _asset_opts(image_refs)).image_key
    or runtime_assets.empty_image(_asset_opts(image_refs)).image_key
  return {
    entry = entry,
    cfg = cfg,
    price_text = price_text,
    icon_key = icon_key,
  }
end

-- Exported for testing
market_view_slots._resolve_market_name = _resolve_market_name

return market_view_slots

--[[ mutate4lua-manifest
version=2
projectHash=3fe80dafa30ce9a7
scope.0.id=chunk:src/ui/render/market/slots.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=203
scope.0.semanticHash=e1ae2435f5509b13
scope.1.id=function:_resolve_runtime:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=e9e3b1d4060fc718
scope.2.id=function:_item_cfg_by_id:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=367dcba6cb8ed2dc
scope.3.id=function:_resolve_market_entry:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=28
scope.3.semanticHash=fd5937731a51ad7e
scope.4.id=function:_resolve_market_name:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=41
scope.4.semanticHash=20458f49fb7421d0
scope.5.id=function:_resolve_market_level:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=52
scope.5.semanticHash=6a0d0f8c67f37f02
scope.6.id=function:_resolve_market_icon_key:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=67
scope.6.semanticHash=8361f45987e408cf
scope.7.id=function:_set_market_slot_hidden:69
scope.7.kind=function
scope.7.startLine=69
scope.7.endLine=77
scope.7.semanticHash=248ac32cb5dc8542
scope.8.id=function:_set_market_slot_visible:99
scope.8.kind=function
scope.8.startLine=99
scope.8.endLine=118
scope.8.semanticHash=22962262fc54ff9f
scope.9.id=function:_set_market_slot:120
scope.9.kind=function
scope.9.startLine=120
scope.9.endLine=126
scope.9.semanticHash=122b5dc7af80449a
scope.10.id=function:anonymous@150:150
scope.10.kind=function
scope.10.startLine=150
scope.10.endLine=152
scope.10.semanticHash=89beb011a3f145a1
scope.11.id=function:market_view_slots.hide_market_slots:149
scope.11.kind=function
scope.11.startLine=149
scope.11.endLine=153
scope.11.semanticHash=e09af905f75c4591
scope.12.id=function:anonymous@158:158
scope.12.kind=function
scope.12.startLine=158
scope.12.endLine=165
scope.12.semanticHash=992f66e4a3491d72
scope.13.id=function:market_view_slots.populate_market_slots:155
scope.13.kind=function
scope.13.startLine=155
scope.13.endLine=170
scope.13.semanticHash=2414ba5714375802
scope.14.id=function:market_view_slots.resolve_selected_option:172
scope.14.kind=function
scope.14.startLine=172
scope.14.endLine=181
scope.14.semanticHash=979c16a226790fee
scope.15.id=function:market_view_slots.resolve_selection:183
scope.15.kind=function
scope.15.startLine=183
scope.15.endLine=197
scope.15.semanticHash=a1bff7dc1101ef0e
]]
