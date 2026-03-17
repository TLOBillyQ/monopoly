require "vendor.third_party.ClassUtils"
local player = Class("Player")

local function _normalize_currency(currency)
  assert(currency ~= nil and currency ~= "", "missing currency")
  return currency
end

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

return player
