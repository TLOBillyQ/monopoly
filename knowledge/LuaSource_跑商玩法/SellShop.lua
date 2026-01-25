local class = require("Utils.ClassUtils").class
local TriggerAreaHandler = require("TriggerAreaHandler")

---@class SellShop
---@field new fun(): SellShop
local SellShop = class("SellShop")

function SellShop:ctor()
	-- 起始8点吧
	self._curTime = 8 * 60
	self._curSellDiscount = 1.0
	self._discounts = {}
	for i = 0, 23 do
		self._discounts[i] = 0.5 + LuaAPI.rand() * 3.0
	end
	-- 添加商店的交互区
	local triggerArea = LuaAPI.query_unit("出售区域触发器")
	TriggerAreaHandler.new(triggerArea, function(role)
		G.uiHandler:setItemOpHandler(role, "出售", function()
			self:onSellItem(role)
		end)
	end, function(role)
		G.uiHandler:setItemOpHandler(role, "", nil)
	end)

	-- 注册一个定时器，实现定时刷新时间和出售倍率信息
	LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 1 }, function()
		self:refreshBillBoard()
	end)
end

function SellShop:onSellItem(role)
	local sellItem = G.itemManager:getRoleLiftedItem(role)
	if sellItem then
		local sellPrice = math.tointeger(sellItem.itemData.buyPrice * self._curSellDiscount)
		G.itemManager:sellItem(role, sellItem, sellPrice)
	else
		role.show_tips("请先举起需要出售的商品")
	end
end

-- 更新出售商店公告, 时间， 折扣信息
function SellShop:refreshBillBoard()
	self._curTime = (self._curTime + 1) % (24 * 60)
	local hour = self._curTime // 60
	self._curSellDiscount = self._discounts[hour]
	local billboard = LuaAPI.query_unit("出售公告牌")
	billboard.set_billboard_text(
		string.format("%02d:%02d", self._curTime // 60, self._curTime % 60)
			.. "#n #n出售价格倍率:"
			.. string.format("%.1f", self._curSellDiscount)
	)
end

return SellShop
