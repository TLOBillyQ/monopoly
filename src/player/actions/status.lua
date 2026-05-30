local common = require("src.player.actions.state_common")

local status_ops = {}

function status_ops.set_player_status(self, player, key, value)
  local status = common.player_status_table(player)
  status[key] = value
  common.mark_players(self)
end

function status_ops.player_dice_count(_self, _player)
  return common.constants.default_dice_count
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
  return _clear_player_move_dir(player)
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

--[[ mutate4lua-manifest
version=2
projectHash=a63f088e3346e0a7
scope.0.id=chunk:src/player/actions/status.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=84
scope.0.semanticHash=fe4264a7a57fdf8f
scope.1.id=function:status_ops.set_player_status:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=9
scope.1.semanticHash=13ef2b09db719bdd
scope.2.id=function:status_ops.player_dice_count:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=e2a48334e4486cb9
scope.3.id=function:status_ops.set_player_eliminated:15
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=18
scope.3.semanticHash=55080555ae63f0f2
scope.4.id=function:status_ops.set_player_property:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=28
scope.4.semanticHash=db5ce1a41e471bc6
scope.5.id=function:status_ops.clear_player_temporal_flags:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=37
scope.5.semanticHash=21f41f27afa6cc2a
scope.6.id=function:_clear_player_move_dir:39
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=46
scope.6.semanticHash=c4e4321e1b26a799
scope.7.id=function:_is_outer_tile:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=57
scope.7.semanticHash=6c43d8b3ac8a0c44
scope.8.id=function:_stop_player_movement:59
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=64
scope.8.semanticHash=c3b862bcd8a47524
scope.9.id=function:status_ops.stop_all_players_movement:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=81
scope.9.semanticHash=b705ccbb3a5540d3
]]
