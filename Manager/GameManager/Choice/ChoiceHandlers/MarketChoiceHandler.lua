local MarketService = require("Manager.GameManager.Market.MarketService")
local IntentDispatcher = require("Library.Monopoly.IntentDispatcher")
local Convert = require("Library.Monopoly.Convert")

local MarketChoiceHandler = {}

function MarketChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice

  local function handle_market_buy(game, choice, action)
    if not choice or choice.kind ~= "market_buy" then
      return nil
    end

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local product_id = Convert.to_number(action.option_id)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    if player and product_id then
      local res = MarketService.buy(game, player, product_id)
      if type(res) == "table" and res.intent then
        IntentDispatcher.dispatch(game, res.intent)
        return { stay = res.intent.kind == "need_choice" }
      end
    end
    return finish_choice(game, false)
  end

  local function handle_vehicle_replace(game, choice, action)
    if not choice or choice.kind ~= "market_vehicle_replace" then
      return nil
    end

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local use = action and action.option_id == "use"
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local product_id = Convert.to_number(meta.product_id)
    if use and player and product_id then
      MarketService.buy_with_opts(game, player, product_id, { skip_vehicle_prompt = true })
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = handle_market_buy,
    market_vehicle_replace = handle_vehicle_replace,
  }
end

return MarketChoiceHandler
