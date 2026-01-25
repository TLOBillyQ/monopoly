local Prefab = require("Data.Prefab")

return {
	Zombie = {
		name = "僵尸",
		prefabID = Prefab.character["近战怪1"],
		scale = 1.0,
		ai = {
			searchTargetDist = math.maxval,
			targetGiveupDist = math.maxval,
			careTargetRange = -1,
			attackDist = 2,
			attackHeight = 1,
			attackCosMin = 0.5,

			patrolRange = 30,
		},
		exp = 5,
	},
	ZombieGiant = {
		name = "巨人僵尸",
		prefabID = Prefab.character["近战怪2"],
		scale = 3.0,
		ai = {
			searchTargetDist = math.maxval,
			targetGiveupDist = math.maxval,
			careTargetRange = -1,
			attackDist = 4,
			attackHeight = 4,
			attackCosMin = 0.5,
			patrolRange = 30,
		},
		exp = 20,
	},
	Soldier = {
		name = "射击怪",
		prefabID = Prefab.character["远程怪"],
		scale = 1.0,
		ai = {
			searchTargetDist = math.maxval,
			targetGiveupDist = math.maxval,
			careTargetRange = -1, -- 目标超过出生点范围
			attackDist = 40,
			attackHeight = 5,
			attackCosMin = 0.9,
			attack_offset = math.Vector3(0.94, 1.2, 1.73),
			patrolRange = 20,
			isShoot = true,
			shootScatter = math.tan(math.deg_to_rad(5)),
		},
		exp = 10,
	},
	Boss = {
		name = "Boss",
		prefabID = Prefab.character.Boss,
		scale = 1.5,
		ai = {
			searchTargetDist = math.maxval,
			targetGiveupDist = math.maxval,
			careTargetRange = -1,
			attackDist = 2 * 1.5,
			attackHeight = 1 * 1.5,
			attackCosMin = 0.5,
			patrolRange = 30,
		},
		size = math.Vector3(0.5, 1.8, 1),
		offset = math.Vector3(0, 1, 1),
		exp = 100,
	},
}
