local market_service = require("src.rules.market")
local choice_outcome = require("src.rules.market.choice.outcome")
local number_utils = require("src.core.utils.number_utils")
local market_context = require("src.rules.market.query.context")
local availability = require("src.rules.items.availability")

local market_choice_handler = {}
local TAB_ITEM = "item"
local TAB_SKIN = "skin"

local function _normalize_market_tab(active_tab)
  if active_tab == TAB_ITEM or active_tab == TAB_SKIN then
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

function market_choice_handler.build(helpers)
  local finish_choice = helpers.finish_choice

  local function _handle_market_buy(game, choice, action)
    local meta = choice.meta
    local player = _validate_market_player(game, meta)
    local product_id = assert(number_utils.to_integer(action.option_id), "missing product_id")
    local entry = _validate_market_entry(product_id)
    local result = market_service.purchase.execute(game, player, product_id, nil)
    return choice_outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  end

  return {
    market_buy = {
      required_meta = { "player_id" },
      normalize_meta = _normalize_market_buy_meta,
      meta_validator = _validate_market_buy_meta,
      normalize_action = _normalize_market_buy_action,
      execute = _handle_market_buy,
    },
  }
end

return market_choice_handler
