local runtime_ports = require("src.foundation.ports.runtime_ports")
local logger = require("src.foundation.log")

local skin_equip = {}

local function _resolve_unit(role_id)
  local role = runtime_ports.resolve_role(role_id)
  if not (role and type(role.get_ctrl_unit) == "function") then
    logger.warn("skin_equip: no role found for player " .. tostring(role_id))
    return nil
  end
  local ok_unit, unit = pcall(role.get_ctrl_unit)
  if not ok_unit then
    logger.warn("skin_equip: role get_ctrl_unit failed for player " .. tostring(role_id))
    return nil
  end
  if not (unit and type(unit.set_model_by_creature_key) == "function") then
    logger.warn("skin_equip: unit missing set_model_by_creature_key for player " .. tostring(role_id))
    return nil
  end
  return unit
end

local function _apply_model(unit, creature_key)
  return pcall(unit.set_model_by_creature_key, creature_key, true, true, true)
      or pcall(unit.set_model_by_creature_key, unit, creature_key, true, true, true)
      or pcall(unit.set_model_by_creature_key, creature_key)
      or pcall(unit.set_model_by_creature_key, unit, creature_key)
end

function skin_equip.equip(role_id, creature_key)
  if creature_key == nil then
    logger.warn("skin_equip: missing creature_key for player " .. tostring(role_id))
    return false
  end
  local unit = _resolve_unit(role_id)
  if unit == nil then
    return false
  end
  local ok_change = _apply_model(unit, creature_key)
  if not ok_change then
    logger.warn("skin_equip: set_model_by_creature_key failed for player " .. tostring(role_id))
  end
  return ok_change == true
end

function skin_equip.unequip(role_id, default_creature_key)
  if default_creature_key == nil then
    logger.warn("skin_equip: missing default creature_key for player " .. tostring(role_id))
    return false
  end
  return skin_equip.equip(role_id, default_creature_key)
end

return skin_equip
