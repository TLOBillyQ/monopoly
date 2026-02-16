local constants = require("cfg.Generated.Constants")
local vehicles_cfg = require("cfg.Generated.Vehicles")
local vehicle_feature = require("game.vehicle")
local logger = require("core.logger")
local bankrupt = require("game.rule.bankrupt")

local state = {}

-- ============================================================================
-- GameStateTurn 部分
-- ============================================================================

local function _mark_turn(self)
  self.dirty.any = true
  self.dirty.turn = true
end

function state.queue_action_anim(self, payload)
  assert(payload ~= nil, "missing action anim payload")
  local seq = (self.turn.action_anim_seq or 0) + 1
  payload.seq = seq
  self.turn.action_anim_seq = seq
  local queue = self.turn.action_anim_queue
  if type(queue) ~= "table" then
    queue = {}
    self.turn.action_anim_queue = queue
  end
  queue[#queue + 1] = payload
  if not self.turn.action_anim then
    self.turn.action_anim = table.remove(queue, 1)
  end
  _mark_turn(self)
  return payload
end

function state.pending_choice(self)
  return self.turn.pending_choice
end

-- ============================================================================
-- GameStatePlayers 部分
-- ============================================================================

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

function state.set_player_status(self, player, key, value)
  local status = _player_status_table(player)
  status[key] = value
  _mark_players(self)
end

function state.set_player_seat(self, player, seat_id)
  seat_id = vehicle_feature.resolve_seat_id(seat_id)
  if not vehicle_feature.is_enabled() then
    player.seat_id = nil
    _mark_players(self)
    return
  end

  local old_seat_id = player.seat_id
  if old_seat_id ~= seat_id and vehicle_helper then
    if old_seat_id ~= nil and vehicle_helper.forward_eca_event_exit then
      vehicle_helper.forward_eca_event_exit(player.id)
    end
    if seat_id ~= nil and vehicle_helper.forward_eca_event_enter then
      vehicle_helper.forward_eca_event_enter(player.id, seat_id)
      if vehicle_helper.needs_enter_wait_by_player then
        vehicle_helper.needs_enter_wait_by_player[player.id] = true
      end
    end
  end
  player.seat_id = seat_id
  _mark_players(self)
end

function state.set_player_eliminated(self, player, eliminated)
  player.eliminated = eliminated == true
  _mark_players(self)
end

function state.set_player_property(self, player, tile_id, owned)
  player.properties = player.properties or {}
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  _mark_players(self)
end

function state.player_balance(self, player, currency)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return player.cash
  end
  local value = player.balances and player.balances[key]
  assert(value ~= nil, "missing balance: " .. tostring(key))
  return value
end

function state.set_player_balance(self, player, currency, value)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return state.set_player_cash(self, player, value)
  end
  player.balances = player.balances or {}
  player.balances[key] = value
  _mark_players(self)
  return value
end

function state.add_player_cash(self, player, amount)
  local next_cash = state.player_balance(self, player, "金币") + amount
  return state.set_player_cash(self, player, next_cash)
end

function state.set_player_cash(self, player, amount)
  player.cash = amount
  _mark_players(self)
  return amount
end

function state.deduct_player_cash(self, player, amount)
  local next_cash = state.player_balance(self, player, "金币") - amount
  return state.set_player_cash(self, player, next_cash)
end

function state.deduct_player_balance(self, player, currency, amount)
  local key = _normalize_currency(currency)
  if key == "金币" then
    return state.deduct_player_cash(self, player, amount)
  end
  local current = state.player_balance(self, player, key)
  local next_value = current - amount
  state.set_player_balance(self, player, key, next_value)
  return next_value
end

function state.player_has_deity(_self, player, name)
  local deity = player.status and player.status.deity
  if not deity then
    return false
  end
  return deity.type == name and deity.remaining > 0
end

function state.player_has_angel(self, player)
  return state.player_has_deity(self, player, "angel")
end

function state.clear_player_deity(self, player)
  local status = _player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = ""
  status.deity.remaining = 0
  _mark_players(self)
end

function state.set_player_deity(self, player, name, duration)
  assert(name ~= nil, "missing deity name")
  local status = _player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = name
  status.deity.remaining = duration or player.deity_duration_turns
  _mark_players(self)
end

function state.tick_player_deity(self, player)
  local status = _player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  local deity = status.deity
  if deity.remaining <= 0 then
    return
  end
  deity.remaining = deity.remaining - 1
  if deity.remaining <= 0 then
    state.clear_player_deity(self, player)
    return
  end
  _mark_players(self)
end

function state.clear_player_temporal_flags(self, player)
  local status = _player_status_table(player)
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
  _mark_players(self)
end

function state.stop_all_players_movement(self)
  local players = self.players or {}
  local players_dirty = false
  for _, player in ipairs(players) do
    local status = _player_status_table(player)
    if status.move_dir ~= nil then
      status.move_dir = nil
      players_dirty = true
    end
    local seat_id = vehicle_feature.resolve_seat_id(player.seat_id)
    if vehicle_helper and vehicle_helper.forward_eca_event_stop and seat_id ~= nil then
      local role_ok = true
      if vehicle_helper.resolve_role then
        role_ok = vehicle_helper.resolve_role(player.id) ~= nil
      end
      if role_ok then
        vehicle_helper.forward_eca_event_stop(player.id)
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

function state.player_vehicle_cfg(_self, player)
  local seat_id = vehicle_feature.resolve_seat_id(player.seat_id)
  if seat_id then
    local cfg = vehicle_by_id[seat_id]
    assert(cfg ~= nil, "missing vehicle cfg: " .. tostring(seat_id))
    return cfg
  end
  return default_vehicle_cfg
end

function state.player_vehicle_name(self, player)
  return state.player_vehicle_cfg(self, player).name
end

function state.player_dice_count(self, player)
  return state.player_vehicle_cfg(self, player).dice_count
end

function state.player_is_vehicle_indestructible(self, player)
  return state.player_vehicle_cfg(self, player).indestructible == true
end

function state.player_apply_hospital_effects(self, player)
  state.set_player_status(self, player, "stay_turns", constants.hospital_stay_turns)
  local fee = constants.hospital_fee
  if state.player_balance(self, player, "金币") < fee then
    logger.event(player.name .. " 资金不足，无法支付医药费 " .. fee)
    bankrupt.eliminate(self, player, { reason = player.name .. " 医药费不足破产" })
    return
  end
  state.deduct_player_cash(self, player, fee)
  logger.event(player.name .. " 支付医药费 " .. fee)
  if state.player_balance(self, player, "金币") <= 0 then
    bankrupt.eliminate(self, player, { reason = player.name .. " 支付医药费后破产" })
    return
  end
  logger.event(player.name .. " 住院，需停留 " .. tostring(player.status.stay_turns) .. " 回合")
end

function state.player_send_to_hospital(self, player)
  local hospital_index = self.board:find_first_by_type("hospital")
  assert(hospital_index ~= nil, "missing hospital tile")
  self:update_player_position(player, hospital_index)
  state.set_player_status(self, player, "move_dir", nil)
  state.player_apply_hospital_effects(self, player)
end

function state.player_apply_mountain_effects(self, player)
  state.set_player_status(self, player, "stay_turns", constants.mountain_stay_turns)
  logger.event(player.name .. " 进入深山，停留 " .. tostring(player.status.stay_turns) .. " 回合")
end

function state.player_send_to_mountain(self, player)
  local idx = self.board:find_first_by_type("mountain")
  assert(idx ~= nil, "missing mountain tile")
  self:update_player_position(player, idx)
  state.set_player_status(self, player, "move_dir", nil)
  state.player_apply_mountain_effects(self, player)
end

function state.player_is_in_mountain(self, player)
  local tile = self.board:get_tile(player.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(player.position))
  return tile.type == "mountain"
end

function state.alive_players(self)
  local alive = {}
  for _, player in ipairs(self.players) do
    if not player.eliminated then
      table.insert(alive, player)
    end
  end
  return alive
end

function state.find_player_by_id(self, player_id)
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
  for _, player in ipairs(self.players or {}) do
    if player and player.id == player_id then
      if type(by_id) == "table" then
        by_id[player_id] = player
      end
      return player
    end
  end
  return nil
end

function state.current_player(self)
  local idx = self.turn.current_player_index
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function state.update_player_position(self, player, new_index)
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

-- ============================================================================
-- GameStateTiles 部分
-- ============================================================================

local function _bump_land_rent_version(self)
  self._land_rent_version = (self._land_rent_version or 0) + 1
end

local function _mark_board(self)
  self.dirty.any = true
  self.dirty.board_tiles = true
end

local function _notify_tile_owner_changed(self, tile_id, owner_id)
  local notifier = self and self.tile_owner_notifier or nil
  if notifier and type(notifier.notify_owner_changed) == "function" then
    notifier:notify_owner_changed(tile_id, owner_id)
    return true
  end
  if notifier and type(notifier.on_tile_owner_changed) == "function" then
    notifier:on_tile_owner_changed(tile_id, owner_id)
    return true
  end
  local ui_port = self and self.ui_port or nil
  if ui_port and type(ui_port.on_tile_owner_changed) == "function" then
    ui_port:on_tile_owner_changed(tile_id, owner_id)
    return true
  end
  return false
end

function state.update_tile(self, tile, updates)
  assert(tile ~= nil and tile.type == "land", "invalid tile for update")
  for key, value in pairs(updates) do
    tile[key] = value
  end
  _mark_board(self)
end

function state.set_tile_owner(self, tile, owner_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for owner")
  _bump_land_rent_version(self)
  _notify_tile_owner_changed(self, tile.id, owner_id)
  state.update_tile(self, tile, { owner_id = owner_id })
end

function state.set_tile_level(self, tile, level)
  _bump_land_rent_version(self)
  state.update_tile(self, tile, { level = level })
end

function state.reset_tile(self, tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for reset")
  _bump_land_rent_version(self)
  _notify_tile_owner_changed(self, tile.id, nil)
  tile.owner_id = nil
  tile.level = 0
  _mark_board(self)
end

-- ============================================================================
-- GameStateOps 部分（重建和其他操作）
-- ============================================================================

function state.rebuild(game)
  local length = game.board:length()
  game.occupants = {}
  for i = 1, length do
    game.occupants[i] = {}
  end
  for _, player in ipairs(game.players) do
    if not player.eliminated then
      local idx = player.position
      player.position = idx
      table.insert(game.occupants[idx], player.id)
    end
  end
end

function state.mark_players_dirty(game)
  game.dirty.any = true
  game.dirty.players = true
end

function state.mark_board_dirty(game)
  game.dirty.any = true
  game.dirty.board_tiles = true
end

return state
