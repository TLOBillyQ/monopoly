local board_slice = require("src.presentation.state" .. ".ui_model.BoardSlice")
local item_slice = require("src.presentation.state" .. ".ui_model.ItemSlice")
local choice_slice = require("src.presentation.state" .. ".ui_model.ChoiceSlice")
local panel_slice = require("src.presentation.state" .. ".ui_model.PanelSlice")
local number_utils = require("src.core.utils.NumberUtils")
local role_id_utils = require("src.core.utils.RoleId")

local ui_model = {}

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

function ui_model.build(game, env)
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

function ui_model.update(prev, game, env, dirty)
  assert(game ~= nil, "missing game")
  if not prev then
    return ui_model.build(game, env)
  end
  env = env or _build_ui_env(nil, game)
  dirty = dirty or {}
  local ui_state = env.ui_state
  local ui_runtime = ui_state and ui_state.ui
  local current, turn = _resolve_current_player(game)
  local current_name, current_cash, current_player_id = _resolve_current_player_meta(current)
  local ui_dirty = dirty.ui == true
  local model = prev

  if dirty.players or dirty.board_tiles or dirty.turn then
    model.board = board_slice.update(model.board, game, env, turn)
  end

  if dirty.players or dirty.turn or ui_dirty then
    model.auto_enabled_by_player = item_slice.build_auto_enabled_by_player(game.players)
  end

  model.panel = panel_slice.update(
    model.panel,
    game,
    env,
    turn,
    current_player_id,
    model.auto_enabled_by_player,
    {
      turn_label = dirty.turn or dirty.turn_countdown or ui_dirty,
      player_rows = dirty.players or dirty.board_tiles or ui_dirty,
      auto_label = dirty.players or dirty.turn or ui_dirty,
    }
  )

  local update_slots = dirty.players or dirty.turn or ui_dirty
  if not update_slots and dirty.inventory_ids then
    for _ in pairs(dirty.inventory_ids) do
      update_slots = true
      break
    end
  end
  if update_slots then
    local slot_count = item_slice.resolve_slot_count(ui_runtime)
    local by_player = item_slice.build_item_slots_by_player(game.players, slot_count)
    model.item_slots_by_player = by_player
    model.item_slots = role_id_utils.read(by_player, current_player_id) or item_slice.build_item_slots_for_player(current, slot_count)
  end

  if dirty.turn or dirty.market or ui_dirty then
    local choice, market = choice_slice.build_choice_and_market(game, env, ui_state)
    model.choice = choice
    model.market = market
    model.item_choice_owner_id = item_slice.resolve_item_choice_owner_id(game, choice, current_player_id)
  elseif dirty.players or update_slots then
    model.item_choice_owner_id = item_slice.resolve_item_choice_owner_id(game, model.choice, current_player_id)
  end

  if ui_dirty then
    model.popup = choice_slice.build_popup(ui_runtime)
  end

  if dirty.players or dirty.turn then
    model.current_player_name = current_name
    model.current_player_cash = current_cash
    model.turn_count = turn.turn_count
    model.current_player_id = current_player_id
  end

  model.board_tile_count = board_slice.tile_count()
  model.last_turn = env.last_turn
  model.finished = env.finished
  model.winner_name = env.winner_name
  return model
end

return ui_model
