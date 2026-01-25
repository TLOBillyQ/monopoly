-- 导入模块
local GoodData = require("Data.GoodsData")
local UINodes = require("Data.UINodes")

local function refresh_mall_panel(role)
	-- 爱心金币
	local love_gold_count = role.get_commodity_count(GoodData.loveGold.commodityId)
	role.set_label_text(UINodes["爱心金币数量"], "已有数量："..tostring(love_gold_count))
	-- 通行证
	local passport_count = role.get_commodity_count(GoodData.passport.commodityId)
	role.set_label_text(UINodes["通行证数量"], "已有数量："..tostring(passport_count))
	-- 通行证购买限制
	buy_btn_text = "购买"
	if passport_count > 0 then
		buy_btn_text = "已拥有"
	end
	role.set_button_text(UINodes["通行证购买按钮"], buy_btn_text)
end

local function register_events()
	-- 注册购买按钮的点击事件
	LuaAPI.global_register_custom_event("点击爱心金币购买按钮", function(_, _, data)
		local role = data.role
		-- 显示购买商品面板
		role.show_goods_purchase_panel(GoodData.loveGold.goodsId, 10.0)
	end)
	LuaAPI.global_register_custom_event("点击通行证购买按钮", function(_, _, data)
		local role = data.role
		if role.get_commodity_count(GoodData.passport.commodityId) > 0 then
			role.show_tips("已拥有", 2.0)
		else
			-- 显示购买商品面板
			role.show_goods_purchase_panel(GoodData.passport.goodsId, 10.0)
		end
	end)
	-- 注册使用按钮的点击事件
	LuaAPI.global_register_custom_event("点击爱心金币使用按钮", function(_, _, data)
		local role = data.role
		-- 消耗商品并显示提示信息
		if role.get_commodity_count(GoodData.loveGold.commodityId) > 0 then
			role.consume_commodity(GoodData.loveGold.commodityId, 1)
			role.show_tips("使用成功", 2.0)
			-- 刷新商城面板
			refresh_mall_panel(role)
		else
			role.show_tips("数量不足", 2.0)
		end
	end)
end

-- 游戏开始事件
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	-- 注册事件
	register_events()
	-- 获取所有有效角色
	local allRoles = GameAPI.get_all_valid_roles()
	for _, role in ipairs(allRoles) do
		-- 刷新商城界面
		refresh_mall_panel(role)
		-- 注册购买成功事件
		LuaAPI.global_register_trigger_event({ EVENT.SPEC_ROLE_PURCHASE_GOODS, role.get_roleid() }, function(_, _, data)
			-- 刷新角色的商城界面
			refresh_mall_panel(role)
		end)
	end
end)
