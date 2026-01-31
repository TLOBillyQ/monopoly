local MapConfig = require "Config.MapConfig"

---@class MapManager
---@field leave_level fun()
MapManager = {}

local AllCanvas = require "Globals.Canvas"
for _, canvas in ipairs(AllCanvas) do
    canvas.visible = false
end

-- 选择关卡
---@param level_name MapCode 关卡名称
MapManager.select_level = function(level_name)
    LevelData.current_select_level = level_name
end

-- 进入关卡
---@param level_name MapCode 关卡名称
MapManager.enter_level = function(level_name)
    LevelData.current_level = level_name
    local map_id = MapConfig[level_name].id
    MapManager.leave_level()
    for _, role in ipairs(ALLROLES) do
        local player = PlayerManager.find_player_by_role(role)
        player:save_data()
    end
    GameAPI.load_level(map_id)
end

-- 初始化关卡
---@param level_name MapCode 关卡名称
MapManager.init_level = function(level_name)
    local map_config = MapConfig[level_name]
    local namespace = map_config.namespace

    -- 加载地图数据
    local map_data_path = ("Manager.MapManager.%s.__init"):format(namespace)
    require(map_data_path)

    -- 加载模式数据
    local mode = LevelData.current_mode
    local mode_data_path = ("Manager.ModeManager.%s.__init"):format(mode)
    require(mode_data_path)
end

MapManager.before_leave_level = function() end

MapManager.leave_level = function()
    MapManager.before_leave_level()
    for _, role in ipairs(ALLROLES) do
        local unit = role.get_ctrl_unit()
        for _, item in ipairs(unit.get_equipment_list_by_slot_type(Enums.EquipmentSlotType.BACKPACK)) do
            item.destroy_equipment()
        end
    end
end