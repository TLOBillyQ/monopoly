local chest_position_list = GameAPI.get_unit(1692605421).get_children()
local C_chest_list = GameAPI.get_unit(1368491374).get_children()
local B_chest_list = GameAPI.get_unit(1484164189).get_children()
local A_chest_list = GameAPI.get_unit(2042785604).get_children()


local A_treasure_config = {
    experience = 3,
    color = 0x800080,
    max_progress = 30 * 45,
    rewards = {
        {
            weight = 70,
            code = "bronze_tripod"
        },
        {
            weight = 25,
            code = "gold_watch"
        },
        {
            weight = 5,
            code = "golden_sculpture"
        }
    },
    used = A_chest_list
}
local B_treasure_config = {
    experience = 2,
    color = 0xc0c0c0,
    max_progress = 30 * 30,
    rewards = {
        {
            weight = 100,
            code = "bronze_coin"
        },
        {
            weight = 100,
            code = "bronze_cup"
        },
        {
            weight = 25,
            code = "bronze_sculpture"
        }
    },
    used = B_chest_list
}
local C_treasure_config = {
    experience = 1,
    color = 0xB87333,
    max_progress = 30 * 15,
    rewards = {
        {
            weight = 100,
            code = "teddy_bear"
        },
        {
            weight = 100,
            code = "embroidered_tension"
        },
        {
            weight = 50,
            code = "stone_sculpture"
        }
    },
    used = C_chest_list
}

---@type LootChestManagerConfig
local config = {
    position_unit_list = chest_position_list,
    chest = {
        A_treasure_config,
        B_treasure_config,
        C_treasure_config
    }
}
return config
