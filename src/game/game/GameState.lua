local composition_root = require("src.game.game.CompositionRoot")
local constants = require("Config.Generated.Constants")
local vehicles_cfg = require("Config.Generated.Vehicles")
local logger = require("src.core.Logger")
local bankruptcy_manager = require("src.game.game.BankruptcyManager")
require "vendor.third_party.Utils"

local game_state = {}

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

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

local function _player_status_table(player)
  player.status = player.status or {}
  return player.status
end

local function _mark_players(self)
  self.dirty.any = true
  self.dirty.players = true
end

local function _mark_board(self)
  self.dirty.any = true
  self.dirty.board_tiles = true
end

local function _mark_turn(self)
  self.dirty.any = true
  self.dirty.turn = true
end

function game_state:set_player_status(player, key, value)
  local status = _player_status_table(player)
  status[key] = value
  _mark_players(self)
end

function game_state:set_player_seat(player, seat_id)
  player.seat_id = seat_id
  _mark_players(self)
end

function game_state:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
  _mark_players(self)
end

function game_state:set_player_property(player, tile_id, owned)
  player.properties = player.properties or {}
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  _mark_players(self)
end

function game_state:player_balance(player, currency)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return player.cash
  end
  local value = player.balances and player.balances[key]
  assert(value ~= nil, "missing balance: " .. tostring(key))
  return value
end

function game_state:set_player_balance(player, currency, value)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return self:set_player_cash(player, value)
  end
  player.balances = player.balances or {}
  player.balances[key] = value
  _mark_players(self)
  return value
end

function game_state:add_player_cash(player, amount)
  local next_cash = self:player_balance(player, "金币") + amount
  return self:set_player_cash(player, next_cash)
end

function game_state:set_player_cash(player, amount)
  player.cash = amount
  _mark_players(self)
  return amount
end

function game_state:deduct_player_cash(player, amount)
  local next_cash = self:player_balance(player, "金币") - amount
  return self:set_player_cash(player, next_cash)
end

function game_state:deduct_player_balance(player, currency, amount)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return self:deduct_player_cash(player, amount)
  end
  local current = self:player_balance(player, key)
  local next_value = current - amount
  self:set_player_balance(player, key, next_value)
  return next_value
end

function game_state:player_has_deity(player, name)
  local deity = player.status and player.status.deity
  if not deity then
    return false
  end
  return deity.type == name and deity.remaining > 0
end

function game_state:player_has_angel(player)
  return self:player_has_deity(player, "angel")
end

function game_state:clear_player_deity(player)
  local status = _player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = ""
  status.deity.remaining = 0
  _mark_players(self)
end

function game_state:set_player_deity(player, name, duration)
  assert(name ~= nil, "missing deity name")
  local status = _player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = name
  status.deity.remaining = duration or player.deity_duration_turns
  _mark_players(self)
end

function game_state:tick_player_deity(player)
  local status = _player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  local deity = status.deity
  if deity.remaining <= 0 then
    return
  end
  deity.remaining = deity.remaining - 1
  if deity.remaining <= 0 then
    self:clear_player_deity(player)
    return
  end
  _mark_players(self)
end

function game_state:clear_player_temporal_flags(player)
  local status = _player_status_table(player)
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
  _mark_players(self)
end

function game_state:player_vehicle_cfg(player)
  local seat_id = player.seat_id
  if seat_id then
    local cfg = vehicle_by_id[seat_id]
    assert(cfg ~= nil, "missing vehicle cfg: " .. tostring(seat_id))
    return cfg
  end
  return default_vehicle_cfg
end

function game_state:player_vehicle_name(player)
  return self:player_vehicle_cfg(player).name
end

function game_state:player_dice_count(player)
  return self:player_vehicle_cfg(player).dice_count
end

function game_state:player_is_vehicle_indestructible(player)
  return self:player_vehicle_cfg(player).indestructible == true
end

function game_state:player_apply_hospital_effects(player)
  self:set_player_status(player, "stay_turns", constants.hospital_stay_turns)
  local fee = constants.hospital_fee
  if self:player_balance(player, "金币") < fee then
    logger.event(player.name .. " 资金不足，无法支付医药费 " .. fee)
    bankruptcy_manager.eliminate(self, player)
    return
  end
  self:deduct_player_cash(player, fee)
  logger.event(player.name .. " 支付医药费 " .. fee)
  if self:player_balance(player, "金币") <= 0 then
    bankruptcy_manager.eliminate(self, player)
    return
  end
  logger.event(player.name .. " 住院，需停留 " .. tostring(player.status.stay_turns) .. " 回合")
end

function game_state:player_send_to_hospital(player)
  local hospital_index = self.board:find_first_by_type("hospital")
  assert(hospital_index ~= nil, "missing hospital tile")
  self:update_player_position(player, hospital_index)
  self:set_player_status(player, "move_dir", nil)
  self:player_apply_hospital_effects(player)
end

function game_state:player_apply_mountain_effects(player)
  self:set_player_status(player, "stay_turns", constants.mountain_stay_turns)
  logger.event(player.name .. " 进入深山，停留 " .. tostring(player.status.stay_turns) .. " 回合")
end

function game_state:player_send_to_mountain(player)
  local idx = self.board:find_first_by_type("mountain")
  assert(idx ~= nil, "missing mountain tile")
  self:update_player_position(player, idx)
  self:set_player_status(player, "move_dir", nil)
  self:player_apply_mountain_effects(player)
end

function game_state:player_is_in_mountain(player)
  local tile = self.board:get_tile(player.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(player.position))
  return tile.type == "mountain"
end

function game_state:update_tile(tile, updates)
  assert(tile ~= nil and tile.type == "land", "invalid tile for update")
  for key, value in pairs(updates) do
    tile[key] = value
  end
  _mark_board(self)
end

function game_state:queue_action_anim(payload)
  assert(payload ~= nil, "missing action anim payload")
  local seq = (self.turn.action_anim_seq or 0) + 1
  payload.seq = seq
  self.turn.action_anim_seq = seq
  self.turn.action_anim = payload
  _mark_turn(self)
  return payload
end

function game_state:set_tile_owner(tile, owner_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for owner")
  _bump_land_rent_version(self)
  local ui_port = self.ui_port
  assert(ui_port ~= nil and ui_port.on_tile_owner_changed ~= nil, "missing ui_port")
  ui_port:on_tile_owner_changed(tile.id, owner_id)
  self:update_tile(tile, { owner_id = owner_id })
end

function game_state:set_tile_level(tile, level)
  _bump_land_rent_version(self)
  self:update_tile(tile, { level = level })
end

function game_state:reset_tile(tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for reset")
  _bump_land_rent_version(self)
  local ui_port = self.ui_port
  assert(ui_port ~= nil and ui_port.on_tile_owner_changed ~= nil, "missing ui_port")
  ui_port:on_tile_owner_changed(tile.id, nil)
  tile.owner_id = nil
  tile.level = 0
  _mark_board(self)
end

function game_state:alive_players()
  local alive = {}
  for _, player in ipairs(self.players) do
    if not player.eliminated then
      table.insert(alive, player)
    end
  end
  return alive
end

function game_state:current_player()
  local idx = self.turn.current_player_index
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function game_state:rebuild()
  local length = self.board:length()
  self.occupants = {}
  for i = 1, length do
    self.occupants[i] = {}
  end
  for _, player in ipairs(self.players) do
    if not player.eliminated then
      local idx = player.position
      player.position = idx
      table.insert(self.occupants[idx], player.id)
    end
  end
end

function game_state:update_player_position(player, new_index)
  local old_index = player.position
  if old_index and self.occupants and self.occupants[old_index] then
    local list = self.occupants[old_index]
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  _mark_players(self)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

function game_state:pending_choice()
  return self.turn.pending_choice
end

return game_state
