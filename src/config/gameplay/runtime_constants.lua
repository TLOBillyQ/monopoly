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
  v3_one = _vec3(1.0, 1.0, 1.0),
  v3_cash_fx_head_offset = _vec3(0.0, 1.6, 0.0),
  v3_left = _vec3(0.0, 0.0, -1.0),
  v3_right = _vec3(0.0, 0.0, 1.0),
  v3_up = _vec3(-1.0, 0.0, 0.0),
  v3_down = _vec3(1.0, 0.0, 0.0),

  q_zero = q_zero,
  q_left = _quat(0.0, -180.0, 0.0),
  q_right = q_zero,
  q_up = _quat(0.0, -90.0, 0.0),
  q_down = _quat(0.0, 90.0, 0.0),

  walk_speed = 7.0,
  robot_speed = 18.0,

  -- 仓库内未引用，暂保留兼容
  vehicle_speed = 20.0,
  vehicle_accel = 20.0,
  -- 默认关闭：载具移动降级为 set_position 逐格跳
  vehicle_move_api_enabled = false,
  vehicle_enter_delay = 1.2,
  fps = 30.0,
  forward_eca_event_ui = "ui_forward",

  eca_event = {
    vehicle = {
      enter = "enter_vehicle_forward",
      exit = "exit_vehicle_forward",
      move = "move_vehicle_forward",
      stop = "stop_vehicle_forward",
      set_position = "set_position_vehicle_forward",
    },
    skin = {
      change = "change_skin",
    },
  },
}

return runtime_constants
