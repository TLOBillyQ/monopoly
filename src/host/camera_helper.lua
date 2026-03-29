local camera_helper = {}

function camera_helper.new(env, deps)
  deps = deps or {}

  local helper = {
    _env = env,
    target_role_id = nil,
  }

  function helper.set_target(role_id)
    helper.target_role_id = role_id
    return role_id
  end

  function helper.get_target()
    return helper.target_role_id
  end

  function helper.follow(role_id)
    if role_id == nil then
      return false
    end

    helper.set_target(role_id)

    local runtime_event_bridge = deps.runtime_event_bridge
    local runtime_constants = deps.runtime_constants
    if runtime_event_bridge == nil
        or runtime_constants == nil
        or runtime_constants.eca_event == nil
        or runtime_constants.eca_event.camera == nil
        or runtime_constants.eca_event.camera.follow == nil then
      return false
    end

    local emitted = runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.camera.follow,
      nil,
      { feature_key = "camera.follow" }
    )
    if emitted ~= true then
      return false
    end

    return true
  end

  return helper
end

return camera_helper
