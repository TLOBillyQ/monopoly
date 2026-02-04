local number_utils = {}

local _tointeger = math and math.tointeger
if not _tointeger then
  _tointeger = function(value)
    if type(value) ~= "number" then
      return nil
    end
    if math and math.floor then
      return math.floor(value)
    end
    return value
  end
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
  return _tointeger(sign * num)
end

function number_utils.to_integer(value)
  local value_type = type(value)
  if value_type == "number" then
    return _tointeger(value)
  end
  if value_type == "string" then
    return _parse_integer_string(value)
  end
  return nil
end

return number_utils
