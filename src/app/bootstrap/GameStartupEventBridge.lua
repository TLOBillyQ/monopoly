local monopoly_event = require("src.game.core.runtime.MonopolyEvents")
local ui_model = require("src.presentation.state.UIModel")
local ui_view = require("src.presentation.api.UIViewService")

local M = {}

local function _build_model_for_choice(state, current_game)
  local winner = current_game.winner
  local winner_name = current_game.winner_names or (winner and assert(winner.name, "missing winner name"))
  return ui_model.build(current_game, {
    game = current_game,
    ui_state = state,
    last_turn = current_game.last_turn,
    finished = current_game.finished,
    winner_name = winner_name,
  })
end

function M.install(state, get_current_game)
  assert(state ~= nil, "missing state")
  assert(type(get_current_game) == "function", "missing get_current_game")

  RegisterCustomEvent(monopoly_event.land.tile_upgraded, function(_, _, data)
    if data and data.tile_id and data.level and state.on_tile_upgraded then
      state:on_tile_upgraded(data.tile_id, data.level)
    end
  end)

  RegisterCustomEvent(monopoly_event.intent.need_choice, function(_, _, data)
    local choice = data and data.choice or nil
    if not choice then
      return
    end
    state.pending_choice = choice
    state.pending_choice_elapsed = 0
    state.pending_choice_id = choice.id
    local current_game = get_current_game()
    assert(current_game ~= nil, "missing current_game")
    local built_model = _build_model_for_choice(state, current_game)
    state.ui_model = built_model
    if built_model.choice then
      ui_view.open_choice_modal(state, built_model.choice, built_model.market)
    end
  end)
end

return M
