local common = require("src.player.actions.state_ops.common")

local status_ops = {}

function status_ops.set_player_status(self, player, key, value)
  local status = common.player_status_table(player)
  status[key] = value
  common.mark_players(self)
end

function status_ops.set_player_seat(self, player, seat_id)
  player.seat_id = seat_id
  common.mark_players(self)
end

function status_ops.set_player_eliminated(self, player, eliminated)
  player.eliminated = eliminated == true
  common.mark_players(self)
end

function status_ops.set_player_property(self, player, tile_id, owned)
  player.properties = player.properties or {}
  if owned then
    player.properties[tile_id] = true
  else
    player.properties[tile_id] = nil
  end
  common.mark_players(self)
end

function status_ops.clear_player_temporal_flags(self, player)
  local status = common.player_status_table(player)
  status.pending_dice_multiplier = 1
  status.pending_free_rent = false
  status.pending_tax_free = false
  status.pending_remote_dice = nil
  common.mark_players(self)
end

local function _clear_player_move_dir(player)
  local status = common.player_status_table(player)
  if status.move_dir == nil then
    return false
  end
  status.move_dir = nil
  return true
end

local function _is_outer_tile(game, player)
  if not (game and game.board and game.board.map and game.board.map.outer_next and player and player.position) then
    return true
  end
  local tile = game.board:get_tile(player.position)
  if tile == nil then
    return true
  end
  return game.board.map.outer_next[tile.id] ~= nil
end

local function _stop_player_movement(game, player)
  if not _is_outer_tile(game, player) then
    return false
  end
  local dirty = _clear_player_move_dir(player)
  return dirty
end

local function _stop_all_players(game, players)
  local players_dirty = false
  for _, player in ipairs(players or {}) do
    if _stop_player_movement(game, player) then
      players_dirty = true
    end
  end
  return players_dirty
end

function status_ops.stop_all_players_movement(self)
  local players_dirty = _stop_all_players(self, self.players)
  if players_dirty then
    common.mark_players(self)
  end
end

return status_ops
