local logger = require("src.core.utils.logger")
local runtime_constants = require("src.core.config.runtime_constants")
local role_id_utils = require("src.core.utils.role_id")

local synthetic_actor_registry = {}

local function _zero_pos()
  if math and math.Vector3 then
    return math.Vector3(0.0, 0.0, 0.0)
  end
  return { x = 0.0, y = 0.0, z = 0.0 }
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

local function _resolve_actor_unit(actor)
  if actor == nil then
    return nil
  end
  return actor.unit
end

local function _destroy_actor(env, actor)
  local destroy_unit = _resolve_destroy_unit(env and env.GameAPI or nil)
  local unit = _resolve_actor_unit(actor)
  if destroy_unit == nil or unit == nil then
    return
  end
  pcall(destroy_unit, unit)
end

local function _build_adapter(actor)
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
    lose = function()
      return false
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
  local ok_spawn, unit = pcall(
    game_api.create_creature_fixed_scale,
    spec.unit_key,
    spawn_pos,
    runtime_constants.q_zero,
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
  actor.adapter = _build_adapter(actor)
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
      _destroy_actor(registry.env, actor)
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
