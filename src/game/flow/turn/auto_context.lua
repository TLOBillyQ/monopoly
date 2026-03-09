local agent = require("src.game.core.ai.agent")
local runtime_state = require("src.core.state_access.runtime_state")

local auto_context = {}

function auto_context.build(game, context)
  local ctx = context or {}
  ctx.game_finished = game.finished
  local current_player_index = ctx.current_player_index
  if not current_player_index then
    current_player_index = game.turn and game.turn.current_player_index or nil
    ctx.current_player_index = current_player_index
  end
  if ctx.current_player_id == nil then
    local player = current_player_index and game.players and game.players[current_player_index] or nil
    ctx.current_player_id = player and player.id or nil
  end
  if ctx.current_player_auto == nil then
    local player = current_player_index and game.players and game.players[current_player_index] or nil
    local is_player_auto = player and player.auto == true or false
    local is_ai_auto = player and agent.is_auto_player(player) == true or false
    ctx.current_player_auto = is_player_auto or is_ai_auto
  end
  return ctx
end

function auto_context.build_tick(game, state, ui_sync_ports)
  local gate = nil
  if ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" then
    gate = ui_sync_ports.resolve_ui_gate(state)
  end
  local pending_choice = game and game.turn and game.turn.pending_choice or runtime_state.get_pending_choice(state)
  return auto_context.build(game, {
    game = game,
    state = state,
    pending_choice = pending_choice,
    choice_active = gate and gate.choice_active == true or false,
    market_active = gate and gate.market_active == true or false,
    popup_active = gate and gate.popup_active == true or false,
    modal_active = gate and (gate.popup_active == true or gate.market_active == true or gate.choice_active == true) or false,
    modal_buttons = nil,
  })
end

return auto_context
