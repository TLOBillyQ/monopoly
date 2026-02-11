local number_utils = {}

local _tointeger = math and math.tointeger

local function _truncate_number(value)
  if type(value) ~= "number" then
    return nil
  end
  if _tointeger then
    local as_int = _tointeger(value)
    if as_int ~= nil then
      return as_int
    end
  end
  if math and math.floor then
    return math.floor(value)
  end
  return value
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

function number_utils.to_integer(value)
  local value_type = type(value)
  if value_type == "number" then
    if _tointeger then
      return _tointeger(value)
    end
    if math and math.floor and value == math.floor(value) then
      return value
    end
    return nil
  end
  if value_type == "string" then
    return _parse_integer_string(value)
  end
  return nil
end

function number_utils.format_integer_part(value)
  local value_type = type(value)
  local truncated = nil
  if value_type == "number" then
    truncated = _truncate_number(value)
  elseif value_type == "string" then
    local as_number = tonumber(value)
    if as_number ~= nil then
      truncated = _truncate_number(as_number)
    end
  end
  if truncated ~= nil then
    local as_int = _tointeger and _tointeger(truncated) or truncated
    return string.format("%d", as_int)
  end
  return tostring(value)
end

return number_utils
