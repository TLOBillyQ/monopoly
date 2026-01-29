-- 导入所需的模块
local class = require("Utils.ClassUtils").class
local Hero = require("Hero")

---@class HeroManager
---@field new fun(): HeroManager
local HeroManager = class("HeroManager")

---构造函数
function HeroManager:ctor()
	-- 初始化英雄列表
	self.heroes = {}
	-- 遍历所有有效角色
	for _, role in ipairs(GameAPI.get_all_valid_roles()) do
		-- 获取角色控制的单位
		local character = role.get_ctrl_unit()
		-- 创建新的英雄对象
		local hero = Hero.new(character)
		-- 将英雄对象添加到列表中，以角色ID为键
		self.heroes[role.get_roleid()] = hero
	end
end

-- 根据角色ID获取英雄对象
---@param roleId integer 角色id
---@return Hero
function HeroManager:getHero(roleId)
	return self.heroes[roleId]
end

-- 返回HeroManager类
return HeroManager
