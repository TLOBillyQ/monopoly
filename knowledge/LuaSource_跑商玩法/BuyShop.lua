-- 导入所需的模块和类
local class = require("Utils.ClassUtils").class
local ItemData = require("Data.ItemData")
local TriggerAreaHandler = require("TriggerAreaHandler")

---@class BuyShop
---@field new fun(): BuyShop
local BuyShop = class("BuyShop")

-- 构造函数，初始化商店
function BuyShop:ctor()
	-- 初始化商店相关的数据结构
	self.shopTriggerIds = {} -- 存储商店触发器ID
	self.deskItems = {} -- 存储桌子上的商品
	self.shopCountDowns = {} -- 存储商店刷新倒计时
	self.roleInAreas = {} -- 存储在区域内的角色

	for i = 1, 2 do
		-- 查询商品桌子单位
		local desk = LuaAPI.query_unit("商品桌子" .. i)
		-- 随机添加商品到桌子上
		self:randomAddItem(desk)

		-- 获取商品触发器
		local triggerArea = desk.get_child_by_name("商品触发器")
		-- 创建触发器处理器
		TriggerAreaHandler.new(triggerArea, function(role)
			-- 进入了出售区域, 显示玩家购买按钮
			G.uiHandler:setItemOpHandler(role, "购买", function()
				local deskUnitId = LuaAPI.get_unit_id(desk)
				local item = self.deskItems[deskUnitId]
				-- 尝试购买商品
				-- 购买商品
				if item and G.itemManager:buyItem(role, item) then
					-- 购买成功后，进入刷新状态
					self:enterRefreshState(desk)
					-- 销毁已购买的商品
					G.itemManager:destroyItem(item)
					-- 从桌子上移除商品
					self.deskItems[deskUnitId] = nil
				end
			end)
		end, function(role)
			-- 角色离开出售区域时，移除购买按钮
			G.uiHandler:setItemOpHandler(role, "", nil)
		end)
	end
end

-- 在指定位置创建商品道具
function BuyShop:bindShopItem(itemKey, deskObj)
	local itemData = ItemData[itemKey]
	-- 计算商品的目标位置（在桌子上方2个单位）
	local targetPos = deskObj.get_position() + math.Vector3(0, 2, 0)
	-- 获取商品的旋转（如果没有指定，则使用默认值）
	local targetRot = itemData.rot or math.Quaternion(0, 0, 0)
	-- 创建商品
	local item = G.itemManager:createItem(itemKey, targetPos, targetRot)
	-- 获取桌子的单位ID
	local deskUnitId = LuaAPI.get_unit_id(deskObj)
	-- 将商品与桌子关联
	self.deskItems[deskUnitId] = item
	-- 设置商品不可被抓举和物理交互
	local unit = item.itemObj
	unit.set_lifted_enabled(false)
	unit.set_physics_active(false)
	-- 更新商品公告牌的内容
	local billboard = deskObj.get_child_by_name("商品公告牌")
	billboard.set_billboard_content(itemKey .. "#n #n$" .. itemData.buyPrice)
	return item
end

-- 购买后，进入商店道具刷新阶段， 3s后随机重新选择道具上架出售
function BuyShop:enterRefreshState(deskObj)
	-- 获取商品公告牌
	local billboard = deskObj.get_child_by_name("商品公告牌")
	-- 获取桌子的单位ID
	local unitId = LuaAPI.get_unit_id(deskObj)
	-- 定义更新倒计时的函数
	local function updateCountDown()
		local second = self.shopCountDowns[unitId].countDown
		second = second - 1
		self.shopCountDowns[unitId].countDown = second
		-- 更新公告牌显示的倒计时
		billboard.set_billboard_content("刷新倒计时#n #n" .. second)
		-- 倒计时结束时，随机添加新商品并取消定时器
		if second < 1 then
			self:randomAddItem(deskObj)
			LuaAPI.global_unregister_trigger_event(self.shopCountDowns[unitId].timerId)
		end
	end
	-- 注册定时器，每秒更新一次倒计时
	local timerId = LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 1.0 }, function()
		updateCountDown()
	end)
	-- 初始化倒计时数据
	self.shopCountDowns[unitId] = { timerId = timerId, countDown = 4 }
	-- 立即更新一次倒计时
	updateCountDown()
end

-- 根据概率随机选择一个道具上架出售
function BuyShop:randomAddItem(deskObj)
	local items = {}
	local totalWeight = 0
	-- 遍历所有商品数据，准备随机选择
	for itemKey, itemData in pairs(ItemData) do
		-- 将商品数据添加到items表中
		table.insert(items, itemKey)
		totalWeight = totalWeight + itemData.probability
	end
	-- 生成随机数
	local randomValue = LuaAPI.rand() * totalWeight
	-- 选择项目
	local currentWeight = 0
	for _, itemKey in ipairs(items) do
		currentWeight = currentWeight + ItemData[itemKey].probability
		if randomValue <= currentWeight then
			-- 将选中的商品绑定到指定的桌子上
			self:bindShopItem(itemKey, deskObj)
			return
		end
	end
end

return BuyShop
