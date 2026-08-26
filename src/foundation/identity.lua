local number_utils = require("src.foundation.number")

local role_id = {}

local function _normalized_integer(value)
  return number_utils.to_integer(value)
end

local function _text_fallback(value)
  local ok, as_text = pcall(tostring, value)
  if ok and type(as_text) == "string" and as_text ~= "" then
    return as_text
  end
  return nil
end

function role_id.normalize(value)
  if value == nil then
    return nil
  end
  local normalized = _normalized_integer(value)
  if normalized ~= nil then
    return normalized
  end
  if type(value) == "string" then
    return value
  end
  return _text_fallback(value)
end

function role_id.equals(left, right)
  -- 直接比较规范化值：nil == non-nil 在 Lua 中恒为 false（等价于显式 nil 守卫），
  -- nil == nil 为 true（两个未知身份视为同一身份）。无需显式 nil guard。
  return role_id.normalize(left) == role_id.normalize(right)
end

-- Looks the normalized id up both as-is and as text, since maps may be keyed either way.
local function _read_normalized(map, normalized)
  if normalized == nil then
    return nil
  end
  local value = map[normalized]
  if value ~= nil then
    return value
  end
  return map[tostring(normalized)]
end

function role_id.read(map, key)
  if type(map) ~= "table" then
    return nil
  end
  local value = _read_normalized(map, role_id.normalize(key))
  if value ~= nil then
    return value
  end
  if key ~= nil then
    return map[key]
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
version=4
projectHash=44b6518a5c36bd76
scope.0.id=chunk:src/foundation/identity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=79
scope.0.semanticHash=b5d5d50912446ccd
scope.1.id=function:_normalized_integer
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=f1ce1850b7232305
scope.2.id=function:_text_fallback
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=15
scope.2.semanticHash=8183695c9894310b
scope.3.id=function:role_id.normalize
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=29
scope.3.semanticHash=f82a55a8fc09b716
scope.4.id=function:role_id.equals
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=35
scope.4.semanticHash=365042269c99b2f4
scope.5.id=function:_read_normalized
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=47
scope.5.semanticHash=25981089c2887da0
scope.6.id=function:role_id.read
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=61
scope.6.semanticHash=90bcb11ad381139f
scope.7.id=function:role_id.write
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=76
scope.7.semanticHash=38e9698aaff0ac3d
]]
