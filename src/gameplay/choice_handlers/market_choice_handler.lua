local MarketService = require("src.gameplay.market_service")
local Convert = require("src.util.convert")

local MarketChoiceHandler = {}

function MarketChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local clear_choice = helpers.clear_choice

  local function handle_market_buy(game, choice, action)
    if not choice or choice.kind ~= "market_buy" then
      return nil
    end

    if is_cancel(action) then
      clear_choice(game)
      return { stay = false }
    end

    local product_id = Convert.to_number(action.option_id)
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
    if player and product_id then
      MarketService.buy(game, player, product_id)
    end
    clear_choice(game)
    return { stay = false }
  end

  return {
    market_buy = handle_market_buy,
  }
end

return MarketChoiceHandler
