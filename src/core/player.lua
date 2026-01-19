local Inventory = require("src.core.inventory")
local Tables = require("src.util.tables")
local gameplay_constants = require("src.gameplay.constants")

local Player = {}
Player.__index = Player

local deep_copy = Tables.deep_copy

local function normalize_currency(currency)
  if currency == nil or currency == "" then
    return "金币"
  end
  return currency
end

local function is_unlimited_currency(currency)
  return currency == gameplay_constants.unlimited_currency
end

function Player:_store_set(path, value)
  if self._store and self._store.set then
    self._store:set(path, value)
  end
end

function Player.new(attrs)
  attrs = attrs or {}
  local constants = attrs.constants
  assert(constants ~= nil, "Player.new(attrs) requires attrs.constants")

  local balances = {}
  if attrs.balances then
    for currency, amount in pairs(attrs.balances) do
      if normalize_currency(currency) == "金币" then
        balances["金币"] = amount
      else
        balances[currency] = amount
      end
    end
  end

  local cash = attrs.starting_cash or constants.starting_cash
  if balances["金币"] ~= nil then
    cash = balances["金币"]
    balances["金币"] = nil
  end
  if balances["金豆"] == nil and constants.starting_jindou ~= nil then
    balances["金豆"] = constants.starting_jindou
  end
  if balances["乐园币"] == nil and constants.starting_leyuanbi ~= nil then
    balances["乐园币"] = constants.starting_leyuanbi
  end

  local p = {
    id = attrs.id,
    name = attrs.name or ("玩家" .. attrs.id),
    role_id = attrs.role_id,
    is_ai = attrs.is_ai or false,
    auto = attrs.auto or false,
    cash = cash,
    position = attrs.start_index or 1,
    seat_id = nil,
    deity_duration_turns = attrs.deity_duration_turns or constants.deity_duration_turns,
    status = {
      stay_turns = 0,
      deity = nil, 
      pending_remote_dice = nil, 
      pending_dice_multiplier = 1,
      pending_free_rent = false,
      pending_tax_free = false,
    },
    inventory = attrs.inventory or Inventory.new({ constants = constants }),
    properties = {},
    balances = balances,
    eliminated = false,
  }
  return setmetatable(p, Player)
end

function Player:balance(currency)
  local key = normalize_currency(currency)
  if is_unlimited_currency(key) then
    return math.huge
  end
  if key == "金币" then
    return self.cash or 0
  end
  return self.balances[key] or 0
end

function Player:deduct_balance(currency, amount)
  local key = normalize_currency(currency)
  if is_unlimited_currency(key) then
    return math.huge
  end
  if key == "金币" then
    return self:deduct_cash(amount)
  end
  local next_value = (self.balances[key] or 0) - amount
  self.balances[key] = next_value
  self:_store_set({ "players", self.id, "balances", key }, next_value)
  return next_value
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
    self:_store_set({ "players", self.id, "status", "deity", "remaining" }, deity.remaining)
  end
end

function Player:clear_temporal_flags()
  self.status.pending_dice_multiplier = 1
  self.status.pending_free_rent = false
  self.status.pending_tax_free = false
  self.status.pending_remote_dice = nil
  -- Update store if necessary, but individual flag updates might happen elsewhere.
  -- To be safe, let's sync status if store exists.
  if self._store then
    self:_store_set({ "players", self.id, "status" }, deep_copy(self.status))
  end
end

function Player:has_angel()
  return self:has_deity("angel")
end

return Player
