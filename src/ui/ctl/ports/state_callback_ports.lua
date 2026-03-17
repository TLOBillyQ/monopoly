local board_view = require("src.ui.render.board")
local modal_controller = require("src.ui.ctl.modal_controller")

local state_callback_ports = {}

function state_callback_ports.install(state, get_current_game)
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
end

return state_callback_ports
