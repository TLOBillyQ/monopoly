local app = require("src.game.game.Game")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")

local game = app:new({
  players = { "P1", "P2" },
  ai = { [2] = true },
  auto_all = false,
  map = map_cfg,
  tiles = tiles_cfg,
})
local player = game.players[1]

assert(player.set_cash == nil, "player should not expose set_cash")
assert(player.add_cash == nil, "player should not expose add_cash")
assert(player.deduct_cash == nil, "player should not expose deduct_cash")
assert(player.set_deity == nil, "player should not expose set_deity")
assert(player.clear_deity == nil, "player should not expose clear_deity")
assert(player.tick_deity == nil, "player should not expose tick_deity")
assert(player.dice_count == nil, "player should not expose dice_count")
assert(player.send_to_hospital == nil, "player should not expose send_to_hospital")

print("Contract player_dto_no_methods passed")
