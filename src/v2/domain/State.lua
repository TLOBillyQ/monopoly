require "vendor.third_party.Utils"

local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local market_cfg = require("Config.Generated.Market")

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
  local rents = cfg.rents
  if type(rents) == "table" and type(rents[1]) == "number" and rents[1] > 0 then
    return rents[1]
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
  local costs = cfg.upgrade_costs
  if type(costs) == "table" and type(costs[1]) == "number" and costs[1] > 0 then
    return costs[1]
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

local function _build_market_limits()
  local limits = {}
  for _, entry in ipairs(market_cfg or {}) do
    local limit = tonumber(entry.limit) or 0
    if limit < 0 then
      limit = 0
    end
    limits[entry.product_id] = limit
  end
  return limits
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
      price = cfg.price or 0,
      rents = deep_copy(cfg.rents or {}),
      upgrade_costs = deep_copy(cfg.upgrade_costs or {}),
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
    overlays = {
      roadblocks = {},
      mines = {},
    },
    map = {
      neighbors = map_cfg.neighbors or {},
      outer_next = map_cfg.outer_next or {},
      outer_prev = map_cfg.outer_prev or {},
      entry_points = map_cfg.entry_points or {},
      branches = map_cfg.branches or {},
      start_id = map_cfg.start_id,
      market_id = map_cfg.market_id,
      turn_left = map_cfg.turn_left or {},
      turn_right = map_cfg.turn_right or {},
      direction = map_cfg.direction,
    },
  }
end

local function _build_player_status()
  return {
    stay_turns = 0,
    deity = { type = "", remaining = 0 },
    pending_remote_dice = nil,
    pending_dice_multiplier = 1,
    pending_free_rent = false,
    pending_tax_free = false,
  }
end

local function _build_players(opts)
  local players = {}
  local seat_by_role_id = {}
  local list = opts.players or {}
  local default_cash = opts.starting_cash or constants.starting_cash or 20000
  local start_jindou = constants.starting_jindou or 0
  local start_leyuanbi = constants.starting_leyuanbi or 0
  local inventory_slots = constants.inventory_slots or 5

  for seat, player in ipairs(list) do
    local role_id = player.role_id
    local is_ai = player.is_ai == true
    local online = role_id ~= nil
    local cash = player.cash or default_cash
    local balances = {
      ["金豆"] = player.jindou or start_jindou,
      ["乐园币"] = player.leyuanbi or start_leyuanbi,
    }
    players[seat] = {
      id = seat,
      seat_id = seat,
      role_id = role_id,
      name = player.name or ("玩家" .. tostring(seat)),
      is_ai = is_ai,
      auto = player.auto == true or (not online) or is_ai,
      online = online,
      offline_since = nil,
      last_seen_at = opts.now or 0,
      eliminated = false,

      cash = cash,
      balances = balances,

      position = player.position or 1,
      move_dir = nil,
      seat_vehicle_id = player.seat_vehicle_id,

      properties = {},
      inventory = {
        items = deep_copy(player.items or {}),
        max_slots = inventory_slots,
      },
      status = _build_player_status(),
    }
    if role_id ~= nil then
      seat_by_role_id[role_id] = seat
    end
  end

  return players, seat_by_role_id
end

local function _build_rules(opts)
  local reconnect = opts.reconnect or gameplay_rules.reconnect or {}
  local out = {
    action_timeout_seconds = opts.action_timeout_seconds or constants.action_timeout_seconds or 10,
    turn_limit = opts.turn_limit or gameplay_rules.turn_limit or 0,
    pass_start_bonus = constants.pass_start_bonus or 2000,
    tax_rate = constants.tax_rate or 0.5,
    hospital_stay_turns = constants.hospital_stay_turns or 2,
    mountain_stay_turns = constants.mountain_stay_turns or 2,
    hospital_fee = constants.hospital_fee or 5000,
    deity_duration_turns = constants.deity_duration_turns or 5,
    reconnect = {
      freeze_on_disconnect = reconnect.freeze_on_disconnect ~= false,
      grace_seconds = reconnect.grace_seconds or 20,
      offline_auto_host_seconds = reconnect.offline_auto_host_seconds or 90,
    },
  }
  return out
end

function state_mod.create(opts)
  opts = opts or {}
  local now = opts.now or 0
  local board = _build_board(assert(opts.map, "missing map config"), assert(opts.tiles, "missing tiles config"))
  local players, seat_by_role_id = _build_players({
    players = opts.players,
    starting_cash = opts.starting_cash,
    now = now,
  })
  local rules = _build_rules({
    action_timeout_seconds = opts.rules and opts.rules.action_timeout_seconds,
    reconnect = opts.rules and opts.rules.reconnect,
    turn_limit = opts.rules and opts.rules.turn_limit,
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

    market = {
      global_limits = _build_market_limits(),
    },

    command_dedup = {},
    clock = {
      now = now,
      dt = 0,
    },
    rules = rules,
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
      item_phase = {},
      item_phase_active = "",
      last_dice = nil,
      last_rolls = {},
      move_result = nil,
      last_turn = nil,
    },
    match = {
      finished = false,
      winner_ids = {},
      winner_names = {},
      reason = nil,
    },
    ui_selected_market_option = nil,
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
