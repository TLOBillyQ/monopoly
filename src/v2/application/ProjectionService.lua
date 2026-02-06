local projection_service = {}
projection_service.__index = projection_service

local function _build_tiles(map_cfg, tiles_cfg)
  local by_id = {}
  for _, cfg in ipairs(tiles_cfg or {}) do
    by_id[cfg.id] = cfg
  end
  local out = {}
  for i, tile_id in ipairs(map_cfg.path or {}) do
    local cfg = by_id[tile_id] or {}
    out[i] = {
      id = tile_id,
      name = cfg.name or tostring(tile_id),
      type = cfg.type or "unknown",
      price = cfg.price,
      row = cfg.row,
      col = cfg.col,
    }
  end
  return out
end

local function _turn_label(state)
  local turn = state.turn
  if turn.countdown_active then
    return "回合: " .. tostring(turn.turn_no) .. " | 倒计时: " .. tostring(turn.countdown_seconds or 0)
  end
  return "回合: " .. tostring(turn.turn_no)
end

local function _phase_label(state)
  local phase = state.turn and state.turn.phase or "idle"
  return "阶段: " .. tostring(phase)
end

local function _build_player_rows(state)
  local rows = {}
  for seat = 1, 4 do
    local player = state.players[seat]
    if player then
      local land_count = 0
      local total_assets = player.cash
      for tile_id in pairs(player.properties or {}) do
        land_count = land_count + 1
        local tile_def = state.board.tile_defs[tile_id]
        local tile_state = state.board.tile_states[tile_id]
        if tile_def and tile_state then
          local level = tile_state.level or 0
          total_assets = total_assets + (tile_def.price or 0) + (tile_def.upgrade_price or 0) * level
        end
      end
      local status = player.eliminated and "(出局)" or ""
      rows[seat] = {
        name = tostring(player.name) .. status,
        cash = "现金: " .. tostring(player.cash),
        land_count = "地块: " .. tostring(land_count),
        total_assets = "总资产: " .. tostring(total_assets),
      }
    else
      rows[seat] = { name = "", cash = "", land_count = "", total_assets = "" }
    end
  end
  return rows
end

local function _choice_projection(state)
  local pending = state.turn.pending_interaction
  if not pending then
    return nil, nil
  end

  local body = ""
  if type(pending.body_lines) == "table" then
    body = table.concat(pending.body_lines, "\n")
  elseif type(pending.body) == "string" then
    body = pending.body
  end

  local options = {}
  for _, opt in ipairs(pending.options or {}) do
    options[#options + 1] = {
      id = opt.id or opt,
      label = opt.label or tostring(opt.id or opt),
    }
  end

  local choice = {
    id = pending.id,
    kind = pending.kind,
    title = pending.title or "请选择",
    body = body,
    options = options,
    allow_cancel = pending.allow_cancel ~= false,
    cancel_label = pending.cancel_label or "取消",
  }

  local market = nil
  if choice.kind == "market_buy" then
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = state.ui_selected_market_option,
    }
  end

  return choice, market
end

local function _build_item_slots(state, seat)
  local player = state.players[seat]
  if not player or not player.inventory then
    return {}
  end
  local slots = {}
  local max_slots = player.inventory.max_slots or 5
  local items = player.inventory.items or {}
  for index = 1, max_slots do
    local item = items[index]
    slots[index] = item and item.id or nil
  end
  return slots
end

local function _resolve_winner_name(state)
  local match = state.match or {}
  if match.winner_names and match.winner_names[1] then
    return match.winner_names[1]
  end
  local winner_id = match.winner_ids and match.winner_ids[1]
  if winner_id and state.players[winner_id] then
    return state.players[winner_id].name
  end
  return nil
end

function projection_service.new(opts)
  opts = opts or {}
  local instance = {
    board_tiles = _build_tiles(assert(opts.map, "missing map config"), assert(opts.tiles, "missing tiles config")),
  }
  setmetatable(instance, projection_service)
  return instance
end

function projection_service:build(state)
  local current = state.players[state.turn.current_seat] or {}
  local choice, market = _choice_projection(state)
  local winner_name = _resolve_winner_name(state)
  local finished = state.match and state.match.finished or state.status ~= "running"

  return {
    board = {
      tiles = self.board_tiles,
      tile_states = state.board.tile_states,
      overlays = state.board.overlays,
      players = state.players,
      phase = state.turn.phase,
      move_anim = state.turn.move_anim,
      action_anim = state.turn.action_anim,
      tile_count = #self.board_tiles,
    },
    panel = {
      turn_label = _turn_label(state),
      phase_label = _phase_label(state),
      player_rows = _build_player_rows(state),
      auto_label = current.auto and "自动：开" or "自动:关",
    },
    item_slots = _build_item_slots(state, state.turn.current_seat),
    choice = choice,
    market = market,
    popup = nil,
    current_player_name = current.name or "",
    current_player_cash = current.cash or 0,
    current_player_status = current.status or {},
    current_player_deity = current.status and current.status.deity or { type = "", remaining = 0 },
    current_player_vehicle = current.seat_vehicle_id,
    turn_count = state.turn.turn_no,
    board_tile_count = #self.board_tiles,
    last_turn = state.turn.last_turn,
    finished = finished,
    winner_name = winner_name,
    winners = state.match and state.match.winner_names or {},
  }
end

return projection_service
