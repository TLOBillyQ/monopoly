require "Library.ClassUtils"

---@class Tile
---@field id string|number
---@field name string
---@field type string
---@field price number
---@field upgrade_costs number[]
---@field rents number[]
---@field row number?
---@field col number?
---@field build_row number?
---@field build_col number?
---地块类，代表棋盘上的一个地块
local Tile = Class("Tile")

---从配置创建新地块
---@param cfg table 地块配置（id/name/type/price等）
function Tile:Init(cfg)
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
end

---从配置创建新地块
---@param cfg table 地块配置（id/name/type/price等）
---@return Tile 新地块对象
function Tile.FromConfig(cfg)
  return Tile:new(cfg)
end

---获取地块的游戏状态（所有者和等级）
---@param game Game 游戏实例
---@param tile Tile 地块对象（必须是land类型）
---@return table 包含owner_id和level的状态表
function Tile.GetState(game, tile)
  assert(game and game.store, "Tile.GetState requires game.store")
  assert(tile and tile.type == "land", "Tile.GetState requires land tile")

  local s = game.store:Get({ "board", "tiles", tile.id })
  assert(type(s) == "table", "missing tile state for tile " .. tostring(tile.id))

  return { owner_id = s.owner_id, level = s.level }
end

return Tile
