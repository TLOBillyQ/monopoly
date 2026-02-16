-- visual/model.lua - Facade 门面模式
-- 按 SRP 拆分为子模块，此文件仅作协调器

local projection = require("visual.model.projection")
local panel = require("visual.model.panel")
local avatar = require("visual.model.avatar")
local context = require("visual.model.context")

local ui_model = {}

local FALLBACK_CURRENT_PLAYER_NAME = "-"
local FALLBACK_CURRENT_PLAYER_CASH = 0
local FALLBACK_CURRENT_PLAYER_ID = nil

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
  return current.name or FALLBACK_CURRENT_PLAYER_NAME, current.cash or FALLBACK_CURRENT_PLAYER_CASH, current.id
end

local function _fill_meta(model, env, current, turn)
  local current_name, current_cash, current_player_id = _resolve_current_player_meta(current)
  model.current_player_name = current_name
  model.current_player_cash = current_cash
  model.turn_count = turn.turn_count
  model.current_player_id = current_player_id
  model.board_tile_count = #projection.board_tiles()
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
  local current, turn = projection.resolve_current_player(game)
  local _, _, current_player_id = _resolve_current_player_meta(current)
  local slot_count = projection.resolve_item_slot_count(ui_runtime)
  local item_slots_by_player = projection.build_item_slots_by_player(game.players, slot_count)
  local auto_enabled_by_player = projection.build_auto_enabled_by_player(game.players)
  local item_slots = item_slots_by_player[current_player_id]
  if not item_slots then
    item_slots = projection.build_item_slots_for_player(current, slot_count)
  end
  local choice, market = projection.build_choice_and_market(game, env, ui_state)

  local model = {
    board = {
      tiles = projection.board_tiles(),
      tile_states = game.board and game.board.tile_lookup or {},
      overlays = projection.build_overlays(env),
      players = game.players,
      phase = turn.phase,
      move_anim = turn.move_anim,
      turn_start_prompt_seq = turn.turn_start_prompt_seq or 0,
      turn_start_prompt_player_id = turn.turn_start_prompt_player_id,
      vehicle_resync_seq = turn.vehicle_resync_seq or 0,
      tile_count = #projection.board_tiles(),
    },
    panel = panel.build(game, env, turn, current_player_id, auto_enabled_by_player),
    item_slots = item_slots,
    item_slots_by_player = item_slots_by_player,
    auto_enabled_by_player = auto_enabled_by_player,
    item_choice_owner_id = projection.resolve_item_choice_owner_id(game, choice, current_player_id),
    choice = choice,
    market = market,
    popup = projection.build_popup(ui_runtime),
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
  local current, turn = projection.resolve_current_player(game)
  local current_name, current_cash, current_player_id = _resolve_current_player_meta(current)
  local ui_dirty = dirty.ui == true
  local model = prev

  if dirty.players or dirty.board_tiles or dirty.turn then
    local board = model.board or {}
    board.tiles = projection.board_tiles()
    board.tile_states = game.board and game.board.tile_lookup or {}
    board.overlays = projection.build_overlays(env)
    board.players = game.players
    board.phase = turn.phase
    board.move_anim = turn.move_anim
    board.turn_start_prompt_seq = turn.turn_start_prompt_seq or 0
    board.turn_start_prompt_player_id = turn.turn_start_prompt_player_id
    board.vehicle_resync_seq = turn.vehicle_resync_seq or 0
    board.tile_count = #projection.board_tiles()
    model.board = board
  end

  if dirty.players or dirty.turn or ui_dirty then
    model.auto_enabled_by_player = projection.build_auto_enabled_by_player(game.players)
  end

  model.panel = panel.update(
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
    local slot_count = projection.resolve_item_slot_count(ui_runtime)
    local by_player = projection.build_item_slots_by_player(game.players, slot_count)
    model.item_slots_by_player = by_player
    model.item_slots = by_player[current_player_id] or projection.build_item_slots_for_player(current, slot_count)
  end

  if dirty.turn or dirty.market or ui_dirty then
    local choice, market = projection.build_choice_and_market(game, env, ui_state)
    model.choice = choice
    model.market = market
    model.item_choice_owner_id = projection.resolve_item_choice_owner_id(game, choice, current_player_id)
  elseif dirty.players or update_slots then
    model.item_choice_owner_id = projection.resolve_item_choice_owner_id(game, model.choice, current_player_id)
  end

  if ui_dirty then
    model.popup = projection.build_popup(ui_runtime)
  end

  if dirty.players or dirty.turn then
    model.current_player_name = current_name
    model.current_player_cash = current_cash
    model.turn_count = turn.turn_count
    model.current_player_id = current_player_id
  end

  model.board_tile_count = #projection.board_tiles()
  model.last_turn = env.last_turn
  model.finished = env.finished
  model.winner_name = env.winner_name
  return model
end

-- 暴露子模块供直接访问
ui_model.projection = projection
ui_model.panel_builder = panel
ui_model.role_avatar = avatar
ui_model.role_context = context

return ui_model
