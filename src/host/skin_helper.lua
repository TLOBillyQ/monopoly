local skin_helper = {}

function skin_helper.new(deps)
  deps = deps or {}

  local helper = {
    target_role_id = nil,
    skin_id = nil,
  }

  function helper.emit_change_skin(role_id, skin_id)
    local resolved_role_id = deps.number_utils.to_integer(role_id)
    local resolved_skin_id = deps.number_utils.to_integer(skin_id)
    if resolved_role_id == nil then
      deps.logger.warn("[Eggy]", "skip skin change event: invalid role_id", tostring(role_id))
      return false
    end
    if resolved_skin_id == nil or resolved_skin_id <= 0 then
      deps.logger.warn("[Eggy]", "skip skin change event: invalid skin_id", tostring(skin_id))
      return false
    end

    helper.target_role_id = resolved_role_id
    helper.skin_id = resolved_skin_id
    deps.runtime_event_bridge.emit_custom_event(
      deps.runtime_constants.eca_event.skin.change,
      {},
      { feature_key = "skin.change" }
    )
    return true
  end

  function helper.set_model_visible(unit, visible)
    if unit == nil or type(unit.set_model_visible) ~= "function" then
      return false
    end
    local ok = pcall(unit.set_model_visible, unit, visible)
    return ok
  end

  return helper
end

return skin_helper
