-- 导入必要的模块
local FrameLoader = require("Utils.FrameLoader")
local PrefabFactory = require("Utils.PrefabFactory")
local MonsterManager = require("MonsterManager")
local HeroManager = require("HeroManager")
local ItemData = require("Data.ItemData")
local Stage0Demo = require("Stage0Demo")

-- 创建全局表G
G = {}
G.gm = require("GM")

-- 注册游戏初始化事件
LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	-- 为所有有效角色设置装备和重生属性
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		local character = role.get_ctrl_unit()
		character.set_reborn_in_place(true, false)
		-- 创建并装备剑
		local sword = GameAPI.create_equipment(ItemData.Sword.prefabID, character.get_position())
		character.swap_equipment_slot(sword, Enums.EquipmentSlotType.EQUIPPED, 1)
		-- 创建并装备枪
		local gun = GameAPI.create_equipment(ItemData.Gun.prefabID, character.get_position())
		character.swap_equipment_slot(gun, Enums.EquipmentSlotType.EQUIPPED, 2)
	end

	-- 初始化各种管理器
	G.prefabFactory = PrefabFactory.new() -- 预设加载工厂类
	G.frameLoader = FrameLoader.new(1, 1) -- 分帧加载器
	G.monsterManager = MonsterManager.new() -- 怪物管理器
	G.heroManager = HeroManager.new() -- 英雄管理器

	-- 初始化怪物表
	G.monsters = {}

	-- 设置可更新对象列表
	G.tickables = {
		G.frameLoader,
	}

	-- 添加可更新对象的函数
	function G.addTickable(obj)
		assert(obj.update)
		table.insert(G.tickables, obj)
	end

	-- 移除可更新对象的函数
	function G.removeTickable(obj)
		for i, v in ipairs(G.tickables) do
			if v == obj then
				table.remove(G.tickables, i)
				break
			end
		end
	end

	-- 定义每帧更新前的处理函数
	local function onPreTick(_)
		for _, v in ipairs(G.tickables) do
			v:update()
		end
	end

	-- 定义每帧更新后的处理函数（当前为空）
	local function onPostTick() end

	-- 设置帧更新处理器
	LuaAPI.set_tick_handler(onPreTick, onPostTick)

	-- 开始生成怪物
	G.monsterManager:startSpawn()

	-- 阶段0：能力确认示例（日志/UI事件/存档/音效）
	Stage0Demo.install()
end)
