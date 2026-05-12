local game_state_players = require("src.state.player_state")
local game_state_tiles = require("src.state.board_state")
local game_state_turn = require("src.state.turn_state")
require "vendor.third_party.ClassUtils"


local game = Class("Game")

local function _install_mixin(target, source, source_name)
  for key, fn in pairs(source) do
    assert(target[key] == nil, "game_state mixin collision: " .. tostring(source_name) .. "." .. tostring(key))
    target[key] = fn
  end
end

_install_mixin(game, game_state_players, "players")
_install_mixin(game, game_state_tiles, "board")
_install_mixin(game, game_state_turn, "turn")

local function _mark_players(game_ctx)
  game_ctx.dirty.any = true
  game_ctx.dirty.players = true
end

local function _mark_board(game_ctx)
  game_ctx.dirty.any = true
  game_ctx.dirty.board_tiles = true
end

local function _noop_false()
  return false
end

local function _ensure_stub_port(ctx, port_name, method_name)
  local port = ctx[port_name]
  if type(port) ~= "table" or type(port[method_name]) ~= "function" then
    ctx[port_name] = { [method_name] = _noop_false }
  end
end

local function _install_default_runtime_ports(game_ctx)
  if type(game_ctx.anim_gate_port) ~= "table" then
    game_ctx.anim_gate_port = {
      wait_move_anim = false,
      wait_action_anim = false,
    }
  end
  _ensure_stub_port(game_ctx, "popup_port", "push_popup")
  _ensure_stub_port(game_ctx, "tip_output_port", "enqueue")
  _ensure_stub_port(game_ctx, "tile_feedback_port", "on_tile_upgraded")
  _ensure_stub_port(game_ctx, "board_visual_feedback_port", "sync_many")
  _ensure_stub_port(game_ctx, "bankruptcy_feedback_port", "on_tiles_cleared")
end

function game:init(opts)
  self.auto_play_port = opts and opts.auto_play_port or self.auto_play_port
  self.bankruptcy_port = opts and opts.bankruptcy_port or self.bankruptcy_port
  _install_default_runtime_ports(self)
end

local function _resolve_turn_runtime(self)
  return self.turn_engine or self.turn_runtime
end

local function _require_port(self, port_name, method_name)
  local port = self[port_name]
  if type(port) == "table" and type(port[method_name]) == "function" then
    return port
  end
  error("missing " .. port_name)
end

function game:ensure_popup_port()
  return _require_port(self, "popup_port", "push_popup")
end

function game:ensure_tip_output_port()
  return _require_port(self, "tip_output_port", "enqueue")
end

function game:ensure_tile_feedback_port()
  return _require_port(self, "tile_feedback_port", "on_tile_upgraded")
end

function game:ensure_board_visual_feedback_port()
  return _require_port(self, "board_visual_feedback_port", "sync_many")
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
