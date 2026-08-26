local board = require("src.rules.board")
local tile = require("src.rules.board.tile")
local player = require("src.player.actions.player")
local control = require("src.player.control")
local balance_ops = require("src.player.actions.balance")
local inventory = require("src.player.actions.inventory")
local constants = require("src.config.content.constants")
local roles_cfg = require("src.config.content.roles")
local runtime_ports = require("src.foundation.ports.runtime_ports")

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
    start_index = 1,
    constants = constants,
    coin_role = coin_role,
    deity_duration_turns = constants.deity_duration_turns,
    inventory = inventory:new({ constants = constants }),
  })
  -- 全员自动调试/测试档案映射为明确的手动托管命令；补位电脑命令无副作用。
  if is_auto then
    control.toggle_manual_delegation(created)
  end
  balance_ops.seed_player_coins(created, constants.starting_cash)
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
version=4
projectHash=5a5ee31ce059ad74
scope.0.id=chunk:src/app/game_factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=139
scope.0.semanticHash=b3bfb1faf3698b1c
scope.1.id=function:_new_rng
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=20
scope.1.semanticHash=0ceabaef2ab1674a
scope.2.id=function:rng:next_int
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=3c26bf1ea8e4b724
scope.3.id=function:_create_board
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=44
scope.3.semanticHash=6904ea04adb828c0
scope.4.id=function:_resolve_coin_role
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=55
scope.4.semanticHash=ccf79f1e6cfc2a74
scope.5.id=function:_new_player_entry
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=75
scope.5.semanticHash=ad96d2c61ff0a42a
scope.6.id=function:_resolve_roster_name
scope.6.kind=function
scope.6.startLine=77
scope.6.endLine=83
scope.6.semanticHash=97253c59af6d1165
scope.7.id=function:_resolve_auto_flag
scope.7.kind=function
scope.7.startLine=85
scope.7.endLine=87
scope.7.semanticHash=8b649d22ba51858e
scope.8.id=function:_create_players_from_roster
scope.8.kind=function
scope.8.startLine=89
scope.8.endLine=101
scope.8.semanticHash=6acbf415c3a7d36c
scope.9.id=function:_create_players_from_names
scope.9.kind=function
scope.9.startLine=103
scope.9.endLine=115
scope.9.semanticHash=48031ee276a7023e
scope.10.id=function:_create_players
scope.10.kind=function
scope.10.startLine=117
scope.10.endLine=124
scope.10.semanticHash=e2bf4c9e0940defd
scope.11.id=function:game_factory.build_rng
scope.11.kind=function
scope.11.startLine=126
scope.11.endLine=128
scope.11.semanticHash=f1ce1850b7232305
scope.12.id=function:game_factory.build_board
scope.12.kind=function
scope.12.startLine=130
scope.12.endLine=132
scope.12.semanticHash=f1ce1850b7232305
scope.13.id=function:game_factory.build_players
scope.13.kind=function
scope.13.startLine=134
scope.13.endLine=136
scope.13.semanticHash=f1ce1850b7232305
]]
