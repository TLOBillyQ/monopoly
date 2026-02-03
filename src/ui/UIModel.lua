local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local choice_view = require("src.ui.UIChoice")
local panel_view = require("src.ui.UIPanel")

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

local ui_model = {}

local function _build_board_tiles()
  local out = {}
  assert(map_cfg.path ~= nil, "missing map path")
  for i, tile_id in ipairs(map_cfg.path) do
    local cfg = tiles_by_id[tile_id]
    assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
    out[i] = {
      id = tile_id,
      name = cfg.name,
      type = cfg.type,
      price = cfg.price,
      row = cfg.row,
      col = cfg.col,
    }
  end
  return out
end

local board_tiles = _build_board_tiles()

local function _build_overlays(env)
  assert(env ~= nil and env.game ~= nil and env.game.board ~= nil and env.game.board.get_overlays ~= nil, "missing board overlays")
  return env.game.board:get_overlays()
end

local function _resolve_current_player(state)
  local turn = state.turn
  local players = state.players
  assert(turn ~= nil and players ~= nil, "missing turn or players")
  local idx = turn.current_player_index
  return players[idx], turn
end

function ui_model.build(store_state, env)
  assert(store_state ~= nil, "missing store_state")
  env = env or {}
  local ui_state = env.ui_state
  local ui_runtime = ui_state and ui_state.ui
  local current, turn = _resolve_current_player(store_state)
  local overlays = _build_overlays(env)
  local slot_count = 5
  if ui_runtime and type(ui_runtime.item_slots) == "table" and #ui_runtime.item_slots > 0 then
    slot_count = #ui_runtime.item_slots
  end
  local current_items = {}
  if current and current.inventory and type(current.inventory.items) == "table" then
    current_items = current.inventory.items
  end
  local item_slots = {}
  for i = 1, slot_count do
    local item = current_items[i]
    item_slots[i] = item and item.id or nil
  end
  local panel = {
    turn_label = panel_view.build_turn_label(turn.turn_count, turn.countdown_seconds or 0),
    player_rows = panel_view.build_player_statuses(store_state, env.game, 4),
    auto_label = panel_view.build_auto_label(ui_runtime and ui_runtime.auto_play),
  }
  local choice = nil
  local pending = store_state.turn and store_state.turn.pending_choice
  if pending then
    choice = choice_view.build_choice_view(pending, { game = env.game })
    choice.id = pending.id
    choice.kind = pending.kind
  end
  local market = nil
  if choice and choice.kind == "market_buy" then
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = ui_state and ui_state.pending_choice_selected_option_id or nil,
    }
  end
  local popup = nil
  if ui_runtime and ui_runtime.popup_active and ui_runtime.popup_payload then
    popup = {
      title = ui_runtime.popup_payload.title,
      body = ui_runtime.popup_payload.body,
      button_text = ui_runtime.popup_payload.button_text,
    }
  end

  return {
    board = {
      tiles = board_tiles,
      tile_states = store_state.board and store_state.board.tiles or {},
      overlays = overlays,
      players = store_state.players,
      phase = turn.phase,
      move_anim = turn.move_anim,
      tile_count = #board_tiles,
    },
    panel = panel,
    item_slots = item_slots,
    choice = choice,
    market = market,
    popup = popup,
    current_player_name = current.name,
    current_player_cash = current.cash,
    turn_count = turn.turn_count,
    board_tile_count = #board_tiles,
    last_turn = env.last_turn,
    finished = env.finished,
    winner_name = env.winner_name,
  }
end

function ui_model.update(prev, store_state, env, dirty)
  assert(store_state ~= nil, "missing store_state")
  if not prev then
    return ui_model.build(store_state, env)
  end
  env = env or {}
  dirty = dirty or {}
  local ui_state = env.ui_state
  local ui_runtime = ui_state and ui_state.ui
  local current, turn = _resolve_current_player(store_state)
  local ui_dirty = dirty.ui == true
  local model = prev

  if dirty.players or dirty.board_tiles or dirty.turn then
    local board = model.board or {}
    board.tiles = board_tiles
    board.tile_states = store_state.board and store_state.board.tiles or {}
    board.overlays = _build_overlays(env)
    board.players = store_state.players
    board.phase = turn.phase
    board.move_anim = turn.move_anim
    board.tile_count = #board_tiles
    model.board = board
  end

  local panel = model.panel or {}
  if dirty.turn or dirty.turn_countdown or ui_dirty then
    panel.turn_label = panel_view.build_turn_label(turn.turn_count, turn.countdown_seconds or 0)
  end
  if dirty.players or dirty.board_tiles or ui_dirty then
    panel.player_rows = panel_view.build_player_statuses(store_state, env.game, 4)
  end
  if ui_dirty then
    panel.auto_label = panel_view.build_auto_label(ui_runtime and ui_runtime.auto_play)
  end
  model.panel = panel

  local update_slots = dirty.players or ui_dirty
  if not update_slots and dirty.inventory_ids then
    for _ in pairs(dirty.inventory_ids) do
      update_slots = true
      break
    end
  end
  if update_slots then
    local slot_count = 5
    if ui_runtime and type(ui_runtime.item_slots) == "table" and #ui_runtime.item_slots > 0 then
      slot_count = #ui_runtime.item_slots
    end
    local current_items = {}
    if current and current.inventory and type(current.inventory.items) == "table" then
      current_items = current.inventory.items
    end
    local item_slots = {}
    for i = 1, slot_count do
      local item = current_items[i]
      item_slots[i] = item and item.id or nil
    end
    model.item_slots = item_slots
  end

  if dirty.turn or dirty.market or ui_dirty then
    local choice = nil
    local pending = store_state.turn and store_state.turn.pending_choice
    if pending then
      choice = choice_view.build_choice_view(pending, { game = env.game })
      choice.id = pending.id
      choice.kind = pending.kind
    end
    model.choice = choice

    local market = nil
    if choice and choice.kind == "market_buy" then
      market = {
        choice_id = choice.id,
        options = choice.options,
        allow_cancel = choice.allow_cancel,
        cancel_label = choice.cancel_label,
        selected_option_id = ui_state and ui_state.pending_choice_selected_option_id or nil,
      }
    end
    model.market = market
  end

  if ui_dirty then
    local popup = nil
    if ui_runtime and ui_runtime.popup_active and ui_runtime.popup_payload then
      popup = {
        title = ui_runtime.popup_payload.title,
        body = ui_runtime.popup_payload.body,
        button_text = ui_runtime.popup_payload.button_text,
      }
    end
    model.popup = popup
  end

  if dirty.players or dirty.turn then
    model.current_player_name = current.name
    model.current_player_cash = current.cash
    model.turn_count = turn.turn_count
  end

  model.board_tile_count = #board_tiles
  model.last_turn = env.last_turn
  model.finished = env.finished
  model.winner_name = env.winner_name

  return model
end

return ui_model
