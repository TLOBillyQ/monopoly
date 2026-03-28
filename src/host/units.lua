local unit_lifecycle = {}

function unit_lifecycle.create_unit_group(group_id, pos, rotation)
  if not (GameAPI and type(GameAPI.create_unit_group) == "function") then
    return nil, "missing GameAPI.create_unit_group"
  end
  return GameAPI.create_unit_group(group_id, pos, rotation)
end

function unit_lifecycle.create_unit_with_scale(unit_id, pos, rotation, scale)
  if not (GameAPI and type(GameAPI.create_unit_with_scale) == "function") then
    return nil, "missing GameAPI.create_unit_with_scale"
  end
  return GameAPI.create_unit_with_scale(unit_id, pos, rotation, scale)
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
