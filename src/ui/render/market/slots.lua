local market_layout = require("src.ui.schema.market_layout")
local ui_controls = require("src.ui.render.support.ui_controls")
local items_cfg = require("src.config.content.items")
local market_catalog = require("src.config.content.market_catalog")
local number_utils = require("src.foundation.lang.number")
local runtime_ui = require("src.ui.render.runtime_ui")

local market_view_slots = {}

local function _resolve_runtime(deps)
  local resolved_deps = deps or {}
  return assert(resolved_deps.runtime or runtime_ui, "missing deps.runtime")
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
  local name = (cfg and cfg.name) or (entry and entry.name)
  if name == nil or name == "" then
    return nil
  end
  return refs[name]
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
  local rarity_key = _resolve_ref_key(refs, market_layout.rarity_ref_keys[level]) or _resolve_ref_key(refs, market_layout.empty_ref_key)
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
    or _resolve_ref_key(image_refs, empty_ref_key)
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
