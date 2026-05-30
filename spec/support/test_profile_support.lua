local support = require("spec.support.shared_support")
local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local default_ports = require("src.turn.output.default_ports")

local M = {}

function M.new_game(opts)
  opts = opts or {}
  local managed = opts.managed == true
  local game = require("src.app.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = not managed and { [2] = true, [3] = true, [4] = true } or {},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
  if managed then
    for i = 2, #game.players do
      game.players[i].auto = true
    end
  end
  return game
end

M.with_patches = support.with_patches

return M
