local store_paths = {}

local function _path(...)
  local parts = { ... }
  return parts
end

store_paths.turn = {
  root = _path("turn"),
  phase = _path("turn", "phase"),
  current_player_index = _path("turn", "current_player_index"),
  turn_count = _path("turn", "turn_count"),
  countdown_seconds = _path("turn", "countdown_seconds"),
  countdown_active = _path("turn", "countdown_active"),
  pending_choice = _path("turn", "pending_choice"),
  choice_seq = _path("turn", "choice_seq"),
  move_anim = _path("turn", "move_anim"),
  move_anim_seq = _path("turn", "move_anim_seq"),
  action_anim = _path("turn", "action_anim"),
  action_anim_seq = _path("turn", "action_anim_seq"),
  market_prompt = _path("turn", "market_prompt"),
  post_action = _path("turn", "post_action"),
  item_phase = _path("turn", "item_phase"),
  item_phase_active = _path("turn", "item_phase_active"),
}

function store_paths.turn.item_phase_by_name(phase_name)
  return _path("turn", "item_phase", phase_name)
end

store_paths.players = {
  root = _path("players"),
}

function store_paths.players.player(player_id)
  return _path("players", player_id)
end

function store_paths.players.cash(player_id)
  return _path("players", player_id, "cash")
end

function store_paths.players.balance(player_id, currency)
  return _path("players", player_id, "balances", currency)
end

function store_paths.players.balances(player_id)
  return _path("players", player_id, "balances")
end

function store_paths.players.position(player_id)
  return _path("players", player_id, "position")
end

function store_paths.players.seat_id(player_id)
  return _path("players", player_id, "seat_id")
end

function store_paths.players.status(player_id)
  return _path("players", player_id, "status")
end

function store_paths.players.status_key(player_id, key)
  return _path("players", player_id, "status", key)
end

function store_paths.players.deity(player_id)
  return _path("players", player_id, "status", "deity")
end

function store_paths.players.deity_remaining(player_id)
  return _path("players", player_id, "status", "deity", "remaining")
end

function store_paths.players.inventory(player_id)
  return _path("players", player_id, "inventory")
end

function store_paths.players.properties(player_id)
  return _path("players", player_id, "properties")
end

function store_paths.players.property(player_id, tile_id)
  return _path("players", player_id, "properties", tile_id)
end

function store_paths.players.eliminated(player_id)
  return _path("players", player_id, "eliminated")
end

store_paths.board = {
  root = _path("board"),
  tiles = _path("board", "tiles"),
}

function store_paths.board.tile(tile_id)
  return _path("board", "tiles", tile_id)
end

function store_paths.board.tile_key(tile_id, key)
  return _path("board", "tiles", tile_id, key)
end

store_paths.market = {
  root = _path("market"),
  global_limits = _path("market", "global_limits"),
}

function store_paths.market.global_limit(product_id)
  return _path("market", "global_limits", product_id)
end

return store_paths
