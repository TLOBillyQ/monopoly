require "lib.third_party.ClassUtils"

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

---从配置创建新地块
function tile.from_config(cfg)
  return tile:new(cfg)
end

---获取地块的游戏状态（所有者和等级）
function tile.get_state(game, tile)
  assert(tile and tile.type == "land", "Tile.GetState requires land tile")
  return { owner_id = tile.owner_id, level = tile.level }
end

return tile
