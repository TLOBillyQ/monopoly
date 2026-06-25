local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local items_cfg = require("src.config.content.items")
local market_catalog = require("src.config.content.market_catalog")
local runtime_ui = require("src.ui.render.runtime_ui")
local slot_assets = require("src.ui.render.market.slot_assets")

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
  local rarity_key = slot_assets.rarity_key(refs, level)
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
  return {
    entry = entry,
    cfg = cfg,
    price_text = slot_assets.price_text(entry),
    icon_key = slot_assets.selection_icon_key(image_refs, option_id, entry, cfg, empty_ref_key),
  }
end

-- Exported for testing
market_view_slots._resolve_market_name = _resolve_market_name

return market_view_slots

--[[ mutate4lua-manifest
version=2
projectHash=0f952912775c5176
scope.0.id=chunk:src/ui/render/market/slots.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=228
scope.0.semanticHash=9db61845c0ef8994
scope.1.id=function:_resolve_runtime:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=e9e3b1d4060fc718
scope.2.id=function:_item_cfg_by_id:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=367dcba6cb8ed2dc
scope.3.id=function:_resolve_market_entry:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=29
scope.3.semanticHash=fd5937731a51ad7e
scope.4.id=function:_resolve_market_name:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=42
scope.4.semanticHash=20458f49fb7421d0
scope.5.id=function:_resolve_market_level:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=53
scope.5.semanticHash=6a0d0f8c67f37f02
scope.6.id=function:_asset_opts:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=60
scope.6.semanticHash=34e5205f46a26a41
scope.7.id=function:_resolve_market_icon_key:62
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=66
scope.7.semanticHash=116d687c2271137d
scope.8.id=function:_market_price_text:68
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=74
scope.8.semanticHash=048342eda02d0fe3
scope.9.id=function:_market_fallback_icon_key:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=82
scope.9.semanticHash=ab96ffbc9cd53b29
scope.10.id=function:_market_selection_icon_key:84
scope.10.kind=function
scope.10.startLine=84
scope.10.endLine=87
scope.10.semanticHash=a93cd593ba76dc74
scope.11.id=function:_resolve_market_rarity_key:89
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=96
scope.11.semanticHash=9cf89c0f1d280cb9
scope.12.id=function:_set_market_slot_hidden:98
scope.12.kind=function
scope.12.startLine=98
scope.12.endLine=106
scope.12.semanticHash=248ac32cb5dc8542
scope.13.id=function:_set_market_slot_visible:128
scope.13.kind=function
scope.13.startLine=128
scope.13.endLine=147
scope.13.semanticHash=7514ba019851c908
scope.14.id=function:_set_market_slot:149
scope.14.kind=function
scope.14.startLine=149
scope.14.endLine=155
scope.14.semanticHash=122b5dc7af80449a
scope.15.id=function:anonymous@179:179
scope.15.kind=function
scope.15.startLine=179
scope.15.endLine=181
scope.15.semanticHash=89beb011a3f145a1
scope.16.id=function:market_view_slots.hide_market_slots:178
scope.16.kind=function
scope.16.startLine=178
scope.16.endLine=182
scope.16.semanticHash=e09af905f75c4591
scope.17.id=function:anonymous@187:187
scope.17.kind=function
scope.17.startLine=187
scope.17.endLine=194
scope.17.semanticHash=992f66e4a3491d72
scope.18.id=function:market_view_slots.populate_market_slots:184
scope.18.kind=function
scope.18.startLine=184
scope.18.endLine=199
scope.18.semanticHash=2414ba5714375802
scope.19.id=function:market_view_slots.resolve_selected_option:201
scope.19.kind=function
scope.19.startLine=201
scope.19.endLine=210
scope.19.semanticHash=979c16a226790fee
scope.20.id=function:market_view_slots.resolve_selection:212
scope.20.kind=function
scope.20.startLine=212
scope.20.endLine=222
scope.20.semanticHash=93f525182abb8dec
]]
