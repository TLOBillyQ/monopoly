local number_utils = require("src.core.utils.number")
local logger = require("src.core.utils.logger")

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
    if math and math.tointeger then
      local ok, coerced = pcall(math.tointeger, value)
      if ok then
        as_int = coerced
      end
    end
  end
  if as_int == nil then
    local text = _safe_tostring(value)
    as_int = number_utils.to_integer(text)
  end
  if as_int == nil then
    _warn_invalid_image_key(value)
    return nil
  end
  if as_int <= 0 then
    _warn_invalid_image_key(value)
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
