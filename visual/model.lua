local map_cfg = require("cfg.Map")
local tiles_cfg = require("cfg.Generated.Tiles")
local choice_view = require("visual.widget.choice")
local panel_view = require("visual.widget.panel")
local number_utils = require("core.math")
local logger = require("core.logger")

local ui_model = {}
local projection = {}
local panel_builder = {}
local role_avatar = {}
local role_context = {}

local warned_values = {}
local warned_unmapped_role_ids = {}

local FALLBACK_CURRENT_PLAYER_NAME = "-"
local FALLBACK_CURRENT_PLAYER_CASH = 0
local FALLBACK_CURRENT_PLAYER_ID = nil

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

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

function projection.board_tiles()
  return board_tiles
end

function projection.resolve_current_player(game)
  local turn = game.turn
  local players = game.players
  assert(turn ~= nil and players ~= nil, "missing turn or players")
  local idx = turn.current_player_index
  if type(idx) ~= "number" then
    return nil, turn,
      string.format("invalid current player index: index=%s, player_count=%d", tostring(idx), #players)
  end
  local current = players[idx]
  if current == nil then
    return nil, turn,
      string.format("current player not found: index=%s, player_count=%d", tostring(idx), #players)
  end
  return current, turn
end

function projection.build_overlays(env)
  assert(env ~= nil and env.game ~= nil and env.game.board ~= nil and env.game.board.get_overlays ~= nil,
    "missing board overlays")
  return env.game.board:get_overlays()
end

function projection.resolve_item_slot_count(ui_runtime)
  local slot_count = 5
  if ui_runtime and type(ui_runtime.item_slots) == "table" and #ui_runtime.item_slots > 0 then
    slot_count = #ui_runtime.item_slots
  end
  return slot_count
end

function projection.build_item_slots_for_player(player, slot_count)
  local current_items = {}
  if player and player.inventory and type(player.inventory.items) == "table" then
    current_items = player.inventory.items
  end
  local item_slots = {}
  for i = 1, slot_count do
    local item = current_items[i]
    item_slots[i] = item and item.id or nil
  end
  return item_slots
end

function projection.build_item_slots_by_player(players, slot_count)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = projection.build_item_slots_for_player(player, slot_count)
    end
  end
  return out
end

function projection.build_auto_enabled_by_player(players)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = player.auto == true
    end
  end
  return out
end

function projection.build_choice_and_market(game, env, ui_state)
  local choice = nil
  local pending = game.turn and game.turn.pending_choice
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
  return choice, market
end

function projection.build_popup(ui_runtime)
  if ui_runtime and ui_runtime.popup_active and ui_runtime.popup_payload then
    return {
      title = ui_runtime.popup_payload.title,
      body = ui_runtime.popup_payload.body,
      button_text = ui_runtime.popup_payload.button_text,
    }
  end
  return nil
end

function projection.resolve_item_choice_owner_id(game, choice, current_player_id)
  local owner_id = current_player_id
  local pending = game and game.turn and game.turn.pending_choice or nil
  if pending and pending.meta and pending.meta.player_id then
    owner_id = pending.meta.player_id
    return owner_id
  end
  if choice and choice.meta and choice.meta.player_id then
    owner_id = choice.meta.player_id
  end
  return owner_id
end

function panel_builder.build_auto_label_by_player(players, enabled_by_player)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = panel_view.build_auto_label(enabled_by_player and enabled_by_player[player_id] == true)
    end
  end
  return out
end

function panel_builder.build(game, env, turn, current_player_id, auto_enabled_by_player)
  local auto_label_by_player = panel_builder.build_auto_label_by_player(game.players, auto_enabled_by_player)
  return {
    turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    ),
    player_rows = panel_view.build_player_statuses(game, env.game, 4),
    auto_label_by_player = auto_label_by_player,
    auto_label = auto_label_by_player[current_player_id] or panel_view.build_auto_label(false),
    no_action_visible = turn.detained_wait_active == true,
    no_action_text = "本回合无法行动",
  }
end

function panel_builder.update(panel, game, env, turn, current_player_id, auto_enabled_by_player, flags)
  panel = panel or {}
  flags = flags or {}
  if flags.turn_label then
    panel.turn_label = panel_view.build_turn_label(
      turn.turn_count,
      turn.countdown_seconds or 0,
      turn.countdown_active == true
    )
  end
  if flags.player_rows then
    panel.player_rows = panel_view.build_player_statuses(game, env.game, 4)
  end
  if flags.auto_label then
    panel.auto_label_by_player = panel_builder.build_auto_label_by_player(game.players, auto_enabled_by_player)
    panel.auto_label = panel.auto_label_by_player[current_player_id] or panel_view.build_auto_label(false)
  end
  if flags.turn_label or flags.turn then
    panel.no_action_visible = turn.detained_wait_active == true
    panel.no_action_text = "本回合无法行动"
  end
  return panel
end

local function _safe_tostring(value)
  local ok, text = pcall(tostring, value)
  if ok then
    return text
  end
  return "<tostring failed>"
end

local function _warn_invalid_image_key(value)
  local value_type = type(value)
  local text = _safe_tostring(value)
  local key = value_type .. ":" .. text
  if warned_values[key] then
    return
  end
  warned_values[key] = true
  logger.warn("头像ImageKey解析失败:", "type=" .. value_type, "value=" .. text)
end

function role_avatar.sanitize_image_key(value)
  if value == nil then
    return nil
  end
  local as_int = number_utils.to_integer(value)
  if as_int == nil then
    if math and math.tointeger then
      local ok, coerced = pcall(math.tointeger, value)
      if ok then
        as_int = coerced
      end
    end
  end
  if as_int == nil then
    local text = _safe_tostring(value)
    as_int = number_utils.to_integer(text)
  end
  if as_int == nil then
    _warn_invalid_image_key(value)
    return nil
  end
  if as_int <= 0 then
    _warn_invalid_image_key(value)
    return nil
  end
  return as_int
end

function role_avatar.resolve_from_role(role)
  if not role or type(role.get_head_icon) ~= "function" then
    return nil
  end
  local ok, icon = pcall(role.get_head_icon)
  if not ok then
    return nil
  end
  return role_avatar.sanitize_image_key(icon)
end

function role_context.resolve(role, ui_model_ref, deps)
  local runtime = deps and deps.runtime or nil
  assert(runtime ~= nil and runtime.resolve_role_id ~= nil, "missing runtime.resolve_role_id")
  local current_player_id = ui_model_ref and ui_model_ref.current_player_id or nil
  local role_id = runtime.resolve_role_id(role)
  local by_player = ui_model_ref and (ui_model_ref.item_slots_by_player_id or ui_model_ref.item_slots_by_player) or nil
  local mapped = role_id ~= nil and by_player ~= nil and by_player[role_id] ~= nil

  if role_id == nil and role == nil then
    return {
      role_id = nil,
      display_player_id = current_player_id,
      can_operate = true,
      is_player_role = true,
    }
  end

  if mapped then
    return {
      role_id = role_id,
      display_player_id = role_id,
      can_operate = role_id == current_player_id,
      is_player_role = true,
    }
  end

  if role_id ~= nil and not warned_unmapped_role_ids[role_id] then
    warned_unmapped_role_ids[role_id] = true
    logger.warn(
      "role->player 映射失败，按观战回退:",
      "role_id=" .. tostring(role_id),
      "current_player_id=" .. tostring(current_player_id)
    )
  end

  return {
    role_id = role_id,
    display_player_id = current_player_id,
    can_operate = false,
    is_player_role = false,
  }
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
    panel = panel_builder.build(game, env, turn, current_player_id, auto_enabled_by_player),
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

  model.panel = panel_builder.update(
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

ui_model.projection = projection
ui_model.panel_builder = panel_builder
ui_model.role_avatar = role_avatar
ui_model.role_context = role_context

return ui_model
