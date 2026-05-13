local INV = {
    free_rent     = { [2001] = 1 },
    remote_dice   = { [2002] = 1 },
    dice_mult     = { [2003] = 1 },
    roadblock     = { [2004] = 1 },
    mine          = { [2005] = 1 },
    clear_obs     = { [2006] = 1 },
    steal         = { [2007] = 1 },
    monster       = { [2008] = 1 },
    strong        = { [2009] = 1 },  -- 金豆
    tax_free      = { [2010] = 1 },  -- 金豆
    share_wealth  = { [2011] = 1 },  -- 金豆
    exile         = { [2012] = 1 },
    missile       = { [2013] = 1 },  -- 金豆
    tax           = { [2014] = 1 },  -- 金豆
    invite_deity  = { [2015] = 1 },  -- 金豆
    send_poor     = { [2016] = 1 },  -- 金豆
    rich          = { [2017] = 1 },  -- 金豆
    poor          = { [2018] = 1 },  -- 金豆
    angel         = { [2019] = 1 },  -- 金豆
}

local constants = require("src.config.content.constants")

local TILE = {
    start = 35, hospital = 36, mountain = 37, market = 39, chance_inner = 40, item_inner = 44,
}

local function _merge_inv(...)
    local out = {}
    for _, src in ipairs({ ... }) do for k, v in pairs(src) do out[k] = (out[k] or 0) + v end end
    return out
end

local function _deity(t, r) return { deity = { type = t, remaining = r or constants.deity_duration_turns } } end

local function _mk_players(default_cash, p1_tile, overrides)
    local players = {
        [1] = { cash = default_cash, position_tile_id = p1_tile },
        [2] = { cash = default_cash, position_tile_id = TILE.start },
        [3] = { cash = default_cash, position_tile_id = TILE.item_inner },
        [4] = { cash = default_cash, position_tile_id = TILE.chance_inner },
    }
    for index, override in pairs(overrides or {}) do
        for k, v in pairs(override) do players[index][k] = v end
    end
    return players
end

local profiles = {

    solo_free_rent = {
        group = "property_control",
        covers = { "free_rent", "rent_response" },
        bootstrap = {
            players = _mk_players(120000, 11, {
                [1] = { item_counts = _merge_inv(INV.free_rent, INV.remote_dice) },
            }),
            tiles = { [12] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    solo_remote_dice = {
        group = "economy_core",
        covers = { "remote_dice", "dice_control" },
        bootstrap = {
            players = _mk_players(120000, TILE.start, {
                [1] = { item_counts = INV.remote_dice },
            }),
        },
    },

    solo_dice_multiplier = {
        group = "economy_core",
        covers = { "dice_multiplier", "dice_multiply" },
        bootstrap = {
            players = _mk_players(120000, TILE.start, {
                [1] = { item_counts = _merge_inv(INV.dice_mult, INV.remote_dice) },
            }),
        },
    },

    solo_roadblock = {
        group = "combat_obstacle",
        covers = { "roadblock", "manual_place" },
        bootstrap = {
            players = _mk_players(120000, 7, { [1] = { item_counts = INV.roadblock } }),
        },
    },

    solo_mine = {
        group = "combat_obstacle",
        covers = { "mine", "manual_arm" },
        bootstrap = {
            players = _mk_players(120000, 7, { [1] = { item_counts = INV.mine } }),
        },
    },

    solo_clear_obstacles = {
        group = "combat_obstacle",
        covers = { "clear_obstacles", "fork_branch", "overlay_cleanup" },
        bootstrap = {
            players = _mk_players(120000, 3, {
                [1] = { item_counts = INV.clear_obs, statuses = { move_dir = "left" } },
            }),
            overlays = {
                roadblocks = {
                    { tile_id = 8,  render_called = true },
                    { tile_id = 41, render_called = true },
                    { tile_id = 42, render_called = true },
                },
                mines = { { tile_id = 41, render_called = true } },
            },
        },
    },

    solo_steal = {
        group = "interrupt_resume",
        covers = { "steal", "pass_player" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = _merge_inv(INV.steal, INV.remote_dice) },
                [2] = { position_tile_id = 8, item_counts = _merge_inv(INV.free_rent, INV.tax_free) },
            }),
        },
    },

    solo_monster = {
        group = "combat_obstacle",
        covers = { "monster", "building_destroy" },
        bootstrap = {
            players = _mk_players(120000, TILE.chance_inner, {
                [1] = { item_counts = INV.monster },
            }),
            tiles = { [11] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    solo_strong = {
        group = "property_control",
        covers = { "strong", "force_acquire" },
        bootstrap = {
            players = _mk_players(120000, 11, {
                [1] = { item_counts = _merge_inv(INV.strong, INV.remote_dice) },
            }),
            tiles = { [12] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    solo_tax_free = {
        group = "economy_core",
        covers = { "tax_free", "tax_response" },
        bootstrap = {
            players = _mk_players(120000, 37, {
                [1] = { item_counts = _merge_inv(INV.tax_free, INV.remote_dice) },
            }),
        },
    },

    solo_share_wealth = {
        group = "interrupt_resume",
        covers = { "share_wealth", "cash_rebalance" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { cash = 1000, item_counts = INV.share_wealth },
                [2] = { position_tile_id = 8, cash = 9000 },
            }),
        },
    },

    solo_exile = {
        group = "relocation_status",
        covers = { "exile", "mountain_followup", "teleport" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.exile },
                [2] = { position_tile_id = 8 },
            }),
        },
    },

    solo_missile = {
        group = "combat_obstacle",
        covers = { "missile", "hospital_followup", "building_destroy" },
        bootstrap = {
            players = _mk_players(120000, TILE.chance_inner, {
                [1] = { item_counts = INV.missile },
                [2] = { position_tile_id = 11 },
            }),
            tiles = { [11] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    solo_tax = {
        group = "economy_core",
        covers = { "tax", "target_choice", "cash_penalty" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.tax },
                [2] = { position_tile_id = 8, cash = 60000 },
                [3] = { cash = 30000 },
                [4] = { cash = 45000 },
            }),
        },
    },

    solo_invite_deity = {
        group = "interrupt_resume",
        covers = { "invite_deity", "deity_transfer" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.invite_deity },
                [2] = { position_tile_id = 8, statuses = _deity("rich") },
            }),
        },
    },

    solo_send_poor = {
        group = "interrupt_resume",
        covers = { "send_poor", "deity_transfer", "poor" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.send_poor, statuses = _deity("poor") },
                [2] = { position_tile_id = 8 },
            }),
        },
    },

    solo_rich = {
        group = "interrupt_resume",
        covers = { "rich", "deity_apply", "self_buff" },
        bootstrap = {
            players = _mk_players(120000, 7, { [1] = { item_counts = INV.rich } }),
        },
    },

    solo_poor = {
        group = "interrupt_resume",
        covers = { "poor", "deity_apply", "target_debuff" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.poor },
                [2] = { position_tile_id = 8 },
            }),
        },
    },

    solo_angel = {
        group = "interrupt_resume",
        covers = { "angel", "deity_apply", "self_immune" },
        bootstrap = {
            players = _mk_players(120000, 7, { [1] = { item_counts = INV.angel } }),
        },
    },

    paid_market_entry = {
        group = "commerce_paid",
        covers = { "market_entry", "shop", "paid_currency", "jindou", "lepark", "remote_dice" },
        bootstrap = {
            -- p1 在 27 起步，2 张遥控骰子（4+4=8 步）刚好经过黑市 39 触发购买
            players = _mk_players(120000, 27, {
                [1] = { item_counts = { [2002] = 2 } },
            }),
        },
    },

    combo_mine_vs_angel = {
        group = "combat_obstacle",
        covers = { "mine", "angel", "immunity" },
        bootstrap = {
            -- p1 天使附身 + 遥控骰子，前方 8 号格有地雷；按设计天使应免疫地雷
            -- (movement.lua:124 / mine.lua:89 显式检查 angel_immune_to_item)
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.remote_dice, statuses = _deity("angel") },
            }),
            overlays = { mines = { { tile_id = 8, render_called = true } } },
        },
    },

    combo_missile_vs_angel = {
        group = "combat_obstacle",
        covers = { "missile", "angel", "immunity" },
        bootstrap = {
            -- p1 用 missile 轰 12 号格（p2 拥有 + 站位且天使附身）
            -- 期望：建筑未被摧毁，p2 不送医（demolish.lua angel_immune_to_item 双闸口）
            players = _mk_players(120000, TILE.chance_inner, {
                [1] = { item_counts = INV.missile },
                [2] = { position_tile_id = 12, statuses = _deity("angel") },
            }),
            tiles = { [12] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    combo_monster_vs_angel = {
        group = "combat_obstacle",
        covers = { "monster", "angel", "immunity" },
        bootstrap = {
            -- p1 用 monster 拆 12 号建筑（p2 拥有且天使附身）
            -- 期望：建筑未被摧毁
            players = _mk_players(120000, TILE.chance_inner, {
                [1] = { item_counts = INV.monster },
                [2] = { position_tile_id = 8, statuses = _deity("angel") },
            }),
            tiles = { [12] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    combo_exile_vs_angel_target = {
        group = "combat_obstacle",
        covers = { "exile", "angel", "immunity", "target_filter" },
        bootstrap = {
            -- p1 持流放卡，p2 天使附身；期望：p2 不出现在目标列表中
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.exile },
                [2] = { position_tile_id = 8, statuses = _deity("angel") },
            }),
        },
    },

    combo_steal_vs_angel = {
        group = "interrupt_resume",
        covers = { "steal", "angel", "immunity", "target_filter" },
        bootstrap = {
            -- p1 持偷窃卡 + 遥控骰子，p2 天使附身；期望：p2 不出现在偷窃目标列表中
            players = _mk_players(120000, 7, {
                [1] = { item_counts = _merge_inv(INV.steal, INV.remote_dice) },
                [2] = { position_tile_id = 8, statuses = _deity("angel") },
            }),
        },
    },

    combo_angel_vs_hospital_landing = {
        group = "relocation_status",
        covers = { "angel", "immunity", "hospital_landing" },
        bootstrap = {
            -- p1 天使附身 + 遥控骰子，从 6 出发走 1 步落在医院格 36
            -- 期望：不住院、不扣医药费，显示天使保护反馈
            players = _mk_players(120000, 6, {
                [1] = { item_counts = INV.remote_dice, statuses = _deity("angel") },
            }),
        },
    },

    combo_angel_vs_mountain_landing = {
        group = "relocation_status",
        covers = { "angel", "immunity", "mountain_landing" },
        bootstrap = {
            -- p1 天使附身 + 遥控骰子，从 12 出发走 1 步落在深山格 37
            -- 期望：不迷路、不停留，显示天使保护反馈
            players = _mk_players(120000, 12, {
                [1] = { item_counts = INV.remote_dice, statuses = _deity("angel") },
            }),
        },
    },

    combo_tax_vs_taxfree = {
        group = "economy_core",
        covers = { "tax", "tax_free", "jindou_attack_defense" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.tax },
                [2] = { position_tile_id = 8, cash = 60000, item_counts = INV.tax_free },
            }),
        },
    },

    combo_strong_vs_freerent = {
        group = "property_control",
        covers = { "strong", "free_rent", "rent_choice" },
        bootstrap = {
            players = _mk_players(120000, 11, {
                [1] = { item_counts = _merge_inv(INV.free_rent, INV.strong, INV.remote_dice) },
            }),
            tiles = { [12] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    combo_invite_overwrites_poor = {
        group = "interrupt_resume",
        covers = { "invite_deity", "deity_overwrite" },
        bootstrap = {
            -- p1 自带穷神，请神把 p2 财神拉到自己身上时会覆盖穷神（单神位语义）
            -- 验证：deity_ops.set_player_deity 直接覆盖，不需要先 clear
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.invite_deity, statuses = _deity("poor") },
                [2] = { position_tile_id = 8, statuses = _deity("rich") },
            }),
        },
    },

    combo_rich_double_rent = {
        group = "property_control",
        covers = { "rich", "rent_double", "deity_active" },
        bootstrap = {
            players = _mk_players(120000, 7, {
                [1] = { item_counts = INV.remote_dice, statuses = _deity("rich") },
                [2] = { position_tile_id = 11, item_counts = INV.remote_dice },
            }),
            tiles = { [12] = { owner_player_index = 1, level = 2, render_called = true } },
            current_turn_player_index = 2,
        },
    },

    combo_poor_double_pay = {
        group = "property_control",
        covers = { "poor", "rent_double_pay", "deity_active" },
        bootstrap = {
            players = _mk_players(120000, 11, {
                [1] = { item_counts = INV.remote_dice, statuses = _deity("poor") },
            }),
            tiles = { [12] = { owner_player_index = 2, level = 2, render_called = true } },
        },
    },

    market_sold_out = {
        group = "commerce_paid",
        covers = { "market_entry", "sold_out", "shop_tab" },
        bootstrap = {
            players = _mk_players(120000, 27, {
                [1] = { item_counts = { [2002] = 2 } },
            }),
            market_limits = {
                [2003] = 0,  -- 骰子加倍卡
                [2002] = 0,  -- 遥控骰子卡
                [2005] = 0,  -- 地雷卡
                [2012] = 0,  -- 流放卡
                [2004] = 0,  -- 路障卡
            },
        },
    },

    edge_bankruptcy_eliminated = {
        group = "economy_core",
        value = "edge",
        covers = { "bankruptcy", "eliminated", "rent", "tile_owner" },
        bootstrap = {
            players = _mk_players(100000, TILE.start, {
                [1] = { cash = 3000, item_counts = INV.remote_dice },
                [2] = { cash = 120000 },
                [4] = { eliminated = true, position_tile_id = TILE.hospital },
            }),
            tiles = { [1] = { owner_player_index = 2, level = 3, render_called = true } },
        },
    },
}

for name, p in pairs(profiles) do
    p.goal = p.goal or name
    p.value = p.value or "core"
    p.owner_tests = p.owner_tests or { "runtime.test_profiles" }
end

return profiles
