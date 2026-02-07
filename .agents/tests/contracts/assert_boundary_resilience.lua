local chance = require("src.game.chance.Chance")
local chance_registry = require("src.game.chance.ChanceRegistry")

local old_trigger = _G.TriggerCustomEvent
_G.TriggerCustomEvent = nil

chance_registry.register_defaults()

local game = {
  add_player_cash = function(_, player, delta)
    player.cash = (player.cash or 0) + delta
  end,
  player_has_deity = function()
    return false
  end,
  player_has_angel = function()
    return true
  end,
}
local player = { name = "P1", cash = 0 }

local ok, err = pcall(function()
  chance.resolve(game, player, { negative = true, effect = "add_cash", amount = 10, target = "self" }, {})
  game.player_has_angel = function()
    return false
  end
  chance.resolve(game, player, { negative = false, effect = "add_cash", amount = 10, target = "self" }, {})
end)

_G.TriggerCustomEvent = old_trigger

assert(ok, "chance resolve should not crash when TriggerCustomEvent missing: " .. tostring(err))
assert(player.cash == 10, "add_cash should still apply without TriggerCustomEvent")

print("Contract assert_boundary_resilience passed")
