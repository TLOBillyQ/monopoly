-- 全新配置：去掉 Spoke 依赖的轻量版本

local Config = {}

Config.window = {
    width = 1280,
    height = 720,
    title = "蛋仔大富翁 - 纯Lua重构"
}

-- 核心规则
Config.rules = {
    maxPlayers = 4,
    startMoney = 20000,
    passStartBonus = 2000,
    hospitalFee = 800,
    hospitalStay = 2,
    mountainStay = 2,
    taxRate = 0.25,
    maxItemSlots = 5,
    autoStepInterval = 0.9 -- 自动模式步进时间（秒）
}

-- 颜色方案
Config.colors = {
    background = {0.95, 0.95, 0.93},
    boardFill = {0.88, 0.88, 0.85},
    boardLine = {0.15, 0.15, 0.15},
    hudText = {0.15, 0.15, 0.15},
    player = {
        {1, 0.35, 0.35},
        {0.35, 0.35, 1},
        {0.35, 0.8, 0.35},
        {1, 0.9, 0.35}
    }
}

-- 角色与座驾（用于展示）
Config.characters = {
    {id = 1001, name = "蛋仔"},
    {id = 1002, name = "泡泡"},
    {id = 1003, name = "小花"},
    {id = 1004, name = "萝卜"}
}

Config.vehicles = {
    {id = 4001, name = "滑板"},
    {id = 4002, name = "摩托"},
    {id = 4003, name = "气垫艇"}
}

-- 5x5 边框环路（16 个格子）
-- 编号从右下角开始，逆时针行进
Config.tiles = {
    {id = 1,  name = "起点",     type = "start",       price = 0,   gridPos = {5, 5}},
    {id = 2,  name = "果冻街",   type = "property",    price = 600, gridPos = {4, 5}},
    {id = 3,  name = "泡泡巷",   type = "property",    price = 650, gridPos = {3, 5}},
    {id = 4,  name = "机会",     type = "chance_card", price = 0,   gridPos = {2, 5}},
    {id = 5,  name = "糖果港",   type = "property",    price = 700, gridPos = {1, 5}},
    {id = 6,  name = "深山",     type = "mountain",    price = 0,   gridPos = {1, 4}},
    {id = 7,  name = "税务局",   type = "tax_office",  price = 0,   gridPos = {1, 3}},
    {id = 8,  name = "薄荷镇",   type = "property",    price = 800, gridPos = {1, 2}},
    {id = 9,  name = "医院",     type = "hospital",    price = 0,   gridPos = {1, 1}},
    {id = 10, name = "酸奶路",   type = "property",    price = 850, gridPos = {2, 1}},
    {id = 11, name = "机会",     type = "chance_card", price = 0,   gridPos = {3, 1}},
    {id = 12, name = "黑市",     type = "black_market",price = 0,   gridPos = {4, 1}},
    {id = 13, name = "可可湾",   type = "property",    price = 900, gridPos = {5, 1}},
    {id = 14, name = "道具铺",   type = "item_card",   price = 0,   gridPos = {5, 2}},
    {id = 15, name = "椰子林",   type = "property",    price = 950, gridPos = {5, 3}},
    {id = 16, name = "休憩站",   type = "rest",        price = 0,   gridPos = {5, 4}},
}

-- 精简机会卡
Config.chanceEvents = {
    {id = 3001, name = "奖金",        type = "gain_money",     value = 1500,  description = "社区奖励奖金。"},
    {id = 3002, name = "罚款",        type = "lose_money",     value = 800,   description = "支付城市管理罚款。"},
    {id = 3003, name = "前进三步",    type = "move_forward",   value = 3,     description = "向前移动 3 格。"},
    {id = 3004, name = "后退两步",    type = "move_backward",  value = 2,     description = "后退 2 格。"},
    {id = 3005, name = "前往医院",    type = "teleport",       target = "hospital",    description = "直接前往医院治疗。"},
    {id = 3006, name = "前往税务局",  type = "teleport",       target = "tax_office",  description = "前往税务局结算税金。"},
    {id = 3007, name = "生日礼金",    type = "collect_from_all", value = 200, description = "每位玩家给你 200 金币。"},
    {id = 3008, name = "请客奶茶",    type = "pay_to_all",     value = 150,   description = "你请大家喝奶茶，每人 150 金币。"},
    {id = 3009, name = "幸运道具",    type = "draw_item",      value = 1,     description = "立即获得一张随机道具卡。"}
}

-- 精简道具表
Config.items = {
    {id = 2001, name = "免费卡",   type = "free_pass",  weight = 300, description = "免除下一次租金或税金。"},
    {id = 2002, name = "加倍骰子", type = "dice_double",weight = 250, description = "本回合掷骰结果翻倍。"},
    {id = 2003, name = "幸运护符", type = "angel",      weight = 180, description = "5 回合内免疫负面机会卡。"},
    {id = 2004, name = "急救包",   type = "heal",       weight = 180, description = "立即恢复，清空住院/深山等待。"}
}

return Config
