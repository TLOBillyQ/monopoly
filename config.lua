-- Clean configuration for rebuilt game loop

local Config = {}

Config.window = {
    width = 960,
    height = 640,
    title = "蛋仔大富翁"
}

Config.rules = {
    maxPlayers = 4,
    minPlayers = 2,
    startMoney = 100000,
    passStartBonus = 2000,
    hospitalFee = 1000,
    hospitalStay = 2,
    mountainStay = 2,
    turnTimeout = 10,
    maxItemSlots = 5,
    blackMarketPrice = 2000
}

Config.colors = {
    background = {0.92, 0.92, 0.9},
    boardFill = {0.85, 0.85, 0.8},
    boardLine = {0.1, 0.1, 0.1},
    hudText = {0.1, 0.1, 0.1},
    player = {
        {1, 0.35, 0.35},
        {0.35, 0.35, 1},
        {0.35, 0.85, 0.35},
        {1, 0.9, 0.35}
    }
}

-- Board tiles laid clockwise starting at index 1 (Start)
Config.tiles = {
    {name = "起点", type = "start", price = 0},
    {name = "福州路", type = "empty", price = 1000},
    {name = "南京路", type = "empty", price = 1500},
    {name = "机会", type = "chance", price = 0},
    {name = "北京路", type = "empty", price = 2000},
    {name = "道具", type = "item", price = 0},
    {name = "上海路", type = "empty", price = 2500},
    {name = "医院", type = "hospital", price = 0},
    {name = "广州路", type = "empty", price = 3000},
    {name = "机会", type = "chance", price = 0},
    {name = "深圳路", type = "empty", price = 3500},
    {name = "黑市", type = "black_market", price = 0},
    {name = "杭州路", type = "empty", price = 4000},
    {name = "深山", type = "mountain", price = 0},
    {name = "苏州路", type = "empty", price = 4500},
    {name = "税务局", type = "tax", price = 0}
}

-- Chance cards: simplified but cover key effects
Config.chanceCards = {
    {name = "奖金", kind = "gain_money", value = 2000, target = "self", negative = false, weight = 5},
    {name = "彩票中奖", kind = "gain_money", value = 5000, target = "self", negative = false, weight = 3},
    {name = "罚款", kind = "lose_money", value = 1000, target = "self", negative = true, weight = 5},
    {name = "医疗费", kind = "lose_money", value = 1500, target = "self", negative = true, weight = 4},
    {name = "投资失败", kind = "lose_percent", value = 0.2, target = "self", negative = true, weight = 3},
    {name = "经济危机", kind = "lose_percent", value = 0.15, target = "all", negative = true, weight = 2},
    {name = "生日祝福", kind = "collect", value = 1000, target = "others", negative = false, weight = 3},
    {name = "请客吃饭", kind = "pay_others", value = 500, target = "others", negative = true, weight = 3},
    {name = "前进5格", kind = "move", value = 5, target = "self", negative = false, weight = 3},
    {name = "后退3格", kind = "move", value = -3, target = "self", negative = true, weight = 3},
    {name = "天使降临", kind = "gain_item", value = "angel", target = "self", negative = false, weight = 2},
    {name = "遗失道具", kind = "lose_item", value = 1, target = "self", negative = true, weight = 2}
}

-- Item deck (simplified)
Config.itemCards = {
    {name = "遥控骰子", type = "remote_dice", weight = 5},
    {name = "清障卡", type = "clear_road", weight = 5},
    {name = "路障卡", type = "roadblock", weight = 6},
    {name = "地雷卡", type = "landmine", weight = 6},
    {name = "天使卡", type = "angel", weight = 3},
    {name = "免税卡", type = "tax_free", weight = 4},
    {name = "免费卡", type = "free_pass", weight = 5},
    {name = "骰子加倍", type = "dice_double", weight = 4}
}

return Config
