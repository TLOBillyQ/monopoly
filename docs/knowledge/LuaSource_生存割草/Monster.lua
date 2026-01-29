-- 导入模块
local MathUtils = require("Utils.MathUtils")
local PrefabFactory = require("Utils.PrefabFactory")
local PrefabType = PrefabFactory.PrefabType
local class = require("Utils.ClassUtils").class

SEARCH_CD_IF_TARGET = 5.0 -- 有目标时的索敌间隔
SEARCH_CD_IF_NOTARGET = 1.0 -- 无目标时的索敌间隔

---@class Monster
---@field new fun(monsterConf: table, position: Vector3, rotation: Quaternion, deadDestroyCallback: function?): Monster
local Monster = class("Monster")

-- 怪物类的构造函数
function Monster:ctor(monsterConf, position, rotation, deadDestroyCallback)
	-- 设置怪物的缩放比例
	local scale = math.Vector3(1.0, 1.0, 1.0)
	-- 记录怪物的出生位置和旋转
	self.bornPos = position
	self.bornRot = rotation
	-- 设置巡逻位置
	self.patrolPos = self.bornPos
	-- 保存怪物配置和AI配置
	self.monsterConf = monsterConf
	self.aiConf = monsterConf.ai
	-- 保存死亡销毁回调函数
	self.deadDestroyCb = deadDestroyCallback
	-- 创建怪物预制体
	G.prefabFactory:createPrefabWithCb(
		PrefabType.UNIT_CREATURE,
		monsterConf.prefabID,
		position,
		rotation,
		scale,
		function(unit)
			self.unit = unit
			self:onCreatureLoaded()
		end
	)
	-- 初始化怪物状态
	self.isStucked = 0
	self.lastMovePos = nil
	self.state = "idle"
	self.aiEnable = true
	self.target = nil
	-- 设置AI思考间隔和目标搜索冷却时间
	self.thinkInterval = 0.2
	self.targetSearchCD = 0.0
end

-- 怪物创建完成后的回调函数
function Monster:onCreatureLoaded()
	-- 将自身添加到可更新对象列表中
	G.addTickable(self)

	-- 初始化全局触发事件列表
	self.globalTriggerEvents = {}

	-- 延迟随机时间后注册AI更新事件
	LuaAPI.call_delay_time(LuaAPI.rand(), function()
		if not self.unit then
			return
		end

		-- 注册定期执行AI逻辑的事件
		table.insert(
			self.globalTriggerEvents,
			LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, self.thinkInterval }, function()
				if self.aiEnable then
					self:tickAI()
				end
			end)
		)
	end)

	-- 注册怪物死亡事件
	self.deadDestroyHandle = LuaAPI.unit_register_trigger_event(
		self.unit,
		{ EVENT.SPEC_LIFEENTITY_DIE },
		function(_, _, data)
			self.dead = true
			if self.deadDestroyCb then
				self.deadDestroyCb(self, data.dmg_unit)
			end
			self:onDeadDestroy()
		end
	)

	-- 设置AI启用状态
	self:setAIEnable(self.aiEnable)
end

-- 设置AI启用状态的函数
function Monster:setAIEnable(enable)
	-- 如果之前AI启用而现在要禁用，则强制停止移动
	if self.aiEnable and not enable then
		self.unit.force_stop_move()
	end
	self.aiEnable = enable
end

-- 验证目标是否有效的函数
function Monster:validateTarget(target, unitPos, nearestDist)
	-- 检查目标是否已死亡
	if target.get_hp() <= 0 then
		return
	end

	-- 检查目标是否处于隐身状态
	if target.has_kv("invisible") and target.get_kv_by_type(Enums.ValueType.Int, "invisible") > 0 then
		return
	end

	local aiConf = self.aiConf
	local taragetPos = target.get_position()
	-- 检查目标是否在关注范围内
	if aiConf.careTargetRange > 0 then
		local direction = taragetPos - self.bornPos
		direction = direction - math.Vector3(0, direction.y, 0)
		if direction:length() > aiConf.careTargetRange then
			return
		end
	end

	-- 计算目标距离
	local direction = taragetPos - unitPos
	direction = direction - math.Vector3(0, direction.y, 0)
	local distance = direction:length()
	-- 如果目标距离小于当前最近距离，则返回新的距离
	if distance < nearestDist then
		return distance
	end
end

-- 搜索最近的目标
function Monster:searchClosestTarget()
	local aiConf = self.aiConf
	local nearest = nil
	local nearestDist = aiConf.searchTargetDist
	local unitPos = self.unit.get_position()
	-- 遍历所有有效角色
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		local target = role.get_ctrl_unit()
		-- 验证目标并获取距离
		local distance = self:validateTarget(target, unitPos, nearestDist)
		if distance ~= nil then
			nearest = target
			nearestDist = distance
		end
	end

	return nearest
end

-- AI逻辑更新
function Monster:tickAI()
	-- 检查当前目标是否有效
	if self.target then
		local unitPos = self.unit.get_position()
		if not self:validateTarget(self.target, unitPos, self.aiConf.targetGiveupDist) then
			self.target = nil

			-- 目标失效加快下次索敌时机
			self.targetSearchCD = self.targetSearchCD - (SEARCH_CD_IF_TARGET - SEARCH_CD_IF_NOTARGET)
		end
	end

	-- 更新目标搜索冷却时间
	self.targetSearchCD = self.targetSearchCD - self.thinkInterval
	if self.targetSearchCD <= 0 then
		self.target = self:searchClosestTarget()
		if self.target then
			self.targetSearchCD = SEARCH_CD_IF_TARGET
		else
			self.targetSearchCD = SEARCH_CD_IF_NOTARGET
		end
	end

	local isStucked = false
	local newPos = nil
	-- 如果有目标，移动并攻击
	if self.target then
		self.state = self:moveToAttack(self.target)
		if self.state == "move" then
			local targetPos = self.target.get_position()
			newPos = self.unit.get_position()
			-- 检查是否卡住
			if targetPos.y - newPos.y > (self.isStucked >= 3 and -1000 or 0.2) then
				local oldPos = self.lastMovePos
				if oldPos then
					local moved = newPos - oldPos
					moved = moved - math.Vector3(0, moved.y, 0)
					isStucked = moved:dot((targetPos - newPos):getUnit()) < 0.05
				end
				self.lastMovePos = newPos
			end
		end
	else
		-- 如果没有目标，进行巡逻
		self.state = self:patrol()
		if self.state == "move" then
			newPos = self.unit.get_position()
			local oldPos = self.lastMovePos
			if oldPos then
				local moved = newPos - oldPos
				moved = moved - math.Vector3(0, moved.y, 0)
				isStucked = moved:length() < 0.05
			end
		end
	end

	-- 更新卡住状态
	if self.state == "move" then
		assert(newPos)
		self.isStucked = math.min(math.max(0, self.isStucked + (isStucked and 1 or -1)), 3)
		self.lastMovePos = newPos
	else
		self.isStucked = 0
		self.lastMovePos = nil
	end
	assert(self.state ~= nil)
end

-- 更新怪物状态
function Monster:update()
	-- 如果卡住超过3次，尝试解除卡住状态
	if self.isStucked >= 3 then
		local unitPos = self.unit.get_position()
		if self.target then
			-- 如果有目标，稍微上移位置
			self.unit.set_position(unitPos + math.Vector3(0, 0.3, 0))
		else
			-- 如果没有目标，重新获取巡逻位置
			self.patrolPos = self:getPatrolPos(unitPos)
		end
	end
end

-- 获取巡逻位置
function Monster:getPatrolPos(unitPos)
	local aiConf = self.aiConf
	return MathUtils.randCirclePoint(unitPos, 0, aiConf.patrolRange)
end

-- 执行巡逻行为
function Monster:patrol()
	local unitPos = self.unit.get_position()
	local dir = self.patrolPos - unitPos
	-- 如果当前朝向与目标方向相反，重新获取巡逻位置
	if self.unit.get_direction():dot(dir) < 0 then
		self.patrolPos = self:getPatrolPos(unitPos)
	end

	local direction = self.patrolPos - unitPos
	self.unit.force_start_move(direction, 1.0)
	return "move"
end

-- 移动并攻击目标
function Monster:moveToAttack(target)
	local aiConf = self.aiConf
	local unitPos = self.unit.get_position()
	local targetPos = target.get_position()
	local direction = targetPos - unitPos
	local yDistance = direction.y
	local roleHeight = 1.8
	direction = direction - math.Vector3(0, direction.y, 0)
	local dirLength = direction:length()
	-- 检查位置、高度和方向是否有效
	local isPosValid = dirLength <= aiConf.attackDist
	local isNotHigher = yDistance <= aiConf.attackHeight
	local isNotLower = yDistance >= -roleHeight
	local isHeightValid = isNotHigher and isNotLower
	local isDirValid = self.unit.get_direction():dot(direction) / dirLength > aiConf.attackCosMin

	if isPosValid and isHeightValid and isDirValid then
		local attackPos = unitPos + math.Vector3(0, 1.2, 0)
		if aiConf.attack_offset then
			attackPos = unitPos + self.unit.get_orientation():apply(aiConf.attack_offset)
		end

		local attackDir = targetPos + math.Vector3(0, 1.2, 0) - attackPos
		-- 如果是远程攻击，检查是否有障碍物
		if aiConf.isShoot then
			local shootObstacle = nil
			GameAPI.raycast_unit(
				attackPos,
				attackPos + attackDir,
				{ Enums.UnitType.OBSTACLE },
				function(unit, point, normal)
					shootObstacle = { unit, point, normal }
				end
			)
			if shootObstacle then
				isPosValid = false
			end
		end

		if isPosValid then
			-- 如果有射击散布，计算散布后的攻击方向
			if aiConf.shootScatter then
				local normDir = attackDir:clone()
				normDir:normalize()
				local scatter = attackDir:length() * aiConf.shootScatter
				local left = math.Vector3(0, 1, 0):cross(normDir)
				attackDir = attackDir + left * (LuaAPI.rand() - 0.5) * 2 * scatter
			end

			self.unit.force_stop_move()
			self.unit.cast_ability_by_ability_slot_and_direction(attackDir, 5, 0.0)
			return "skill"
		end
	end

	-- 如果目标位置有效但高度不够，尝试跳跃
	if isPosValid and not isNotHigher and isDirValid then
		self.unit.jump()
		return "move"
	end

	-- 如果无法攻击，继续移动
	self.unit.force_start_move(direction, 1.0)
	return "move"
end

-- 销毁怪物
function Monster:destroy()
	LuaAPI.unit_unregister_trigger_event(self.unit, self.deadDestroyHandle)
	GameAPI.destroy_unit(self.unit)
	self:_onDestroy()
end

-- 怪物死亡时的销毁处理
function Monster:onDeadDestroy()
	self:_onDestroy()
end

-- 内部销毁处理
function Monster:_onDestroy()
	G.removeTickable(self)
	for _, event in ipairs(self.globalTriggerEvents) do
		LuaAPI.global_unregister_trigger_event(event)
	end

	self.unit = nil
end

-- 获取怪物半径
function Monster:getRadius()
	return self.monsterConf.scale * 0.5
end

-- 获取怪物中心点
function Monster:getCenter()
	return self.unit.get_position() + math.Vector3(0, 1, 0) * self.monsterConf.scale
end

return Monster
