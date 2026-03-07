local composition_root = require("src.game.core.runtime.composition_root")
local game_state_players = require("src.game.core.runtime.game_state_players")
local game_state_tiles = require("src.game.core.runtime.game_state_tiles")
local game_state_turn = require("src.game.core.runtime.game_state_turn")
local game_victory = require("src.game.systems.endgame.game_victory")
require "vendor.third_party.ClassUtils"


local game = Class("Game")

for key, fn in pairs(game_state_players) do
  game[key] = fn
end

for key, fn in pairs(game_state_tiles) do
  game[key] = fn
end

for key, fn in pairs(game_state_turn) do
  game[key] = fn
end

game.check_victory = game_victory.check_victory

local function _mark_players(game_ctx)
  game_ctx.dirty.any = true
  game_ctx.dirty.players = true
end

local function _mark_board(game_ctx)
  game_ctx.dirty.any = true
  game_ctx.dirty.board_tiles = true
end

local function _install_default_runtime_ports(game_ctx)
  if type(game_ctx.anim_gate_port) ~= "table" then
    game_ctx.anim_gate_port = {
      wait_move_anim = false,
      wait_action_anim = false,
    }
  end
  if type(game_ctx.popup_port) ~= "table" or type(game_ctx.popup_port.push_popup) ~= "function" then
    game_ctx.popup_port = {
      push_popup = function()
        return false
      end,
    }
  end
  if type(game_ctx.tile_feedback_port) ~= "table" or type(game_ctx.tile_feedback_port.on_tile_upgraded) ~= "function" then
    game_ctx.tile_feedback_port = {
      on_tile_upgraded = function()
        return false
      end,
    }
  end
  if type(game_ctx.bankruptcy_feedback_port) ~= "table"
      or type(game_ctx.bankruptcy_feedback_port.on_tiles_cleared) ~= "function" then
    game_ctx.bankruptcy_feedback_port = {
      on_tiles_cleared = function()
        return false
      end,
    }
  end
end

function game:init(opts)
  if opts and opts.__skip_assemble then
    return
  end
  composition_root.assemble(opts, self)
  _install_default_runtime_ports(self)
end

local function _resolve_turn_runtime(self)
  return self.turn_engine
end

function game:ensure_popup_port()
  local popup_port = self.popup_port
  if type(popup_port) == "table" and type(popup_port.push_popup) == "function" then
    return popup_port
  end
  error("missing popup_port")
end

function game:ensure_tile_feedback_port()
  local tile_feedback_port = self.tile_feedback_port
  if type(tile_feedback_port) == "table" and type(tile_feedback_port.on_tile_upgraded) == "function" then
    return tile_feedback_port
  end
  error("missing tile_feedback_port")
end

function game:advance_turn()
  if self.finished then
    return
  end
  local runtime = _resolve_turn_runtime(self)
  if runtime and runtime.run_turn then
    runtime:run_turn()
  end
  self:check_victory()
end

function game:dispatch_action(action)
  if self.finished then
    return
  end
  local runtime = _resolve_turn_runtime(self)
  if runtime and runtime.dispatch then
    runtime:dispatch(action)
  end
  self:check_victory()
end

function game:rebuild()
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

function game:mark_players_dirty()
  _mark_players(self)
end

function game:mark_board_dirty()
  _mark_board(self)
end
 
return game
