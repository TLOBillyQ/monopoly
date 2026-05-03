local number_utils = {}

local _tointeger = math and math.tointeger
local _numeric_type_names = {
  number = true,
  integer = true,
  fixed = true,
}

local function _is_numeric_type_name(value_type)
  return _numeric_type_names[value_type] == true
end

local function _to_integer_safe(value)
  if value == nil then
    return nil
  end
  if _tointeger then
    local ok, as_int = pcall(_tointeger, value)
    if ok and as_int ~= nil then
      return as_int
    end
  end
  if math and math.floor then
    local ok, floored = pcall(math.floor, value)
    if ok and floored ~= nil then
      return floored
    end
  end
  return nil
end

local function _truncate_number(value)
  if not number_utils.is_numeric(value) then
    return nil
  end
  return _to_integer_safe(value)
end

local function _parse_integer_string(value)
  if value == nil then
    return nil
  end
  if not string.match(value, "^-?%d+$") then
    return nil
  end
  local len = #value
  if len == 0 then
    return nil
  end
  local i = 1
  local sign = 1
  if string.sub(value, 1, 1) == "-" then
    sign = -1
    i = 2
    if i > len then
      return nil
    end
  end
  local num = 0
  for idx = i, len do
    local byte = string.byte(value, idx)
    local digit = byte - 48
    if digit < 0 or digit > 9 then
      return nil
    end
    num = num * 10 + digit
  end
  if _tointeger then
    return _tointeger(sign * num)
  end
  return sign * num
end

function number_utils.is_numeric(value)
  local value_type = type(value)
  if value_type == "nil" then
    return false
  end
  if _is_numeric_type_name(value_type) then
    return true
  end
  if value_type == "string" then
    return false
  end
  return _to_integer_safe(value) ~= nil
end

function number_utils.to_integer(value)
  local value_type = type(value)
  if value_type == "string" then
    local parsed = _parse_integer_string(value)
    if parsed ~= nil then
      return parsed
    end
    return nil
  end
  if number_utils.is_numeric(value) then
    local parsed = _to_integer_safe(value)
    if parsed ~= nil then
      return parsed
    end
  end
  if value ~= nil then
    local ok, as_text = pcall(tostring, value)
    if ok and type(as_text) == "string" then
      local parsed = _parse_integer_string(as_text)
      if parsed ~= nil then
        return parsed
      end
    end
  end
  return nil
end

function number_utils.clamp(value, min, max)
  if value == nil or value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
end

function number_utils.format_integer_part(value)
  local truncated = _truncate_number(value)
  if truncated ~= nil then
    local as_int = _to_integer_safe(truncated) or truncated
    return string.format("%d", as_int)
  end
  return tostring(value)
end

return number_utils
