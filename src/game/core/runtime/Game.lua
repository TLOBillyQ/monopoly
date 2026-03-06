local composition_root = require("src.game.core.runtime.CompositionRoot")
local game_state_players = require("src.game.core.runtime.GameStatePlayers")
local game_state_tiles = require("src.game.core.runtime.GameStateTiles")
local game_state_turn = require("src.game.core.runtime.GameStateTurn")
local game_victory = require("src.game.core.runtime.GameVictory")
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

function game:init(opts)
  if opts and opts.__skip_assemble then
    return
  end
  composition_root.assemble(opts, self)
end

local function _resolve_turn_runtime(self)
  return self.turn_engine
end

function game:ensure_popup_port()
  local popup_port = self.popup_port
  if type(popup_port) == "table" and type(popup_port.push_popup) == "function" then
    return popup_port
  end

  local compat_port = {}
  compat_port.push_popup = function(_, payload, opts)
    local raw_port = self["ui_port"]
    local push_popup = raw_port and raw_port["push_popup"] or nil
    if type(push_popup) == "function" then
      return push_popup(raw_port, payload, opts)
    end
    return false
  end
  self.popup_port = compat_port
  return compat_port
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
