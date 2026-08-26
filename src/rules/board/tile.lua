local Class = require("src.foundation.class")

---地块类，代表棋盘上的一个地块
local tile = Class("Tile")

function tile:init(cfg)
  self.id = cfg.id
  self.name = cfg.name
  self.type = cfg.type
  self.price = cfg.price or 0
  self.upgrade_costs = cfg.upgrade_costs or {}
  self.rents = cfg.rents or {}
  self.row = cfg.row
  self.col = cfg.col
  self.build_row = cfg.build_row
  self.build_col = cfg.build_col
  self.owner_id = nil
  self.level = 0
end

function tile.get_state(game, land_tile)
  assert(land_tile and land_tile.type == "land", "Tile.GetState requires land tile")
  return { owner_id = land_tile.owner_id, level = land_tile.level }
end

return tile

--[[ mutate4lua-manifest
version=4
projectHash=a61d8547667a28b5
scope.0.id=chunk:src/rules/board/tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=27
scope.0.semanticHash=85261f462361258c
scope.1.id=function:tile:init
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=19
scope.1.semanticHash=9e20b28e0f77e0a6
scope.2.id=function:tile.get_state
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=24
scope.2.semanticHash=b29a8c2142bf9842
]]
