local availability = require("src.rules.items.availability")
local number_utils = require("src.foundation.number")
local market_service = require("src.rules.market")
local choice_outcome = require("src.rules.market.choice").outcome
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
    return choice_outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
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
projectHash=45da973294ccc766
scope.0.id=chunk:src/rules/choice_handlers/market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=88
scope.0.semanticHash=36e3673be5a009f1
scope.1.id=function:_normalize_market_tab:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=16
scope.1.semanticHash=a9fcfd44e3831bdb
scope.2.id=function:_normalize_page_value:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=24
scope.2.semanticHash=2c2c770ed9411c97
scope.3.id=function:_normalize_market_buy_meta:26
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=37
scope.3.semanticHash=0f2ae9542e165ce2
scope.4.id=function:_validate_market_player:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=41
scope.4.semanticHash=089c950a65677afb
scope.5.id=function:_validate_market_entry:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=45
scope.5.semanticHash=05ea0225d948aa48
scope.6.id=function:_validate_market_buy_meta:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=49
scope.6.semanticHash=f1c72a58a94421ad
scope.7.id=function:_normalize_market_buy_action:51
scope.7.kind=function
scope.7.startLine=51
scope.7.endLine=55
scope.7.semanticHash=1402fc8b6246b92f
scope.8.id=function:_handle_market_buy:60
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=67
scope.8.semanticHash=36771ae1696eba4d
scope.9.id=function:_build:57
scope.9.kind=function
scope.9.startLine=57
scope.9.endLine=78
scope.9.semanticHash=65d878dec9e31e8d
]]
