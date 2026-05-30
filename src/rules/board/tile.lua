require "vendor.third_party.ClassUtils"

---地块类，代表棋盘上的一个地块
local tile = Class("Tile")

---从配置创建新地块
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

---获取地块的游戏状态（所有者和等级）
function tile.get_state(game, land_tile)
  assert(land_tile and land_tile.type == "land", "Tile.GetState requires land tile")
  return { owner_id = land_tile.owner_id, level = land_tile.level }
end

return tile

--[[ mutate4lua-manifest
version=2
projectHash=ccb8291f9390d1b5
scope.0.id=chunk:src/rules/board/tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=d9205d99c500c7ca
scope.1.id=function:tile:init:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=20
scope.1.semanticHash=1922850574e474b6
scope.2.id=function:tile.get_state:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=26
scope.2.semanticHash=86df31d682680a16
]]
