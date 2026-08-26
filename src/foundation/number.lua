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

-- Returns nil when `convert` is absent or raises, so callers can chain fallbacks.
local function _try_convert(convert, value)
  if convert == nil then
    return nil
  end
  local ok, converted = pcall(convert, value)
  if ok and converted ~= nil then
    return converted
  end
  return nil
end

local function _to_integer_safe(value)
  if value == nil then
    return nil
  end
  local as_int = _try_convert(_tointeger, value)
  if as_int ~= nil then
    return as_int
  end
  return _try_convert(math and math.floor, value)
end

local function _truncate_number(value)
  if not number_utils.is_numeric(value) then
    return nil
  end
  return _to_integer_safe(value)
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

local function _digits_to_number(value, first_index)
  local num = 0
  for idx = first_index, #value do
    local digit = string.byte(value, idx) - 48
    num = num * 10 + digit
  end
  return num
end

local function _parse_integer_string(value)
  if value == nil then
    return nil
  end
  if not string.match(value, "^-?%d+$") then
    return nil
  end
  local sign = 1
  local first_index = 1
  if string.sub(value, 1, 1) == "-" then
    sign = -1
    first_index = 2
  end
  local num = sign * _digits_to_number(value, first_index)
  if _tointeger then
    return _tointeger(num)
  end
  return num
end

-- Last resort for host values (userdata/Fixed) that only reveal digits via tostring.
local function _parse_via_tostring(value)
  if value == nil then
    return nil
  end
  local ok, as_text = pcall(tostring, value)
  if ok and type(as_text) == "string" then
    return _parse_integer_string(as_text)
  end
  return nil
end

function number_utils.to_integer(value)
  if type(value) == "string" then
    return _parse_integer_string(value)
  end
  if number_utils.is_numeric(value) then
    local parsed = _to_integer_safe(value)
    if parsed ~= nil then
      return parsed
    end
  end
  return _parse_via_tostring(value)
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

function number_utils.page_count(item_count, page_size)
  return math.max(1, math.floor((item_count + page_size - 1) / page_size))
end

function number_utils.format_integer_part(value)
  local as_int = _truncate_number(value)
  if as_int ~= nil then
    return string.format("%d", as_int)
  end
  return tostring(value)
end

function number_utils.resolve_numeric(value, fallback)
  if number_utils.is_numeric(value) then
    return value + 0
  end
  if number_utils.is_numeric(fallback) then
    return fallback + 0
  end
  return nil
end

function number_utils.diff_or_zero(timestamp_1, timestamp_2)
  if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
    return timestamp_1 - timestamp_2
  end
  return 0
end

return number_utils

--[[ mutate4lua-manifest
version=4
projectHash=fa29012d4eefbe56
scope.0.id=chunk:src/foundation/number.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=152
scope.0.semanticHash=2f21d1fd790e8826
scope.1.id=function:_is_numeric_type_name
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=92047a25c743520b
scope.2.id=function:_try_convert
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=24
scope.2.semanticHash=ed52e9d8f3acd54a
scope.3.id=function:_to_integer_safe
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=35
scope.3.semanticHash=9dd65585008d305d
scope.4.id=function:_truncate_number
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=42
scope.4.semanticHash=ab52e8dc7a9badec
scope.5.id=function:number_utils.is_numeric
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=56
scope.5.semanticHash=c269e11b8f36e07d
scope.6.id=function:_digits_to_number
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=65
scope.6.semanticHash=5c9a4433e46e7eaa
scope.7.id=function:_parse_integer_string
scope.7.kind=function
scope.7.startLine=67
scope.7.endLine=85
scope.7.semanticHash=66c26278af1e1197
scope.8.id=function:_parse_via_tostring
scope.8.kind=function
scope.8.startLine=88
scope.8.endLine=97
scope.8.semanticHash=fefcc4bd12403d7e
scope.9.id=function:number_utils.to_integer
scope.9.kind=function
scope.9.startLine=99
scope.9.endLine=110
scope.9.semanticHash=e9672cf12aa8fa90
scope.10.id=function:number_utils.clamp
scope.10.kind=function
scope.10.startLine=112
scope.10.endLine=120
scope.10.semanticHash=929d0237675ad64a
scope.11.id=function:number_utils.page_count
scope.11.kind=function
scope.11.startLine=122
scope.11.endLine=124
scope.11.semanticHash=de509373d1faea86
scope.12.id=function:number_utils.format_integer_part
scope.12.kind=function
scope.12.startLine=126
scope.12.endLine=132
scope.12.semanticHash=396e7d2a071b6321
scope.13.id=function:number_utils.resolve_numeric
scope.13.kind=function
scope.13.startLine=134
scope.13.endLine=142
scope.13.semanticHash=d6fc6b239854b4dd
scope.14.id=function:number_utils.diff_or_zero
scope.14.kind=function
scope.14.startLine=144
scope.14.endLine=149
scope.14.semanticHash=0c0ba870b509e374
]]
