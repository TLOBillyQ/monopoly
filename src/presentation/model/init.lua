local board_slice = require("src.presentation.model.board_slice")
local item_slice = require("src.presentation.model.item_slice")
local choice_slice = require("src.presentation.model.choice_slice")
local panel_slice = require("src.presentation.model.panel_slice")
local number_utils = require("src.core.utils.number_utils")
local role_id_utils = require("src.core.utils.role_id")

local model_api = {}

local FALLBACK_CURRENT_PLAYER_NAME = "-"
local FALLBACK_CURRENT_PLAYER_CASH = 0
local FALLBACK_CURRENT_PLAYER_ID = nil

local function _resolve_current_player(game)
  local turn = game.turn
  local players = game.players
  assert(turn ~= nil and players ~= nil, "missing turn or players")
  local idx = number_utils.to_integer(turn.current_player_index)
  if idx == nil then
    return nil, turn,
      string.format("invalid current player index: index=%s, player_count=%d", tostring(turn.current_player_index), #players)
  end
  local current = players[idx]
  if current == nil then
    return nil, turn,
      string.format("current player not found: index=%s, player_count=%d", tostring(idx), #players)
  end
  return current, turn
end

local function _build_ui_env(state, game)
  local winner = game.winner
  local winner_name = game.winner_names or (winner and assert(winner.name, "missing winner name"))
  return {
    game = game,
    ui_state = state,
    last_turn = game.last_turn,
    finished = game.finished,
    winner_name = winner_name,
  }
end

local function _resolve_current_player_meta(current)
  if current == nil then
    return FALLBACK_CURRENT_PLAYER_NAME, FALLBACK_CURRENT_PLAYER_CASH, FALLBACK_CURRENT_PLAYER_ID
  end
  return current.name or FALLBACK_CURRENT_PLAYER_NAME, current.cash or FALLBACK_CURRENT_PLAYER_CASH,
    role_id_utils.normalize(current.id)
end

local function _fill_meta(model, env, current, turn)
  local current_name, current_cash, current_player_id = _resolve_current_player_meta(current)
  model.current_player_name = current_name
  model.current_player_cash = current_cash
  model.turn_count = turn.turn_count
  model.current_player_id = current_player_id
  model.board_tile_count = board_slice.tile_count()
  model.last_turn = env.last_turn
  model.finished = env.finished
  model.winner_name = env.winner_name
  return model
end

local function _should_update_board(dirty)
  return dirty.players or dirty.board_tiles or dirty.turn
end

local function _should_update_auto_labels(dirty, ui_dirty)
  return dirty.players or dirty.turn or ui_dirty
end

local function _build_panel_flags(dirty, ui_dirty)
  return {
    turn_label = dirty.turn or dirty.turn_countdown or ui_dirty,
    player_rows = dirty.players or dirty.board_tiles or ui_dirty,
    auto_label = dirty.players or dirty.turn or ui_dirty,
  }
end

local function _should_update_slots(dirty, ui_dirty)
  if dirty.players or dirty.turn or ui_dirty then
    return true
  end
  if not dirty.inventory_ids then
    return false
  end
  for _ in pairs(dirty.inventory_ids) do
    return true
  end
  return false
end

local function _update_slots(model, game, current, current_player_id, ui_runtime)
  local slot_count = item_slice.resolve_slot_count(ui_runtime)
  local by_player = item_slice.build_item_slots_by_player(game.players, slot_count)
  model.item_slots_by_player = by_player
  model.item_slots = role_id_utils.read(by_player, current_player_id)
    or item_slice.build_item_slots_for_player(current, slot_count)
end

local function _should_refresh_choice(dirty, ui_dirty)
  return dirty.turn or dirty.market or ui_dirty
end

local function _update_choice_and_market(model, game, env, ui_state, current_player_id)
  local choice, market = choice_slice.build_choice_and_market(game, env, ui_state)
  model.choice = choice
  model.market = market
  model.item_choice_owner_id = item_slice.resolve_item_choice_owner_id(game, choice, current_player_id)
end

local function _update_current_player_meta(model, current_name, current_cash, current_player_id, turn)
  model.current_player_name = current_name
  model.current_player_cash = current_cash
  model.turn_count = turn.turn_count
  model.current_player_id = current_player_id
end

local function _fill_runtime_meta(model, env)
  model.board_tile_count = board_slice.tile_count()
  model.last_turn = env.last_turn
  model.finished = env.finished
  model.winner_name = env.winner_name
end

local function _refresh_board_and_auto_labels(model, game, env, turn, dirty, ui_dirty)
  if _should_update_board(dirty) then
    model.board = board_slice.update(model.board, game, env, turn)
  end

  if _should_update_auto_labels(dirty, ui_dirty) then
    model.auto_enabled_by_player = item_slice.build_auto_enabled_by_player(game.players)
  end
end

local function _refresh_panel_and_slots(model, game, env, turn, current, current_player_id, ui_runtime, dirty, ui_dirty)
  model.panel = panel_slice.update(
    model.panel,
    game,
    env,
    turn,
    current_player_id,
    model.auto_enabled_by_player,
    _build_panel_flags(dirty, ui_dirty)
  )

  local update_slots = _should_update_slots(dirty, ui_dirty)
  if update_slots then
    _update_slots(model, game, current, current_player_id, ui_runtime)
  end
  return update_slots
end

local function _refresh_choice_and_meta(model, game, env, ui_state, ui_runtime, current_name, current_cash, current_player_id, turn, dirty, ui_dirty, update_slots)
  if _should_refresh_choice(dirty, ui_dirty) then
    _update_choice_and_market(model, game, env, ui_state, current_player_id)
  elseif dirty.players or update_slots then
    model.item_choice_owner_id = item_slice.resolve_item_choice_owner_id(game, model.choice, current_player_id)
  end

  if ui_dirty then
    model.popup = choice_slice.build_popup(ui_runtime)
  end

  if dirty.players or dirty.turn then
    _update_current_player_meta(model, current_name, current_cash, current_player_id, turn)
  end
end

function model_api.build(game, env)
  assert(game ~= nil, "missing game")
  env = env or _build_ui_env(nil, game)
  local ui_state = env.ui_state
  local ui_runtime = ui_state and ui_state.ui
  local current, turn = _resolve_current_player(game)
  local _, _, current_player_id = _resolve_current_player_meta(current)
  local slot_count = item_slice.resolve_slot_count(ui_runtime)
  local item_slots_by_player = item_slice.build_item_slots_by_player(game.players, slot_count)
  local auto_enabled_by_player = item_slice.build_auto_enabled_by_player(game.players)
  local item_slots = role_id_utils.read(item_slots_by_player, current_player_id)
  if not item_slots then
    item_slots = item_slice.build_item_slots_for_player(current, slot_count)
  end
  local choice, market = choice_slice.build_choice_and_market(game, env, ui_state)

  local model = {
    board = board_slice.build(game, env, turn),
    panel = panel_slice.build(game, env, turn, current_player_id, auto_enabled_by_player),
    item_slots = item_slots,
    item_slots_by_player = item_slots_by_player,
    auto_enabled_by_player = auto_enabled_by_player,
    item_choice_owner_id = item_slice.resolve_item_choice_owner_id(game, choice, current_player_id),
    choice = choice,
    market = market,
    popup = choice_slice.build_popup(ui_runtime),
  }
  return _fill_meta(model, env, current, turn)
end

function model_api.update(prev, game, env, dirty)
  assert(game ~= nil, "missing game")
  if not prev then
    return model_api.build(game, env)
  end
  env = env or _build_ui_env(nil, game)
  dirty = dirty or {}
  local ui_state = env.ui_state
  local ui_runtime = ui_state and ui_state.ui
  local current, turn = _resolve_current_player(game)
  local current_name, current_cash, current_player_id = _resolve_current_player_meta(current)
  local ui_dirty = dirty.ui == true
  local model = prev

  _refresh_board_and_auto_labels(model, game, env, turn, dirty, ui_dirty)
  local update_slots = _refresh_panel_and_slots(
    model,
    game,
    env,
    turn,
    current,
    current_player_id,
    ui_runtime,
    dirty,
    ui_dirty
  )
  _refresh_choice_and_meta(
    model,
    game,
    env,
    ui_state,
    ui_runtime,
    current_name,
    current_cash,
    current_player_id,
    turn,
    dirty,
    ui_dirty,
    update_slots
  )

  _fill_runtime_meta(model, env)
  return model
end

return model_api
