---AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT

return {
	[1073745935] = {
		duration = 15.0,
		name = "开启手电",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073750075] = {
		duration = 15.0,
		name = "开启手电",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073754128] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 30,
				frame = 0,
				name = "无视失控",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10003,
			},
			[3] = {
				duration = 19,
				frame = 11,
				name = "创建音效",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.6333333334,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 4849,
					},
				},
				time = 0.3666666665,
				track = 10002,
			},
			[4] = {
				duration = 0,
				frame = 18,
				name = "施加环绕矩形范围打击",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 2295,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_BULLET_HITBUFF",
						vType = "ModifierKey",
						value = 0,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_HITPOWER",
						vType = "Fixed",
						value = 300,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_BULLET_DAMAGE",
						vType = "Fixed",
						value = 10,
					},
					[6] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.2999999999,
					},
					[7] = {
						name = "ABILITY_ANOSTATE_CASTANGOFF",
						vType = "Fixed",
						value = 100,
					},
					[8] = {
						name = "ABILITY_ANOSTATE_FACE_SYNC",
						vType = "Bool",
						value = true,
					},
					[9] = {
						name = "ABILITY_ANOSTATE_ASPEED",
						vType = "Vector3",
						value = math.Vector3(0, -570, 0),
					},
					[10] = {
						name = "ABILITY_ANOSTATE_HITBOX_SCALE",
						vType = "Vector3",
						value = math.Vector3(1.2000000478, 3, 4),
					},
					[11] = {
						name = "ABILITY_ANOSTATE_HITBOX_OFFSET",
						vType = "Vector3",
						value = math.Vector3(3.5, 0, 0),
					},
				},
				time = 0.5999999999,
				track = 10001,
			},
		},
	},
	[1073758267] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 30,
				frame = 0,
				name = "无视失控",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10003,
			},
			[3] = {
				duration = 20,
				frame = 10,
				name = "创建音效",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 4849,
					},
					[2] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.6666666666,
					},
				},
				time = 0.3333333333,
				track = 10002,
			},
			[4] = {
				duration = 0,
				frame = 18,
				name = "施加环绕矩形范围打击",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_HITBOX_OFFSET",
						vType = "Vector3",
						value = math.Vector3(3.5, 0, 0),
					},
					[2] = {
						name = "ABILITY_ANOSTATE_HITBOX_SCALE",
						vType = "Vector3",
						value = math.Vector3(1.2000000478, 3, 4),
					},
					[3] = {
						name = "ABILITY_ANOSTATE_ASPEED",
						vType = "Vector3",
						value = math.Vector3(0, -570, 0),
					},
					[4] = {
						name = "ABILITY_ANOSTATE_FACE_SYNC",
						vType = "Bool",
						value = true,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_CASTANGOFF",
						vType = "Fixed",
						value = 100,
					},
					[6] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.2999999999,
					},
					[7] = {
						name = "ABILITY_ANOSTATE_BULLET_DAMAGE",
						vType = "Fixed",
						value = 10,
					},
					[8] = {
						name = "ABILITY_ANOSTATE_HITPOWER",
						vType = "Fixed",
						value = 300,
					},
					[9] = {
						name = "ABILITY_ANOSTATE_BULLET_HITBUFF",
						vType = "ModifierKey",
						value = 0,
					},
					[10] = {
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 2295,
					},
					[11] = {
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0.5999999999,
				track = 10001,
			},
		},
	},
	[1073762400] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 30,
				frame = 0,
				name = "无视失控",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10003,
			},
			[3] = {
				duration = 19,
				frame = 11,
				name = "创建音效",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.6333333334,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 4849,
					},
				},
				time = 0.3666666665,
				track = 10002,
			},
			[4] = {
				duration = 0,
				frame = 18,
				name = "施加环绕矩形范围打击",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 2295,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_BULLET_HITBUFF",
						vType = "ModifierKey",
						value = 0,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_HITPOWER",
						vType = "Fixed",
						value = 300,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_BULLET_DAMAGE",
						vType = "Fixed",
						value = 10,
					},
					[6] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.2999999999,
					},
					[7] = {
						name = "ABILITY_ANOSTATE_CASTANGOFF",
						vType = "Fixed",
						value = 100,
					},
					[8] = {
						name = "ABILITY_ANOSTATE_FACE_SYNC",
						vType = "Bool",
						value = true,
					},
					[9] = {
						name = "ABILITY_ANOSTATE_ASPEED",
						vType = "Vector3",
						value = math.Vector3(0, -570, 0),
					},
					[10] = {
						name = "ABILITY_ANOSTATE_HITBOX_SCALE",
						vType = "Vector3",
						value = math.Vector3(1.2000000478, 3, 4),
					},
					[11] = {
						name = "ABILITY_ANOSTATE_HITBOX_OFFSET",
						vType = "Vector3",
						value = math.Vector3(3.5, 0, 0),
					},
				},
				time = 0.5999999999,
				track = 10001,
			},
		},
	},
	[1073766432] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 30,
				frame = 0,
				name = "播放半身动画",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 20701,
					},
					[5] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10001,
			},
			[3] = {
				duration = 30,
				frame = 0,
				name = "无视失控",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0,
				track = 10004,
			},
			[4] = {
				duration = 27,
				frame = 3,
				name = "创建音效",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 4849,
					},
					[2] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.9,
					},
				},
				time = 0.0999999999,
				track = 10003,
			},
			[5] = {
				duration = 0,
				frame = 8,
				name = "施加环绕矩形范围打击",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_HITBOX_OFFSET",
						vType = "Vector3",
						value = math.Vector3(1.75, 1, 0),
					},
					[2] = {
						name = "ABILITY_ANOSTATE_HITBOX_SCALE",
						vType = "Vector3",
						value = math.Vector3(1.2000000478, 1.2000000478, 3.5),
					},
					[3] = {
						name = "ABILITY_ANOSTATE_ASPEED",
						vType = "Vector3",
						value = math.Vector3(0, -800, 0),
					},
					[4] = {
						name = "ABILITY_ANOSTATE_FACE_SYNC",
						vType = "Bool",
						value = false,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_CASTANGOFF",
						vType = "Fixed",
						value = 100,
					},
					[6] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.2999999999,
					},
					[7] = {
						name = "ABILITY_ANOSTATE_BULLET_DAMAGE",
						vType = "Fixed",
						value = 10,
					},
					[8] = {
						name = "ABILITY_ANOSTATE_HITPOWER",
						vType = "Fixed",
						value = 300,
					},
					[9] = {
						name = "ABILITY_ANOSTATE_BULLET_HITBUFF",
						vType = "ModifierKey",
						value = 0,
					},
					[10] = {
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 342,
					},
					[11] = {
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0.2666666667,
				track = 10002,
			},
		},
	},
	[1073770564] = {
		duration = 15.0,
		name = "寻宝",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073774700] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073778698] = {
		duration = 15.0,
		name = "寻宝",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073782904] = {
		duration = 15.0,
		name = "寻宝",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073786982] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073791078] = {
		duration = 15.0,
		name = "空技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073795134] = {
		duration = 15.0,
		name = "寻宝",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 0,
				frame = 4,
				name = "UI_ABILITY_ANCHOR_10010",
				params = {
					[1] = {
						name = "投射物预设",
						vType = "ObstacleKey",
						value = 1073745998,
					},
					[2] = {
						name = "垂直速度",
						vType = "Fixed",
						value = 0,
					},
					[3] = {
						name = "水平速度",
						vType = "Fixed",
						value = 20,
					},
					[4] = {
						name = "投射物生命周期",
						vType = "Fixed",
						value = 10,
					},
					[5] = {
						name = "缩放",
						vType = "Vector3",
						value = math.Vector3(1, 1, 1),
					},
					[6] = {
						name = "偏移位置",
						vType = "Vector3",
						value = math.Vector3(0, 1, 0),
					},
					[7] = {
						name = "击中伤害",
						vType = "Fixed",
						value = 10,
					},
					[8] = {
						name = "击中效果",
						vType = "ModifierKey",
						value = 0,
					},
					[9] = {
						name = "击中特效",
						vType = "SfxKey",
						value = 0,
					},
					[10] = {
						name = "击中销毁投射物",
						vType = "Bool",
						value = false,
					},
					[11] = {
						name = "击中特效缩放",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0.133333333333,
				track = 10003,
			},
			[3] = {
				duration = 3,
				frame = 4,
				name = "UI_ABILITY_ANCHOR_10007",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 7598,
					},
					[2] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.1,
					},
				},
				time = 0.133333333333,
				track = 10001,
			},
		},
	},
	[1073799230] = {
		duration = 15.0,
		name = "自定义技能",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
		},
	},
	[1073803342] = {
		duration = 15.0,
		name = "小丑抽刀",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 15,
				frame = 0,
				name = "禁止施法者能力",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.5,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_DISABLE_JUMP",
						vType = "Bool",
						value = true,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_DISABLE_RUSH",
						vType = "Bool",
						value = true,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_DISABLE_ROLL",
						vType = "Bool",
						value = true,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_DISABLE_CATCH",
						vType = "Bool",
						value = true,
					},
				},
				time = 0,
				track = 10002,
			},
			[3] = {
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10040",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_QUD",
						vType = "Vector3",
						value = math.Vector3(0, 0, 0),
					},
					[2] = {
						name = "ABILITY_ANOSTATE_BINDSOCKET",
						vType = "ModelSocket",
						value = "ugc_hand_r",
					},
					[3] = {
						name = "ABILITY_ANOSTATE_NEW_SFX",
						vType = "SfxKey",
						value = 4440,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.5,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_OFFSET",
						vType = "Vector3",
						value = math.Vector3(0, 0, 0),
					},
					[6] = {
						name = "ABILITY_ANOSTATE_SCALE",
						vType = "Fixed",
						value = 0.5,
					},
				},
				time = 0,
				track = 10004,
			},
			[4] = {
				duration = 15,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10013",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 20701,
					},
					[5] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.5,
					},
				},
				time = 0,
				track = 10003,
			},
			[5] = {
				duration = 30,
				frame = 5,
				name = "创建音效",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_NEW_SOUND",
						vType = "SoundKey",
						value = 4849,
					},
					[2] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1,
					},
				},
				time = 0.1666666666,
				track = 10004,
			},
			[6] = {
				duration = 0,
				frame = 10,
				name = "锚点触发器组",
				params = {},
				time = 0.3333333333,
				track = 10005,
			},
			[7] = {
				duration = 50.0,
				frame = 10,
				name = "UI_ABILITY_ANCHOR_10013",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 1.6666666666,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 20683,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
				},
				time = 0.3333333333,
				track = 10006,
			},
			[8] = {
				duration = 0,
				frame = 48,
				name = "播放融合动画",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_ANIM_FIXMODE",
						vType = "Int",
						value = 0,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = true,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 5,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					[6] = {
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 22,
					},
				},
				time = 1.5999999999,
				track = 10007,
			},
		},
	},
	[1073807466] = {
		duration = 15.0,
		name = "右拳击",
		triggers = {
			[1] = {
				duration = 0,
				frame = 0,
				name = "激活冷却",
				params = {},
				time = 0,
				track = 10000,
			},
			[2] = {
				duration = 15,
				frame = 0,
				name = "禁止施法者能力",
				params = {
					[1] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.5,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_DISABLE_JUMP",
						vType = "Bool",
						value = true,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_DISABLE_RUSH",
						vType = "Bool",
						value = true,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_DISABLE_ROLL",
						vType = "Bool",
						value = true,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_DISABLE_CATCH",
						vType = "Bool",
						value = true,
					},
				},
				time = 0,
				track = 10002,
			},
			[3] = {
				duration = 0,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10040",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_QUD",
						vType = "Vector3",
						value = math.Vector3(0, 0, 0),
					},
					[2] = {
						name = "ABILITY_ANOSTATE_BINDSOCKET",
						vType = "ModelSocket",
						value = "ugc_hand_r",
					},
					[3] = {
						name = "ABILITY_ANOSTATE_NEW_SFX",
						vType = "SfxKey",
						value = 4440,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.5,
					},
					[5] = {
						name = "ABILITY_ANOSTATE_OFFSET",
						vType = "Vector3",
						value = math.Vector3(0, 0, 0),
					},
					[6] = {
						name = "ABILITY_ANOSTATE_SCALE",
						vType = "Fixed",
						value = 0.5,
					},
				},
				time = 0,
				track = 10004,
			},
			[4] = {
				duration = 15,
				frame = 0,
				name = "UI_ABILITY_ANCHOR_10013",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_LOOP",
						vType = "Bool",
						value = false,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_ANIM_SPEED",
						vType = "Fixed",
						value = 1,
					},
					[3] = {
						name = "ABILITY_ANOSTATE_ANIM_STARTPOINT",
						vType = "Fixed",
						value = 0,
					},
					[4] = {
						name = "ABILITY_ANOSTATE_ANIMKEY",
						vType = "AnimKey",
						value = 20701,
					},
					[5] = {
						name = "持续时间",
						vType = "Fixed",
						value = 0.5,
					},
				},
				time = 0,
				track = 10003,
			},
			[5] = {
				duration = 0,
				frame = 10,
				name = "UI_ABILITY_ANCHOR_10015",
				params = {
					[1] = {
						name = "ABILITY_ANOSTATE_USECASTPOS",
						vType = "Bool",
						value = true,
					},
					[2] = {
						name = "ABILITY_ANOSTATE_OFFSET",
						vType = "Vector3",
						value = math.Vector3(0, 1, 0.300000012),
					},
					[3] = {
						name = "ABILITY_ANOSTATE_CASTANGOFF",
						vType = "Vector3",
						value = math.Vector3(0, -45, 0),
					},
					[4] = {
						name = "ABILITY_ANOSTATE_AREA",
						vType = "Vector3",
						value = math.Vector3(1, 2, 2),
					},
					[5] = {
						name = "ABILITY_ANOSTATE_DUR",
						vType = "Fixed",
						value = 0.15,
					},
					[6] = {
						name = "ABILITY_ANOSTATE_HITPOWER",
						vType = "Fixed",
						value = 100,
					},
					[7] = {
						name = "ABILITY_ANOSTATE_BULLET_DAMAGE",
						vType = "Fixed",
						value = 10,
					},
					[8] = {
						name = "ABILITY_ANOSTATE_BULLET_HITBUFF",
						vType = "ModifierKey",
						value = 0,
					},
					[9] = {
						name = "ABILITY_ANOSTATE_HIT_SFX",
						vType = "SfxKey",
						value = 3943,
					},
					[10] = {
						name = "ABILITY_ANOSTATE_HIT_SFX_SCALE",
						vType = "Fixed",
						value = 0.5999999999,
					},
				},
				time = 0.3333333333,
				track = 10004,
			},
		},
	},
}
