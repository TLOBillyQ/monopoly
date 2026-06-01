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
  return unit
end

local function _apply_model(unit, creature_key)
  local set_model = unit and unit.set_model_by_creature_key
  if type(set_model) ~= "function" then
    return false
  end
  return pcall(set_model, creature_key, true, true, true)
      or pcall(set_model, unit, creature_key, true, true, true)
      or pcall(set_model, creature_key)
      or pcall(set_model, unit, creature_key)
end

local function _apply_reset_model(unit)
  local reset_model = unit.reset_model
  return pcall(reset_model) or pcall(reset_model, unit)
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
  local unit = _resolve_unit(role_id)
  if unit == nil then
    return false
  end
  if type(unit.reset_model) == "function" then
    local ok_reset = _apply_reset_model(unit)
    if ok_reset then
      return true
    end
    logger.warn("skin_equip: reset_model failed for player " .. tostring(role_id))
  end
  if default_creature_key == nil then
    logger.warn("skin_equip: missing default creature_key fallback for player " .. tostring(role_id))
    return false
  end
  local ok_change = _apply_model(unit, default_creature_key)
  if not ok_change then
    logger.warn("skin_equip: default creature fallback failed for player " .. tostring(role_id))
  end
  return ok_change == true
end

return skin_equip

--[[ mutate4lua-manifest
version=2
projectHash=1f3d95b349a428d4
scope.0.id=chunk:src/rules/cosmetics.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=76
scope.0.semanticHash=bbb82cf4fb61f06c
scope.0.lastMutatedAt=2026-05-31T13:13:09Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:_resolve_unit:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=18
scope.1.semanticHash=8c25d6ee24e79953
scope.1.lastMutatedAt=2026-05-31T13:13:09Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=10
scope.2.id=function:_apply_model:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=29
scope.2.semanticHash=20ebe19374510bb3
scope.2.lastMutatedAt=2026-05-31T13:13:09Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=12
scope.2.lastMutationKilled=12
scope.3.id=function:_apply_reset_model:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=34
scope.3.semanticHash=3168040b4b176ccd
scope.3.lastMutatedAt=2026-05-31T13:13:09Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:skin_equip.equip:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=50
scope.4.semanticHash=1fe6906a1b1a4776
scope.4.lastMutatedAt=2026-05-31T13:13:09Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=11
scope.4.lastMutationKilled=11
scope.5.id=function:skin_equip.unequip:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=73
scope.5.semanticHash=6477044f8ff611de
scope.5.lastMutatedAt=2026-05-31T13:13:09Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=17
scope.5.lastMutationKilled=17
]]
