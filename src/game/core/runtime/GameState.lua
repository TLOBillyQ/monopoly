local composition_root = require("src.game.core.runtime.CompositionRoot")
local logger = require("src.core.Logger")
require "vendor.third_party.Utils"

local game_state_players = require("src.game.core.runtime.GameStatePlayers")
local game_state_tiles = require("src.game.core.runtime.GameStateTiles")
local game_state_turn = require("src.game.core.runtime.GameStateTurn")

local game_state = {}

local deep_copy = Utils.deep_copy

local function _mark_players(self)
  self.dirty.any = true
  self.dirty.players = true
end

local function _mark_board(self)
  self.dirty.any = true
  self.dirty.board_tiles = true
end

function game_state:set_player_status(player, key, value)
  return game_state_players.set_player_status(self, player, key, value)
end

function game_state:set_player_seat(player, seat_id)
  return game_state_players.set_player_seat(self, player, seat_id)
end

function game_state:set_player_eliminated(player, eliminated)
  return game_state_players.set_player_eliminated(self, player, eliminated)
end

function game_state:set_player_property(player, tile_id, owned)
  return game_state_players.set_player_property(self, player, tile_id, owned)
end

function game_state:player_balance(player, currency)
  return game_state_players.player_balance(self, player, currency)
end

function game_state:set_player_balance(player, currency, value)
  return game_state_players.set_player_balance(self, player, currency, value)
end

function game_state:add_player_cash(player, amount)
  return game_state_players.add_player_cash(self, player, amount)
end

function game_state:set_player_cash(player, amount)
  return game_state_players.set_player_cash(self, player, amount)
end

function game_state:deduct_player_cash(player, amount)
  return game_state_players.deduct_player_cash(self, player, amount)
end

function game_state:deduct_player_balance(player, currency, amount)
  return game_state_players.deduct_player_balance(self, player, currency, amount)
end

function game_state:player_has_deity(player, name)
  return game_state_players.player_has_deity(self, player, name)
end

function game_state:player_has_angel(player)
  return game_state_players.player_has_angel(self, player)
end

function game_state:clear_player_deity(player)
  return game_state_players.clear_player_deity(self, player)
end

function game_state:set_player_deity(player, name, duration)
  return game_state_players.set_player_deity(self, player, name, duration)
end

function game_state:tick_player_deity(player)
  return game_state_players.tick_player_deity(self, player)
end

function game_state:clear_player_temporal_flags(player)
  return game_state_players.clear_player_temporal_flags(self, player)
end

function game_state:stop_all_players_movement()
  return game_state_players.stop_all_players_movement(self)
end

function game_state:player_vehicle_cfg(player)
  return game_state_players.player_vehicle_cfg(self, player)
end

function game_state:player_vehicle_name(player)
  return game_state_players.player_vehicle_name(self, player)
end

function game_state:player_dice_count(player)
  return game_state_players.player_dice_count(self, player)
end

function game_state:player_is_vehicle_indestructible(player)
  return game_state_players.player_is_vehicle_indestructible(self, player)
end

function game_state:player_apply_hospital_effects(player)
  return game_state_players.player_apply_hospital_effects(self, player)
end

function game_state:player_send_to_hospital(player)
  return game_state_players.player_send_to_hospital(self, player)
end

function game_state:player_apply_mountain_effects(player)
  return game_state_players.player_apply_mountain_effects(self, player)
end

function game_state:player_send_to_mountain(player)
  return game_state_players.player_send_to_mountain(self, player)
end

function game_state:player_is_in_mountain(player)
  return game_state_players.player_is_in_mountain(self, player)
end

function game_state:update_tile(tile, updates)
  return game_state_tiles.update_tile(self, tile, updates)
end

function game_state:queue_action_anim(payload)
  return game_state_turn.queue_action_anim(self, payload)
end

function game_state:set_tile_owner(tile, owner_id)
  return game_state_tiles.set_tile_owner(self, tile, owner_id)
end

function game_state:set_tile_level(tile, level)
  return game_state_tiles.set_tile_level(self, tile, level)
end

function game_state:reset_tile(tile)
  return game_state_tiles.reset_tile(self, tile)
end

function game_state:alive_players()
  return game_state_players.alive_players(self)
end

function game_state:find_player_by_id(player_id)
  return game_state_players.find_player_by_id(self, player_id)
end

function game_state:current_player()
  return game_state_players.current_player(self)
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
  return game_state_players.update_player_position(self, player, new_index)
end

function game_state:pending_choice()
  return game_state_turn.pending_choice(self)
end

function game_state:mark_players_dirty()
  _mark_players(self)
end

function game_state:mark_board_dirty()
  _mark_board(self)
end

function game_state:snapshot_inventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
end

function game_state:new(opts)
  opts = opts or {}
  if opts.__skip_assemble == true then
    return setmetatable(opts, { __index = self })
  end
  local composed = composition_root.assemble(opts, self)
  return setmetatable(composed, { __index = self })
end

game_state.new = game_state.new or function(opts)
  return game_state:new(opts)
end

return game_state
