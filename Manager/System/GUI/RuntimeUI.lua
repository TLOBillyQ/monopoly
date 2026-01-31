local logger = require("Library.Monopoly.Logger")
local MainView = require("Manager.TurnManager.GUI.MainView")
local Presenter = require("Manager.TurnManager.GUI.Presenter")

local RuntimeUI = {}

local function build_log_prefix()
  return "[EggyAdapter]"
end

local function log_once(runtime, level, key, ...)
  if not runtime or not runtime._log_once or runtime._log_once[key] then
    return
  end
  runtime._log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

function RuntimeUI.build_view(runtime)
  local store_state = runtime.game.store.state
  local winner_name = runtime.game.winner_names
  if not winner_name and runtime.game.winner then
    winner_name = runtime.game.winner.name
  end
  return Presenter.present(store_state, {
    game = runtime.game,
    last_turn = runtime.game.last_turn,
    finished = runtime.game.finished,
    winner_name = winner_name,
  })
end

function RuntimeUI.refresh_view(runtime)
  local view = RuntimeUI.build_view(runtime)
  RuntimeUI.refresh_panel(runtime, view)
  RuntimeUI.refresh_board(runtime, view)

  local players = view and view.state and view.state.players or nil
  local turn = view and view.state and view.state.turn or nil
  local current_index = turn and turn.current_player_index or nil
  if players and current_index then
    local current = players[current_index]
    local current_id = current and (current.id or current_index) or nil
    if current_id then
      if runtime.camera_follow_player_id ~= current_id then
        runtime.camera_follow_player_id = current_id
        local role = GameAPI.get_role(current_id);
        role.set_camera_bind_mode(Enums.CameraBindMode.TRACK)
      end

      local target_pos = nil
      local unit = runtime.player_units and runtime.player_units[current_id] or nil
      if unit and unit.get_position then
        target_pos = unit.get_position()
      else
        local pos_idx = current and current.position or nil
        if pos_idx and runtime.tile_positions then
          target_pos = runtime.tile_positions[pos_idx]
        end
      end

      if target_pos and role and role.set_camera_lock_position then
        role.set_camera_lock_position(target_pos)
      end
    end
  end
end

function RuntimeUI.refresh_panel(runtime, view)
  MainView.refresh_panel(runtime, view)
end

function RuntimeUI.refresh_item_slots(runtime, view)
  MainView.refresh_item_slots(runtime, view)
end

function RuntimeUI.refresh_board(runtime, view)
  MainView.refresh_board(runtime, view, log_once, build_log_prefix)
end

function RuntimeUI.on_tile_upgraded(runtime, tile_id, level)
  MainView.on_tile_upgraded(runtime, tile_id, level)
end

function RuntimeUI.on_tile_owner_changed(runtime, tile_id, owner_id)
  MainView.on_tile_owner_changed(runtime, tile_id, owner_id)
end

function RuntimeUI.select_market_option(runtime, option_id)
  MainView.select_market_option(runtime, option_id)
end

function RuntimeUI.open_choice_modal(runtime, pending)
  MainView.open_choice_modal(runtime, pending)
end

function RuntimeUI.close_choice_modal(runtime)
  MainView.close_choice_modal(runtime)
end

function RuntimeUI.push_popup(runtime, payload)
  return MainView.push_popup(runtime, payload)
end

function RuntimeUI.close_popup(runtime)
  MainView.close_popup(runtime)
end

return RuntimeUI
