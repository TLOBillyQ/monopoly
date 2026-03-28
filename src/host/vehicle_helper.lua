local monopoly_event = require("src.core.events.monopoly_events")
local vehicle_feature = require("src.rules.vehicle")
local vehicle_catalog = require("src.config.gameplay.vehicle_catalog")

local vehicle_helper = {}
local _emit_event = monopoly_event.emit

local function _require_enabled()
  if not vehicle_feature.is_enabled() then
    return nil, "vehicle feature disabled"
  end
  return true
end

local function _require_param(value, name, action)
  if value == nil then
    return nil, action .. ": missing " .. name
  end
  return true
end

function vehicle_helper.create(opts)
  opts = opts or {}
  local ok, err = _require_enabled()
  if not ok then
    return nil, err
  end
  ok, err = _require_param(opts.vehicle_key, "vehicle_key", "create")
  if not ok then
    return nil, err
  end
  ok, err = _require_param(opts.position, "position", "create")
  if not ok then
    return nil, err
  end
  ok, err = _require_param(opts.direction, "direction", "create")
  if not ok then
    return nil, err
  end

  local success, vehicle = pcall(GameAPI.create_vehicle, opts.vehicle_key, opts.position, opts.direction, opts.role)
  if not success then
    return nil, "create_vehicle failed: " .. tostring(vehicle)
  end

  local catalog_entry = vehicle_catalog.find(opts.vehicle_key)
  _emit_event(monopoly_event.vehicle.created, {
    vehicle = vehicle,
    vehicle_key = opts.vehicle_key,
    name = catalog_entry and catalog_entry.name or tostring(opts.vehicle_key),
    position = opts.position,
    direction = opts.direction,
    role = opts.role,
  })

  return {
    vehicle = vehicle,
    vehicle_key = opts.vehicle_key,
  }
end

function vehicle_helper.copy(opts)
  opts = opts or {}
  local ok, err = _require_enabled()
  if not ok then
    return nil, err
  end
  ok, err = _require_param(opts.vehicle, "vehicle", "copy")
  if not ok then
    return nil, err
  end
  ok, err = _require_param(opts.position, "position", "copy")
  if not ok then
    return nil, err
  end
  ok, err = _require_param(opts.direction, "direction", "copy")
  if not ok then
    return nil, err
  end

  local success, copied = pcall(GameAPI.copy_vehicle, opts.vehicle, opts.position, opts.direction, opts.role)
  if not success then
    return nil, "copy_vehicle failed: " .. tostring(copied)
  end

  _emit_event(monopoly_event.vehicle.copied, {
    source_vehicle = opts.vehicle,
    vehicle = copied,
    position = opts.position,
    direction = opts.direction,
    role = opts.role,
  })

  return {
    vehicle = copied,
  }
end

function vehicle_helper.destroy(vehicle)
  local ok, err = _require_enabled()
  if not ok then
    return false, err
  end
  ok, err = _require_param(vehicle, "vehicle", "destroy")
  if not ok then
    return false, err
  end

  local success, call_err = pcall(GameAPI.delay_destroy_vehicle, vehicle)
  if not success then
    return false, "delay_destroy_vehicle failed: " .. tostring(call_err)
  end

  _emit_event(monopoly_event.vehicle.destroyed, {
    vehicle = vehicle,
  })

  return true
end

function vehicle_helper.get_driving_vehicle(character)
  local ok, err = _require_param(character, "character", "get_driving_vehicle")
  if not ok then
    return nil, err
  end

  local success, vehicle = pcall(GameAPI.get_driving_vehicle, character)
  if not success then
    return nil, "get_driving_vehicle failed: " .. tostring(vehicle)
  end

  return vehicle
end

function vehicle_helper.enter(life_entity, vehicle)
  local ok, err = _require_enabled()
  if not ok then
    return false, err
  end
  ok, err = _require_param(life_entity, "life_entity", "enter")
  if not ok then
    return false, err
  end
  ok, err = _require_param(vehicle, "vehicle", "enter")
  if not ok then
    return false, err
  end

  local success, call_err = pcall(life_entity.try_enter_vehicle, vehicle)
  if not success then
    return false, "try_enter_vehicle failed: " .. tostring(call_err)
  end

  _emit_event(monopoly_event.vehicle.entered, {
    life_entity = life_entity,
    vehicle = vehicle,
  })

  return true
end

function vehicle_helper.exit(life_entity)
  local ok, err = _require_enabled()
  if not ok then
    return false, err
  end
  ok, err = _require_param(life_entity, "life_entity", "exit")
  if not ok then
    return false, err
  end

  local success, call_err = pcall(life_entity.try_exit_vehicle)
  if not success then
    return false, "try_exit_vehicle failed: " .. tostring(call_err)
  end

  _emit_event(monopoly_event.vehicle.exited, {
    life_entity = life_entity,
  })

  return true
end

function vehicle_helper.move(vehicle, direction, duration)
  local ok, err = _require_enabled()
  if not ok then
    return false, err
  end
  ok, err = _require_param(vehicle, "vehicle", "move")
  if not ok then
    return false, err
  end
  ok, err = _require_param(direction, "direction", "move")
  if not ok then
    return false, err
  end
  ok, err = _require_param(duration, "duration", "move")
  if not ok then
    return false, err
  end

  local success, call_err = pcall(vehicle.start_move_by_direction, direction, duration)
  if not success then
    return false, "start_move_by_direction failed: " .. tostring(call_err)
  end

  _emit_event(monopoly_event.vehicle.moved, {
    vehicle = vehicle,
    direction = direction,
    duration = duration,
  })

  return true
end

function vehicle_helper.stop(vehicle)
  local ok, err = _require_enabled()
  if not ok then
    return false, err
  end
  ok, err = _require_param(vehicle, "vehicle", "stop")
  if not ok then
    return false, err
  end

  local success, call_err = pcall(vehicle.stop_move)
  if not success then
    return false, "stop_move failed: " .. tostring(call_err)
  end

  _emit_event(monopoly_event.vehicle.stopped, {
    vehicle = vehicle,
  })

  return true
end

function vehicle_helper.reset(vehicle)
  local ok, err = _require_enabled()
  if not ok then
    return false, err
  end
  ok, err = _require_param(vehicle, "vehicle", "reset")
  if not ok then
    return false, err
  end

  local success, call_err = pcall(vehicle.reset)
  if not success then
    return false, "reset failed: " .. tostring(call_err)
  end

  _emit_event(monopoly_event.vehicle.reset, {
    vehicle = vehicle,
  })

  return true
end

return vehicle_helper
