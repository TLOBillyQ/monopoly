local market_service = require("src.game.systems.market.market_service")
local choice_outcome = require("src.game.systems.market.application.choice_outcome")
local number_utils = require("src.core.utils.number_utils")
local market_context = require("src.game.systems.market.application.context")

local market_choice_handler = {}

function market_choice_handler.build(helpers)
  local finish_choice = helpers.finish_choice

  local function _handle_market_buy(game, choice, action)
    local product_id = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(product_id ~= nil, "missing product_id")
    local entry = market_context.entry_by_id(product_id)
    assert(entry ~= nil, "missing market entry: " .. tostring(product_id))
    local result = market_service.purchase.execute(game, player, product_id, nil)
    return choice_outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  end

  local function _handle_vehicle_replace(game, choice, action)
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
    market_buy = {
      required_meta = { "player_id" },
      execute = _handle_market_buy,
    },
    market_vehicle_replace = {
      required_meta = { "player_id", "product_id" },
      execute = _handle_vehicle_replace,
    },
  }
end

return market_choice_handler
