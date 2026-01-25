-- 导入必要的模块
local Consts = require("Data.Consts")
local DressUpData = require("Data.DressUpData")
local class = require("Utils.ClassUtils").class

-- 定义DressUpArea类
---@class DressUpArea
---@field new fun(string, table, fun, fun, fun, Vector3, number): DressUpArea
local DressUpArea = class("DressUpArea")

-- DressUpArea类的构造函数
function DressUpArea:ctor(dressUpId, info, enterCallback, exitCallback, pos, yaw)
	self.id = dressUpId
	self.info = info
	self.exitTrigger = nil
	self.enterCb = enterCallback
	self.exitCb = exitCallback

	self.areaObj = nil
	self.showObj = nil
	self.center = math.Vector3(0, 0, 0)
	self:createArea(pos, yaw)
end

-- 创建装扮区域
function DressUpArea:createArea(pos, yaw)
	local info = self.info
	local text = info.name
	-- 创建单位组
	local area = GameAPI.create_unit_group(Consts.JOB_CHOOSE_PREFAB, pos, math.Quaternion(0, yaw, 0))
	self.areaObj = area
	local boardPos = pos
	-- 遍历区域中的子对象
	for _, child in ipairs(area.get_children()) do
		local childName = child.get_name()
		-- 设置装扮介绍
		if string.find(childName, "名称", 1, true) == 1 then
			child.set_billboard_text(text)
			boardPos = child.get_position()
		end
		-- 设置装扮选择区域
		if string.find(childName, "选择区域", 1, true) == 1 then
			local areaId = LuaAPI.get_unit_id(child)
			local areaCenter = child.get_position()
			self.center = areaCenter
			-- 注册进入装扮选择区域的触发器
			LuaAPI.global_register_trigger_event(
				{ EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, Enums.TriggerSpaceEventType.ENTER, areaId },
				function(_, _, data)
					local character = data.event_unit
					local role = character.get_role()
					-- 检查是否为有效角色
					if role == nil or character.get_camp_id() == -1 then
						return
					end
					self.enterCb(role, character)
				end
			)

			-- 注册退出装扮选择区域的触发器
			self.exitTrigger = LuaAPI.global_register_trigger_event(
				{ EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, Enums.TriggerSpaceEventType.LEAVE, areaId },
				function(_, _, data)
					local character = data.event_unit
					local role = character.get_role()
					if self.exitCb then
						self.exitCb(role, character)
					end
				end
			)
		end
	end

	if info.modelCreatureKey then
		-- 计算展示用角色的位置和方向
		local dir = math.Vector3(0, 0, 1)
		dir:set_pitch_yaw(0, yaw + math.pi / 2)
		-- 创建展示用角色
		self.showObj = GameAPI.create_creature_fixed_scale(
			info.modelCreatureKey,
			boardPos + dir * 1.0,
			math.Quaternion(0, yaw + math.pi / 2, 0),
			math.Vector3(1, 1, 1)
		)
	end
end

-- 创建装扮区域的辅助函数
local function createDressUpArea(key, info, pos, yaw)
	-- 定义进入区域的回调函数
	local function _enterCallback(role, character)
		if character.get_role_id() == -1 then
			return
		end

		character.set_model_by_creature_key(info.modelCreatureKey)
	end
	DressUpArea.new(key, info, _enterCallback, nil, pos, yaw)
end

-- 设置所有装扮区域
local function setupDressUpAreas()
	local dressUpDatas = {}
	for key, info in pairs(DressUpData) do
		table.insert(dressUpDatas, { key, info })
	end
	-- 计算圆形排列的参数
	local numDressUps = #dressUpDatas
	local angleDelta = math.pi * 2.0 / numDressUps
	local radius = 30
	local currAngle = 0.0

	-- 创建每个装扮区域
	for _, data in ipairs(dressUpDatas) do
		local key = data[1]
		local info = data[2]

		-- 计算装扮区域的位置
		local dir = math.Vector3(math.cos(currAngle), 0, math.sin(currAngle))
		local pos = math.Vector3(0, -4, 0) + dir * radius

		createDressUpArea(key, info, pos, math.pi - currAngle)

		currAngle = currAngle + angleDelta
	end
	DressUpArea.new("Default", { name = "取消装扮" }, function(role, character)
		character.reset_model()
	end, nil, math.Vector3(0, -4, 0), math.pi)
end

-- 注册游戏初始化事件
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	setupDressUpAreas()
end)
