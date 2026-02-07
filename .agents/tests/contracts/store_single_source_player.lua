local app = require("src.game.game.Game")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local store_paths = require("src.core.StorePaths")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local game = app:new({
  players = { "P1", "P2" },
  ai = { [2] = true },
  auto_all = false,
  map = map_cfg,
  tiles = tiles_cfg,
})
local player = game.players[1]

game:set_player_cash(player, 1234)
_assert_eq(game.store:get(store_paths.players.cash(player.id)), 1234, "cash mirrored to store")

game:deduct_player_balance(player, "金币", 234)
_assert_eq(game.store:get(store_paths.players.cash(player.id)), 1000, "cash deduct mirrored to store")

game:set_player_balance(player, "金豆", 99)
_assert_eq(game.store:get(store_paths.players.balance(player.id, "金豆")), 99, "balance mirrored to store")

print("Contract store_single_source_player passed")
