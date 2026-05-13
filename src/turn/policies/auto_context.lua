local runtime_state = require("src.state.runtime")
local auto_play_port = require("src.rules.ports.auto_play")

local auto_context = {}

local function _resolve_current_player_index(game, ctx)
  if ctx.current_player_index then
    return ctx.current_player_index
  end
  return game.turn and game.turn.current_player_index or nil
end

local function _is_player_auto(player, game)
  local is_player_auto = player and player.auto == true or false
  local is_ai_auto = player and auto_play_port.is_auto_player(game, player) == true or false
  return is_player_auto or is_ai_auto
end

function auto_context.build(game, context)
  local ctx = context or {}
  ctx.game_finished = game.finished

  local current_player_index = _resolve_current_player_index(game, ctx)
  ctx.current_player_index = current_player_index

  local player = current_player_index and game.players and game.players[current_player_index] or nil
  if ctx.current_player_id == nil then
    ctx.current_player_id = player and player.id or nil
  end
  if ctx.current_player_auto == nil then
    ctx.current_player_auto = _is_player_auto(player, game)
  end
  return ctx
end

function auto_context.build_tick(game, state, ui_sync_ports)
  local gate = nil
  if ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" then
    gate = ui_sync_ports.resolve_ui_gate(state)
  end
  local pending_choice = game and game.turn and game.turn.pending_choice or runtime_state.get_pending_choice(state)
  local ctx = state._tick_context
  if ctx == nil then
    ctx = {}
    state._tick_context = ctx
  end
  ctx.game = game
  ctx.state = state
  ctx.pending_choice = pending_choice
  ctx.current_player_index = nil
  ctx.current_player_id = nil
  ctx.current_player_auto = nil
  ctx.choice_active = gate and gate.choice_active == true or false
  ctx.market_active = gate and gate.market_active == true or false
  ctx.popup_active = gate and gate.popup_active == true or false
  ctx.modal_active = gate and (gate.popup_active == true or gate.market_active == true or gate.choice_active == true) or false
  ctx.modal_buttons = nil
  return auto_context.build(game, ctx)
end

return auto_context
