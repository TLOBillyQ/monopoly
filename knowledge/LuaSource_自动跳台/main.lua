-- 常量定义
local ARROW_PRESET_ID = 1404042
local CLOUD_PRESET_ID = 100636
local CLOUD_OFFSET = math.Vector3(2.5, 2.5, 2.5)

-- 局部变量
local Vector3 = math.Vector3
local Quaternion = math.Quaternion
local created_clouds = {}
local resurrect_count = 0

-- 创建云朵函数
local function create_cloud(arrow)
    local position = arrow.get_position() - arrow.get_orientation():apply(Vector3(0.0, 1.0, 0.0)) * CLOUD_OFFSET
    local orientation = Quaternion(0.0, 0.0, 0.0)
    local scale = Vector3(1.0, 1.0, 1.0)
    return GameAPI.create_obstacle(CLOUD_PRESET_ID, position, orientation, scale, nil)
end

-- 监听箭的创建和碰撞
LuaAPI.register_unit_creation_handler(Enums.UnitType.OBSTACLE, ARROW_PRESET_ID, function(arrow)
    LuaAPI.unit_register_trigger_event(arrow, { EVENT.SPEC_OBSTACLE_CONTACT_BEGIN }, function()
        table.insert(created_clouds, create_cloud(arrow))
    end)
end)

local resurrect_count = 0

-- 重生处理函数
---@export
---@desc 当重生时调用Lua
---@param save_clouds boolean
---@return integer
function on_resurrection(save_clouds)
	print("Resurrect with clouds: " .. tostring(save_clouds))

	if not save_clouds then
		for _, v in ipairs(created_clouds) do
			GameAPI.destroy_unit(v)
		end

		created_clouds = {}
	end

	resurrect_count = resurrect_count + 1
	return resurrect_count
end
