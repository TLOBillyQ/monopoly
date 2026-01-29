-- 导入所需的模块
local class = require("Utils.ClassUtils").class
local UINodes = require("Data.UINodes")
local LevelData = require("Data.HeroLevelData")
local Consts = require("Data.Consts")

---@class Hero
---@field new fun(Character): Hero
local Hero = class("Hero")

---构造函数，初始化英雄
---@param character Character 角色对象
function Hero:ctor(character)
	self.character = character -- 设置英雄的角色
	self.level = 1 -- 初始等级为1
	self.exp = 0 -- 初始经验值为0
	local role = GameAPI.get_role(self.character.get_role_id()) -- 获取角色对象
	self.setLevel(self.level) -- 设置初始等级
	role.set_progressbar_current(UINodes["经验值"], self.exp) -- 设置经验值进度条当前值
	role.set_progressbar_max(UINodes["经验值"], self:getLevelUpExp()) -- 设置经验值进度条最大值
end

---获取升到下一级级所需经验值
function Hero:getLevelUpExp()
	return LevelData[self.level + 1].exp
end

-- 设置英雄等级
function Hero:setLevel(level)
	local levelData = LevelData[level]
	if levelData == nil then
		return
	end
	self.level = level
	-- 设置hp
	local maxHp = levelData.hpMax
	local hpDelta = maxHp - self.character.get_hp_max()
	self.character.set_attr_by_type(Enums.ValueType.Fixed, "hp_max", levelData.hpMax)
	self.character.change_hp(hpDelta)

	-- 设置移动速度
	self.character.set_attr_ratio_fixed("move_speed", levelData.moveSpd - 1.0)

	-- 设置攻击力
	self.character.set_attr_by_type(Enums.ValueType.Fixed, Consts.CHARACTER_DMG_INC_RATIO_KEY, levelData.atkRatio - 1.0)

	local role = GameAPI.get_role(self.character.get_role_id())
	role.set_label_text(UINodes["等级"], "当前等级：" .. self.level) -- 更新等级显示
	local nextLevelData = LevelData[self.level + 1]
	if nextLevelData ~= nil then
		role.set_progressbar_max(UINodes["经验值"], nextLevelData.exp) -- 设置下一级所需经验值
	else
		self.exp = 0
		role.set_progressbar_current(UINodes["经验值"], 0) -- 如果已达最高等级，重置经验值
	end
end

-- 增加经验值
function Hero:addExp(delta)
	self.exp = self.exp + delta
	local nextLevelData = LevelData[self.level + 1]
	if nextLevelData ~= nil then
		local nextLevelExp = nextLevelData.exp
		if self.exp >= nextLevelExp then
			self.exp = self.exp - nextLevelExp
			self:setLevel(self.level + 1)
		end
		local role = GameAPI.get_role(self.character.get_role_id())
		role.set_progressbar_current(UINodes["经验值"], self.exp)
	end
end

return Hero
