local UnitPrefab = require("Data.Prefab").unit
local UINodes = require("Data.UINodes")
local class = require("Utils.ClassUtils").class

---@class StickController
---@field new fun(): StickController
local StickController = class("StickController")

function StickController:ctor()
	self.previewUnits = {} -- 预览焊接位置的指示器
	self.charLiftInfos = {} -- 角色举起物体的信息

	local scale = 0.5
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		local roleId = role.get_roleid()

		-- 创建用来预览焊接位置的指示器
		self.previewUnits[roleId] = GameAPI.create_obstacle(
			UnitPrefab["焊接预览"],
			math.Vector3(0, 0, 0),
			math.Quaternion(0, 0, 0),
			math.Vector3(scale, scale, scale),
			role
		)

		self.charLiftInfos[roleId] = {}
		local character = role.get_ctrl_unit()

		-- 监听角色举起物体的事件
		LuaAPI.unit_register_trigger_event(character, { EVENT.SPEC_LIFEENTITY_LIFT_BEGAN }, function(_, _, data)
			local lifted = data.lifted_unit
			self:tryRemoveStickJoints(lifted)

			-- 举起的物体变半透明，同时关闭物理
			lifted.enable_expr_device_by_name("修改透明度")
			lifted.set_physics_active(false)

			self.charLiftInfos[roleId] = { unit = lifted }

			-- 举起后打开相机朝向的更新
			role.set_camera_rotation_sync_enabled(true)
		end)

		-- 监听角色放下物体的事件
		LuaAPI.unit_register_trigger_event(character, { EVENT.SPEC_LIFEENTITY_LIFT_ENDED }, function(_, _, data)
			local lifted = data.lifted_unit

			-- 举起的物体恢复透明度，同时恢复物理
			lifted.disable_expr_device_by_name("修改透明度")
			lifted.set_physics_active(true)
			self.charLiftInfos[roleId] = {}

			-- 重置放下物体的位置
			local direction = character.get_orientation():apply(math.Vector3(0, 2, 0))
			lifted.set_position(character.get_position() + direction)
			lifted.set_orientation(character.get_orientation())

			-- 放下后关闭相机朝向的更新
			role.set_camera_rotation_sync_enabled(false)
		end)
	end

	-- 预览的指示器需要对所有人都默认隐藏
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		for _, unit in pairs(self.previewUnits) do
			role.set_unit_visible(unit, false)
		end
	end

	-- 点击焊接按钮
	LuaAPI.global_register_custom_event("点击焊接", function(_, _, data)
		local role = data.role
		local liftInfo = self.charLiftInfos[role.get_roleid()]
		if self:checkRoleCanStick(role, liftInfo) then
			self:tryStickUnit(role, liftInfo)
		end
	end)
end

function StickController:checkRoleCanStick(role, liftInfo)
	if not liftInfo.unit then
		return false
	end

	-- 获取相机朝向
	local camRot = role.get_camera_rotation()
	if camRot.w == 0 then
		-- 需要剔除无效的相机朝向（刚开启相机方向监听的时候，相机朝向可能还未更新）
		return false
	end

	local character = role.get_ctrl_unit()
	-- 角色头顶处
	local startPos = character.get_position() + math.Vector3(0, 2.9, 0)
	-- 相机朝向
	local direction = camRot:apply(math.Vector3(0, 0, 1))
	local length = 15.0
	liftInfo.stickTo = nil
	liftInfo.stickPos = nil

	-- 从角色头顶朝相机方向打射线（最远距离为 length)，碰到的第一个物体和位置，作为焊接目标和焊接点
	GameAPI.raycast_unit(
		startPos,
		startPos + direction * length,
		{ Enums.UnitType.OBSTACLE },
		function(unit, point, normal)
			-- 只有射线检测成功才会更新焊接目标和焊接点
			liftInfo.stickTo = unit
			liftInfo.stickPos = point
		end
	)

	-- 只有找到焊接点才算成功
	return liftInfo.stickTo ~= nil
end

function StickController:tryStickUnit(role, liftInfo)
	if liftInfo.stickTo and liftInfo.stickTo ~= liftInfo.unit then
		-- 先把举起物体放下
		role.get_ctrl_unit().lift_unit(liftInfo.unit)

		-- 再恢复举起物体的物理
		liftInfo.unit.set_physics_active(true)
		liftInfo.unit.set_position(liftInfo.stickPos)
		liftInfo.unit.set_orientation(liftInfo.stick_rot or role.get_ctrl_unit().get_orientation())
		local joint = GameAPI.create_joint_assistant(Enums.JointAssistantKey.FIXED, liftInfo.unit, liftInfo.stickTo)

		-- 给关节标记为动态焊接，方便删除
		joint.set_kv_by_type(Enums.ValueType.Bool, "isDynamicStick", true)
	end
end

function StickController:tryRemoveStickJoints(unit)
	-- 只删除标记为动态焊接的关节
	for _, v in ipairs(GameAPI.get_joint_assistants(unit)) do
		if v.has_kv("isDynamicStick") then
			GameAPI.destroy_unit(v)
		end
	end
end

function StickController:update()
	-- 需要一直检测能否焊接，如果能焊接则显示焊接预览指示器和焊接按钮
	for roleid, liftInfo in pairs(self.charLiftInfos) do
		local role = GameAPI.get_role(roleid)
		local previewUnit = self.previewUnits[role.get_roleid()]
		local canStick = self:checkRoleCanStick(role, liftInfo)
		role.set_node_visible(UINodes["焊接按钮"], canStick)
		role.set_unit_visible(previewUnit, canStick)

		if canStick then
			local rot = role.get_ctrl_unit().get_orientation()
			local pos = liftInfo.stickPos
			previewUnit.set_position(pos)
			previewUnit.set_orientation(rot)
		end
	end
end

return StickController
