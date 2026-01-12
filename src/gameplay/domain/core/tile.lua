local Tile = {}
Tile.__index = Tile

local MAX_LEVEL = 3

function Tile.from_config(cfg)
  local t = {
    id = cfg.id,
    name = cfg.name,
    type = cfg.type,
    price = cfg.price or 0,
    base_rent = cfg.base_rent or 0,
    owner_id = nil,
    level = 0, 
  }
  return setmetatable(t, Tile)
end

function Tile:can_upgrade()
  return self.type == "land" and self.owner_id ~= nil and self.level < MAX_LEVEL
end

function Tile:next_upgrade_cost()
  if not self:can_upgrade() then
    return nil
  end
  local target_level = self.level + 1
  return self.price * (2 ^ target_level)
end

function Tile:current_rent()
  if self.type ~= "land" or not self.owner_id then
    return 0
  end
  local exponent = self.level
  return self.price * (2 ^ exponent) * 0.5
end

function Tile:total_invested()
  if self.type ~= "land" or not self.owner_id then
    return 0
  end
  local total = self.price
  for lvl = 1, self.level do
    total = total + self.price * (2 ^ lvl)
  end
  return total
end

function Tile:reset()
  self.owner_id = nil
  self.level = 0
end

return Tile
