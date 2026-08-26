local pricing = require("src.rules.land.pricing")
local tile_mod = require("src.rules.board.tile")

local asset_total = {}

-- Remaining total assets for a player: cash plus the invested value of every
-- land tile they own (purchase price plus per-level upgrade costs).
function asset_total.player_total(game, player)
  local total = game:player_cash(player)
  assert(total ~= nil, "missing player cash")
  for tile_id in pairs(player.properties or {}) do
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil and tile.type == "land", "invalid property tile: " .. tostring(tile_id))
    local st = tile_mod.get_state(game, tile)
    total = total + pricing.total_invested(tile, st.level)
  end
  return total
end

return asset_total

--[[ mutate4lua-manifest
version=4
projectHash=e219b0b210b80d47
scope.0.id=chunk:src/rules/land/asset_total.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=2e663a2fa1a49651
scope.1.id=function:asset_total.player_total
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=18
scope.1.semanticHash=51fa1d4a86724a01
]]
