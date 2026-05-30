local ui_view = require("src.ui.coord.ui_runtime")
local runtime_state = require("src.ui.state.runtime")
local state_callback_ports = require("src.ui.ports.callbacks")

local M = {}

local function _normalize_args(arg1, arg2)
  if type(arg1) == "table" then
    local opts = arg1
    return opts.get_current_game, opts
  end
  return arg1, arg2 or {}
end

function M.build_state(arg1, arg2)
  local get_current_game, opts = _normalize_args(arg1, arg2)
  opts = opts or {}
  local build_game_factory = opts.build_game_factory
  local auto_runner = opts.auto_runner
  assert(type(get_current_game) == "function", "missing get_current_game")
  assert(type(build_game_factory) == "function", "missing build_game_factory")
  assert(auto_runner ~= nil, "missing auto_runner")

  local ui = ui_view.build_ui_state()
  local state = {
    ui = ui,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    wait_move_anim = true,
    wait_action_anim = true,
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    tick_started = false,
    countdown_last = nil,
    countdown_active_last = nil,
    action_button_elapsed = 0,
    action_button_active = false,
  }

  state.game_factory = build_game_factory(state)
  state.auto_runner = auto_runner

  runtime_state.ensure_all(state)
  state_callback_ports.install(state, get_current_game)

  return state
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=63b470721e30c422
scope.0.id=chunk:src/app/state_factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=06fec0f41df320ce
scope.1.id=function:_normalize_args:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=13
scope.1.semanticHash=cf707b281e5d51e5
scope.2.id=function:M.build_state:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=53
scope.2.semanticHash=e0c4a82841a7bdd4
]]
