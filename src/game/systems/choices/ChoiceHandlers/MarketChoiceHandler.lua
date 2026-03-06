local market_service = require("src.game.systems.market.MarketService")
local choice_outcome = require("src.game.systems.market.service.ChoiceOutcome")
local number_utils = require("src.core.NumberUtils")
local market_context = require("src.game.systems.market.service.Context")

local market_choice_handler = {}

function market_choice_handler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice

  local function _handle_market_buy(game, choice, action)
    assert(choice ~= nil and choice.kind == "market_buy", "invalid market choice")

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local product_id = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(product_id ~= nil, "missing product_id")
    local entry = market_context.entry_by_id(product_id)
    assert(entry ~= nil, "missing market entry: " .. tostring(product_id))
    local res = market_service.purchase.execute(game, player, product_id, nil)
    return choice_outcome.resolve_purchase(game, choice, player, entry, res, finish_choice)
  end

  local function _handle_vehicle_replace(game, choice, action)
    assert(choice ~= nil and choice.kind == "market_vehicle_replace", "invalid vehicle replace choice")

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    assert(action ~= nil, "missing action")
    local use = action.option_id == "use"
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local product_id = assert(number_utils.to_integer(meta.product_id), "missing product_id")
    if use then
      market_service.purchase.execute(game, player, product_id, { skip_vehicle_prompt = true })
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = _handle_market_buy,
    market_vehicle_replace = _handle_vehicle_replace,
  }
end

return market_choice_handler
