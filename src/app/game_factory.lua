local board = require("src.rules.board")
local tile = require("src.rules.board.tile")
local player = require("src.player.actions.player")
local inventory = require("src.player.actions.inventory")
local constants = require("src.config.content.constants")
local roles_cfg = require("src.config.content.roles")
require "vendor.third_party.Utils"

local game_factory = {}

local function _new_rng(random_fn)
  random_fn = random_fn or GameAPI.random_int
  local rng = {}
  function rng:next_int(min, max)
    return random_fn(min, max)
  end
  return rng
end

local function _create_board(opts)
  assert(opts ~= nil, "missing board opts")
  local tiles = assert(opts.tiles, "missing tiles config")
  local map_cfg = assert(opts.map, "missing map config")

  local tile_lookup = {}
  for _, cfg in ipairs(tiles) do
    tile_lookup[cfg.id] = tile:new(cfg)
  end

  local path = {}
  for _, id in ipairs(map_cfg.path) do
    table.insert(path, tile_lookup[id])
  end

  return board:new({
    path = path,
    tile_lookup = tile_lookup,
    branches = map_cfg.branches,
    map = map_cfg,
    overlays = { roadblocks = {}, mines = {} },
  })
end

local function _create_players(opts)
  local players = {}
  local ai_map = opts.ai or {}
  local auto_map = opts.auto or {}
  local role_roster = opts.role_roster

  local function _resolve_auto(key)
    local explicit = auto_map[key]
    if explicit ~= nil then
      return explicit
    end
    return opts.auto_all
  end

  if type(role_roster) == "table" and #role_roster > 0 then
    for i, entry in ipairs(role_roster) do
      local role_id = entry and (entry.role_id or entry.id) or nil
      assert(role_id ~= nil, "missing role_id in role_roster: " .. tostring(i))
      local name = entry and entry.name or nil
      if not name or name == "" then
        name = "玩家" .. tostring(i)
      end
      local is_ai = ai_map[role_id]
      local new_player = player:new({
        id = role_id,
        name = name,
        role_id = role_id,
        is_ai = is_ai,
        auto = _resolve_auto(role_id),
        start_index = 1,
        constants = constants,
        balances = {
          ["金币"] = constants.starting_cash,
        },
        deity_duration_turns = constants.deity_duration_turns,
        inventory = inventory:new({ constants = constants }),
      })
      table.insert(players, new_player)
    end
    return players
  end

  local names = assert(opts.players, "missing player names")
  if #names == 1 then
    names = { names[1], "玩家2", "玩家3", "玩家4" }
  end
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local is_ai = ai_map[i]
    local new_player = player:new({
      id = i,
      name = name,
      role_id = role.id,
      is_ai = is_ai,
      auto = _resolve_auto(i),
      start_index = 1,
      constants = constants,
      balances = {
        ["金币"] = constants.starting_cash,
      },
      deity_duration_turns = constants.deity_duration_turns,
      inventory = inventory:new({ constants = constants }),
    })
    table.insert(players, new_player)
  end
  return players
end

function game_factory.build_rng(random_fn)
  return _new_rng(random_fn)
end

function game_factory.build_board(opts)
  return _create_board(opts)
end

function game_factory.build_players(opts)
  return _create_players(opts)
end

return game_factory
