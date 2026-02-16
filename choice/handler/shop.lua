local market = require("game.shop")
local intent_dispatcher = require("turn.intent")
local number_utils = require("core.math")

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
    local res = market.buy_with_opts(game, player, product_id, nil)
    if type(res) == "table" then
      local intent = res.intent or {}
      intent_dispatcher.dispatch(game, intent)
      return { stay = intent.kind == "need_choice" }
    end
    return finish_choice(game, false)
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
      market.buy_with_opts(game, player, product_id, { skip_vehicle_prompt = true })
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = _handle_market_buy,
    market_vehicle_replace = _handle_vehicle_replace,
  }
end

return market_choice_handler
