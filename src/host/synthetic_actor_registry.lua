local logger = require("src.foundation.log")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local role_id_utils = require("src.foundation.identity")
local host_types = require("src.foundation.host_types")

local synthetic_actor_registry = {}

local function _zero_pos()
  return host_types.vec3(0.0, 0.0, 0.0)
end

local function _resolve_start_tile_id(map_cfg)
  local path = map_cfg and map_cfg.path or nil
  if type(path) ~= "table" then
    return nil
  end
  return path[1]
end

local function _query_start_tile_unit(lua_api, start_tile_id)
  if not (lua_api and type(lua_api.query_unit) == "function" and start_tile_id ~= nil) then
    return nil
  end
  local ok_unit, tile_unit = pcall(lua_api.query_unit, "t" .. tostring(start_tile_id))
  if ok_unit then
    return tile_unit
  end
  return nil
end

local function _query_tile_position(tile_unit)
  if not (tile_unit and type(tile_unit.get_position) == "function") then
    return nil
  end
  local ok_pos, pos = pcall(tile_unit.get_position)
  if ok_pos then
    return pos
  end
  return nil
end

local function _safe_query_start_pos(env, map_cfg)
  local lua_api = env and env.LuaAPI or nil
  local start_tile_id = _resolve_start_tile_id(map_cfg)
  local tile_unit = _query_start_tile_unit(lua_api, start_tile_id)
  local pos = _query_tile_position(tile_unit)
  if pos == nil then
    return _zero_pos()
  end
  return pos
end

local function _resolve_destroy_unit(game_api)
  if game_api and type(game_api.destroy_unit) == "function" then
    return game_api.destroy_unit
  end
  return nil
end

local function _destroy_actor(env, actor)
  local destroy_unit = _resolve_destroy_unit(env and env.GameAPI or nil)
  local unit = actor and actor.unit or nil
  if destroy_unit == nil or unit == nil then
    return
  end
  pcall(destroy_unit, unit)
end

local function _retire_actor(registry, actor)
  if actor == nil or actor.destroyed == true then
    return false
  end
  actor.destroyed = true
  _destroy_actor(registry.env, actor)
  role_id_utils.write(registry.actors_by_player_id, actor.player_id, nil)
  return true
end

local function _build_adapter(registry, actor)
  return {
    id = actor.player_id,
    is_synthetic_actor = true,
    get_roleid = function()
      return actor.player_id
    end,
    get_name = function()
      return actor.name
    end,
    get_ctrl_unit = function()
      return actor.unit
    end,
    get_head_icon = function()
      return actor.avatar_image_key
    end,
    send_ui_custom_event = function()
      return false
    end,
    die = function()
      return _retire_actor(registry, actor)
    end,
    lose = function()
      return _retire_actor(registry, actor)
    end,
    game_win_and_show_result_panel = function()
      return false
    end,
  }
end

local function _normalize_pending_spec(spec)
  return {
    player_id = role_id_utils.normalize(spec and spec.player_id),
    name = spec and spec.name or nil,
    unit_key = spec and spec.unit_key or nil,
    avatar_image_key = spec and spec.avatar_image_key or nil,
  }
end

local function _spawn_actor(registry, spec, spawn_pos)
  local game_api = registry.env and registry.env.GameAPI or nil
  local player_id = role_id_utils.normalize(spec.player_id)
  assert(player_id ~= nil, "missing synthetic player_id")
  assert(spec.unit_key ~= nil, "missing synthetic unit_key")
  assert(game_api and type(game_api.create_creature_fixed_scale) == "function",
    "missing GameAPI.create_creature_fixed_scale")
  local ok_spawn, unit = pcall(
    game_api.create_creature_fixed_scale,
    spec.unit_key,
    spawn_pos,
    runtime_constants.q_left,
    1.0,
    nil
  )
  assert(ok_spawn and unit ~= nil, "failed to spawn synthetic actor: " .. tostring(player_id))
  local actor = {
    player_id = player_id,
    name = spec.name or ("AI" .. tostring(player_id)),
    unit = unit,
    unit_key = spec.unit_key,
    avatar_image_key = spec.avatar_image_key,
  }
  actor.adapter = _build_adapter(registry, actor)
  role_id_utils.write(registry.actors_by_player_id, player_id, actor)
  if type(unit.start_ai) == "function" then
    local ok_start, err = pcall(unit.start_ai)
    if not ok_start then
      logger.warn("[Eggy]", "synthetic actor start_ai failed", tostring(player_id), tostring(err))
    end
    return
  end
  logger.warn("[Eggy]", "synthetic actor missing start_ai", tostring(player_id), tostring(spec.unit_key))
end

function synthetic_actor_registry.new(env)
  local registry = {
    env = env or {},
    pending_specs = {},
    actors_by_player_id = {},
  }

  function registry.reset()
    for _, actor in pairs(registry.actors_by_player_id) do
      if actor.destroyed ~= true then
        actor.destroyed = true
        _destroy_actor(registry.env, actor)
      end
    end
    registry.pending_specs = {}
    registry.actors_by_player_id = {}
  end

  function registry.register_specs(specs)
    registry.reset()
    if type(specs) ~= "table" then
      return
    end
    for _, spec in ipairs(specs) do
      registry.pending_specs[#registry.pending_specs + 1] = _normalize_pending_spec(spec)
    end
  end

  function registry.resolve_actor(player_id)
    return role_id_utils.read(registry.actors_by_player_id, player_id)
  end

  function registry.spawn_pending(map_cfg)
    if #registry.pending_specs == 0 then
      return
    end
    local game_api = registry.env and registry.env.GameAPI or nil
    assert(game_api and type(game_api.create_creature_fixed_scale) == "function",
      "missing GameAPI.create_creature_fixed_scale")
    local spawn_pos = _safe_query_start_pos(registry.env, map_cfg)
    for _, spec in ipairs(registry.pending_specs) do
      _spawn_actor(registry, spec, spawn_pos)
    end
  end

  return registry
end

return synthetic_actor_registry

--[[ mutate4lua-manifest
version=2
projectHash=9b6661f7e72ddab3
scope.0.id=chunk:src/host/synthetic_actor_registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=203
scope.0.semanticHash=8e090a42bb78ac59
scope.1.id=function:_zero_pos:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=a7edb89590488197
scope.2.id=function:_resolve_start_tile_id:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=18
scope.2.semanticHash=61365fe5d5d9d2b5
scope.3.id=function:_query_start_tile_unit:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=29
scope.3.semanticHash=b1b50b8dfebdd48f
scope.4.id=function:_query_tile_position:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=40
scope.4.semanticHash=c646ba983c985f60
scope.5.id=function:_safe_query_start_pos:42
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=51
scope.5.semanticHash=1056374c45a0f695
scope.6.id=function:_resolve_destroy_unit:53
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=58
scope.6.semanticHash=43f38c80f18f538a
scope.7.id=function:_destroy_actor:60
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=67
scope.7.semanticHash=5584d5c1aec918fc
scope.8.id=function:_retire_actor:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=77
scope.8.semanticHash=931ec0fe0759fff0
scope.9.id=function:anonymous@83:83
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=85
scope.9.semanticHash=f0fefe10f2e5c229
scope.10.id=function:anonymous@86:86
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=88
scope.10.semanticHash=faf0777316efaa3b
scope.11.id=function:anonymous@89:89
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=91
scope.11.semanticHash=7737d70e08f3c1f6
scope.12.id=function:anonymous@92:92
scope.12.kind=function
scope.12.startLine=92
scope.12.endLine=94
scope.12.semanticHash=ac58f6877c5668f7
scope.13.id=function:anonymous@95:95
scope.13.kind=function
scope.13.startLine=95
scope.13.endLine=97
scope.13.semanticHash=c168b2cdb12a737a
scope.14.id=function:anonymous@98:98
scope.14.kind=function
scope.14.startLine=98
scope.14.endLine=100
scope.14.semanticHash=ef6d45fe5f00b5cc
scope.15.id=function:anonymous@101:101
scope.15.kind=function
scope.15.startLine=101
scope.15.endLine=103
scope.15.semanticHash=ef6d45fe5f00b5cc
scope.16.id=function:anonymous@104:104
scope.16.kind=function
scope.16.startLine=104
scope.16.endLine=106
scope.16.semanticHash=c168b2cdb12a737a
scope.17.id=function:_build_adapter:79
scope.17.kind=function
scope.17.startLine=79
scope.17.endLine=108
scope.17.semanticHash=50e3baf86017b3f5
scope.18.id=function:_normalize_pending_spec:110
scope.18.kind=function
scope.18.startLine=110
scope.18.endLine=117
scope.18.semanticHash=6685bbc23258cdcc
scope.19.id=function:_spawn_actor:119
scope.19.kind=function
scope.19.startLine=119
scope.19.endLine=152
scope.19.semanticHash=13598c5af84c665b
scope.20.id=function:registry.resolve_actor:182
scope.20.kind=function
scope.20.startLine=182
scope.20.endLine=184
scope.20.semanticHash=985659740ef8bdf4
scope.21.id=function:registry.spawn_pending:186
scope.21.kind=function
scope.21.startLine=186
scope.21.endLine=200
scope.21.semanticHash=a2277f2ed0be5f0a
]]
