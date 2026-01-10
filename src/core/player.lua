local constants = require("src.config.constants")

local Inventory = require("src.core.inventory")

local Player = {}
Player.__index = Player

function Player.new(attrs)
  local p = {
    id = attrs.id,
    name = attrs.name or ("玩家" .. attrs.id),
    role_id = attrs.role_id,
    is_ai = attrs.is_ai or false,
    auto = attrs.auto or false,
    cash = constants.starting_cash,
    position = attrs.start_index or 1,
    seat_id = nil,
    status = {
      stay_turns = 0,
      deity = nil, -- { type="angel"|"rich"|"poor", remaining=5 }
      pending_remote_dice = nil, -- { values = {..} }
      pending_dice_multiplier = 1,
      pending_free_rent = false,
      pending_tax_free = false,
    },
    inventory = attrs.inventory or Inventory.new(),
    properties = {},
    eliminated = false,
  }
  return setmetatable(p, Player)
end

function Player:add_cash(amount)
  self.cash = self.cash + amount
end

function Player:deduct_cash(amount)
  self.cash = self.cash - amount
  return self.cash
end

function Player:net_worth(board)
  local total = self.cash
  for tile_id in pairs(self.properties) do
    local tile = board:get_tile_by_id(tile_id)
    if tile then
      total = total + tile:total_invested()
    end
  end
  return total
end

function Player:has_deity(name)
  return self.status.deity ~= nil and self.status.deity.type == name and self.status.deity.remaining > 0
end

function Player:set_deity(name, duration)
  if name == nil then
    self.status.deity = nil
    return
  end
  self.status.deity = { type = name, remaining = duration or constants.deity_duration_turns }
end

function Player:tick_deity()
  local deity = self.status.deity
  if deity then
    deity.remaining = deity.remaining - 1
    if deity.remaining <= 0 then
      self.status.deity = nil
    end
  end
end

function Player:clear_temporal_flags()
  self.status.pending_remote_dice = nil
  self.status.pending_dice_multiplier = 1
  self.status.pending_free_rent = false
  self.status.pending_tax_free = false
end

return Player
