local number_utils = require("src.foundation.number")
local cash_display = require("src.rules.market.cash_display")
local game_driver = require("tools.acceptance.game_driver")

local market_cash_steps = {}

local function _resolve_player(world)
  if world.market_player then
    return world.market_player
  end
  if world.driver then
    return game_driver.current_player(world.driver)
  end
  return nil
end

function market_cash_steps.handlers()
  return {
    ["当前角色ID为<验证角色ID>"] = function(world, example)
      local expected = number_utils.to_integer(example["验证角色ID"])
      if expected == nil then
        return nil, "invalid 验证角色ID: " .. tostring(example["验证角色ID"])
      end
      if world.ui_role_id ~= expected then
        return nil, "expected ui_role_id=" .. tostring(expected) ..
          ", got " .. tostring(world.ui_role_id)
      end
      return true
    end,

    ["玩家当前现金为<设置金额>"] = function(world, example)
      local amount = number_utils.to_integer(example["设置金额"])
      if amount == nil then return nil, "invalid amount: " .. tostring(example["设置金额"]) end
      local player = _resolve_player(world)
      if world.driver and player then
        world.driver.game:set_player_cash(player, amount)
      end
      world.market_cash_amount = amount
      return true
    end,

    ["黑市向玩家开放"] = function(world)
      local player = _resolve_player(world)
      if world.driver and player then
        world.displayed_cash = cash_display.for_player(world.driver.game, player)
      else
        world.displayed_cash = world.market_cash_amount or 0
      end
      return true
    end,

    ["黑市现金显示区刷新"] = function(world)
      local player = _resolve_player(world)
      if world.driver and player then
        world.displayed_cash = cash_display.for_player(world.driver.game, player)
      end
      return true
    end,

    ["黑市现金显示区显示金额<显示金额>"] = function(world, example)
      local expected = number_utils.to_integer(example["显示金额"])
      if expected == nil then return nil, "invalid amount: " .. tostring(example["显示金额"]) end
      if world.displayed_cash ~= expected then
        return nil, "expected displayed cash " .. tostring(expected) .. ", got " .. tostring(world.displayed_cash)
      end
      return true
    end,
  }
end

return market_cash_steps
