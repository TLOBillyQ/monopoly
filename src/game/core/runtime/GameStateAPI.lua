local game_state_players = require("src.game.core.runtime.GameStatePlayers")
local game_state_tiles = require("src.game.core.runtime.GameStateTiles")
local game_state_turn = require("src.game.core.runtime.GameStateTurn")

local game_state_api = {}

local function _mark_players(game)
  game.dirty.any = true
  game.dirty.players = true
end

local function _mark_board(game)
  game.dirty.any = true
  game.dirty.board_tiles = true
end

function game_state_api.set_player_status(game, player, key, value)
  return game_state_players.set_player_status(game, player, key, value)
end

function game_state_api.set_player_seat(game, player, seat_id)
  return game_state_players.set_player_seat(game, player, seat_id)
end

function game_state_api.set_player_eliminated(game, player, eliminated)
  return game_state_players.set_player_eliminated(game, player, eliminated)
end

function game_state_api.set_player_property(game, player, tile_id, owned)
  return game_state_players.set_player_property(game, player, tile_id, owned)
end

function game_state_api.player_balance(game, player, currency)
  return game_state_players.player_balance(game, player, currency)
end

function game_state_api.set_player_balance(game, player, currency, value)
  return game_state_players.set_player_balance(game, player, currency, value)
end

function game_state_api.add_player_cash(game, player, amount)
  return game_state_players.add_player_cash(game, player, amount)
end

function game_state_api.set_player_cash(game, player, amount)
  return game_state_players.set_player_cash(game, player, amount)
end

function game_state_api.deduct_player_cash(game, player, amount)
  return game_state_players.deduct_player_cash(game, player, amount)
end

function game_state_api.deduct_player_balance(game, player, currency, amount)
  return game_state_players.deduct_player_balance(game, player, currency, amount)
end

function game_state_api.player_has_deity(game, player, name)
  return game_state_players.player_has_deity(game, player, name)
end

function game_state_api.player_has_angel(game, player)
  return game_state_players.player_has_angel(game, player)
end

function game_state_api.clear_player_deity(game, player)
  return game_state_players.clear_player_deity(game, player)
end

function game_state_api.set_player_deity(game, player, name, duration)
  return game_state_players.set_player_deity(game, player, name, duration)
end

function game_state_api.tick_player_deity(game, player)
  return game_state_players.tick_player_deity(game, player)
end

function game_state_api.clear_player_temporal_flags(game, player)
  return game_state_players.clear_player_temporal_flags(game, player)
end

function game_state_api.stop_all_players_movement(game)
  return game_state_players.stop_all_players_movement(game)
end

function game_state_api.player_vehicle_cfg(game, player)
  return game_state_players.player_vehicle_cfg(game, player)
end

function game_state_api.player_vehicle_name(game, player)
  return game_state_players.player_vehicle_name(game, player)
end

function game_state_api.player_dice_count(game, player)
  return game_state_players.player_dice_count(game, player)
end

function game_state_api.player_is_vehicle_indestructible(game, player)
  return game_state_players.player_is_vehicle_indestructible(game, player)
end

function game_state_api.player_apply_hospital_effects(game, player)
  return game_state_players.player_apply_hospital_effects(game, player)
end

function game_state_api.player_send_to_hospital(game, player)
  return game_state_players.player_send_to_hospital(game, player)
end

function game_state_api.player_apply_mountain_effects(game, player)
  return game_state_players.player_apply_mountain_effects(game, player)
end

function game_state_api.player_send_to_mountain(game, player)
  return game_state_players.player_send_to_mountain(game, player)
end

function game_state_api.player_is_in_mountain(game, player)
  return game_state_players.player_is_in_mountain(game, player)
end

function game_state_api.update_tile(game, tile, updates)
  return game_state_tiles.update_tile(game, tile, updates)
end

function game_state_api.queue_action_anim(game, payload)
  return game_state_turn.queue_action_anim(game, payload)
end

function game_state_api.set_tile_owner(game, tile, owner_id)
  return game_state_tiles.set_tile_owner(game, tile, owner_id)
end

function game_state_api.set_tile_level(game, tile, level)
  return game_state_tiles.set_tile_level(game, tile, level)
end

function game_state_api.reset_tile(game, tile)
  return game_state_tiles.reset_tile(game, tile)
end

function game_state_api.alive_players(game)
  return game_state_players.alive_players(game)
end

function game_state_api.find_player_by_id(game, player_id)
  return game_state_players.find_player_by_id(game, player_id)
end

function game_state_api.current_player(game)
  return game_state_players.current_player(game)
end

function game_state_api.rebuild(game)
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

function game_state_api.update_player_position(game, player, new_index)
  return game_state_players.update_player_position(game, player, new_index)
end

function game_state_api.pending_choice(game)
  return game_state_turn.pending_choice(game)
end

function game_state_api.mark_players_dirty(game)
  _mark_players(game)
end

function game_state_api.mark_board_dirty(game)
  _mark_board(game)
end

return game_state_api
