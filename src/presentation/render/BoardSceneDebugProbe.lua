local M = {}
local DEFAULT_SOURCE_UNIT_NAME = "角色形象-海绵宝宝"

local UNIT_TYPE_NAMES = {
  [4] = "CREATURE",
  [8] = "CUSTOMTRIGGERSPACE",
  [128] = "CHARACTER",
  [256] = "OBSTACLE",
  [512] = "TRIGGERSPACE",
  [1024] = "DECORATION",
}

local function _resolve_source_unit_name(opts)
  if type(opts) == "table" and type(opts.source_unit_name) == "string" and opts.source_unit_name ~= "" then
    return opts.source_unit_name
  end
  return DEFAULT_SOURCE_UNIT_NAME
end

local function _query_source_unit(unit_name)
  if type(LuaAPI) ~= "table" or type(LuaAPI.query_unit) ~= "function" then
    print("[BoardSceneProbe] missing LuaAPI.query_unit")
    return nil
  end

  local ok, unit = pcall(LuaAPI.query_unit, unit_name)
  if not ok then
    print("[BoardSceneProbe] query source unit failed:", tostring(unit_name), tostring(unit))
    return nil
  end
  if unit == nil then
    print("[BoardSceneProbe] source unit not found:", tostring(unit_name))
    return nil
  end
  return unit
end

local function _resolve_unit_type_name(unit)
  local unit_type = nil
  if type(unit.get_unit_type) == "function" then
    local ok, value = pcall(unit.get_unit_type, unit)
    if ok then
      unit_type = value
    end
  end
  return unit_type, UNIT_TYPE_NAMES[unit_type] or "UNKNOWN"
end

local function _is_valid_source_creature(unit)
  local unit_type = nil
  if type(unit.get_unit_type) == "function" then
    local ok_type, resolved_type = pcall(unit.get_unit_type, unit)
    if ok_type then
      unit_type = resolved_type
    end
  end
  if unit_type ~= nil and unit_type ~= 4 then
    print("[BoardSceneProbe] source unit is not CREATURE:", tostring(unit_type))
    return false
  end

  if type(unit.is_creature) == "function" then
    local ok_is, is_creature = pcall(unit.is_creature, unit)
    if ok_is and is_creature ~= true then
      print("[BoardSceneProbe] source unit is_creature() is false")
      return false
    end
  end
  return true
end

function M.probe_named_unit(unit_name)
  if type(unit_name) ~= "string" or unit_name == "" then
    print("[BoardSceneProbe] invalid unit name")
    return
  end

  if type(LuaAPI) ~= "table" or type(LuaAPI.query_unit) ~= "function" then
    print("[BoardSceneProbe] missing LuaAPI.query_unit")
    return
  end

  local unit = LuaAPI.query_unit(unit_name)
  if unit == nil then
    print("[BoardSceneProbe] target=", unit_name, "not found")
    return
  end

  local unit_id = nil
  if type(LuaAPI.get_unit_id) == "function" then
    local ok_unit_id, value = pcall(LuaAPI.get_unit_id, unit)
    if ok_unit_id then
      unit_id = value
    end
  end
  local unit_type, unit_type_name = _resolve_unit_type_name(unit)

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

function M.apply_startup_player_models(units_by_player_id, opts)
  if type(units_by_player_id) ~= "table" then
    print("[BoardSceneProbe] apply startup model skipped: invalid units_by_player_id")
    return
  end

  local source_unit_name = _resolve_source_unit_name(opts)
  local source_creature = _query_source_unit(source_unit_name)
  if source_creature == nil then
    return
  end
  if not _is_valid_source_creature(source_creature) then
    return
  end

  local source_type, source_type_name = _resolve_unit_type_name(source_creature)
  local success_count = 0
  local failed_count = 0
  local skipped_count = 0

  for player_id, unit in pairs(units_by_player_id) do
    if unit == nil then
      skipped_count = skipped_count + 1
      print("[BoardSceneProbe] player unit missing:", tostring(player_id))
    elseif type(unit.set_model_by_creature) ~= "function" then
      failed_count = failed_count + 1
      print("[BoardSceneProbe] player unit missing set_model_by_creature:", tostring(player_id))
    else
      local ok, err = pcall(unit.set_model_by_creature, unit, source_creature, true, false, false)
      if ok then
        success_count = success_count + 1
      else
        failed_count = failed_count + 1
        print("[BoardSceneProbe] set_model_by_creature failed:", tostring(player_id), tostring(err))
      end
    end
  end

  print(
    "[BoardSceneProbe] startup player model apply",
    "source=",
    tostring(source_unit_name),
    "type=",
    tostring(source_type),
    "(" .. source_type_name .. ")",
    "success=",
    tostring(success_count),
    "failed=",
    tostring(failed_count),
    "skipped=",
    tostring(skipped_count)
  )
end

return M
