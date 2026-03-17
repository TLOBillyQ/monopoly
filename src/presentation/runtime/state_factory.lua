local board_view = require("src.ui.render.board")
local ui_view = require("src.ui.ctl.ui_runtime")
local modal_controller = require("src.ui.ctl.modal_controller")
local runtime_state = require("src.state.state_access.runtime_state")

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
  local profile_name = opts.profile_name

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
    active_profile_name = profile_name,
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

  state.push_popup = function(_, payload, opts)
    local ok = modal_controller.push_popup(state, payload, opts)
    if state.ui then
      local current_game = get_current_game()
      if ok and current_game and current_game.turn then
        state.ui.popup_owner_index = current_game.turn.current_player_index
      else
        state.ui.popup_owner_index = nil
      end
    end
    return ok
  end
  state.on_tile_upgraded = function(_, tile_id, level)
    board_view.on_tile_upgraded(state, tile_id, level)
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    board_view.on_tile_owner_changed(state, tile_id, owner_id)
  end
  state.on_board_visual_sync = function(_, payload)
    return board_view.sync_many(state, payload)
  end

  return state
end

return M
