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

local function _game_api_of(env)
  return env and env.GameAPI or nil
end

local function _actor_unit(actor)
  return actor and actor.unit or nil
end

local function _destroy_actor(env, actor)
  local destroy_unit = _resolve_destroy_unit(_game_api_of(env))
  local unit = _actor_unit(actor)
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

local function _spec_field(spec, key)
  return spec and spec[key] or nil
end

local function _normalize_pending_spec(spec)
  return {
    player_id = role_id_utils.normalize(spec and spec.player_id),
    name = _spec_field(spec, "name"),
    unit_key = _spec_field(spec, "unit_key"),
    avatar_image_key = _spec_field(spec, "avatar_image_key"),
  }
end

local function _validate_spawn_preconditions(registry, spec)
  local game_api = registry.env and registry.env.GameAPI or nil
  local player_id = role_id_utils.normalize(spec.player_id)
  assert(player_id ~= nil, "missing synthetic player_id")
  assert(spec.unit_key ~= nil, "missing synthetic unit_key")
  assert(game_api and type(game_api.create_creature_fixed_scale) == "function",
    "missing GameAPI.create_creature_fixed_scale")
  return game_api, player_id
end

local function _spawn_unit(game_api, spec, spawn_pos, player_id)
  local ok_spawn, unit = pcall(
    game_api.create_creature_fixed_scale,
    spec.unit_key,
    spawn_pos,
    runtime_constants.q_left,
    1.0,
    nil
  )
  assert(ok_spawn and unit ~= nil, "failed to spawn synthetic actor: " .. tostring(player_id))
  return unit
end

local function _start_actor_ai(unit, player_id, unit_key)
  if type(unit.start_ai) == "function" then
    local ok_start, err = pcall(unit.start_ai)
    if not ok_start then
      logger.warn("[Eggy]", "synthetic actor start_ai failed", tostring(player_id), tostring(err))
    end
    return
  end
  logger.warn("[Eggy]", "synthetic actor missing start_ai", tostring(player_id), tostring(unit_key))
end

local function _spawn_actor(registry, spec, spawn_pos)
  local game_api, player_id = _validate_spawn_preconditions(registry, spec)
  local unit = _spawn_unit(game_api, spec, spawn_pos, player_id)
  local actor = {
    player_id = player_id,
    name = spec.name or ("AI" .. tostring(player_id)),
    unit = unit,
    unit_key = spec.unit_key,
    avatar_image_key = spec.avatar_image_key,
  }
  actor.adapter = _build_adapter(registry, actor)
  role_id_utils.write(registry.actors_by_player_id, player_id, actor)
  _start_actor_ai(unit, player_id, spec.unit_key)
end

function synthetic_actor_registry.new(env)
  local registry = {
    env = env or {},
    pending_specs = {},
    actors_by_player_id = {},
    -- 合成 AI 身份集合(#611):开局登记后只由 reset 清空,不随退役擦除。
    -- actors_by_player_id 在 die/lose 退役时删表项,因此不能兼任身份真源。
    synthetic_player_ids = {},
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
    registry.synthetic_player_ids = {}
  end

  function registry.register_specs(specs)
    registry.reset()
    if type(specs) ~= "table" then
      return
    end
    for _, spec in ipairs(specs) do
      local normalized = _normalize_pending_spec(spec)
      registry.pending_specs[#registry.pending_specs + 1] = normalized
      role_id_utils.write(registry.synthetic_player_ids, normalized.player_id, true)
    end
  end

  function registry.resolve_actor(player_id)
    return role_id_utils.read(registry.actors_by_player_id, player_id)
  end

  -- 「该 player 是合成 AI 吗」的唯一真源:据开局登记的 spec 回答,对已退役
  -- (resolve_actor 已返回 nil)的合成 AI 同样为真(#611)。
  function registry.is_synthetic_player(player_id)
    return role_id_utils.read(registry.synthetic_player_ids, player_id) == true
  end

  local function _registry_game_api(reg)
    return reg.env and reg.env.GameAPI or nil
  end

  local function _assert_spawn_api(game_api)
    assert(game_api and type(game_api.create_creature_fixed_scale) == "function",
      "missing GameAPI.create_creature_fixed_scale")
  end

  function registry.spawn_pending(map_cfg)
    if #registry.pending_specs == 0 then
      return
    end
    local game_api = _registry_game_api(registry)
    _assert_spawn_api(game_api)
    local spawn_pos = _safe_query_start_pos(registry.env, map_cfg)
    for _, spec in ipairs(registry.pending_specs) do
      _spawn_actor(registry, spec, spawn_pos)
    end
  end

  return registry
end

return synthetic_actor_registry

--[[ mutate4lua-manifest
version=4
projectHash=83596535517ca357
scope.0.id=chunk:src/host/synthetic_actor_registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=249
scope.0.semanticHash=691640ab00cee27d
scope.1.id=function:_zero_pos
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=0b0a2e4b16b982cf
scope.2.id=function:_resolve_start_tile_id
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=18
scope.2.semanticHash=e2345c5a56e3cc55
scope.3.id=function:_query_start_tile_unit
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=29
scope.3.semanticHash=4e91b78d8f026d21
scope.4.id=function:_query_tile_position
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=40
scope.4.semanticHash=f8a696538f32b5a1
scope.5.id=function:_safe_query_start_pos
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=51
scope.5.semanticHash=52e7fb6733cc7c07
scope.6.id=function:_resolve_destroy_unit
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=58
scope.6.semanticHash=027fadea6d7b6c90
scope.7.id=function:_game_api_of
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=62
scope.7.semanticHash=616a2ca60599c94f
scope.8.id=function:_actor_unit
scope.8.kind=function
scope.8.startLine=64
scope.8.endLine=66
scope.8.semanticHash=616a2ca60599c94f
scope.9.id=function:_destroy_actor
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=75
scope.9.semanticHash=6c660e10de6b82d0
scope.10.id=function:_retire_actor
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=85
scope.10.semanticHash=1c63fb626a81ee82
scope.11.id=function:_build_adapter
scope.11.kind=function
scope.11.startLine=87
scope.11.endLine=116
scope.11.semanticHash=28b814cecff76637
scope.12.id=function:<anonymous>
scope.12.kind=function
scope.12.startLine=91
scope.12.endLine=93
scope.12.semanticHash=24f2b9b574225623
scope.13.id=function:<anonymous>#2
scope.13.kind=function
scope.13.startLine=94
scope.13.endLine=96
scope.13.semanticHash=24f2b9b574225623
scope.14.id=function:<anonymous>#3
scope.14.kind=function
scope.14.startLine=97
scope.14.endLine=99
scope.14.semanticHash=24f2b9b574225623
scope.15.id=function:<anonymous>#4
scope.15.kind=function
scope.15.startLine=100
scope.15.endLine=102
scope.15.semanticHash=24f2b9b574225623
scope.16.id=function:<anonymous>#5
scope.16.kind=function
scope.16.startLine=103
scope.16.endLine=105
scope.16.semanticHash=22b57f529f3a8828
scope.17.id=function:<anonymous>#6
scope.17.kind=function
scope.17.startLine=106
scope.17.endLine=108
scope.17.semanticHash=5076d53a4090f1e9
scope.18.id=function:<anonymous>#7
scope.18.kind=function
scope.18.startLine=109
scope.18.endLine=111
scope.18.semanticHash=5076d53a4090f1e9
scope.19.id=function:<anonymous>#8
scope.19.kind=function
scope.19.startLine=112
scope.19.endLine=114
scope.19.semanticHash=22b57f529f3a8828
scope.20.id=function:_spec_field
scope.20.kind=function
scope.20.startLine=118
scope.20.endLine=120
scope.20.semanticHash=cd6b189045fad21d
scope.21.id=function:_normalize_pending_spec
scope.21.kind=function
scope.21.startLine=122
scope.21.endLine=129
scope.21.semanticHash=3c311891d1877e47
scope.22.id=function:_validate_spawn_preconditions
scope.22.kind=function
scope.22.startLine=131
scope.22.endLine=139
scope.22.semanticHash=02534c1bfa0d73fd
scope.23.id=function:_spawn_unit
scope.23.kind=function
scope.23.startLine=141
scope.23.endLine=152
scope.23.semanticHash=688e9b2b7ac2985d
scope.24.id=function:_start_actor_ai
scope.24.kind=function
scope.24.startLine=154
scope.24.endLine=163
scope.24.semanticHash=35f3f70be94ae782
scope.25.id=function:_spawn_actor
scope.25.kind=function
scope.25.startLine=165
scope.25.endLine=178
scope.25.semanticHash=bf821ee60a710fd5
scope.26.id=function:synthetic_actor_registry.new
scope.26.kind=function
scope.26.startLine=180
scope.26.endLine=246
scope.26.semanticHash=87ccd2c9e500e19a
scope.27.id=function:registry.reset
scope.27.kind=function
scope.27.startLine=190
scope.27.endLine=200
scope.27.semanticHash=79ec9f3f50bac0bb
scope.28.id=function:registry.register_specs
scope.28.kind=function
scope.28.startLine=202
scope.28.endLine=212
scope.28.semanticHash=a3eb9d77ad5ea509
scope.29.id=function:registry.resolve_actor
scope.29.kind=function
scope.29.startLine=214
scope.29.endLine=216
scope.29.semanticHash=233b0ba31339d60b
scope.30.id=function:registry.is_synthetic_player
scope.30.kind=function
scope.30.startLine=220
scope.30.endLine=222
scope.30.semanticHash=dcf482d886ff46f1
scope.31.id=function:_registry_game_api
scope.31.kind=function
scope.31.startLine=224
scope.31.endLine=226
scope.31.semanticHash=13ddff47d34fa2ed
scope.32.id=function:_assert_spawn_api
scope.32.kind=function
scope.32.startLine=228
scope.32.endLine=231
scope.32.semanticHash=95f58cfbf9d54adb
scope.33.id=function:registry.spawn_pending
scope.33.kind=function
scope.33.startLine=233
scope.33.endLine=243
scope.33.semanticHash=4a967193dab11252
]]
