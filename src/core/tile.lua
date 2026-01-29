---@class Tile
---地块类，代表棋盘上的一个地块
local Tile = {}
Tile.__index = Tile

---从配置创建新地块
---@param cfg table 地块配置（id/name/type/price等）
---@return Tile 新地块对象
function Tile.from_config(cfg)
  local t = {
    id = cfg.id,
    name = cfg.name,
    type = cfg.type,
    price = cfg.price or 0,
    upgrade_costs = cfg.upgrade_costs or {},
    rents = cfg.rents or {},
    row = cfg.row,
    col = cfg.col,
    build_row = cfg.build_row,
    build_col = cfg.build_col,
  }
  return setmetatable(t, Tile)
end

---获取地块的游戏状态（所有者和等级）
---@param game Game 游戏实例
---@param tile Tile 地块对象（必须是land类型）
---@return table 包含owner_id和level的状态表
function Tile.get_state(game, tile)
  assert(game and game.store, "Tile.get_state requires game.store")
  assert(tile and tile.type == "land", "Tile.get_state requires land tile")

  local s = game.store:get({ "board", "tiles", tile.id })
  assert(type(s) == "table", "missing tile state for tile " .. tostring(tile.id))

  return { owner_id = s.owner_id, level = s.level }
end

return Tile