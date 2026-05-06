local choice_builder = require("src.rules.market.choice.builder")
local feedback = require("src.rules.market.choice.feedback")
local number_utils = require("src.foundation.lang.number")
local logger = require("src.foundation.log.logger")
local choice_contract = require("src.config.choice.contract")

local session = {}

local function _mark_choice_dirty(game)
  if not game or not game.dirty then
    return
  end
  game.dirty.turn = true
  game.dirty.market = true
  game.dirty.any = true
end

local function _current_choice_state(pending_choice)
  return {
    active_tab = pending_choice and pending_choice.active_tab or nil,
    page_index = pending_choice and pending_choice.page_index or nil,
  }
end

local function _resolve_owner_role_id(pending_choice)
  return choice_contract.resolve_owner_role_id(pending_choice)
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
  local spec = choice_builder.build(player, game, state or _current_choice_state(pending_choice))
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
  local spec = choice_builder.build(player, game, {
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

return session
