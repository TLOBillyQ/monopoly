---@type table<AbilityCode, AbilityConfig>
local AbilityConfig = {
    ["treasure_hunt"] = {
        id = 1073786982,
        name = "寻宝",
        introduce = "快速查找附近的宝藏。",
        slot = 1,
        icon = 15691,
        cooldown = "10.0",
    },
    ["dragon_breath_loading"] = {
        id = 1073778698,
        name = "龙息装填",
        introduce = "装填龙息弹药，提高射击效率。",
        slot = 1,
        icon = 15287,
        cooldown = "25.0"
    },
    ["precision_shooting"] = {
        id = 1073791078,
        name = "精准打击",
        introduce = "射出的子弹会追踪目标，提高命中概率。",
        slot = 10,
        icon = 14294
    },
    ["shotgun_shooting"] = {
        id = 1073795134,
        name = "猎枪发射",
        introduce = "猎枪发射一颗子弹对射中目标造成一定伤害。",
        transition = {
            ["hunter"] = "precision_shooting"
        },
        icon = 14294
    },
    ["treasure_bonus"] = {
        id = 1073770564,
        name = "探宝增益",
        introduce = "开箱时更高概率获得高品质宝物。",
        slot = 10,
        icon = 15275
    },
    ["flashlight_switch_on"] = {
        id = 0,
        name = "开启手电",
        introduce = "打开手电筒"
    },
    ["flashlight_switch_off"] = {
        id = 1,
        name = "关闭手电",
        introduce = "关闭手电筒"
    }
}

return AbilityConfig