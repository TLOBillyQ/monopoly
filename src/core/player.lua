local Inventory = require("src.core.inventory")
local Tables = require("src.util.tables")
local Tile = require("src.core.tile")
local constants = require("src.config.constants")
local logger = require("src.util.logger")

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
      deity = nil, 
      pending_remote_dice = nil, 
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
      local st = Tile.get_state(self._store and { store = self._store } or nil, tile)
      local level = st.level or 0
      if st.owner_id then
        local price = tile.price or 0
        total = total + price * ((2 ^ (level + 1)) - 1)
      end
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

function Player:apply_deity(deity_type)
  self:set_deity(deity_type, constants.deity_duration_turns)
  logger.event(self.name .. " 获得附身：" .. deity_type)
end

function Player:apply_hospital_effects(game)
  if game.set_player_status then
    game:set_player_status(self, "stay_turns", constants.hospital_stay_turns)
  else
    self.status.stay_turns = constants.hospital_stay_turns
  end
  
  local fee = constants.hospital_fee
  if self.cash < fee then
      local bankruptcy = game and game.services and game.services.bankruptcy
      if not bankruptcy then
        logger.warn("缺少 BankruptcyService，无法淘汰破产玩家")
        return
      end
      bankruptcy.eliminate(game, self)
      return
  end
  self:deduct_cash(fee)
  logger.event(self.name .. " 支付医药费 " .. fee)

  logger.event(self.name .. " 住院，需停留 " .. self.status.stay_turns .. " 回合")
end

function Player:send_to_hospital(game)
  local hospital_index = game.board:find_first_by_type("hospital")
  if hospital_index then
    game:update_player_position(self, hospital_index)
  end
  if game.set_player_status then
    game:set_player_status(self, "move_dir", nil)
  end
  self:apply_hospital_effects(game)
end

function Player:apply_mountain_effects(game)
  if game.set_player_status then
    game:set_player_status(self, "stay_turns", constants.mountain_stay_turns)
  else
      self.status.stay_turns = constants.mountain_stay_turns
  end
  logger.event(self.name .. " 进入深山，停留 " .. self.status.stay_turns .. " 回合")
end

function Player:send_to_mountain(game)
  local idx = game.board:find_first_by_type("mountain")
  if idx then
    game:update_player_position(self, idx)
  end
  if game.set_player_status then
    game:set_player_status(self, "move_dir", nil)
  end
  self:apply_mountain_effects(game)
end

function Player:is_in_mountain(game)
  local tile = game.board:get_tile(self.position)
  return tile and tile.type == "mountain"
end

return Player
