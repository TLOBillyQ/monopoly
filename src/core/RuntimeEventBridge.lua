local logger = require("src.core.Logger")

local runtime_event_bridge = {}

local disabled_features = {}
local warned_features = {}

local upvalue_scan_limit = 128

local function _warn_feature_once(feature_key, reason)
  if warned_features[feature_key] then
    return
  end
  warned_features[feature_key] = true
  logger.warn(
    "[Eggy]",
    "custom event feature disabled:",
    tostring(feature_key),
    tostring(reason)
  )
end

local function _disable_feature(feature_key, reason)
  if disabled_features[feature_key] == true then
    return
  end
  disabled_features[feature_key] = true
  _warn_feature_once(feature_key, reason)
end

local function _resolve_trigger_available()
  if type(TriggerCustomEvent) ~= "function" then
    return false, "TriggerCustomEvent is not function"
  end
  if not (debug and type(debug.getupvalue) == "function") then
    -- Zero-error-first strategy: no safe precheck capability means do not attempt.
    return false, "debug.getupvalue unavailable"
  end

  local name = nil
  local newenv = nil
  for i = 1, upvalue_scan_limit do
    local upvalue_name, upvalue_value = debug.getupvalue(TriggerCustomEvent, i)
    if upvalue_name == nil then
      break
    end
    if upvalue_name == "name" and type(upvalue_value) == "string" then
      name = upvalue_value
    elseif upvalue_name == "newenv" and type(upvalue_value) == "table" then
      newenv = upvalue_value
    end
  end

  if name ~= nil and newenv ~= nil and newenv[name] == nil then
    return false, "unbound runtime function: " .. tostring(name)
  end

  return true, nil
end

function runtime_event_bridge.is_trigger_available()
  local available = _resolve_trigger_available()
  return available
end

function runtime_event_bridge.emit_custom_event(event_name, payload, opts)
  opts = opts or {}
  local feature_key = opts.feature_key or event_name or "__anonymous__"
  if disabled_features[feature_key] == true then
    return false
  end
  if event_name == nil then
    _disable_feature(feature_key, "missing event_name")
    return false
  end

  local available, reason = _resolve_trigger_available()
  if not available then
    _warn_feature_once(feature_key, "precheck failed: " .. tostring(reason))
    return false
  end

  local ok, err = pcall(TriggerCustomEvent, event_name, payload or {})
  if not ok then
    _disable_feature(feature_key, "dispatch failed: " .. tostring(err))
    return false
  end
  return true
end

function runtime_event_bridge._reset_for_tests()
  disabled_features = {}
  warned_features = {}
end

return runtime_event_bridge
