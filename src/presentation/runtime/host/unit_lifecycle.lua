local logger = require("src.core.utils.logger")

local unit_lifecycle = {}

local function _describe_handle(handle)
  if handle == nil then
    return "nil"
  end
  if type(handle) == "table" then
    return tostring(handle._unit_id or handle._group_id or handle.id or handle)
  end
  return tostring(handle)
end

function unit_lifecycle.create_unit_group(group_id, pos, rotation)
  if not (GameAPI and type(GameAPI.create_unit_group) == "function") then
    logger.warn(
      "[OverlayDebug]",
      "create_unit_group unavailable",
      "group_id=" .. tostring(group_id),
      "has_game_api=" .. tostring(GameAPI ~= nil),
      "has_method=" .. tostring(GameAPI and type(GameAPI.create_unit_group) == "function" or false)
    )
    return nil, "missing GameAPI.create_unit_group"
  end
  local handle = GameAPI.create_unit_group(group_id, pos, rotation)
  if handle == nil then
    logger.warn(
      "[OverlayDebug]",
      "create_unit_group returned nil",
      "group_id=" .. tostring(group_id),
      "handle=" .. _describe_handle(handle)
    )
  end
  return handle
end

function unit_lifecycle.create_unit_with_scale(unit_id, pos, rotation, scale)
  if not (GameAPI and type(GameAPI.create_unit_with_scale) == "function") then
    logger.warn(
      "[OverlayDebug]",
      "create_unit_with_scale unavailable",
      "unit_id=" .. tostring(unit_id),
      "has_game_api=" .. tostring(GameAPI ~= nil),
      "has_method=" .. tostring(GameAPI and type(GameAPI.create_unit_with_scale) == "function" or false)
    )
    return nil, "missing GameAPI.create_unit_with_scale"
  end
  local handle = GameAPI.create_unit_with_scale(unit_id, pos, rotation, scale)
  if handle == nil then
    logger.warn(
      "[OverlayDebug]",
      "create_unit_with_scale returned nil",
      "unit_id=" .. tostring(unit_id),
      "handle=" .. _describe_handle(handle)
    )
  end
  return handle
end

function unit_lifecycle.destroy_unit_with_children(handle, include_children)
  if not (GameAPI and type(GameAPI.destroy_unit_with_children) == "function") then
    return false
  end
  GameAPI.destroy_unit_with_children(handle, include_children == true)
  return true
end

function unit_lifecycle.destroy_unit(handle)
  if not (GameAPI and type(GameAPI.destroy_unit) == "function") then
    return false
  end
  GameAPI.destroy_unit(handle)
  return true
end

return unit_lifecycle
