local number_utils = require("src.foundation.number")
local cash_display = require("src.rules.market.cash_display")

local market_cash_steps = {}

function market_cash_steps.handlers()
  return {
    ["玩家当前现金为<p2>"] = function(world, example)
      local amount = number_utils.to_integer(example.p2)
      if amount == nil then return nil, "invalid amount: " .. tostring(example.p2) end
      if world.driver and world.market_player then
        world.driver.game:set_player_cash(world.market_player, amount)
      end
      world.market_cash_amount = amount
      return true
    end,

    ["黑市向玩家开放"] = function(world)
      if world.driver and world.market_player then
        world.displayed_cash = cash_display.for_player(world.driver.game, world.market_player)
      else
        world.displayed_cash = world.market_cash_amount or 0
      end
      return true
    end,

    ["黑市现金显示区显示金额<p3>"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
      if expected == nil then return nil, "invalid amount: " .. tostring(example.p3) end
      if world.displayed_cash ~= expected then
        return nil, "expected displayed cash " .. tostring(expected) .. ", got " .. tostring(world.displayed_cash)
      end
      return true
    end,
  }
end

return market_cash_steps
