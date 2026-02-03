local inventory = require("src.game.player.Inventory")
local constants = require("Config.Generated.Constants")
local vehicles_cfg = require("Config.Generated.Vehicles")
local logger = require("src.core.Logger")
local bankruptcy_manager = require("src.game.game.BankruptcyManager")
require "vendor.third_party.ClassUtils"
require "vendor.third_party.Utils"

---玩家对象，管理玩家资产、状态和物品
local player = Class("Player")

local deep_copy = Utils.deep_copy

local vehicle_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_by_id[cfg.id] = cfg
end
local default_vehicle_cfg = {
  id = 0,
  name = "",
  dice_count = constants.default_dice_count,
  indestructible = false,
}

local function _normalize_currency(currency)
  assert(currency ~= nil and currency ~= "", "missing currency")
  return currency
end

---内部方法：更新玩家状态到存储
function player:_store_set(path, value)
  assert(self._store ~= nil, "missing store")
  self._store:set(path, value)
end

---创建新玩家实例
function player:init(attrs)
  assert(attrs ~= nil, "Player.new(attrs) requires attrs")
  local constants = attrs.constants
  assert(constants ~= nil, "Player.new(attrs) requires attrs.constants")

  local balances = attrs.balances
  assert(balances ~= nil, "Player.new(attrs) requires attrs.balances")
  for currency, amount in pairs(balances) do
    local key = _normalize_currency(currency)
    balances[key] = amount
  end

  local cash = balances["金币"]
  assert(cash ~= nil, "balances missing 金币")
  balances["金币"] = nil
  assert(balances["金豆"] ~= nil, "balances missing 金豆")
  assert(balances["乐园币"] ~= nil, "balances missing 乐园币")

  self.id = attrs.id
  assert(attrs.name ~= nil, "Player.new(attrs) requires attrs.name")
  self.name = attrs.name
  self.role_id = attrs.role_id
  self.is_ai = attrs.is_ai
  self.auto = attrs.auto
  self.cash = cash
  self.position = attrs.start_index
  self.seat_id = nil
  self.deity_duration_turns = attrs.deity_duration_turns
  self.status = {
    stay_turns = 0,
    deity = { type = "", remaining = 0 },
    pending_remote_dice = nil,
    pending_dice_multiplier = 1,
    pending_free_rent = false,
    pending_tax_free = false,
  }
  self.inventory = attrs.inventory
  self.properties = {}
  self.balances = balances
  self.eliminated = false
end

---创建新玩家实例
---获取玩家指定币种的余额
function player:balance(currency)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return self.cash
  end
  local value = self.balances[key]
  assert(value ~= nil, "missing balance: " .. tostring(key))
  return value
end

---扣除玩家指定币种的余额
function player:deduct_balance(currency, amount)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return self:deduct_cash(amount)
  end
  local current = self.balances[key]
  assert(current ~= nil, "missing balance: " .. tostring(key))
  local next_value = current - amount
  self.balances[key] = next_value
  self:_store_set({ "players", self.id, "balances", key }, next_value)
  return next_value
end

---增加玩家现金
function player:add_cash(amount)
  self.cash = self.cash + amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
end

---设置玩家现金（绝对值）
function player:set_cash(amount)
  self.cash = amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
end

---扣除玩家现金
function player:deduct_cash(amount)
  self.cash = self.cash - amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
  return self.cash
end

---检查玩家是否拥有特定神力
function player:has_deity(name)
  return self.status.deity.type == name and self.status.deity.remaining > 0
end

---设置或清除玩家的神力状态
function player:clear_deity()
  self.status.deity.type = ""
  self.status.deity.remaining = 0
  self:_store_set({ "players", self.id, "status", "deity" }, deep_copy(self.status.deity))
end

function player:set_deity(name, duration)
  assert(name ~= nil, "missing deity name")
  self.status.deity.type = name
  self.status.deity.remaining = duration or self.deity_duration_turns
  self:_store_set({ "players", self.id, "status", "deity" }, deep_copy(self.status.deity))
end

---减少神力的剩余回合数
function player:tick_deity()
  local deity = self.status.deity
  if deity.remaining <= 0 then
    return
  end
  deity.remaining = deity.remaining - 1
  if deity.remaining <= 0 then
    self:clear_deity()
    return
  end
  self:_store_set({ "players", self.id, "status", "deity", "remaining" }, deity.remaining)
end

---清除玩家的临时标志位（用于回合开始）
function player:clear_temporal_flags()
  self.status.pending_dice_multiplier = 1
  self.status.pending_free_rent = false
  self.status.pending_tax_free = false
  self.status.pending_remote_dice = nil
  self:_store_set({ "players", self.id, "status" }, deep_copy(self.status))
end

---快速检查玩家是否拥有天使神力
function player:has_angel()
  return self:has_deity("angel")
end

function player:vehicle_cfg()
  local seat_id = self.seat_id
  if seat_id then
    local cfg = vehicle_by_id[seat_id]
    assert(cfg ~= nil, "missing vehicle cfg: " .. tostring(seat_id))
    return cfg
  end
  local cfg = default_vehicle_cfg
  return cfg
end

function player:vehicle_name()
  return self:vehicle_cfg().name
end

function player:dice_count()
  return self:vehicle_cfg().dice_count
end

function player:is_vehicle_indestructible()
  return self:vehicle_cfg().indestructible == true
end

function player:apply_hospital_effects(game)
  game:set_player_status(self, "stay_turns", constants.hospital_stay_turns)

  local fee = constants.hospital_fee
  if self.cash < fee then
    logger.event(self.name .. " 资金不足，无法支付医药费 " .. fee)
    bankruptcy_manager.eliminate(game, self)
    return
  end
  self:deduct_cash(fee)
  logger.event(self.name .. " 支付医药费 " .. fee)
  if self.cash <= 0 then
    bankruptcy_manager.eliminate(game, self)
    return
  end

  logger.event(self.name .. " 住院，需停留 " .. self.status.stay_turns .. " 回合")
end

function player:send_to_hospital(game)
  local hospital_index = game.board:find_first_by_type("hospital")
  assert(hospital_index ~= nil, "missing hospital tile")
  game:update_player_position(self, hospital_index)
  game:set_player_status(self, "move_dir", nil)
  self:apply_hospital_effects(game)
end

function player:apply_mountain_effects(game)
  game:set_player_status(self, "stay_turns", constants.mountain_stay_turns)
  logger.event(self.name .. " 进入深山，停留 " .. self.status.stay_turns .. " 回合")
end

function player:send_to_mountain(game)
  local idx = game.board:find_first_by_type("mountain")
  assert(idx ~= nil, "missing mountain tile")
  game:update_player_position(self, idx)
  game:set_player_status(self, "move_dir", nil)
  self:apply_mountain_effects(game)
end

function player:is_in_mountain(game)
  local tile = game.board:get_tile(self.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(self.position))
  return tile.type == "mountain"
end

return player

