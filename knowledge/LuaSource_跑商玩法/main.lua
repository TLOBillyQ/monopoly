-- 导入必要的模块
local SellShop = require("SellShop")
local BuyShop = require("BuyShop")
local ItemManager = require("ItemManager")
local UIHandler = require("UIHandler")

--- 唯一全局变量
G = {}

-- 游戏开始事件
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	-- 初始化物品管理器
	G.itemManager = ItemManager.new()
	-- 初始化购买商店
	G.buyShop = BuyShop.new()
	-- 初始化出售商店
	G.sellShop = SellShop.new()
	-- 初始化UI处理器
	G.uiHandler = UIHandler.new()
end)
