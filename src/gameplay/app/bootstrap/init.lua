local BoardFactory = require("src.gameplay.app.factories.board_factory")
local Player = require("src.core.player")
local Inventory = require("src.core.inventory")
local constants = require("src.config.constants")
local roles_cfg = require("src.config.roles")
local Tables = require("src.util.tables")

local Bootstrap = {}

local deep_copy = Tables.deep_copy

function Bootstrap.create_board(opts)
  return BoardFactory.create(opts)
end

function Bootstrap.create_players(opts)
  opts = opts or {}
  local players = {}
  local names = opts.players or { "玩家1" }
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local player = Player.new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = opts.ai and opts.ai[i] or (i > 1),
      auto = opts.auto_all or false,
      start_index = 1,
      constants = constants,
      inventory = Inventory.new({ constants = constants }),
    })
    table.insert(players, player)
  end
  return players
end

function Bootstrap.snapshot_inventory(inv)
  return { items = deep_copy(inv.items), max_slots = inv.max_slots }
end

function Bootstrap.snapshot_players(players)
  local ps = {}
  for _, p in ipairs(players) do
    ps[p.id] = {
      id = p.id,
      name = p.name,
      role_id = p.role_id,
      is_ai = p.is_ai,
      auto = p.auto,
      cash = p.cash,
      position = p.position,
      seat_id = p.seat_id,
      eliminated = p.eliminated,
      properties = deep_copy(p.properties),
      status = deep_copy(p.status),
      inventory = Bootstrap.snapshot_inventory(p.inventory),
    }
  end
  return ps
end

function Bootstrap.snapshot_tiles(path)
  local ts = {}
  for _, tile in ipairs(path) do
    if tile.type == "land" then
      ts[tile.id] = { owner_id = nil, level = 0 }
    end
  end
  return ts
end

function Bootstrap.build_initial_state(board, players, rng)
  return {
    board = {
      tiles = Bootstrap.snapshot_tiles(board.path),
    },
    turn = {
      current_player_index = 1,
      turn_count = 0,
      phase = "start",
      pending_choice = nil,
      choice_seq = 0,
    },
    rng = rng and rng:snapshot() or nil,
    players = Bootstrap.snapshot_players(players),
  }
end

return Bootstrap
