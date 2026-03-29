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
  if camera and type(camera.follow) == "function" then
    return camera.follow(player_id)
  end
  return false
end

return camera_sync
