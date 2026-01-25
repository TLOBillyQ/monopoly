local Consts = require("Data.Consts")
local class = require("Utils.ClassUtils").class

---@class PrefabFactory: table<string, any> 预设工厂类
---@field new fun(): PrefabFactory
local PrefabFactory = class("PrefabFactory")

PrefabFactory.PrefabType = Consts.PrefabType

function PrefabFactory:ctor()
	self._recyleObjs = {}
	self._enableReuse = true
	self._inactiveMachines = {}
	self:init()
end

function PrefabFactory:init() end

function PrefabFactory:_createUnitGroup(obj, prefabID, pos, rot, scale)
	local target = obj
	local phyPos = pos
	if obj then
		obj.set_position(phyPos)
		obj.set_orientation(rot)
	else
		target = GameAPI.create_unit_group(prefabID, phyPos, rot, nil)
	end
	return target
end

function PrefabFactory:_createObstacle(obj, prefabID, pos, rot, scale)
	local target = obj
	if obj then
		obj.set_position(pos)
		obj.set_orientation(rot)
	else
		target = GameAPI.create_obstacle(prefabID, pos, rot, scale, nil)
	end
	return target
end

function PrefabFactory:_createCreature(obj, prefabID, pos, rot, scale)
	local target = obj
	if obj then
		obj.set_position(pos)
		obj.set_direction(rot:apply(math.Vector3(0, 0, 1)))
	else
		target = GameAPI.create_creature(prefabID, pos, rot, scale, nil)
	end
	return target
end

function PrefabFactory:_createEquipment(obj, prefabID, pos, rot, scale)
	local target = GameAPI.create_equipment(prefabID, pos)
	local unit = target.get_unit()
	if unit then
		unit.set_orientation(rot)
	end
	return target
end

---从缓存中返回对象，阻塞
---@param prefabType string 预设类型（PrefabFactory.PrefabType)
---@param prefabID integer 预设ID，可从编辑器中查看
---@param pos Vector3 创建位置
---@param rot Quaternion 创建旋转
---@param scale Vector3|nil 创建缩放
---@return Unit|Creature|Obstacle|UnitGroup|Equipment|any
function PrefabFactory:createPrefab(prefabType, prefabID, pos, rot, scale)
	local objs = self._recyleObjs[prefabID]
	local obj = nil
	-- 缓存里有， 直接返回
	if objs and #objs > 0 then
		obj = table.remove(objs)
		obj.set_model_visible(true)
		if prefabType == self.PrefabType.UNIT_CREATURE then
			obj.set_physic_enable(true)
		end
	end
	local func = self["_create" .. prefabType]
	local target = func(self, obj, prefabID, pos, rot, scale)
	target.set_kv_by_type(Enums.ValueType.Str, "type", prefabType)
	target.set_kv_by_type(Enums.ValueType.Int, "prefabID", prefabID)
	target.set_kv_by_type(Enums.ValueType.Vector3, "pos", pos)
	target.set_kv_by_type(Enums.ValueType.Quaternion, "rot", rot)
	return target
end

-- 回收对象
function PrefabFactory:destroyPrefab(obj, recyle)
	if recyle == nil then
		recyle = true
	end
	-- 物品对象，直接删除好了，不复用
	local prefabType = obj.get_kv_by_type(Enums.ValueType.Str, "type")
	local prefabID = obj.get_kv_by_type(Enums.ValueType.Int, "prefabID")
	if prefabType == self.PrefabType.UNIT_EQUIPMENT then
		obj.destroy_equipment()
		return
	end
	-- 其他对象，回收方便复用
	if self._enableReuse and recyle then
		if not self._recyleObjs[prefabID] then
			self._recyleObjs[prefabID] = {}
		end
		table.insert(self._recyleObjs[prefabID], obj)
		obj.set_model_visible(false)
		if prefabType == self.PrefabType.UNIT_CREATURE then
			obj.set_physic_enable(false)
		end
	else
		if prefabType == self.PrefabType.UNIT_GROUP then
			GameAPI.destroy_unit_with_children(obj, true)
		else
			GameAPI.destroy_unit(obj)
		end
	end
end

function PrefabFactory:clear() end

function PrefabFactory:_createUnitGroupWithCb(obj, prefabID, pos, rot, scale, callback)
	local phyPos = pos
	if obj then
		obj.set_position(phyPos)
		obj.set_orientation(rot)
		if callback ~= nil then
			callback(obj)
		end
		return -1
	else
		return G.frameLoader:load(GameAPI.create_unit_group, function(target)
			if callback ~= nil then
				callback(target)
			end
		end, prefabID, phyPos, rot, nil)
	end
end

function PrefabFactory:_createObstacleWithCb(obj, prefabID, pos, rot, scale, callback)
	if obj then
		obj.set_position(pos)
		obj.set_orientation(rot)
		if callback ~= nil then
			callback(obj)
		end
		return -1
	else
		return G.frameLoader:load(GameAPI.create_obstacle, callback, prefabID, pos, rot, scale, nil)
	end
end

function PrefabFactory:_createCreatureWithCb(obj, prefabID, pos, rot, scale, callback)
	if obj then
		obj.set_position(pos)
		obj.set_orientation(rot)
		if callback ~= nil then
			callback(obj)
		end
		return -1
	else
		return G.frameLoader:load(GameAPI.create_creature, callback, prefabID, pos, rot, scale, nil)
	end
end

function PrefabFactory:_createEquipmentWithCb(obj, prefabID, pos, rot, scale, callback)
	G.frameLoader:load(GameAPI.create_equipment, callback, prefabID, pos)
end

---从缓存中返回对象，非阻塞
---@param prefabType string 预设类型（PrefabFactory.PrefabType)
---@param prefabID integer 预设ID，可从编辑器中查看
---@param pos Vector3 创建位置
---@param rot Quaternion 创建旋转
---@param scale Vector3|nil 创建缩放
---@param callback fun(obj: Unit|Obstacle|Creature|UnitGroup|Equipment|any)|nil 创建成功后的回调
---@return integer id
function  PrefabFactory:createPrefabWithCb(prefabType, prefabID, pos, rot, scale, callback)
	local objs = self._recyleObjs[prefabID]
	local obj = nil
	-- 缓存里有， 直接返回
	if objs and #objs > 0 then
		obj = table.remove(objs)
		obj.set_model_visible(true)
		if prefabType == self.PrefabType.UNIT_CREATURE then
			obj.set_physic_enable(true)
		end
	end
	local func = self["_create" .. prefabType .. "WithCb"]
	return func(self, obj, prefabID, pos, rot, scale, function(target)
		target.set_kv_by_type(Enums.ValueType.Str, "type", prefabType)
		target.set_kv_by_type(Enums.ValueType.Int, "prefabID", prefabID)
		target.set_kv_by_type(Enums.ValueType.Vector3, "pos", pos)
		target.set_kv_by_type(Enums.ValueType.Quaternion, "rot", rot)
		if callback ~= nil then
			callback(target)
		end
	end)
end

return PrefabFactory
