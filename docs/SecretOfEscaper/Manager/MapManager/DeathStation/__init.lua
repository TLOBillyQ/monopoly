require 'Manager.MapManager.DeathStation.GUI.MainController'

MapManager.before_leave_level = function()
    LevelData.current_mode = nil
    GameManager.gaming = false
end