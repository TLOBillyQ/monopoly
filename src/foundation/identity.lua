local number_utils = require("src.foundation.number")

local role_id = {}

function role_id.normalize(value)
  if value == nil then
    return nil
  end
  local normalized = number_utils.to_integer(value)
  if normalized ~= nil then
    return normalized
  end
  local value_type = type(value)
  if value_type == "string" then
    return value
  end
  local ok, as_text = pcall(tostring, value)
  if ok and type(as_text) == "string" and as_text ~= "" then
    return as_text
  end
  return nil
end

function role_id.equals(left, right)
  local normalized_left = role_id.normalize(left)
  local normalized_right = role_id.normalize(right)
  if normalized_left == nil or normalized_right == nil then
    return false
  end
  return normalized_left == normalized_right
end

function role_id.read(map, key)
  if type(map) ~= "table" then
    return nil
  end
  local normalized = role_id.normalize(key)
  if normalized ~= nil then
    local value = map[normalized]
    if value ~= nil then
      return value
    end
    local text_key = tostring(normalized)
    value = map[text_key]
    if value ~= nil then
      return value
    end
  end
  if key ~= nil then
    local value = map[key]
    if value ~= nil then
      return value
    end
  end
  return nil
end

function role_id.write(map, key, value)
  if type(map) ~= "table" then
    return nil
  end
  local normalized = role_id.normalize(key)
  if normalized == nil then
    return nil
  end
  map[normalized] = value
  if type(normalized) ~= "string" then
    map[tostring(normalized)] = nil
  end
  return normalized
end

return role_id

--[[ mutate4lua-manifest
version=2
projectHash=9841be1d0a7ccf69
scope.0.id=chunk:src/foundation/identity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=74
scope.0.semanticHash=80ab0760fead21c3
scope.0.lastMutatedAt=2026-07-07T04:12:44Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:role_id.normalize:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=22
scope.1.semanticHash=4453ee020b8756fc
scope.1.lastMutatedAt=2026-07-07T04:12:44Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=14
scope.1.lastMutationKilled=14
scope.2.id=function:role_id.equals:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=31
scope.2.semanticHash=aa199046c8d6848a
scope.2.lastMutatedAt=2026-07-07T04:12:44Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=survived
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=6
scope.3.id=function:role_id.read:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=56
scope.3.semanticHash=2424f2afff834c70
scope.3.lastMutatedAt=2026-07-07T04:12:44Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=10
scope.4.id=function:role_id.write:58
scope.4.kind=function
scope.4.startLine=58
scope.4.endLine=71
scope.4.semanticHash=311189619395d29d
scope.4.lastMutatedAt=2026-07-07T04:12:44Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=9
scope.4.lastMutationKilled=9
]]
