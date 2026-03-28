local runtime_constants = require("src.config.gameplay.runtime_constants")
local host_runtime_ports = require("src.ui.host_bridge")
local runtime_ports = require("src.core.ports.runtime_ports")

local camera_sync = {}

function camera_sync.follow_camera(player_id)
  if player_id == nil then
    return false
  end
  local camera = runtime_ports.resolve_camera_helper()
  if camera then
    camera.target_role_id = player_id
  end
  if camera
      and runtime_constants
      and runtime_constants.eca_event
      and runtime_constants.eca_event.camera
      and runtime_constants.eca_event.camera.follow then
    local event_name = runtime_constants.eca_event.camera.follow
    local emitted, emit_err = host_runtime_ports.emit_custom_event(
      event_name,
      nil,
      { feature_key = "camera.follow" }
    )
    if emitted ~= true then
      return false
    end
    return true
  end
  return false
end

return camera_sync
