local board = require("src.rules.board")
local tile = require("src.rules.board.tile")
local player = require("src.player.actions.player")
local balance_ops = require("src.player.actions.balance")
local inventory = require("src.player.actions.inventory")
local constants = require("src.config.content.constants")
local roles_cfg = require("src.config.content.roles")
local fan_club = require("src.app.host_integrations.fan_club")
local runtime_ports = require("src.foundation.ports.runtime_ports")
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

local function _starting_cash()
  return constants.starting_cash + (fan_club.starting_cash_bonus() or 0)
end

local function _resolve_coin_role(entry, player_id)
  if entry and entry.role ~= nil then
    return entry.role
  end
  local runtime_role = runtime_ports.resolve_role(player_id)
  if runtime_role ~= nil then
    return runtime_role
  end
  return balance_ops.new_memory_coin_role()
end

local function _new_player_entry(id, name, role_id, is_ai, is_auto, coin_role)
  local created = player:new({
    id = id,
    name = name,
    role_id = role_id,
    is_ai = is_ai,
    auto = is_auto,
    start_index = 1,
    constants = constants,
    coin_role = coin_role,
    deity_duration_turns = constants.deity_duration_turns,
    inventory = inventory:new({ constants = constants }),
  })
  balance_ops.initialize_player_coins(created, _starting_cash())
  return created
end

local function _resolve_roster_name(entry, index)
  local name = entry and entry.name or nil
  if not name or name == "" then
    return "玩家" .. tostring(index)
  end
  return name
end

local function _resolve_auto_flag(opts, auto_players, role_id)
  return opts.auto_all or (auto_players and auto_players[role_id]) or false
end

local function _create_players_from_roster(opts, role_roster, ai_map)
  local players = {}
  local auto_players = opts.auto_players
  for i, entry in ipairs(role_roster) do
    local role_id = entry and (entry.role_id or entry.id) or nil
    assert(role_id ~= nil, "missing role_id in role_roster: " .. tostring(i))
    local name = _resolve_roster_name(entry, i)
    local is_ai = ai_map[role_id]
    local is_auto = _resolve_auto_flag(opts, auto_players, role_id)
    table.insert(players, _new_player_entry(role_id, name, role_id, is_ai, is_auto, _resolve_coin_role(entry, role_id)))
  end
  return players
end

local function _create_players_from_names(opts, ai_map)
  local players = {}
  local names = assert(opts.players, "missing player names")
  if #names == 1 then
    names = { names[1], "玩家2", "玩家3", "玩家4" }
  end
  for i, name in ipairs(names) do
    local role = roles_cfg[((i - 1) % #roles_cfg) + 1]
    local is_ai = ai_map[i]
    table.insert(players, _new_player_entry(i, name, role.id, is_ai, opts.auto_all, _resolve_coin_role(nil, i)))
  end
  return players
end

local function _create_players(opts)
  local ai_map = opts.ai or {}
  local role_roster = opts.role_roster
  if type(role_roster) == "table" and #role_roster > 0 then
    return _create_players_from_roster(opts, role_roster, ai_map)
  end
  return _create_players_from_names(opts, ai_map)
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

--[[ mutate4lua-manifest
version=2
projectHash=0615b002c9c83e3d
scope.0.id=chunk:src/app/game_factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=123
scope.0.semanticHash=8c501f68a3accf6e
scope.1.id=function:rng:next_int:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=a235f76a7b1af2ea
scope.2.id=function:_new_rng:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=19
scope.2.semanticHash=3ea1211e3a1862be
scope.3.id=function:_starting_cash:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=47
scope.3.semanticHash=f6478d4f85d2799d
scope.4.id=function:game_factory.build_rng:110
scope.4.kind=function
scope.4.startLine=110
scope.4.endLine=112
scope.4.semanticHash=9dd018ed6b84c574
scope.5.id=function:game_factory.build_board:114
scope.5.kind=function
scope.5.startLine=114
scope.5.endLine=116
scope.5.semanticHash=8b98b2c25fd31d7e
scope.6.id=function:game_factory.build_players:118
scope.6.kind=function
scope.6.startLine=118
scope.6.endLine=120
scope.6.semanticHash=7460e1ccf07721b2
]]
