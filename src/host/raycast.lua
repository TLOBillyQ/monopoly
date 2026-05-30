local number_utils = require("src.foundation.number")
local host_types = require("src.foundation.host_types")

local raycast = {}

local _vec_new = host_types.vec3

local function _vec_component(vec, key, index)
  if type(vec) ~= "table" then
    return nil
  end
  local value = vec[key]
  if value ~= nil then
    return value
  end
  return vec[index]
end

local function _native_add(a, b)
  return a + b
end

local function _vec_add(a, b)
  local ok, added = pcall(_native_add, a, b)
  if ok and added ~= nil then
    return added
  end
  return _vec_new(
    (_vec_component(a, "x", 1) or 0) + (_vec_component(b, "x", 1) or 0),
    (_vec_component(a, "y", 2) or 0) + (_vec_component(b, "y", 2) or 0),
    (_vec_component(a, "z", 3) or 0) + (_vec_component(b, "z", 3) or 0)
  )
end

local function _native_mul(a, b)
  return a * b
end

local function _vec_scale(vec, factor)
  local ok, scaled = pcall(_native_mul, vec, factor)
  if ok and scaled ~= nil then
    return scaled
  end
  return _vec_new(
    (_vec_component(vec, "x", 1) or 0) * factor,
    (_vec_component(vec, "y", 2) or 0) * factor,
    (_vec_component(vec, "z", 3) or 0) * factor
  )
end

local function _call_method(target, name)
  if type(target) ~= "table" then
    return nil
  end
  local fn = target[name]
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, target)
  if ok then
    return value
  end
  return nil
end

local function _resolve_cfg_number(cfg, key, fallback)
  local value = cfg and cfg[key] or nil
  if number_utils.is_numeric(value) then
    return value
  end
  return fallback
end

local _hit_pos_keys = { "hit_pos", "hit_point", "point", "position", "pos" }

local _role_camera_getters = {
  "get_camera_dir",
  "get_camera_direction",
  "get_view_dir",
  "get_look_dir",
  "get_forward",
}
local _unit_camera_getters = {
  "get_camera_dir",
  "get_camera_direction",
  "get_forward",
}

local function _resolve_camera_dir(role, ctrl_unit)
  for _, getter in ipairs(_role_camera_getters) do
    local vec = _call_method(role, getter)
    if vec ~= nil then
      return vec
    end
  end
  for _, getter in ipairs(_unit_camera_getters) do
    local vec = _call_method(ctrl_unit, getter)
    if vec ~= nil then
      return vec
    end
  end
  return nil
end

function raycast.build_camera_ray(role, cfg)
  if type(role) ~= "table" then
    return nil, "missing role"
  end
  local get_ctrl_unit = role.get_ctrl_unit
  if type(get_ctrl_unit) ~= "function" then
    return nil, "missing role.get_ctrl_unit"
  end
  local ok, ctrl_unit = pcall(get_ctrl_unit)
  if not ok or ctrl_unit == nil then
    return nil, "missing ctrl_unit"
  end
  local get_position = ctrl_unit.get_position
  if type(get_position) ~= "function" then
    return nil, "missing ctrl_unit.get_position"
  end
  local ok_pos, ctrl_pos = pcall(get_position, ctrl_unit)
  if not ok_pos or ctrl_pos == nil then
    return nil, "missing ctrl_pos"
  end

  local eye_offset_y = _resolve_cfg_number(cfg, "eye_offset_y", 1.5)
  local ray_distance = _resolve_cfg_number(cfg, "ray_distance", 24.0)
  local start_pos = _vec_add(ctrl_pos, _vec_new(0, eye_offset_y, 0))
  local dir = _resolve_camera_dir(role, ctrl_unit)
  if dir == nil then
    return nil, "missing camera dir"
  end
  local end_pos = _vec_add(start_pos, _vec_scale(dir, ray_distance))
  return {
    start_pos = start_pos,
    end_pos = end_pos,
    direction = dir,
    ctrl_unit = ctrl_unit,
  }
end

local function _resolve_hit_unit(hit)
  if hit == nil then
    return nil
  end
  if type(hit) ~= "table" then
    return hit
  end
  if hit.unit ~= nil then
    return hit.unit
  end
  if hit.hit_unit ~= nil then
    return hit.hit_unit
  end
  if hit.obstacle ~= nil then
    return hit.obstacle
  end
  if hit[1] ~= nil and type(hit[1]) ~= "boolean" then
    return hit[1]
  end
  return nil
end

local function _is_vec3(t)
  return _vec_component(t, "x", 1) ~= nil
      and _vec_component(t, "y", 2) ~= nil
      and _vec_component(t, "z", 3) ~= nil
end

local function _find_vec3_in_hit(hit)
  for _, key in ipairs(_hit_pos_keys) do
    local maybe = hit[key]
    if type(maybe) == "table" and _is_vec3(maybe) then
      return maybe
    end
  end
  return nil
end

function raycast.resolve_hit_position(hit)
  if type(hit) ~= "table" then return nil end
  if _is_vec3(hit) then return hit end
  return _find_vec3_in_hit(hit)
end

local function _pick_with(api_name, start_pos, end_pos, cfg)
  if not (GameAPI and type(GameAPI[api_name]) == "function") then
    return nil
  end
  local ok, hit = pcall(GameAPI[api_name], start_pos, end_pos, cfg)
  if not ok then
    return nil
  end
  local unit = _resolve_hit_unit(hit)
  if unit == nil then
    return nil
  end
  return {
    unit = unit,
    hit = hit,
    hit_pos = raycast.resolve_hit_position(hit),
    source = api_name,
  }
end

function raycast.pick_first_hit_unit(start_pos, end_pos, cfg)
  if start_pos == nil or end_pos == nil then
    return nil, "missing ray points"
  end

  local hit = _pick_with("raycast_unit", start_pos, end_pos, cfg)
  if hit ~= nil then
    return hit
  end
  hit = _pick_with("get_obstacle_by_raycast", start_pos, end_pos, cfg)
  if hit ~= nil then
    return hit
  end
  hit = _pick_with("get_first_customtriggerspace_in_raycast", start_pos, end_pos, cfg)
  if hit ~= nil then
    return hit
  end

  return nil, "missing raycast api"
end

function raycast.get_unit_id(unit)
  if unit == nil then
    return nil
  end
  if LuaAPI and type(LuaAPI.get_unit_id) == "function" then
    local ok, unit_id = pcall(LuaAPI.get_unit_id, unit)
    if ok then
      return unit_id
    end
  end
  local get_unit_id = type(unit) == "table" and unit.get_unit_id or nil
  if type(get_unit_id) == "function" then
    local ok, unit_id = pcall(get_unit_id, unit)
    if ok then
      return unit_id
    end
  end
  return nil
end

return raycast

--[[ mutate4lua-manifest
version=2
projectHash=fa2254d4f0447efe
scope.0.id=chunk:src/host/raycast.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=248
scope.0.semanticHash=d7a89d38f4bc5965
scope.1.id=function:_vec_component:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=17
scope.1.semanticHash=ab7ac5d0c6b6c928
scope.2.id=function:_native_add:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=216841ec3bc3eafc
scope.3.id=function:_vec_add:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=33
scope.3.semanticHash=7899e8a2280c0c66
scope.4.id=function:_native_mul:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=37
scope.4.semanticHash=ec30b0d20fcd1e7c
scope.5.id=function:_vec_scale:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=49
scope.5.semanticHash=cf144f07825a494e
scope.6.id=function:_call_method:51
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=64
scope.6.semanticHash=af9d09278cc05009
scope.7.id=function:_resolve_cfg_number:66
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=72
scope.7.semanticHash=410117c8f921751c
scope.8.id=function:raycast.build_camera_ray:105
scope.8.kind=function
scope.8.startLine=105
scope.8.endLine=140
scope.8.semanticHash=41b8e1af38e388f9
scope.9.id=function:_resolve_hit_unit:142
scope.9.kind=function
scope.9.startLine=142
scope.9.endLine=162
scope.9.semanticHash=8b34c55a975f970d
scope.10.id=function:_is_vec3:164
scope.10.kind=function
scope.10.startLine=164
scope.10.endLine=168
scope.10.semanticHash=b79cfc229f33ae71
scope.11.id=function:raycast.resolve_hit_position:180
scope.11.kind=function
scope.11.startLine=180
scope.11.endLine=184
scope.11.semanticHash=6a004c73bd9e898f
scope.12.id=function:_pick_with:186
scope.12.kind=function
scope.12.startLine=186
scope.12.endLine=204
scope.12.semanticHash=95aefda521ec5bb6
scope.13.id=function:raycast.pick_first_hit_unit:206
scope.13.kind=function
scope.13.startLine=206
scope.13.endLine=225
scope.13.semanticHash=9ac71b90a0f48b3f
scope.14.id=function:raycast.get_unit_id:227
scope.14.kind=function
scope.14.startLine=227
scope.14.endLine=245
scope.14.semanticHash=b536b4a4f6960b1e
]]
