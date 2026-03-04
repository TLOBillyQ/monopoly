local context = require("src.game.systems.market.service.Context")
local eligibility = require("src.game.systems.market.service.Eligibility")
local number_utils = require("src.core.NumberUtils")

local choice = {}
local PAGE_SIZE = 10
local TAB_ITEM = "item"
local TAB_SKIN = "skin"
local TAB_VEHICLE = "vehicle"
local VEHICLE_TAB_ENABLED = false
local TABS = { TAB_ITEM, TAB_SKIN, TAB_VEHICLE }

local function _contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function _normalize_tab(tab)
  if tab == TAB_VEHICLE and not VEHICLE_TAB_ENABLED then
    return TAB_ITEM
  end
  if _contains(TABS, tab) then
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
        and context.entry_vehicle_enabled(entry)
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
    options[#options + 1] = { id = entry.product_id, label = label, can_buy = slot.can_buy }
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

local function _mark_choice_dirty(game)
  if not game or not game.dirty then
    return
  end
  game.dirty.turn = true
  game.dirty.any = true
end

function choice.build(player, game, state)
  state = state or {}
  local active_tab = _normalize_tab(state.active_tab)
  local visible = _build_tab_entries(player, game, active_tab)
  local page_count = _resolve_page_count(#visible, PAGE_SIZE)
  local page_index = _clamp_page(state.page_index, page_count)
  local body_lines, options = _build_options_for_page(visible, page_index, PAGE_SIZE)

  if #visible == 0 then
    return nil, {
      kind = "push_popup",
      payload = { title = "黑市", body = player.name .. " 暂无可展示商品" },
    }
  end

  return {
    kind = "market_buy",
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

function choice.apply_navigation(game, pending_choice, action)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    return false
  end
  local meta = pending_choice.meta or {}
  local player_id = number_utils.to_integer(meta.player_id)
  if not player_id then
    return false
  end
  local player = game:find_player_by_id(player_id)
  if not player then
    return false
  end
  local active_tab = _normalize_tab(meta.active_tab)
  local page_index = _clamp_page(meta.page_index, meta.page_count)
  if action.type == "market_tab_select" then
    active_tab = _normalize_tab(action.tab)
    page_index = 1
  elseif action.type == "market_page_prev" then
    page_index = page_index - 1
  elseif action.type == "market_page_next" then
    page_index = page_index + 1
  end
  local spec = choice.build(player, game, {
    active_tab = active_tab,
    page_index = page_index,
  })
  if not spec then
    return false
  end
  pending_choice.title = spec.title
  pending_choice.body_lines = spec.body_lines
  pending_choice.options = spec.options
  pending_choice.allow_cancel = spec.allow_cancel
  pending_choice.cancel_label = spec.cancel_label
  pending_choice.active_tab = spec.active_tab
  pending_choice.page_index = spec.page_index
  pending_choice.page_count = spec.page_count
  pending_choice.meta = spec.meta
  _mark_choice_dirty(game)
  return true
end

return choice
