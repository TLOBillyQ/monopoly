require "vendor.third_party.Utils"

local state_mod = {}

local deep_copy = Utils.deep_copy

local function _build_tile_lookup(tiles)
  local lookup = {}
  for _, cfg in ipairs(tiles or {}) do
    lookup[cfg.id] = cfg
  end
  return lookup
end

local function _derive_rent_base(cfg)
  if cfg == nil then
    return 200
  end
  if type(cfg.rent_base) == "number" and cfg.rent_base > 0 then
    return cfg.rent_base
  end
  local price = tonumber(cfg.price) or 0
  if price <= 0 then
    return 200
  end
  local rent = math.floor(price * 0.12)
  if rent < 100 then
    rent = 100
  end
  return rent
end

local function _derive_upgrade_price(cfg)
  if cfg == nil then
    return 1000
  end
  if type(cfg.upgrade_price) == "number" and cfg.upgrade_price > 0 then
    return cfg.upgrade_price
  end
  local price = tonumber(cfg.price) or 0
  if price <= 0 then
    return 1000
  end
  local upgrade = math.floor(price * 0.6)
  if upgrade < 500 then
    upgrade = 500
  end
  return upgrade
end

local function _build_board(map_cfg, tiles_cfg)
  local tile_cfg_by_id = _build_tile_lookup(tiles_cfg)
  local path_ids = {}
  local index_by_tile_id = {}
  local tile_defs = {}
  local tile_states = {}

  for idx, tile_id in ipairs(map_cfg.path or {}) do
    path_ids[idx] = tile_id
    if not index_by_tile_id[tile_id] then
      index_by_tile_id[tile_id] = idx
    end
    local cfg = tile_cfg_by_id[tile_id] or { id = tile_id, name = tostring(tile_id), type = "unknown" }
    tile_defs[tile_id] = {
      id = tile_id,
      name = cfg.name,
      type = cfg.type,
      row = cfg.row,
      col = cfg.col,
      price = cfg.price,
      rent_base = _derive_rent_base(cfg),
      upgrade_price = _derive_upgrade_price(cfg),
    }
    if cfg.type == "land" and tile_states[tile_id] == nil then
      tile_states[tile_id] = {
        owner_id = nil,
        level = 0,
      }
    end
  end

  return {
    path = path_ids,
    index_by_tile_id = index_by_tile_id,
    tile_defs = tile_defs,
    tile_states = tile_states,
    overlays = { roadblocks = {}, mines = {} },
  }
end

local function _build_players(opts)
  local players = {}
  local seat_by_role_id = {}
  local list = opts.players or {}
  local default_cash = opts.starting_cash or 20000

  for seat, player in ipairs(list) do
    local role_id = player.role_id
    local is_ai = player.is_ai == true
    local online = role_id ~= nil
    players[seat] = {
      id = seat,
      seat_id = seat,
      role_id = role_id,
      name = player.name or ("玩家" .. tostring(seat)),
      cash = player.cash or default_cash,
      position = player.position or 1,
      online = online,
      auto = player.auto == true or (not online) or is_ai,
      is_ai = is_ai,
      eliminated = false,
      properties = {},
      inventory = { items = {}, max_slots = 5 },
      status = {},
      offline_since = nil,
      last_seen_at = opts.now or 0,
    }
    if role_id ~= nil then
      seat_by_role_id[role_id] = seat
    end
  end

  return players, seat_by_role_id
end

function state_mod.create(opts)
  opts = opts or {}
  local now = opts.now or 0
  local reconnect = opts.reconnect or {}
  local rules = opts.rules or {}
  local board = _build_board(assert(opts.map, "missing map config"), assert(opts.tiles, "missing tiles config"))
  local players, seat_by_role_id = _build_players({
    players = opts.players,
    starting_cash = opts.starting_cash,
    now = now,
  })

  local state = {
    schema_version = 2,
    match_id = opts.match_id or ("match-" .. tostring(now)),
    status = "running",
    version = 0,
    event_index = 0,
    next_command_id = 1,
    rng_seed = opts.rng_seed or 20260206,
    board = board,
    players = players,
    seat_by_role_id = seat_by_role_id,
    command_dedup = {},
    clock = {
      now = now,
      dt = 0,
    },
    rules = {
      action_timeout_seconds = rules.action_timeout_seconds or 15,
      reconnect = {
        freeze_on_disconnect = reconnect.freeze_on_disconnect ~= false,
        grace_seconds = reconnect.grace_seconds or 20,
        offline_auto_host_seconds = reconnect.offline_auto_host_seconds or 90,
      },
    },
    reconnect = {
      grace_until = {},
    },
    turn = {
      current_seat = 1,
      turn_no = 0,
      phase = "idle",
      seq = {
        move = 0,
        action = 0,
        choice = 0,
      },
      pending_interaction = nil,
      move_anim = nil,
      action_anim = nil,
      frozen = false,
      frozen_reason = nil,
      frozen_seat = nil,
      choice_deadline = nil,
      choice_remaining = nil,
      countdown_seconds = 0,
      countdown_active = false,
      last_dice = nil,
    },
  }

  for seat = 1, #players do
    state.command_dedup[seat] = {}
  end

  return state
end

function state_mod.deep_copy(input)
  return deep_copy(input)
end

function state_mod.get_current_player(state)
  local seat = state.turn.current_seat
  return state.players[seat]
end

function state_mod.resolve_seat_by_role_id(state, role_id)
  if role_id == nil then
    return nil
  end
  return state.seat_by_role_id[role_id]
end

function state_mod.next_alive_seat(state, from_seat)
  local total = #state.players
  if total <= 0 then
    return nil
  end
  local cursor = from_seat
  for _ = 1, total do
    cursor = (cursor % total) + 1
    local player = state.players[cursor]
    if player and not player.eliminated then
      return cursor
    end
  end
  return from_seat
end

return state_mod
