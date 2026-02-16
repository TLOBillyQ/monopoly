local constants = require("cfg.Generated.Constants")
local vehicles_cfg = require("cfg.Generated.Vehicles")
local vehicle_feature = require("game.vehicle")
local logger = require("core.logger")

local player = {}

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

local function _player_status_table(player)
  player.status = player.status or {}
  return player.status
end

local function _normalize_currency(currency)
  assert(currency ~= nil and currency ~= "", "missing currency")
  return currency
end

local function _mark_players(self)
  self.dirty.any = true
  self.dirty.players = true
end

local function _vehicle_helper(self)
  if self._helpers and self._helpers.vehicle then
    return self._helpers.vehicle
  end
  -- 回退：兼容旧测试代码（全局变量）
  return _G.vehicle_helper or nil
end

function player.set_player_status(self, player_obj, key, value)
  local status = _player_status_table(player_obj)
  status[key] = value
  _mark_players(self)
end

function player.set_player_seat(self, player_obj, seat_id)
  seat_id = vehicle_feature.resolve_seat_id(seat_id)
  if not vehicle_feature.is_enabled() then
    player_obj.seat_id = nil
    _mark_players(self)
    return
  end

  local old_seat_id = player_obj.seat_id
  local vh = _vehicle_helper(self)
  if old_seat_id ~= seat_id and vh then
    if old_seat_id ~= nil and vh.forward_eca_event_exit then
      vh.forward_eca_event_exit(player_obj.id)
    end
    if seat_id ~= nil and vh.forward_eca_event_enter then
      vh.forward_eca_event_enter(player_obj.id, seat_id)
      if vh.needs_enter_wait_by_player then
        vh.needs_enter_wait_by_player[player_obj.id] = true
      end
    end
  end
  player_obj.seat_id = seat_id
  _mark_players(self)
end

function player.set_player_eliminated(self, player_obj, eliminated)
  player_obj.eliminated = eliminated == true
  _mark_players(self)
end

function player.set_player_property(self, player_obj, tile_id, owned)
  player_obj.properties = player_obj.properties or {}
  if owned then
    player_obj.properties[tile_id] = true
  else
    player_obj.properties[tile_id] = nil
  end
  _mark_players(self)
end

function player.player_balance(_self, player_obj, currency)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return player_obj.cash
  end
  local value = player_obj.balances and player_obj.balances[key]
  assert(value ~= nil, "missing balance: " .. tostring(key))
  return value
end

function player.set_player_balance(self, player_obj, currency, value)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return player.set_player_cash(self, player_obj, value)
  end
  player_obj.balances = player_obj.balances or {}
  player_obj.balances[key] = value
  _mark_players(self)
  return value
end

function player.add_player_cash(self, player_obj, amount)
  local next_cash = player.player_balance(self, player_obj, "金币") + amount
  return player.set_player_cash(self, player_obj, next_cash)
end

function player.set_player_cash(self, player_obj, amount)
  player_obj.cash = amount
  _mark_players(self)
  return amount
end

function player.deduct_player_cash(self, player_obj, amount)
  local next_cash = player.player_balance(self, player_obj, "金币") - amount
  return player.set_player_cash(self, player_obj, next_cash)
end

function player.deduct_player_balance(self, player_obj, currency, amount)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return player.deduct_player_cash(self, player_obj, amount)
  end
  local current = player.player_balance(self, player_obj, key)
  local next_value = current - amount
  player.set_player_balance(self, player_obj, key, next_value)
  return next_value
end

function player.player_has_deity(_self, player_obj, name)
  local deity = player_obj.status and player_obj.status.deity
  if not deity then
    return false
  end
  return deity.type == name and deity.remaining > 0
end

function player.player_has_angel(self, player_obj)
  return player.player_has_deity(self, player_obj, "angel")
end

function player.clear_player_deity(self, player_obj)
  local status = _player_status_table(player_obj)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = ""
  status.deity.remaining = 0
  _mark_players(self)
end

function player.set_player_deity(self, player_obj, name, duration)
  assert(name ~= nil, "missing deity name")
  local status = _player_status_table(player_obj)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = name
  status.deity.remaining = duration or player_obj.deity_duration_turns
  _mark_players(self)
end

function player.tick_player_deity(self, player_obj)
  local status = _player_status_table(player_obj)
  status.deity = status.deity or { type = "", remaining = 0 }
  local deity = status.deity
  if deity.remaining <= 0 then
    return
  end
  deity.remaining = deity.remaining - 1
  if deity.remaining <= 0 then
    player.clear_player_deity(self, player_obj)
    return
  end
  _mark_players(self)
end

function player.clear_player_temporal_flags(self, player_obj)
  local status = _player_status_table(player_obj)
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
  _mark_players(self)
end

function player.stop_all_players_movement(self)
  local players = self.players or {}
  local players_dirty = false
  local vh = _vehicle_helper(self)
  for _, player_obj in ipairs(players) do
    local status = _player_status_table(player_obj)
    if status.move_dir ~= nil then
      status.move_dir = nil
      players_dirty = true
    end
    local seat_id = vehicle_feature.resolve_seat_id(player_obj.seat_id)
    if vh and vh.forward_eca_event_stop and seat_id ~= nil then
      local role_ok = true
      if vh.resolve_role then
        role_ok = vh.resolve_role(player_obj.id) ~= nil
      end
      if role_ok then
        vh.forward_eca_event_stop(player_obj.id)
      end
    end
  end
  if players_dirty then
    _mark_players(self)
  end
  if self.turn then
    self.turn.vehicle_resync_seq = (self.turn.vehicle_resync_seq or 0) + 1
    self.dirty.turn = true
    self.dirty.any = true
  end
end

function player.player_vehicle_cfg(_self, player_obj)
  local seat_id = vehicle_feature.resolve_seat_id(player_obj.seat_id)
  if seat_id then
    local cfg = vehicle_by_id[seat_id]
    assert(cfg ~= nil, "missing vehicle cfg: " .. tostring(seat_id))
    return cfg
  end
  return default_vehicle_cfg
end

function player.player_vehicle_name(self, player_obj)
  return player.player_vehicle_cfg(self, player_obj).name
end

function player.player_dice_count(self, player_obj)
  return player.player_vehicle_cfg(self, player_obj).dice_count
end

function player.player_is_vehicle_indestructible(self, player_obj)
  return player.player_vehicle_cfg(self, player_obj).indestructible == true
end

function player.alive_players(self)
  local alive = {}
  for _, player_obj in ipairs(self.players) do
    if not player_obj.eliminated then
      table.insert(alive, player_obj)
    end
  end
  return alive
end

function player.find_player_by_id(self, player_id)
  if player_id == nil then
    return nil
  end
  local by_id = self.player_by_id
  if type(by_id) == "table" then
    local cached = by_id[player_id]
    if cached then
      return cached
    end
  end
  for _, player_obj in ipairs(self.players or {}) do
    if player_obj and player_obj.id == player_id then
      if type(by_id) == "table" then
        by_id[player_id] = player_obj
      end
      return player_obj
    end
  end
  return nil
end

function player.current_player(self)
  local idx = self.turn.current_player_index
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function player.update_player_position(self, player_obj, new_index)
  local old_index = player_obj.position
  if old_index and self.occupants and self.occupants[old_index] then
    local list = self.occupants[old_index]
    for i = #list, 1, -1 do
      if list[i] == player_obj.id then
        table.remove(list, i)
      end
    end
  end
  player_obj.position = new_index
  _mark_players(self)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player_obj.id)
end

function player.rebuild(game)
  local length = game.board:length()
  game.occupants = {}
  for i = 1, length do
    game.occupants[i] = {}
  end
  for _, player_obj in ipairs(game.players) do
    if not player_obj.eliminated then
      local idx = player_obj.position
      player_obj.position = idx
      table.insert(game.occupants[idx], player_obj.id)
    end
  end
end

return player
