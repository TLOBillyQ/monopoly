local modal = require("src.ui.ctl.modal")
local runtime_state = require("src.ui.runtime.state")
local choice_slice = require("src.ui.pres.choice_slice")

local runtime_event_ports = {}

local function _build_choice_view(state, current_game)
  local choice, market = choice_slice.build_choice_and_market(current_game, {
    game = current_game,
  }, state.ui)
  return choice, market
end

function runtime_event_ports.on_tile_upgraded(state, payload)
  if payload and payload.tile_id and state.on_board_visual_sync then
    state:on_board_visual_sync({
      tile_ids = { payload.tile_id },
    })
  end
end

function runtime_event_ports.on_need_choice(state, get_current_game, payload)
  local choice = payload and payload.choice or nil
  if not choice then
    return
  end
  runtime_state.set_pending_choice(state, choice, {
    choice_id = choice.id,
    elapsed_seconds = 0,
  })
  runtime_state.set_ui_dirty(state, true)
  local current_game = get_current_game()
  assert(current_game ~= nil, "missing current_game")
  local built_choice, built_market = _build_choice_view(state, current_game)
  if built_choice then
    modal.open_choice_modal(state, built_choice, built_market)
  end
end

return runtime_event_ports
