local function main_after()
    require 'init'
    MapManager.init_level(LevelData.current_level)
end

-- require "Library.Utils"
-- main_after = function()
--     NavMesh = require "Library.NavMesh.__init"
--     Mesh = NavMesh.build(require "Manager.MapManager.DeathStation.MeshData")
--     GameAPI.get_all_valid_roles()[1].send_ui_custom_event("显示跳跃", {})
--     NavMesh.render()
--     NavMesh.start_edit()
-- end

LuaAPI.call_delay_frame(1, function()
    main_after()
end)
