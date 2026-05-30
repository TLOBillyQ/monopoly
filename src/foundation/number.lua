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

local function _parse_integer_string(value)
  if value == nil then
    return nil
  end
  if not string.match(value, "^-?%d+$") then
    return nil
  end
  local len = #value
  local i = 1
  local sign = 1
  if string.sub(value, 1, 1) == "-" then
    sign = -1
    i = 2
  end
  local num = 0
  for idx = i, len do
    local digit = string.byte(value, idx) - 48
    num = num * 10 + digit
  end
  if _tointeger then
    return _tointeger(sign * num)
  end
  return sign * num
end

function number_utils.to_integer(value)
  local value_type = type(value)
  if value_type == "string" then
    return _parse_integer_string(value)
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
version=2
projectHash=fa3e45a109ecc7fd
scope.0.id=chunk:src/foundation/number.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=142
scope.0.semanticHash=00498cb1ffa2b61f
scope.1.id=function:_is_numeric_type_name:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=b2607573a365264f
scope.2.id=function:_to_integer_safe:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=31
scope.2.semanticHash=57538734b8e428a6
scope.3.id=function:_truncate_number:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=38
scope.3.semanticHash=a530d6fdc1557140
scope.4.id=function:number_utils.is_numeric:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=52
scope.4.semanticHash=fb4078954280596a
scope.5.id=function:number_utils.to_integer:79
scope.5.kind=function
scope.5.startLine=79
scope.5.endLine=100
scope.5.semanticHash=063d86f2249d7758
scope.6.id=function:number_utils.clamp:102
scope.6.kind=function
scope.6.startLine=102
scope.6.endLine=110
scope.6.semanticHash=5f4f0d32f23f78e0
scope.7.id=function:number_utils.page_count:112
scope.7.kind=function
scope.7.startLine=112
scope.7.endLine=114
scope.7.semanticHash=d9cca50fb5a641ca
scope.8.id=function:number_utils.format_integer_part:116
scope.8.kind=function
scope.8.startLine=116
scope.8.endLine=122
scope.8.semanticHash=09a1f80810356ec9
scope.9.id=function:number_utils.resolve_numeric:124
scope.9.kind=function
scope.9.startLine=124
scope.9.endLine=132
scope.9.semanticHash=a330381e5dd3bbe4
scope.10.id=function:number_utils.diff_or_zero:134
scope.10.kind=function
scope.10.startLine=134
scope.10.endLine=139
scope.10.semanticHash=7d6ab5a510425aae
]]
