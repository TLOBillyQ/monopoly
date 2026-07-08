local availability = require("src.rules.items.availability")
local number_utils = require("src.foundation.number")
local market_service = require("src.rules.market")
local purchase_settlement = require("src.rules.market.purchase_settlement")
local market_context = require("src.rules.market.query").context
local event_kinds = require("src.config.gameplay.event_kinds")
local dirty_tracker = require("src.state.dirty_tracker")

local M = {}

local TAB_ITEM = "item"

local function _normalize_market_tab(active_tab)
  if active_tab == TAB_ITEM then
    return active_tab
  end
  return TAB_ITEM
end

local function _normalize_page_value(value)
  local page_value = number_utils.to_integer(value) or 1
  if page_value < 1 then
    return 1
  end
  return page_value
end

local function _normalize_market_buy_meta(_, meta, choice_spec)
  local normalized_meta = availability.copy_table(meta)
  availability.normalize_integer_field(normalized_meta, "player_id", choice_spec.kind)
  normalized_meta.active_tab = _normalize_market_tab(normalized_meta.active_tab or choice_spec.active_tab)
  normalized_meta.page_index = _normalize_page_value(normalized_meta.page_index or choice_spec.page_index)
  normalized_meta.page_count = _normalize_page_value(normalized_meta.page_count or choice_spec.page_count)
  choice_spec.owner_role_id = choice_spec.owner_role_id or normalized_meta.player_id
  choice_spec.active_tab = normalized_meta.active_tab
  choice_spec.page_index = normalized_meta.page_index
  choice_spec.page_count = normalized_meta.page_count
  return normalized_meta
end

local function _validate_market_player(game, meta)
  return assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
end

local function _validate_market_entry(product_id)
  return assert(market_context.entry_by_id(product_id), "missing market entry: " .. tostring(product_id))
end

local function _validate_market_buy_meta(game, meta)
  _validate_market_player(game, meta)
end

local function _normalize_market_buy_action(_, _, action)
  local normalized_action = availability.copy_table(action)
  availability.normalize_integer_field(normalized_action, "option_id", "market_buy", "action", true)
  return normalized_action
end

local function _is_market_item_reveal(anim)
  return anim ~= nil
    and anim.kind == event_kinds.item_get_reveal
    and anim.source == "market"
end

local function _remove_market_reveals_from_queue(queue)
  if type(queue) ~= "table" then
    return false
  end
  local removed = false
  for index = #queue, 1, -1 do
    if _is_market_item_reveal(queue[index]) then
      table.remove(queue, index)
      removed = true
    end
  end
  return removed
end

local function _clear_market_item_reveals(game)
  local turn = game and game.turn or nil
  if turn == nil then
    return
  end
  local changed = false
  if _is_market_item_reveal(turn.action_anim) then
    turn.action_anim = nil
    changed = true
  end
  if _remove_market_reveals_from_queue(turn.action_anim_queue) then
    changed = true
  end
  if changed then
    dirty_tracker.mark(game.dirty, "turn")
  end
end

local function _build(helpers)
  local finish_choice = helpers.finish_choice

  local function _handle_market_buy(game, choice, action)
    local meta = choice.meta
    local player = _validate_market_player(game, meta)
    local product_id = assert(number_utils.to_integer(action.option_id), "missing product_id")
    local entry = _validate_market_entry(product_id)
    local result = market_service.purchase.execute(game, player, product_id)
    local verdict = purchase_settlement.resolve(game, choice, player, entry, result)
    if verdict.keep_open then
      return { stay = true }
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = {
      required_meta = { "player_id" },
      normalize_meta = _normalize_market_buy_meta,
      meta_validator = _validate_market_buy_meta,
      normalize_action = _normalize_market_buy_action,
      cancel = {
        resolve = function(game)
          _clear_market_item_reveals(game)
        end,
      },
      execute = _handle_market_buy,
    },
  }
end

function M.register(registry, helpers)
  local handlers = _build(helpers)
  for kind, handler in pairs(handlers) do
    registry[kind] = handler
  end
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=1ab0e687a1a07999
scope.0.id=chunk:src/rules/choice_handlers/market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=e6b01e0db29116d1
scope.1.id=function:_normalize_market_tab:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=18
scope.1.semanticHash=a9fcfd44e3831bdb
scope.2.id=function:_normalize_page_value:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=26
scope.2.semanticHash=2c2c770ed9411c97
scope.3.id=function:_normalize_market_buy_meta:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=39
scope.3.semanticHash=0f2ae9542e165ce2
scope.4.id=function:_validate_market_player:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=43
scope.4.semanticHash=089c950a65677afb
scope.5.id=function:_validate_market_entry:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=47
scope.5.semanticHash=05ea0225d948aa48
scope.6.id=function:_validate_market_buy_meta:49
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=51
scope.6.semanticHash=f1c72a58a94421ad
scope.7.id=function:_normalize_market_buy_action:53
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=57
scope.7.semanticHash=1402fc8b6246b92f
scope.8.id=function:_is_market_item_reveal:59
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=63
scope.8.semanticHash=99edbc845bb138be
scope.9.id=function:_clear_market_item_reveals:79
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=95
scope.9.semanticHash=3a8b877130322988
scope.10.id=function:_handle_market_buy:100
scope.10.kind=function
scope.10.startLine=100
scope.10.endLine=111
scope.10.semanticHash=0fa59219836d3bd1
scope.11.id=function:anonymous@120:120
scope.11.kind=function
scope.11.startLine=120
scope.11.endLine=122
scope.11.semanticHash=cbfc55ae33457f48
scope.12.id=function:_build:97
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=127
scope.12.semanticHash=55a98564617bc50e
]]
