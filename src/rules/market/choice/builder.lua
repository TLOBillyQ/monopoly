local context = require("src.rules.market.query.context")
local eligibility = require("src.rules.market.query.eligibility")
local number_utils = require("src.core.utils.number_utils")
local availability = require("src.rules.items.availability")

local choice = {}
local PAGE_SIZE = 10
local TAB_ITEM = "item"
local TAB_SKIN = "skin"
local TABS = { TAB_ITEM, TAB_SKIN }

local function _normalize_tab(tab)
  if availability.contains(TABS, tab) then
    return tab
  end
  return TAB_ITEM
end

local function _clamp_page(page_index, page_count)
  local page = number_utils.to_integer(page_index) or 1
  local count = number_utils.to_integer(page_count) or 1
  if count < 1 then
    count = 1
  end
  if page < 1 then
    return 1
  end
  if page > count then
    return count
  end
  return page
end

local function _build_tab_entries(player, game, active_tab)
  local buyable = {}
  local unbuyable = {}
  for _, entry in ipairs(eligibility.sorted_entries()) do
    if entry.kind == active_tab
        and context.entry_market_enabled(entry) then
      if eligibility.can_buy_entry(game, player, entry) then
        buyable[#buyable + 1] = entry
      else
        unbuyable[#unbuyable + 1] = entry
      end
    end
  end
  local merged = {}
  for _, entry in ipairs(buyable) do
    merged[#merged + 1] = { entry = entry, can_buy = true }
  end
  for _, entry in ipairs(unbuyable) do
    merged[#merged + 1] = { entry = entry, can_buy = false }
  end
  return merged, buyable
end

local function _build_options_for_page(visible, page_index, page_size)
  local start_index = (page_index - 1) * page_size + 1
  local last_index = start_index + page_size - 1
  local options = {}
  local body_lines = {}
  for index = start_index, last_index do
    local slot = visible[index]
    if not slot then
      break
    end
    local entry = slot.entry
    local name = context.entry_name(entry)
    local price = context.entry_price(entry)
    local currency = context.entry_currency(entry)
    local label = name .. " - " .. number_utils.format_integer_part(price) .. " " .. currency
    body_lines[#body_lines + 1] = label
    options[#options + 1] = {
      id = entry.product_id,
      label = label,
      can_buy = slot.can_buy,
    }
  end
  return body_lines, options
end

local function _resolve_page_count(total_count, page_size)
  local total = number_utils.to_integer(total_count) or 0
  local size = number_utils.to_integer(page_size) or 1
  if size < 1 then
    size = 1
  end
  if total <= 0 then
    return 1
  end
  return math.floor((total + size - 1) / size)
end

function choice.build(player, game, state)
  state = state or {}
  local active_tab = _normalize_tab(state.active_tab)
  local visible, buyable = _build_tab_entries(player, game, active_tab)
  local page_count = _resolve_page_count(#visible, PAGE_SIZE)
  local page_index = _clamp_page(state.page_index, page_count)
  local body_lines, options = _build_options_for_page(visible, page_index, PAGE_SIZE)
  return {
    kind = "market_buy",
    route_key = "market",
    owner_role_id = player.id,
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    active_tab = active_tab,
    page_index = page_index,
    page_count = page_count,
    meta = {
      player_id = player.id,
      active_tab = active_tab,
      page_index = page_index,
      page_count = page_count,
    },
  }
end

return choice
