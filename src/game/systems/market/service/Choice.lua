local context = require("src.game.systems.market.service.Context")
local eligibility = require("src.game.systems.market.service.Eligibility")
local number_utils = require("src.core.NumberUtils")
local monopoly_event = require("src.core.events.MonopolyEvents")
local logger = require("src.core.Logger")

local choice = {}
local PAGE_SIZE = 10
local TAB_ITEM = "item"
local TAB_SKIN = "skin"
local TAB_VEHICLE = "vehicle"
local VEHICLE_TAB_ENABLED = false
local TABS = { TAB_ITEM, TAB_SKIN, TAB_VEHICLE }
local _emit_event = monopoly_event.emit

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

local function _current_choice_state(pending_choice)
  local meta = pending_choice and pending_choice.meta or {}
  return {
    active_tab = pending_choice and pending_choice.active_tab or meta.active_tab,
    page_index = pending_choice and pending_choice.page_index or meta.page_index,
  }
end

local function _apply_spec(game, pending_choice, spec)
  assert(pending_choice ~= nil, "missing pending_choice")
  assert(spec ~= nil, "missing spec")
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
end

function choice.build(player, game, state)
  state = state or {}
  local active_tab = _normalize_tab(state.active_tab)
  local visible, buyable = _build_tab_entries(player, game, active_tab)
  local page_count = _resolve_page_count(#visible, PAGE_SIZE)
  local page_index = _clamp_page(state.page_index, page_count)
  local body_lines, options = _build_options_for_page(visible, page_index, PAGE_SIZE)
  logger.warn(
    "[MarketDebug] choice_build",
    "player_id=" .. tostring(player and player.id),
    "active_tab=" .. tostring(active_tab),
    "visible_count=" .. tostring(#visible),
    "buyable_count=" .. tostring(#buyable),
    "page_index=" .. tostring(page_index),
    "page_count=" .. tostring(page_count),
    "options_count=" .. tostring(#options)
  )

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

function choice.rebuild_pending(game, pending_choice, player, state)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    logger.warn("[MarketDebug] rebuild_pending rejected: invalid pending_choice")
    return false
  end
  if not player then
    logger.warn("[MarketDebug] rebuild_pending rejected: missing player")
    return false
  end
  local spec = choice.build(player, game, state or _current_choice_state(pending_choice))
  if not spec then
    logger.warn("[MarketDebug] rebuild_pending rejected: build returned nil")
    return false
  end
  _apply_spec(game, pending_choice, spec)
  return true
end

function choice.apply_navigation(game, pending_choice, action)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    logger.warn("[MarketDebug] apply_navigation rejected: invalid pending_choice")
    return false
  end
  local meta = pending_choice.meta or {}
  local player_id = number_utils.to_integer(meta.player_id)
  if not player_id then
    logger.warn("[MarketDebug] apply_navigation rejected: invalid meta.player_id")
    return false
  end
  local player = game:find_player_by_id(player_id)
  if not player then
    logger.warn("[MarketDebug] apply_navigation rejected: player not found", tostring(player_id))
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
  logger.warn(
    "[MarketDebug] apply_navigation begin",
    "action_type=" .. tostring(action.type),
    "requested_tab=" .. tostring(action.tab),
    "resolved_tab=" .. tostring(active_tab),
    "requested_page=" .. tostring(page_index)
  )
  local spec = choice.build(player, game, {
    active_tab = active_tab,
    page_index = page_index,
  })
  if not spec then
    logger.warn("[MarketDebug] apply_navigation rejected: build returned nil")
    return false
  end
  if #spec.options == 0 then
    logger.warn(
      "[MarketDebug] apply_navigation empty_options",
      "player_id=" .. tostring(player.id),
      "active_tab=" .. tostring(spec.active_tab)
    )
    _emit_event(monopoly_event.market.buy_failed, {
      player = player,
      reason = "empty_tab",
      popup = { title = "黑市", body = "当前页签暂无可购买项" },
    })
  end
  _apply_spec(game, pending_choice, spec)
  logger.warn(
    "[MarketDebug] apply_navigation done",
    "active_tab=" .. tostring(pending_choice.active_tab),
    "page_index=" .. tostring(pending_choice.page_index),
    "page_count=" .. tostring(pending_choice.page_count),
    "options_count=" .. tostring(pending_choice.options and #pending_choice.options or 0)
  )
  return true
end

return choice
