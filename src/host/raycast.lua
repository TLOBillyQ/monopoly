local number_utils = require("src.foundation.lang.number")

local raycast = {}

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

local function _vec_new(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x, y, z)
  end
  return { x = x, y = y, z = z }
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

function raycast.resolve_hit_position(hit)
  if hit == nil then
    return nil
  end
  if type(hit) == "table" then
    if _vec_component(hit, "x", 1) ~= nil
        and _vec_component(hit, "y", 2) ~= nil
        and _vec_component(hit, "z", 3) ~= nil then
      return hit
    end
    for _, key in ipairs(_hit_pos_keys) do
      local maybe = hit[key]
      if type(maybe) == "table"
          and _vec_component(maybe, "x", 1) ~= nil
          and _vec_component(maybe, "y", 2) ~= nil
          and _vec_component(maybe, "z", 3) ~= nil then
        return maybe
      end
    end
  end
  return nil
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
