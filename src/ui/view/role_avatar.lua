local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")

local role_avatar = {}
local warned_values = {}

local function _safe_tostring(value)
  local ok, text = pcall(tostring, value)
  if ok then
    return text
  end
  return "<tostring failed>"
end

local function _warn_invalid_image_key(value)
  local value_type = type(value)
  local text = _safe_tostring(value)
  local key = value_type .. ":" .. text
  if warned_values[key] then
    return
  end
  warned_values[key] = true
  logger.warn("头像ImageKey解析失败:", "type=" .. value_type, "value=" .. text)
end

function role_avatar.sanitize_image_key(value)
  if value == nil then
    return nil
  end
  local as_int = number_utils.to_integer(value)
  if as_int == nil then
    _warn_invalid_image_key(value)
    return nil
  end
  if as_int <= 0 then
    if as_int < 0 then
      _warn_invalid_image_key(value)
    end
    return nil
  end
  return as_int
end

function role_avatar.resolve_from_role(role)
  if not role or type(role.get_head_icon) ~= "function" then
    return nil
  end
  local ok, icon = pcall(role.get_head_icon)
  if not ok then
    return nil
  end
  return role_avatar.sanitize_image_key(icon)
end

return role_avatar

--[[ mutate4lua-manifest
version=2
projectHash=6eb5a80ae9f8fa10
scope.0.id=chunk:src/ui/view/role_avatar.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=587960d464f79cdf
scope.1.id=function:_safe_tostring:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=13
scope.1.semanticHash=9e17ee5b0412392f
scope.2.id=function:_warn_invalid_image_key:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=24
scope.2.semanticHash=bea4a67259e533ff
scope.3.id=function:role_avatar.sanitize_image_key:26
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=42
scope.3.semanticHash=1304f94373df9f57
scope.4.id=function:role_avatar.resolve_from_role:44
scope.4.kind=function
scope.4.startLine=44
scope.4.endLine=53
scope.4.semanticHash=380861bc2ac01e45
]]
