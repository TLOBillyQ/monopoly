local game_state_players = require("src.state.player_state")
local game_state_tiles = require("src.state.board_state")
local game_state_turn = require("src.state.turn_state")
local dirty_tracker = require("src.state.dirty_tracker")
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
  dirty_tracker.mark(self.dirty, "players")
end

function game:mark_board_dirty()
  dirty_tracker.mark(self.dirty, "board_tiles")
end

return game

--[[ mutate4lua-manifest
version=2
projectHash=8f98437edc826230
scope.0.id=chunk:src/state/game_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=126
scope.0.semanticHash=7c837a70ff80c138
scope.1.id=function:_noop_false:21
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=23
scope.1.semanticHash=c531382525945dd5
scope.2.id=function:_ensure_stub_port:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=30
scope.2.semanticHash=3d408210ba706e4c
scope.3.id=function:_install_default_runtime_ports:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=44
scope.3.semanticHash=f708dadc60622637
scope.4.id=function:game:init:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=50
scope.4.semanticHash=1d27bfa62789de51
scope.5.id=function:_resolve_turn_runtime:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=54
scope.5.semanticHash=3c5632c8fa486a02
scope.6.id=function:_require_port:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=62
scope.6.semanticHash=dd2e82521678b5db
scope.7.id=function:game:ensure_popup_port:64
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=66
scope.7.semanticHash=5e0b6bc9a9e5eed0
scope.8.id=function:game:ensure_tip_output_port:68
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=70
scope.8.semanticHash=53dcd5136fd38017
scope.9.id=function:game:ensure_tile_feedback_port:72
scope.9.kind=function
scope.9.startLine=72
scope.9.endLine=74
scope.9.semanticHash=2b60900b2047a926
scope.10.id=function:game:ensure_board_visual_feedback_port:76
scope.10.kind=function
scope.10.startLine=76
scope.10.endLine=78
scope.10.semanticHash=0b2d4be4d1753188
scope.11.id=function:game:advance_turn:80
scope.11.kind=function
scope.11.startLine=80
scope.11.endLine=89
scope.11.semanticHash=6fdfcf2907ceff16
scope.12.id=function:game:dispatch_action:91
scope.12.kind=function
scope.12.startLine=91
scope.12.endLine=100
scope.12.semanticHash=189862f6617f9d5b
scope.13.id=function:game:mark_players_dirty:117
scope.13.kind=function
scope.13.startLine=117
scope.13.endLine=119
scope.13.semanticHash=285ceb62389f53d3
scope.14.id=function:game:mark_board_dirty:121
scope.14.kind=function
scope.14.startLine=121
scope.14.endLine=123
scope.14.semanticHash=8fdca32e071bb029
]]
