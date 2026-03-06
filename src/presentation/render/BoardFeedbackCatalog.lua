local runtime_refs = require("Config.RuntimeRefs")
local runtime_constants = require("src.core.config.RuntimeConstants")

local catalog = {}

local function _copy_table(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, nested in pairs(value) do
    out[key] = _copy_table(nested)
  end
  return out
end

local function _resolve_scale(value)
  if value == nil then
    return nil
  end
  if type(value) == "table" then
    return value
  end
  return value
end

local function _resolve_bind_offset(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    return runtime_constants[value]
  end
  return value
end

local function _resolve_cue(cue)
  local resolved = _copy_table(cue)
  if type(resolved) ~= "table" then
    return nil
  end
  resolved.scale = _resolve_scale(resolved.scale)
  resolved.bind_offset = _resolve_bind_offset(resolved.bind_offset)
  return resolved
end

function catalog.get(cue_name)
  if cue_name == nil then
    return nil
  end
  local cues = runtime_refs.board_feedback or {}
  return _resolve_cue(cues[cue_name])
end

return catalog
