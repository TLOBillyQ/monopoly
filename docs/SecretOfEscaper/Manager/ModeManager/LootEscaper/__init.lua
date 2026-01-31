for _, role in ipairs(ALLROLES) do
    role.send_ui_custom_event("显示移动", {})
    role.send_ui_custom_event("显示跳跃", {})
    local code = LevelData[role.get_name()].escaper_code --[[@as EscaperCode]]
    local player = PlayerManager.find_player_by_role(role)
    player:set_escaper(code)
    player.equipment:show(player, Enums.EquipmentSlotType.EQUIPPED)
    role.set_camera_property(Enums.CameraPropertyType.DIST, 6.5)
    role.set_camera_property(Enums.CameraPropertyType.OBSERVER_HEIGHT, 3.0)
end


LuaAPI.global_register_custom_event("切换视角", function(_, _, data)
    local role = data.role --[[@as Role]]
    local unit = role.get_ctrl_unit()
    local player = PlayerManager.find_player_by_role(role)
    if player.custom_data.switched then
        role.set_camera_property(Enums.CameraPropertyType.DIST, 6.5)
        role.set_camera_property(Enums.CameraPropertyType.OBSERVER_HEIGHT, 3.0)
        LuaAPI.unit_send_custom_event(unit, "取消隐藏本地角色", {})
        player.custom_data.switched = nil
    else
        role.set_camera_property(Enums.CameraPropertyType.DIST, -1.0)
        role.set_camera_property(Enums.CameraPropertyType.OBSERVER_HEIGHT, 3.0)
        LuaAPI.unit_send_custom_event(unit, "隐藏本地角色", {})
        player.custom_data.switched = true
    end
end)


LootEscaper = {}
require "Manager.ModeManager.LootEscaper.GUI.__init"
local LootChestManager = require "Manager.ModeManager.LootEscaper.LootChestManager"
local MapConfig = require "Config.MapConfig"

local namespace = MapConfig[LevelData.current_select_level].namespace
local config = require(("Manager.MapManager.%s.LootChest"):format(namespace))
LootEscaper.LootChestManager = LootChestManager:new(config)

local NavMesh = require "Library.NavMesh.__init"
local mesh_data = require(("Manager.MapManager.%s.MeshData"):format(namespace))
LootEscaper.NavMesh = NavMesh.build(mesh_data)

local MonsterManager = require "Manager.ModeManager.LootEscaper.MonsterManager"
local VengefulClown = require "Manager.EntityManager.Monster.VengefulClown.__init"
local ENode = require("Library.UIManager.ENode")
local monster = VengefulClown:new(GameAPI.get_unit(1389644959)) --[[@as VengefulClown]]
MonsterManager.monster = monster
local blackboard = monster.behavior_tree:get_blackboard()
blackboard:set("Mesh", LootEscaper.NavMesh)
blackboard:set("PathFinder", require "Library.NavMesh.Path")

require "Manager.ModeManager.LootEscaper.EscapeDoorManager"
require "Manager.ModeManager.LootEscaper.GameOver"
require "Manager.ModeManager.LootEscaper.WarnSphere"
