local runtime_constants = require("Config.RuntimeConstants")

local player_positioning = {}

local function _build_vector(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x, y, z)
  end
  return { x = x, y = y, z = z }
end

local function _resolve_ground_pos(scene, allow_missing)
  if scene == nil then
    if allow_missing then
      return nil
    end
    error("missing board_scene")
  end
  if scene.ground == nil then
    if allow_missing then
      return nil
    end
    error("missing board_scene.ground")
  end
  if scene.ground.get_position == nil then
    if allow_missing then
      return nil
    end
    error("missing board_scene.ground.get_position")
  end
  local ground_pos = scene.ground.get_position()
  if ground_pos == nil or ground_pos.y == nil then
    if allow_missing then
      return nil
    end
    error("missing ground position")
  end
  return ground_pos
end

function player_positioning.resolve_min_player_y(scene, opts)
  local allow_missing = opts and opts.allow_missing == true or false
  local ground_pos = _resolve_ground_pos(scene, allow_missing)
  if ground_pos == nil then
    return nil
  end
  local clearance = runtime_constants.player_ground_clearance
  if clearance == nil then
    clearance = 1.5
  end
  return ground_pos.y + clearance
end

function player_positioning.clamp_to_safe_player_pos(scene, pos)
  if pos == nil then
    return nil
  end
  if pos.x == nil or pos.y == nil or pos.z == nil then
    return pos
  end
  local min_player_y = player_positioning.resolve_min_player_y(scene, { allow_missing = true })
  if min_player_y == nil then
    return pos
  end
  if pos.y >= min_player_y then
    return pos
  end
  return _build_vector(pos.x, min_player_y, pos.z)
end

return player_positioning
