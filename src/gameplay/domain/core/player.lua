local Inventory = require("src.gameplay.domain.core.inventory")
local Tables = require("src.util.tables")

local Player = {}
Player.__index = Player

local deep_copy = Tables.deep_copy

function Player:_store_set(path, value)
  if self._store and self._store.set then
    self._store:set(path, value)
  end
end

function Player.new(attrs)
  attrs = attrs or {}
  local constants = attrs.constants
  assert(constants ~= nil, "Player.new(attrs) requires attrs.constants")

  local p = {
    id = attrs.id,
    name = attrs.name or ("玩家" .. attrs.id),
    role_id = attrs.role_id,
    is_ai = attrs.is_ai or false,
    auto = attrs.auto or false,
    cash = attrs.starting_cash or constants.starting_cash,
    position = attrs.start_index or 1,
    seat_id = nil,
    deity_duration_turns = attrs.deity_duration_turns or constants.deity_duration_turns,
    status = {
      stay_turns = 0,
      deity = nil, -- { type="angel"|"rich"|"poor", remaining=5 }
      pending_remote_dice = nil, -- { values = {..} }
      pending_dice_multiplier = 1,
      pending_free_rent = false,
      pending_tax_free = false,
    },
    inventory = attrs.inventory or Inventory.new({ constants = constants }),
    properties = {},
    eliminated = false,
  }
  return setmetatable(p, Player)
end

function Player:add_cash(amount)
  self.cash = self.cash + amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
end

function Player:set_cash(amount)
  self.cash = amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
end

function Player:deduct_cash(amount)
  self.cash = self.cash - amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
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
    self:_store_set({ "players", self.id, "status", "deity" }, nil)
    return
  end
  self.status.deity = { type = name, remaining = duration or self.deity_duration_turns }
  self:_store_set({ "players", self.id, "status", "deity" }, deep_copy(self.status.deity))
end

function Player:tick_deity()
  local deity = self.status.deity
  if deity then
    deity.remaining = deity.remaining - 1
    if deity.remaining <= 0 then
      self.status.deity = nil
      self:_store_set({ "players", self.id, "status", "deity" }, nil)
      return
    end
    self:_store_set({ "players", self.id, "status", "deity" }, deep_copy(deity))
  end
end

function Player:clear_temporal_flags()
  self.status.pending_remote_dice = nil
  self.status.pending_dice_multiplier = 1
  self.status.pending_free_rent = false
  self.status.pending_tax_free = false

  self:_store_set({ "players", self.id, "status", "pending_remote_dice" }, nil)
  self:_store_set({ "players", self.id, "status", "pending_dice_multiplier" }, 1)
  self:_store_set({ "players", self.id, "status", "pending_free_rent" }, false)
  self:_store_set({ "players", self.id, "status", "pending_tax_free" }, false)
end

return Player
