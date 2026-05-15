local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local tables = require("src.foundation.tables")
local logger = require("src.foundation.log")
local choice_contract = require("src.config.choice.contract")
local dirty_tracker = require("src.state.dirty_tracker")
local intent_output_port = require("src.rules.ports.intent_output")
local market_query = require("src.rules.market.query")

local query_context = market_query.context
local query_eligibility = market_query.eligibility

local feedback = {}
local _emit_event = monopoly_event.emit

local popup_title = "黑市"

function feedback.emit_buy_failed(player, entry, reason, body)
  _emit_event(monopoly_event.market.buy_failed, {
    player = player,
    entry = entry,
    reason = reason,
    popup = { title = popup_title, body = body },
  })
end

function feedback.emit_inventory_full(player, entry)
  _emit_event(monopoly_event.market.inventory_full, {
    player = player,
    entry = entry,
    body = "卡槽已满，无法继续购买",
  })
end

local builder = {}
local PAGE_SIZE = 10
local TAB_ITEM = "item"

local function _normalize_tab(tab)
  if tables.contains({ TAB_ITEM }, tab) then
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
  return number_utils.clamp(page, 1, count)
end

local function _build_tab_entries(player, game, active_tab)
  local merged = {}
  local buyable = {}
  for _, entry in ipairs(query_eligibility.sorted_entries()) do
    if entry.kind == active_tab
        and query_context.entry_market_enabled(entry) then
      local can_buy = query_eligibility.can_buy_entry(game, player, entry)
      if can_buy then
        buyable[#buyable + 1] = entry
      end
      merged[#merged + 1] = {
        entry = entry,
        can_buy = can_buy,
        sold_out = query_eligibility.is_sold_out(game, entry),
      }
    end
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
    local name = query_context.entry_name(entry)
    local price = query_context.entry_price(entry)
    local currency = query_context.entry_currency(entry)
    local label = name .. " - " .. number_utils.format_integer_part(price) .. " " .. currency
    body_lines[#body_lines + 1] = label
    options[#options + 1] = {
      id = entry.product_id,
      label = label,
      can_buy = slot.can_buy,
      sold_out = slot.sold_out,
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

function builder.build(player, game, state)
  state = state or {}
  local active_tab = _normalize_tab(state.active_tab)
  local visible, _ = _build_tab_entries(player, game, active_tab)
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

local session = {}

local function _mark_choice_dirty(game)
  if not game or not game.dirty then
    return
  end
  dirty_tracker.mark(game.dirty, "turn")
  dirty_tracker.mark(game.dirty, "market")
end

local function _current_choice_state(pending_choice)
  return {
    active_tab = pending_choice and pending_choice.active_tab or nil,
    page_index = pending_choice and pending_choice.page_index or nil,
  }
end

local _resolve_owner_role_id = choice_contract.resolve_owner_role_id

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
  pending_choice.owner_role_id = spec.owner_role_id
  pending_choice.meta = spec.meta
  _mark_choice_dirty(game)
end

function session.rebuild_pending(game, pending_choice, player, state)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    logger.warn("[MarketDebug] rebuild_pending rejected: invalid pending_choice")
    return false
  end
  if not player then
    logger.warn("[MarketDebug] rebuild_pending rejected: missing player")
    return false
  end
  local spec = builder.build(player, game, state or _current_choice_state(pending_choice))
  if not spec then
    logger.warn("[MarketDebug] rebuild_pending rejected: build returned nil")
    return false
  end
  _apply_spec(game, pending_choice, spec)
  return true
end

function session.apply_navigation(game, pending_choice, action)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    logger.warn("[MarketDebug] apply_navigation rejected: invalid pending_choice")
    return false
  end
  local player_id = _resolve_owner_role_id(pending_choice)
  if not player_id then
    logger.warn("[MarketDebug] apply_navigation rejected: invalid owner_role_id")
    return false
  end
  local player = game:find_player_by_id(player_id)
  if not player then
    logger.warn("[MarketDebug] apply_navigation rejected: player not found", tostring(player_id))
    return false
  end
  local active_tab = pending_choice.active_tab
  local page_index = pending_choice.page_index
  local page_count = pending_choice.page_count
  if action.type == "market_tab_select" then
    if active_tab == action.tab then
      return true
    end
    active_tab = action.tab
    page_index = 1
  elseif action.type == "market_page_prev" then
    page_index = (number_utils.to_integer(page_index) or 1) - 1
  elseif action.type == "market_page_next" then
    page_index = (number_utils.to_integer(page_index) or 1) + 1
  end
  local spec = builder.build(player, game, {
    active_tab = active_tab,
    page_index = page_index,
    page_count = page_count,
  })
  if not spec then
    logger.warn("[MarketDebug] apply_navigation rejected: build returned nil")
    return false
  end
  if #spec.options == 0 then
    feedback.emit_buy_failed(player, nil, "empty_tab", "当前页签暂无可购买项")
  end
  _apply_spec(game, pending_choice, spec)
  return true
end

function session.refresh_after_paid_callback(game, player, entry)
  local pending_choice = game and game.turn and game.turn.pending_choice or nil
  if not pending_choice or pending_choice.kind ~= "market_buy" then
    return false
  end
  local owner_id = _resolve_owner_role_id(pending_choice)
  if owner_id ~= (player and player.id or nil) then
    return false
  end
  local rebuilt = session.rebuild_pending(game, pending_choice, player)
  if rebuilt then
    return true
  end
  logger.warn(
    "market paid callback refresh skipped:",
    "player_id=" .. tostring(player and player.id or nil),
    "product_id=" .. tostring(entry and entry.product_id)
  )
  return false
end

local outcome = {}

local function _dispatch_intent(game, intent)
  if type(intent) ~= "table" then
    return false
  end
  if intent.kind == "need_choice" and intent.choice_spec ~= nil then
    return intent_output_port.open_choice(game, intent.choice_spec, intent.opts) ~= nil
  end
  if intent.kind == "push_popup" and intent.payload ~= nil then
    return intent_output_port.push_popup(game, intent.payload, intent.popup_opts or intent.opts) == true
  end
  return false
end

local function _is_purchase_failure(result)
  return type(result) == "table" and result.ok == false
end

local function _should_keep_market_open(entry, result)
  if type(result) ~= "table" or result.ok ~= true then
    return false
  end
  if result.deferred_fulfillment == true then
    return true
  end
  return entry and entry.kind == "item" and result.fulfilled_now == true
end

function outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  assert(type(finish_choice) == "function", "missing finish_choice")

  if _should_keep_market_open(entry, result) then
    local rebuilt = session.rebuild_pending(game, choice, player)
    if not rebuilt then
      return finish_choice(game, false)
    end
    if entry
        and entry.kind == "item"
        and result.fulfilled_now == true
        and result.inventory_full_after == true then
      feedback.emit_inventory_full(player, entry)
    end
    return { stay = true }
  end

  if _is_purchase_failure(result) then
    local rebuilt = session.rebuild_pending(game, choice, player)
    if rebuilt then
      return { stay = true }
    end
  end

  if type(result) == "table" then
    local intent = result.intent or {}
    _dispatch_intent(game, intent)
    if intent.kind == "need_choice" then
      return { stay = true }
    end
  end

  return finish_choice(game, false)
end

return {
  builder = builder,
  feedback = feedback,
  session = session,
  outcome = outcome,
}
