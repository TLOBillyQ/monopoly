-- 定义 ItemManager 类
local class = require("Utils.ClassUtils").class
local ItemData = require("Data.ItemData")

---@class ItemManager
---@field new fun(): ItemManager
local ItemManager = class("ItemManger")

function ItemManager:ctor()
	-- 初始化角色举起物品的映射表
	self._char2lift = {}
	-- 初始化物品ID到物品数据的映射表
	self._id2ItemData = {}

	-- 遍历所有物品数据，建立ID到数据的映射
	for _, itemData in pairs(ItemData) do
		self._id2ItemData[itemData.prefabID] = itemData
	end

	-- 获取所有有效角色
	local allRoles = GameAPI.get_all_valid_roles()
	-- 为每个角色注册事件
	for _, role in ipairs(allRoles) do
		local character = role.get_ctrl_unit()
		self:registerEvents(character)
	end
end

function ItemManager:registerEvents(character)
	-- 注册角色举起物品的事件
	LuaAPI.unit_register_trigger_event(character, { EVENT.SPEC_LIFEENTITY_LIFT_BEGAN }, function(_, _, data)
		local itemObj = data.lifted_unit
		-- 禁用物品的物理效果
		itemObj.set_physics_active(false)
		-- 记录角色举起的物品信息
		self._char2lift[character.get_role_id()] =
			{ itemData = self._id2ItemData[itemObj.get_key()], itemObj=itemObj}
	end)

	-- 注册角色放下物品的事件
	LuaAPI.unit_register_trigger_event(character, { EVENT.SPEC_LIFEENTITY_LIFT_ENDED }, function(_, _, data)
		local unit = data.lift_unit
		local itemObj = data.lifted_unit
		-- 重新启用物品的物理效果
		itemObj.set_physics_active(true)
		-- 计算放下物品的位置
		local direction = unit.get_orientation():apply(math.Vector3(0, 0, 1))
		itemObj.set_position(unit.get_position() + direction)
		-- 清除角色举起物品的记录
		self._char2lift[character.get_role_id()] = nil
	end)
end

-- 创建商品
function ItemManager:createItem(itemKey, targetPos, targetRot)
	local itemData = ItemData[itemKey]
	local prefabId = itemData.prefabID
	local scale = itemData.scale or math.Vector3(1, 1, 1)
	-- 在指定位置创建物品
	local unit = GameAPI.create_obstacle(prefabId, targetPos, targetRot or math.Quaternion(0, 0, 0), scale)
	-- 设置物品朝向
	-- unit.set_orientation(targetRot or math.Quaternion(0, 0, 0))
	local item = { name = itemKey, itemData = itemData, itemObj=unit}
	-- 设置物品可被举起
	unit.set_lifted_enabled(true)
	-- 禁用物品交互
	unit.set_interact_enabled(false)
	-- 启用自定义投掷力度
	unit.set_custom_thrown_force_enabled(true)
	-- 设置投掷力度为0
	unit.set_custom_thrown_force(math.toreal(0))
	return item
end

-- 销毁商品
function ItemManager:destroyItem(item)
	item.itemObj.destroy()
end

-- 购买商品
function ItemManager:buyItem(role, item)
	-- 获取角色当前金钱
	local money = role.get_kv_by_type(Enums.ValueType.Int, "money")
	local buyPrice = item.itemData.buyPrice

	-- 检查金钱是否足够
	if money < buyPrice then
		role.show_tips("金币不足")
		return false
	end

	-- 扣除金钱
	money = money - buyPrice
	role.set_kv_by_type(Enums.ValueType.Int, "money", money)
	-- 更新UI显示
	G.uiHandler:updateRoleMoneyUI(role)

	-- 创建并给予商品
	local character = role.get_ctrl_unit()
	self:createItem(item.name, character.get_position())
	return true
end

-- 出售商品
function ItemManager:sellItem(role, item, sellPrice)
	-- 获取角色当前金钱
	local money = role.get_kv_by_type(Enums.ValueType.Int, "money")
	-- 增加金钱
	money = money + sellPrice
	role.set_kv_by_type(Enums.ValueType.Int, "money", money)
	-- 更新UI显示
	G.uiHandler:updateRoleMoneyUI(role)
	-- 销毁商品
	self:destroyItem(item)
end

-- 获取指定角色当前举起的商品信息
function ItemManager:getRoleLiftedItem(role)
	return self._char2lift[role.get_roleid()]
end

return ItemManager
