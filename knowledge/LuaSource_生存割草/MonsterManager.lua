-- 导入所需的模块和类
local class = require("Utils.ClassUtils").class
local MathUtils = require("Utils.MathUtils")
local MonsterData = require("Data.MonsterData")
local MonsterSpawnWaveData = require("Data.MonsterSpawnWaveData")
local UINodes = require("Data.UINodes")
local Monster = require("Monster")
local Consts = require("Data.Consts")

---@class SpawnWave
---@field new fun(MonsterManager, table): SpawnWave
local SpawnWave = class("SpawnWave")

-- SpawnWave类的构造函数
function SpawnWave:ctor(owner, waveData)
	self.owner = owner
	self.monsters = {} -- 刷怪池
	self.deadMonsterCount = 0
	self.totalMonsterCount = 0
	-- 初始化怪物数据
	for _, monsterSpawnData in ipairs(waveData.monsters) do
		table.insert(self.monsters, { data = monsterSpawnData, count = monsterSpawnData.count })
		self.totalMonsterCount = self.totalMonsterCount + monsterSpawnData.count
	end
	self.startedTime = 0
	self.spawnInterval = waveData.spawnInterval
	self.maxNum = waveData.maxNum
	self.maxNumOnce = waveData.maxNumOnce

	self._spawnTimerId = nil
end

-- 开始生成怪物波次
function SpawnWave:start()
	self.startedTime = 0

	-- 定义定时器回调函数
	local function _timerFunc(eventName, actor, data)
		local numMonster = #self.owner.monsters
		-- 检查是否达到最大怪物数量或怪物池是否为空
		if numMonster >= self.maxNum or #self.monsters <= 0 then
			return
		end

		-- 计算权重并选择怪物类型
		local weights = {}
		for _, item in ipairs(self.monsters) do
			table.insert(weights, item.data.weight)
		end
		local idx, monsterSpawnData = MathUtils.weightedRandomChoice(self.monsters, weights)
		local range = monsterSpawnData.data.range
		-- 计算本次生成的怪物数量
		local spawnNum = math.min(self.maxNum - numMonster, MathUtils.randint(1, self.maxNumOnce))
		spawnNum = math.min(spawnNum, monsterSpawnData.count)
		-- 随机选择一个角色作为生成中心
		local roles = GameAPI.get_all_valid_roles()
		local role = MathUtils.randomChoice(roles)
		local character = role.get_ctrl_unit()
		-- 获取地图边界
		local boundaryXMin = Consts.MAP_BOUNDARY_X[1]
		local boundaryXMax = Consts.MAP_BOUNDARY_X[2]
		local boundaryZMin = Consts.MAP_BOUNDARY_Z[1]
		local boundaryZMax = Consts.MAP_BOUNDARY_Z[2]
		-- 生成怪物
		for _ = 1, spawnNum do
			-- 超出地图外需要重新随机位置
			local maxTryCount = 5
			local pos
			repeat
				pos = MathUtils.randCirclePoint(character.get_position(), range[1], range[2])
				maxTryCount = maxTryCount - 1
				-- 没有找到合法位置的情况
				if maxTryCount == 0 then
					break
				end
			until pos.x > boundaryXMin and pos.x < boundaryXMax and pos.z > boundaryZMin and pos.z < boundaryZMax
			if maxTryCount ~= 0 then
				-- 生成怪物并设置随机朝向
				local yaw = LuaAPI.rand() * math.pi * 2
				self.owner:createMonster(
					monsterSpawnData.data.key,
					pos,
					math.Quaternion(0, yaw, 0),
					function(monster, dmgSrc)
						self:onMonsterDie(monster, dmgSrc)
					end
				)

				-- 更新怪物数量
				monsterSpawnData.count = monsterSpawnData.count - spawnNum
				if monsterSpawnData.count <= 0 then
					table.remove(self.monsters, idx)
				end
			end
		end
		self.startedTime = self.startedTime + self.spawnInterval
	end

	-- 先立刻触发一次
	_timerFunc()
	-- 注册定时器事件
	self._spawnTimerId = LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, self.spawnInterval }, _timerFunc)
end

-- 停止生成怪物波次
function SpawnWave:stop()
	LuaAPI.global_unregister_trigger_event(self._spawnTimerId)
	self.owner:onWaveFinished()
end

-- 处理怪物死亡事件
function SpawnWave:onMonsterDie(monster, dmgSrc)
	-- 如果有伤害来源，给对应英雄增加经验
	if dmgSrc and dmgSrc.get_role_id then
		local roleId = dmgSrc.get_role_id()
		local hero = G.heroManager:getHero(roleId)
		if hero ~= nil then
			hero:addExp(monster.monsterConf.exp)
		end
	end

	-- 从怪物列表中移除死亡的怪物
	for idx, item in ipairs(self.owner.monsters) do
		if item == monster then
			table.remove(self.owner.monsters, idx)
			break
		end
	end
	-- 检查是否所有怪物都已死亡，如果是则停止当前波次
	if #self.owner.monsters == 0 and #self.monsters == 0 then
		self:stop()
	end
end

---@class MonsterManager
---@field new fun(): MonsterManager
local MonsterManager = class("MonsterManager")

-- MonsterManager类的构造函数
function MonsterManager:ctor()
	self.monsters = {}
	self.waveCount = 0
	self.currWave = nil
end

-- 创建怪物
function MonsterManager:createMonster(key, pos, rot, deadCallback)
	local data = MonsterData[key]
	if data == nil then
		return nil
	end
	local monster = Monster.new(data, pos, rot, deadCallback)
	table.insert(self.monsters, monster)
	return monster
end

-- 开始生成怪物
function MonsterManager:startSpawn()
	self:interWaveCountDown(10)
end

-- 更新倒计时UI
function MonsterManager:updateCountDownUI(countdown, visible)
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		role.set_node_visible(UINodes["倒计时"], visible)
		role.set_label_text(UINodes["倒计时"], "距离下一波：" .. countdown)
	end
end

-- 波次间隔倒计时
function MonsterManager:interWaveCountDown(countdown)
	local triggerId = nil
	self:updateCountDownUI(countdown, true)
	local function _timerFunc(eventName, actor, data)
		countdown = countdown - 1
		self:updateCountDownUI(countdown, true)

		if countdown <= 0 then
			if triggerId ~= nil then
				LuaAPI.global_unregister_trigger_event(triggerId)
				self:updateCountDownUI("", false)
				self:nextSpawnWave()
			end
		end
	end
	triggerId = LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 1.0 }, _timerFunc)
end

-- 开始下一波怪物生成
function MonsterManager:nextSpawnWave()
	self:startSpawnWave(self.waveCount + 1)
end

-- 开始指定波次的怪物生成
function MonsterManager:startSpawnWave(waveCount)
	self.waveCount = math.min(waveCount, #MonsterSpawnWaveData)
	self.currWaveData = MonsterSpawnWaveData[self.waveCount]
	self.currWave = SpawnWave.new(self, self.currWaveData)
	self.currWave:start()
end

-- 当前波次结束的处理
function MonsterManager:onWaveFinished()
	self.currWave = nil
	self:interWaveCountDown(10)
end

return MonsterManager
