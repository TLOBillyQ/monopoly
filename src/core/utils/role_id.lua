local number_utils = require("src.core.utils.number_utils")

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
