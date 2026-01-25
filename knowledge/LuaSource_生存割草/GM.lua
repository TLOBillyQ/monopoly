local MonsterData = require("Data.MonsterData")
local Monster = require("Monster")
local GM = {}

function GM.hp_max(hp_max)
	hp_max = hp_max or 999999999.0
	local roles = GameAPI.get_all_valid_roles()
	for _, role in ipairs(roles) do
		local unit = role.get_ctrl_unit()
		unit.set_attr_by_type(Enums.ValueType.Fixed, "hp_max", hp_max)
		unit.set_attr_by_type(Enums.ValueType.Fixed, "hp_cur", hp_max)
	end
end

function GM.hp(hp)
	local roles = GameAPI.get_all_valid_roles()
	for _, role in ipairs(roles) do
		local unit = role.get_ctrl_unit()
		unit.set_attr_by_type(Enums.ValueType.Fixed, "hp_cur", hp)
	end
end

function GM.hp_percent(hp)
	local roles = GameAPI.get_all_valid_roles()
	for _, role in ipairs(roles) do
		local unit = role.get_ctrl_unit()
		local hp_max = unit.get_attr_by_type(Enums.ValueType.Fixed, "hp_max")
		unit.set_attr_by_type(Enums.ValueType.Fixed, "hp_cur", hp_max * hp / 100.0)
	end
end

function GM.character_die()
	local roles = GameAPI.get_all_valid_roles()
	for _, role in ipairs(roles) do
		local unit = role.get_ctrl_unit()
		unit.change_hp(-10000000.0)
	end
end

function GM.monster_die()
	for _, monster in ipairs(G.monsterManager.monsters) do
		monster.unit.change_hp(-10000000.0)
	end
end

function GM.generate_monster(monsterKey, count)
	local monsterData = MonsterData[monsterKey]
	for _ = 1, count do
		local monster = Monster.new(monsterData, math.Vector3(0.0, 3.0, 0.0), math.Quaternion(0.0, 0.0, 0.0), nil)
		table.insert(G.monsters, monster)
	end
end

return GM
