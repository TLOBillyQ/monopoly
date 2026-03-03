local M = {}

local UNIT_TYPE_NAMES = {
  [4] = "CREATURE",
  [8] = "CUSTOMTRIGGERSPACE",
  [128] = "CHARACTER",
  [256] = "OBSTACLE",
  [512] = "TRIGGERSPACE",
  [1024] = "DECORATION",
}

function M.probe_named_unit(unit_name)
  if type(unit_name) ~= "string" or unit_name == "" then
    print("[BoardSceneProbe] invalid unit name")
    return
  end

  local unit = LuaAPI.query_unit(unit_name)
  if unit == nil then
    print("[BoardSceneProbe] target=", unit_name, "not found")
    return
  end

  local unit_id = LuaAPI.get_unit_id(unit)
  local unit_type = nil
  if type(unit.get_unit_type) == "function" then
    unit_type = unit.get_unit_type()
  end
  local unit_type_name = UNIT_TYPE_NAMES[unit_type] or "UNKNOWN"

  print(
    "[BoardSceneProbe]",
    "target=",
    unit_name,
    "id=",
    tostring(unit_id),
    "type=",
    tostring(unit_type),
    "(" .. unit_type_name .. ")"
  )
end

return M
