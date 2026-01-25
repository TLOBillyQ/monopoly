---AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT

return {
	[1073741876] = {
		duration = 15.0,
		name = "Boss普攻",
		triggers = {
			{
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			{
				duration = 28,
				frame = 0,
				name = "播放半身动画",
				params = {
					{
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 50,
					},
					{
						name = "持续时间",
						vType = "Fixed",
						value = 0.9666666666,
					},
				},
				time = 0,
				track = 10002,
			},
			{
				duration = 0,
				frame = 3,
				name = "锚点触发器组",
				params = {
					{
						name = "命中伤害",
						vType = "Int",
						value = 0,
					},
				},
				time = 0.0999999999,
				track = 10003,
			},
		},
	},
	[1073745992] = {
		duration = 15.0,
		name = "近战怪2普攻",
		triggers = {
			{
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			{
				duration = 28,
				frame = 0,
				name = "播放半身动画",
				params = {
					{
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 50,
					},
					{
						name = "持续时间",
						vType = "Fixed",
						value = 0.933333333,
					},
				},
				time = 0,
				track = 10002,
			},
			{
				duration = 0,
				frame = 3,
				name = "锚点触发器组",
				params = {
					{
						name = "命中伤害",
						vType = "Int",
						value = 0,
					},
				},
				time = 0.0999999999,
				track = 10003,
			},
		},
	},
	[1073750090] = {
		duration = 15.0,
		name = "editor_ability_10031",
		triggers = {
			{
				duration = 1,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10007",
				params = {
					{
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 7600,
					},
					{
						name = "持续时间",
						vType = "Fixed",
						value = 0.0333333333,
					},
				},
				time = 0,
				track = 10006,
			},
			{
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10039",
				params = {
					{
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 20705,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
				},
				time = 0,
				track = 10005,
			},
			{
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10043",
				params = {
					{
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 5,
					},
				},
				time = 0,
				track = 10007,
			},
			{
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10010",
				params = {
					{
						name = "ABILITY_ANOSTATE_BULLET_OBJ",
						vType = "ObstacleKey",
						value = 1003002,
					},
					{
						name = "ABILITY_ANOSTATE_BULLET_HSPEED",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_BULLET_VSPEED",
						vType = "Fixed",
						value = 20,
					},
					{
						name = "ABILITY_ANOSTATE_BULLET_DUR",
						vType = "Fixed",
						value = 10,
					},
					{
						name = "ABILITY_ANOSTATE_SCALE",
						vType = "Vector3",
						value = math.Vector3(0.5, 0, 0.5),
					},
					{
						name = "ABILITY_ANOSTATE_OFFSET",
						vType = "Vector3",
						value = math.Vector3(0, 1, 0),
					},
					{
						name = "ABILITY_ANOSTATE_BULLET_DAMAGE",
						vType = "Fixed",
						value = 10,
					},
					{
						name = "ABILITY_ANOSTATE_BULLET_HITBUFF",
						vType = "ModifierKey",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 2223,
					},
					{
						name = "ABILITY_ANOSTATE_BULLET_HITDESTROY",
						vType = "Bool",
						value = true,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10004,
			},
		},
	},
	[1073758264] = {
		duration = 15.0,
		name = "近战怪1普攻",
		triggers = {
			{
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			{
				duration = 28,
				frame = 0,
				name = "播放半身动画",
				params = {
					{
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 50,
					},
					{
						name = "持续时间",
						vType = "Fixed",
						value = 0.9666666666,
					},
				},
				time = 0,
				track = 10002,
			},
			{
				duration = 0,
				frame = 3,
				name = "锚点触发器组",
				params = {
					{
						name = "命中伤害",
						vType = "Int",
						value = 0,
					},
				},
				time = 0.0999999999,
				track = 10003,
			},
		},
	},
	[1073762327] = {
		duration = 15.0,
		name = "editor_ability_10031",
		triggers = {
			{
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10037",
				params = {
					{
						name = "ABILITY_ANOSTATE_BULLET_VSPEED",
						vType = "Fixed",
						value = 360,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 3997,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_DAMAGE_DECAY_DISTANCE",
						vType = "Fixed",
						value = 30,
					},
					{
						name = "ABILITY_ANOSTATE_DAMAGE_DECAY_FACTOR",
						vType = "Fixed",
						value = 0.0999999999,
					},
					{
						name = "ABILITY_GUN_BASIC_DAMAGE",
						vType = "Fixed",
						value = 12,
					},
					{
						name = "ABILITY_GUN_BULLET_SFX_ID",
						vType = "SfxKey",
						value = 3992,
					},
					{
						name = "ABILITY_GUN_FIRE_SFX_OFFSET",
						vType = "Vector3",
						value = math.Vector3(0.9399999977, 1.2000000478, 1.730000019),
					},
					{
						name = "ABILITY_GUN_FIRE_SFX_ID",
						vType = "SfxKey",
						value = 3989,
					},
					{
						name = "ABILITY_GUN_FIRE_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_GUN_FIRE_SFX_ROTATION",
						vType = "Vector3",
						value = math.Vector3(0, 0, 0),
					},
					{
						name = "ABILITY_GUN_FIRE_SFX_DUR",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX_ROTATION",
						vType = "Vector3",
						value = math.Vector3(0, 0, 0),
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX_DUR",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX_LOOP",
						vType = "Bool",
						value = false,
					},
					{
						name = "ABILITY_ANOSTATE_HIT_SFX_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_GUN_FIRE_SFX_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10004,
			},
			{
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10007",
				params = {
					{
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 7598,
					},
					{
						name = "持续时间",
						vType = "Fixed",
						value = 0,
					},
				},
				time = 0,
				track = 10006,
			},
			{
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10039",
				params = {
					{
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 20705,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
				},
				time = 0,
				track = 10005,
			},
		},
	},
	[1073774673] = {
		duration = 15.0,
		name = "editor_ability_10038",
		triggers = {
			{
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			{
				duration = 28,
				frame = 0,
				name = "播放半身动画",
				params = {
					{
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					{
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					{
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 50,
					},
					{
						name = "持续时间",
						vType = "Fixed",
						value = 0.9666666666,
					},
				},
				time = 0,
				track = 10002,
			},
			{
				duration = 0,
				frame = 3,
				name = "小怪打击点",
				params = {
					{
						name = "命中伤害",
						vType = "Int",
						value = 0,
					},
				},
				time = 0.0999999999,
				track = 10003,
			},
		},
	},
}
