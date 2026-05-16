local function _vec3(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x, y, z)
  end
  return { x = x, y = y, z = z }
end

local function _quat(x, y, z)
  if math and math.Quaternion then
    return math.Quaternion(x, y, z)
  end
  return { x = x, y = y, z = z }
end

local q_zero = _quat(0.0, 0.0, 0.0)

local runtime_constants = {
  v3_zero = _vec3(0.0, 0.0, 0.0),
  v3_one = _vec3(1.0, 1.0, 1.0),
  v3_cash_fx_head_offset = _vec3(0.0, 1.6, 0.0),
  v3_right = _vec3(0.0, 0.0, 1.0),
  v3_left = _vec3(0.0, 0.0, -1.0),

  q_zero = q_zero,
  q_left = _quat(0.0, -180.0, 0.0),

  walk_speed = 13.0,
  speed_boost_modifier_key = 100000,
  robot_speed = 18.0,

  fps = 30.0,

  entity_pool_max_idle = 8,
  entity_pool_park_pos = _vec3(0.0, -9999.0, 0.0),
}

return runtime_constants
