local app = require("game")
local map_cfg = require("cfg.Map")
local tiles_cfg = require("cfg.Generated.Tiles")
local gameplay_loop = require("turn")
local auto_runner = require("turn.auto")

local ports_stub = require("support.ports_stub")

local context_builder = {}

local function _build_ui_state()
  return {
    input_blocked = false,
    popup_active = false,
    choice_active = false,
    market_active = false,
    popup_owner_index = nil,
  }
end

function context_builder.new_ports_stub(overrides)
  return ports_stub.new(overrides)
end

function context_builder.new_loop_state(opts)
  opts = opts or {}
  local ui = opts.ui or _build_ui_state()
  local state = {
    gameplay_loop_ports = context_builder.new_ports_stub(opts.ports_overrides),
    ui = ui,
    ui_dirty = false,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
    role_control_lock_active = false,
    role_control_lock_suppress = 0,
    _log_once = {},
    auto_runner = opts.auto_runner or auto_runner:new({ interval = 0.01 }),
  }
  state.auto_runner:set_enabled(true)
  return state
end

function context_builder.new_game_context(opts)
  opts = opts or {}
  app.setup({
    players = opts.players or { "P1", "P2" },
    ai = opts.ai or { [2] = true },
    auto_all = opts.auto_all == true,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  local game = app
  local state = context_builder.new_loop_state({
    ports_overrides = opts.ports_overrides,
    ui = opts.ui,
  })
  gameplay_loop.set_game(state, game)
  return {
    game = game,
    state = state,
    ports = state.gameplay_loop_ports,
  }
end

function context_builder.run_tick(game, state, dt)
  gameplay_loop.tick(game, state, dt)
end

return context_builder
