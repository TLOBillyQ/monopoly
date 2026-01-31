require 'Manager.MapManager.Lobby.GUI.MainController'
require 'Manager.MapManager.Lobby.GUI.ShopController'
require 'Manager.MapManager.Lobby.GUI.EscaperController'
require 'Manager.MapManager.Lobby.GUI.BackpackController'

for _, role in ipairs(ALLROLES) do
    role.send_ui_custom_event("隐藏移动", {})
    role.send_ui_custom_event("隐藏跳跃", {})
    role.set_camera_draggable(false)
    role.set_camera_lock_position(math.Vector3(40.0, 5.0, -70.79))
    role.set_camera_property(Enums.CameraPropertyType.PITCH, 5.0)
    role.set_camera_property(Enums.CameraPropertyType.YAW, -90.0)
    local player = PlayerManager.find_player_by_role(role)
end

MapManager.before_leave_level = function()
    for _, role in ipairs(ALLROLES) do
        role.send_ui_custom_event("重置请求探索动画", {})
        role.send_ui_custom_event("重置选择逃生动画", {})
    end
    LevelData.current_mode = "LootEscaper"
end
