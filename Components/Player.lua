local Inventory = require("Components.Inventory")
local Tables = require("Library.Monopoly.Tables")
require "Library.ClassUtils"

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
Player.__class_new = Player.new

local deep_copy = Tables.deep_copy

local function normalize_currency(currency)
  if currency == nil or currency == "" then
    return "金币"
  end
  return currency
end

---内部方法：更新玩家状态到存储
---@param self Player
---@param path table 状态路径
---@param value any 值
function Player:_store_set(path, value)
  if self._store and self._store.set then
    self._store:set(path, value)
  end
end

---创建新玩家实例
---@param attrs table 玩家属性表（id/name/role_id/constants等）
function Player:init(attrs)
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

  self.id = attrs.id
  self.name = attrs.name or ("玩家" .. attrs.id)
  self.role_id = attrs.role_id
  self.is_ai = attrs.is_ai or false
  self.auto = attrs.auto or false
  self.cash = cash
  self.position = attrs.start_index or 1
  self.seat_id = nil
  self.deity_duration_turns = attrs.deity_duration_turns or constants.deity_duration_turns
  self.status = {
    stay_turns = 0,
    deity = nil,
    pending_remote_dice = nil,
    pending_dice_multiplier = 1,
    pending_free_rent = false,
    pending_tax_free = false,
  }
  self.inventory = attrs.inventory or Inventory.new({ constants = constants })
  self.properties = {}
  self.balances = balances
  self.eliminated = false
end

---创建新玩家实例
---@param attrs table 玩家属性表（id/name/role_id/constants等）
---@return Player 新玩家对象
function Player.new(attrs)
  return Player.__class_new(Player, attrs)
end

---获取玩家指定币种的余额
---@param self Player
---@param currency string? 币种名称（默认"金币"）
---@return number 余额
function Player:balance(currency)
  local key = normalize_currency(currency)
  if key == "金币" then
    return self.cash or 0
  end
  return self.balances[key] or 0
end

---扣除玩家指定币种的余额
---@param self Player
---@param currency string? 币种名称
---@param amount number 扣除金额
---@return number 扣除后的余额
function Player:deduct_balance(currency, amount)
  local key = normalize_currency(currency)
  if key == "金币" then
    return self:deduct_cash(amount)
  end
  local next_value = (self.balances[key] or 0) - amount
  self.balances[key] = next_value
  self:_store_set({ "players", self.id, "balances", key }, next_value)
  return next_value
end

---增加玩家现金
---@param self Player
---@param amount number 增加金额
function Player:add_cash(amount)
  self.cash = self.cash + amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
end

---设置玩家现金（绝对值）
---@param self Player
---@param amount number 现金数量
function Player:set_cash(amount)
  self.cash = amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
end

---扣除玩家现金
---@param self Player
---@param amount number 扣除金额
---@return number 扣除后的现金
function Player:deduct_cash(amount)
  self.cash = self.cash - amount
  self:_store_set({ "players", self.id, "cash" }, self.cash)
  return self.cash
end

---检查玩家是否拥有特定神力
---@param self Player
---@param name string 神力名称
---@return boolean 是否拥有该神力
function Player:has_deity(name)
  return self.status.deity ~= nil and self.status.deity.type == name and self.status.deity.remaining > 0
end

---设置或清除玩家的神力状态
---@param self Player
---@param name string? 神力名称，nil表示清除
---@param duration number? 持续回合数
function Player:set_deity(name, duration)
  if name == nil then
    self.status.deity = nil
    self:_store_set({ "players", self.id, "status", "deity" }, nil)
    return
  end
  self.status.deity = { type = name, remaining = duration or self.deity_duration_turns }
  self:_store_set({ "players", self.id, "status", "deity" }, deep_copy(self.status.deity))
end

---减少神力的剩余回合数
---@param self Player
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

---清除玩家的临时标志位（用于回合开始）
---@param self Player
function Player:clear_temporal_flags()
  self.status.pending_dice_multiplier = 1
  self.status.pending_free_rent = false
  self.status.pending_tax_free = false
  self.status.pending_remote_dice = nil
  if self._store then
    self:_store_set({ "players", self.id, "status" }, deep_copy(self.status))
  end
end

---快速检查玩家是否拥有天使神力
---@param self Player
---@return boolean 是否有天使神力
function Player:has_angel()
  return self:has_deity("angel")
end

return Player
