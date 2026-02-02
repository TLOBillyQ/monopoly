local Inventory = require("Components.Inventory")
local Constants = require("Config.Generated.Constants")
local VehiclesCfg = require("Config.Generated.Vehicles")
local Logger = require("Components.Logger")
local ServiceKey = require("Globals.ServiceKeys")
require "Library.ClassUtils"
require "Library.Utils"

---@class Player
---@field id number
---@field name string
---@field role_id number?
---@field is_ai boolean
---@field auto boolean
---@field cash number
---@field position number
---@field seat_id number?
---@field deity_duration_turns number
---@field status table
---@field inventory Inventory
---@field properties table
---@field balances table
---@field eliminated boolean
---@field _store Store?
---玩家对象，管理玩家资产、状态和物品
local Player = Class("Player")

local deep_copy = Utils.deep_copy

local vehicle_by_id = {}
for _, cfg in ipairs(VehiclesCfg) do
  vehicle_by_id[cfg.id] = cfg
end
local default_vehicle_cfg = {
  id = 0,
  name = "",
  dice_count = Constants.default_dice_count,
  indestructible = false,
}

local function _NormalizeCurrency(currency)
  assert(currency ~= nil and currency ~= "", "missing currency")
  return currency
end

---内部方法：更新玩家状态到存储
---@param self Player
---@param path table 状态路径
---@param value any 值
function Player:_StoreSet(path, value)
  assert(self._store ~= nil, "missing store")
  self._store:set(path, value)
end

---创建新玩家实例
---@param attrs table 玩家属性表（id/name/role_id/constants等）
function Player:Init(attrs)
  assert(attrs ~= nil, "Player.new(attrs) requires attrs")
  local constants = attrs.constants
  assert(constants ~= nil, "Player.new(attrs) requires attrs.constants")

  local balances = attrs.balances
  assert(balances ~= nil, "Player.new(attrs) requires attrs.balances")
  for currency, amount in pairs(balances) do
    local key = _NormalizeCurrency(currency)
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
---@param attrs table 玩家属性表（id/name/role_id/constants等）
---@return Player 新玩家对象
---获取玩家指定币种的余额
---@param self Player
---@param currency string? 币种名称（默认"金币"）
---@return number 余额
function Player:Balance(currency)
  local key = _NormalizeCurrency(currency)
  if key == "金币" then
    return self.cash
  end
  local value = self.balances[key]
  assert(value ~= nil, "missing balance: " .. tostring(key))
  return value
end

---扣除玩家指定币种的余额
---@param self Player
---@param currency string? 币种名称
---@param amount number 扣除金额
---@return number 扣除后的余额
function Player:DeductBalance(currency, amount)
  local key = _NormalizeCurrency(currency)
  if key == "金币" then
    return self:DeductCash(amount)
  end
  local current = self.balances[key]
  assert(current ~= nil, "missing balance: " .. tostring(key))
  local next_value = current - amount
  self.balances[key] = next_value
  self:_StoreSet({ "players", self.id, "balances", key }, next_value)
  return next_value
end

---增加玩家现金
---@param self Player
---@param amount number 增加金额
function Player:AddCash(amount)
  self.cash = self.cash + amount
  self:_StoreSet({ "players", self.id, "cash" }, self.cash)
end

---设置玩家现金（绝对值）
---@param self Player
---@param amount number 现金数量
function Player:SetCash(amount)
  self.cash = amount
  self:_StoreSet({ "players", self.id, "cash" }, self.cash)
end

---扣除玩家现金
---@param self Player
---@param amount number 扣除金额
---@return number 扣除后的现金
function Player:DeductCash(amount)
  self.cash = self.cash - amount
  self:_StoreSet({ "players", self.id, "cash" }, self.cash)
  return self.cash
end

---检查玩家是否拥有特定神力
---@param self Player
---@param name string 神力名称
---@return boolean 是否拥有该神力
function Player:HasDeity(name)
  return self.status.deity.type == name and self.status.deity.remaining > 0
end

---设置或清除玩家的神力状态
---@param self Player
---@param name string? 神力名称，nil表示清除
---@param duration number? 持续回合数
function Player:ClearDeity()
  self.status.deity.type = ""
  self.status.deity.remaining = 0
  self:_StoreSet({ "players", self.id, "status", "deity" }, deep_copy(self.status.deity))
end

function Player:SetDeity(name, duration)
  assert(name ~= nil, "missing deity name")
  self.status.deity.type = name
  self.status.deity.remaining = duration or self.deity_duration_turns
  self:_StoreSet({ "players", self.id, "status", "deity" }, deep_copy(self.status.deity))
end

---减少神力的剩余回合数
---@param self Player
function Player:TickDeity()
  local deity = self.status.deity
  if deity.remaining <= 0 then
    return
  end
  deity.remaining = deity.remaining - 1
  if deity.remaining <= 0 then
    self:ClearDeity()
    return
  end
  self:_StoreSet({ "players", self.id, "status", "deity", "remaining" }, deity.remaining)
end

---清除玩家的临时标志位（用于回合开始）
---@param self Player
function Player:ClearTemporalFlags()
  self.status.pending_dice_multiplier = 1
  self.status.pending_free_rent = false
  self.status.pending_tax_free = false
  self.status.pending_remote_dice = nil
  self:_StoreSet({ "players", self.id, "status" }, deep_copy(self.status))
end

---快速检查玩家是否拥有天使神力
---@param self Player
---@return boolean 是否有天使神力
function Player:HasAngel()
  return self:HasDeity("angel")
end

function Player:VehicleCfg()
  local seat_id = self.seat_id
  if seat_id then
    local cfg = vehicle_by_id[seat_id]
    assert(cfg ~= nil, "missing vehicle cfg: " .. tostring(seat_id))
    return cfg
  end
  local cfg = default_vehicle_cfg
  return cfg
end

function Player:VehicleName()
  return self:VehicleCfg().name
end

function Player:DiceCount()
  return self:VehicleCfg().dice_count
end

function Player:IsVehicleIndestructible()
  return self:VehicleCfg().indestructible == true
end

function Player:ApplyHospitalEffects(game)
  game:SetPlayerStatus(self, "stay_turns", Constants.hospital_stay_turns)

  local fee = Constants.hospital_fee
  if self.cash < fee then
    Logger.Event(self.name .. " 资金不足，无法支付医药费 " .. fee)
    local bankruptcy = game:GetService(ServiceKey.bankruptcy)
    bankruptcy.Eliminate(game, self)
    return
  end
  self:DeductCash(fee)
  Logger.Event(self.name .. " 支付医药费 " .. fee)
  if self.cash <= 0 then
    local bankruptcy = game:GetService(ServiceKey.bankruptcy)
    bankruptcy.Eliminate(game, self)
    return
  end

  Logger.Event(self.name .. " 住院，需停留 " .. self.status.stay_turns .. " 回合")
end

function Player:SendToHospital(game)
  local hospital_index = game.board:FindFirstByType("hospital")
  assert(hospital_index ~= nil, "missing hospital tile")
  game:UpdatePlayerPosition(self, hospital_index)
  game:SetPlayerStatus(self, "move_dir", nil)
  self:ApplyHospitalEffects(game)
end

function Player:ApplyMountainEffects(game)
  game:SetPlayerStatus(self, "stay_turns", Constants.mountain_stay_turns)
  Logger.Event(self.name .. " 进入深山，停留 " .. self.status.stay_turns .. " 回合")
end

function Player:SendToMountain(game)
  local idx = game.board:FindFirstByType("mountain")
  assert(idx ~= nil, "missing mountain tile")
  game:UpdatePlayerPosition(self, idx)
  game:SetPlayerStatus(self, "move_dir", nil)
  self:ApplyMountainEffects(game)
end

function Player:IsInMountain(game)
  local tile = game.board:GetTile(self.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(self.position))
  return tile.type == "mountain"
end

return Player


