local config = {}

config.window = {
    width = 1280,
    height = 720,
    title = "蛋仔大富翁"
}

-- 核心规则（保留自动步进设置）
config.rules = {
    max_players = 4,
    min_players = 2,
    start_money = 100000,
    pass_start_bonus = 2000,
    hospital_fee = 1000,     -- 进入医院费用
    hospital_stay = 2,       -- 医院停留回合数
    mountain_stay = 2,       -- 深山停留回合数
    turn_timeout = 30,       -- 回合超时时间
    max_item_slots = 5,       -- 最多持有道具数
    auto_step_interval = 0.1, -- 自动模式步进时间（秒）

    -- 神仙附身时间（回合）
    angel_duration = 5,
    poor_duration = 5,
    wealth_duration = 5,

    -- 税务相关
    tax_rate = 0.5 -- 查税卡扣款比例
}

-- 颜色方案
config.colors = {
    background = { 0.92, 0.92, 0.9 },
    board_fill = { 0.85, 0.85, 0.8 },
    board_line = { 0.1, 0.1, 0.1 },
    hud_text = { 0.1, 0.1, 0.1 },
    player = {
        { 1,    0.35, 0.35 },
        { 0.35, 0.35, 1 },
        { 0.35, 0.85, 0.35 },
        { 1,    0.9,  0.35 }
    }
}

-- 角色与座驾（用于展示）
config.characters = {
    { id = 1001, name = "蛋仔" },
    { id = 1002, name = "泡泡" },
    { id = 1003, name = "小花" },
    { id = 1004, name = "萝卜" }
}

config.vehicles = {
    { id = 4001, name = "滑板" },
    { id = 4002, name = "哈雷摩托" },
    { id = 4003, name = "法拉利" }
}

-- 9x9 网格布局的完整地块数据（参考 map.md）
config.tiles = {
    -- 从起点开始逆时针编号
    { id = 1, name = "起点", type = "start", price = 0, grid_pos = { 9, 9 } },

    -- 底边从右向左 (2-9)
    { id = 2, name = "福州路", type = "property", price = 500, grid_pos = { 8, 9 } },
    { id = 3, name = "台北路", type = "property", price = 550, grid_pos = { 7, 9 } },
    { id = 4, name = "海口路", type = "property", price = 600, grid_pos = { 6, 9 } },
    { id = 5, name = "道具卡", type = "item_card", price = 0, grid_pos = { 5, 9 } },
    { id = 6, name = "广州路", type = "property", price = 650, grid_pos = { 4, 9 } },
    { id = 7, name = "香港路", type = "property", price = 700, grid_pos = { 3, 9 } },
    { id = 8, name = "澳门路", type = "property", price = 750, grid_pos = { 2, 9 } },
    { id = 9, name = "医院", type = "hospital", price = 0, grid_pos = { 1, 9 } },

    -- 左边从下向上 (10-17)
    { id = 10, name = "南宁路", type = "property", price = 800, grid_pos = { 1, 8 } },
    { id = 11, name = "贵阳路", type = "property", price = 850, grid_pos = { 1, 7 } },
    { id = 12, name = "昆明路", type = "property", price = 900, grid_pos = { 1, 6 } },
    { id = 13, name = "机会卡", type = "chance_card", price = 0, grid_pos = { 1, 5 } },
    { id = 14, name = "成都路", type = "property", price = 950, grid_pos = { 1, 4 } },
    { id = 15, name = "西宁路", type = "property", price = 1000, grid_pos = { 1, 3 } },
    { id = 16, name = "拉萨路", type = "property", price = 1050, grid_pos = { 1, 2 } },
    { id = 17, name = "深山", type = "mountain", price = 0, grid_pos = { 1, 1 } },

    -- 顶边从左向右 (18-25)
    { id = 18, name = "乌鲁木齐路", type = "property", price = 1100, grid_pos = { 2, 1 } },
    { id = 19, name = "兰州路", type = "property", price = 1150, grid_pos = { 3, 1 } },
    { id = 20, name = "呼和浩特路", type = "property", price = 1200, grid_pos = { 4, 1 } },
    { id = 21, name = "道具卡", type = "item_card", price = 0, grid_pos = { 5, 1 } },
    { id = 22, name = "哈尔滨路", type = "property", price = 1250, grid_pos = { 6, 1 } },
    { id = 23, name = "长春路", type = "property", price = 1300, grid_pos = { 7, 1 } },
    { id = 24, name = "沈阳路", type = "property", price = 1350, grid_pos = { 8, 1 } },
    { id = 25, name = "税务局", type = "tax_office", price = 0, grid_pos = { 9, 1 } },

    -- 右边从上向下 (26-32)
    { id = 26, name = "石家庄路", type = "property", price = 1400, grid_pos = { 9, 2 } },
    { id = 27, name = "郑州路", type = "property", price = 1450, grid_pos = { 9, 3 } },
    { id = 28, name = "合肥路", type = "property", price = 1500, grid_pos = { 9, 4 } },
    { id = 29, name = "机会卡", type = "chance_card", price = 0, grid_pos = { 9, 5 } },
    { id = 30, name = "济南路", type = "property", price = 1550, grid_pos = { 9, 6 } },
    { id = 31, name = "南京路", type = "property", price = 1600, grid_pos = { 9, 7 } },
    { id = 32, name = "杭州路", type = "property", price = 1650, grid_pos = { 9, 8 } },

    -- 中间横行从右向左 (33-39)
    { id = 33, name = "上海路", type = "property", price = 1700, grid_pos = { 8, 5 } },
    { id = 34, name = "北京路", type = "property", price = 1750, grid_pos = { 7, 5 } },
    { id = 35, name = "机会卡", type = "chance_card", price = 0, grid_pos = { 6, 5 } },
    { id = 36, name = "黑市", type = "black_market", price = 0, grid_pos = { 5, 5 } },
    { id = 37, name = "武汉路", type = "property", price = 1800, grid_pos = { 4, 5 } },
    { id = 38, name = "长沙路", type = "property", price = 1850, grid_pos = { 3, 5 } },
    { id = 39, name = "南昌路", type = "property", price = 1900, grid_pos = { 2, 5 } },

    -- 中间列从上向下 (40-45)
    { id = 40, name = "银川路", type = "property", price = 1950, grid_pos = { 5, 2 } },
    { id = 41, name = "西安路", type = "property", price = 2000, grid_pos = { 5, 3 } },
    { id = 42, name = "太原路", type = "property", price = 2050, grid_pos = { 5, 4 } },
    { id = 43, name = "天津路", type = "property", price = 2100, grid_pos = { 5, 6 } },
    { id = 44, name = "重庆路", type = "property", price = 2150, grid_pos = { 5, 7 } },
    { id = 45, name = "机会卡", type = "chance_card", price = 0, grid_pos = { 5, 8 } }
}

-- 机会卡表（34个事件）
config.chance_events = {
    -- 3001-3009: 金币相关
    { id = 3001, name = "奖金", type = "gain_money", value = 2000, weight = 300, negative = false, target = "self", description = "你赢得了彩票，获得2000金币。" },
    { id = 3002, name = "双倍奖金", type = "gain_money", value = 5000, weight = 200, negative = false, target = "self", description = "投资成功，获得5000金币。" },
    { id = 3003, name = "罚款", type = "lose_money", value = 1000, weight = 300, negative = true, target = "self", description = "你被罚款1000金币。" },
    { id = 3004, name = "医疗费", type = "lose_money", value = 1500, weight = 250, negative = true, target = "self", description = "支付医疗费1500金币。" },
    { id = 3005, name = "罚金翻倍", type = "lose_money", value = 2000, weight = 150, negative = true, target = "self", description = "支付罚金2000金币。" },
    { id = 3006, name = "生日祝福", type = "collect_from_all", value = 1000, weight = 200, negative = false, target = "others", description = "今天是你的生日！每个玩家都要祝贺你，各支付1000金币。" },
    { id = 3007, name = "投资失败", type = "lose_percent", value = 0.2, weight = 250, negative = true, target = "self", description = "投资失败，失去资金的20%。" },
    { id = 3008, name = "经济危机", type = "lose_percent_all", value = 0.15, weight = 200, negative = true, target = "all", description = "经济危机，所有玩家失去资金的15%。" },
    { id = 3009, name = "请客吃饭", type = "pay_to_all", value = 500, weight = 200, negative = true, target = "others", description = "今天请客吃饭，每个玩家各支付500金币。" },

    -- 3010-3019: 移动相关
    { id = 3010, name = "前进5格", type = "move_forward", value = 5, weight = 200, negative = false, target = "self", description = "前进5格。" },
    { id = 3011, name = "前进10格", type = "move_forward", value = 10, weight = 150, negative = false, target = "self", description = "前进10格。" },
    { id = 3012, name = "后退3格", type = "move_backward", value = 3, weight = 200, negative = true, target = "self", description = "后退3格。" },
    { id = 3013, name = "后退5格", type = "move_backward", value = 5, weight = 150, negative = true, target = "self", description = "后退5格。" },
    { id = 3014, name = "前往税务局", type = "teleport_to_tax", value = 0, weight = 150, negative = true, target = "self", description = "前往税务局。" },
    { id = 3015, name = "前往医院", type = "teleport_to_hospital", value = 0, weight = 150, negative = true, target = "self", description = "前往医院。" },
    { id = 3016, name = "前往黑市", type = "teleport_to_market", value = 0, weight = 200, negative = false, target = "self", description = "前往黑市。" },
    { id = 3017, name = "回到起点", type = "teleport_to_start", value = 0, weight = 200, negative = false, target = "self", description = "回到起点。" },
    { id = 3018, name = "免费停留", type = "skip_jail", value = 0, weight = 100, negative = false, target = "self", description = "获得一张免费停留卡。" },

    -- 3020-3027: 道具相关
    { id = 3020, name = "幸运道具", type = "gain_item", value = 2001, weight = 300, negative = false, target = "self", description = "获得一张免费卡。" },
    { id = 3021, name = "遥控骰子", type = "gain_item", value = 2002, weight = 250, negative = false, target = "self", description = "获得一张遥控骰子卡。" },
    { id = 3022, name = "清障卡", type = "gain_item", value = 2006, weight = 250, negative = false, target = "self", description = "获得一张清障卡。" },
    { id = 3023, name = "财神降临", type = "gain_item", value = 2017, weight = 200, negative = false, target = "self", description = "财神降临，获得财神卡。" },
    { id = 3024, name = "天使降临", type = "gain_item", value = 2019, weight = 200, negative = false, target = "self", description = "天使降临，获得天使卡。" },
    { id = 3025, name = "幸运轮盘", type = "gain_item", value = 2003, weight = 200, negative = false, target = "self", description = "获得一张骰子加倍卡。" },
    { id = 3026, name = "穷神附身", type = "gain_item", value = 2018, weight = 300, negative = false, target = "self", description = "穷神附身，持续5回合，支付的租金和罚金翻倍。" },
    { id = 3027, name = "天使附身", type = "gain_item", value = 2019, weight = 300, negative = false, target = "self", description = "天使附身，持续5回合，免受负面道具效果影响。" },

    -- 3028-3034: 道具丢失和移动惩罚
    { id = 3028, name = "小偷光临", type = "lose_random_item", value = 1, weight = 200, negative = true, target = "self", description = "小偷光临，你随机丢失1张道具卡。" },
    { id = 3029, name = "强盗来袭", type = "lose_all_items", value = 0, weight = 200, negative = true, target = "self", description = "强盗来袭，你丢失所有道具卡。" },
    { id = 3030, name = "火灾", type = "lose_property", value = 1, weight = 200, negative = true, target = "self", description = "你遭遇火灾，随机丢失1张地块持有证。" },
    { id = 3031, name = "住院", type = "force_hospital", value = 0, weight = 200, negative = true, target = "self", description = "你突然晕倒了，被送入医院。" },
    { id = 3032, name = "迷路", type = "force_mountain", value = 0, weight = 200, negative = true, target = "self", description = "你迷路走进了深山。" },
    { id = 3033, name = "税务局", type = "teleport_to_tax", value = 0, weight = 200, negative = true, target = "self", description = "你收到税务局通知，立刻赶往税务局交代问题。" },
    { id = 3034, name = "密道", type = "teleport_secret", value = 0, weight = 200, negative = false, target = "self", description = "你发现密道，进入黑市。" }
}

-- 道具表（19个道具）
config.items = {
    -- 1级道具（基础卡）
    {
        id = 2001,
        name = "免费卡",
        level = 1,
        type = "free_pass",
        weight = 1000,
        immune_to_angel = false,
        trigger_time = "after_action",
        description = "当你停留在其他玩家的地块上时，使用此卡可以免交本次租金。"
    },

    {
        id = 2002,
        name = "遥控骰子卡",
        level = 1,
        type = "remote_dice",
        weight = 1000,
        immune_to_angel = false,
        trigger_time = "before_action",
        description = "在你行动前可以使用，可以遥控骰子投出的点数。"
    },

    {
        id = 2003,
        name = "骰子加倍卡",
        level = 1,
        type = "dice_double",
        weight = 1000,
        immune_to_angel = false,
        trigger_time = "after_roll",
        description = "投出骰子后可以使用，使当前投出的点数加倍。"
    },

    {
        id = 2004,
        name = "路障卡",
        level = 1,
        type = "roadblock",
        weight = 1000,
        immune_to_angel = true,
        trigger_time = "active_use",
        description = "放置路障，任何玩家经过此地时强制停留1个回合。"
    },

    {
        id = 2005,
        name = "地雷卡",
        level = 1,
        type = "landmine",
        weight = 1000,
        immune_to_angel = true,
        trigger_time = "active_use",
        description = "在脚下放置地雷，任何玩家经过此地时触发地雷，摧毁座驾并强制住院。"
    },

    {
        id = 2006,
        name = "清障卡",
        level = 1,
        type = "clear_road",
        weight = 1000,
        immune_to_angel = false,
        trigger_time = "before_action",
        description = "放出机器人清除前方12格以内的路障和地雷。"
    },

    -- 2级道具（中级卡）
    {
        id = 2007,
        name = "偷窃卡",
        level = 2,
        type = "steal",
        weight = 500,
        immune_to_angel = true,
        trigger_time = "pass_player",
        description = "当你路过其他玩家时，可以选择使用此卡获得他的一个道具。"
    },

    {
        id = 2008,
        name = "怪兽卡",
        level = 2,
        type = "monster",
        weight = 500,
        immune_to_angel = false,
        trigger_time = "active_use",
        description = "选择前后3格内其他玩家的建筑，释放怪兽拆除该建筑。"
    },

    {
        id = 2009,
        name = "强征卡",
        level = 2,
        type = "force_acquire",
        weight = 500,
        immune_to_angel = false,
        trigger_time = "after_action",
        description = "停留在其他玩家地块上时，支付费用后强制获得这块地块的所有权。"
    },

    {
        id = 2010,
        name = "免税卡",
        level = 2,
        type = "tax_free",
        weight = 500,
        immune_to_angel = false,
        trigger_time = "tax_time",
        description = "在税务局征税时使用，可以抵扣本次税金。"
    },

    {
        id = 2011,
        name = "均富卡",
        level = 2,
        type = "equal_wealth",
        weight = 500,
        immune_to_angel = true,
        trigger_time = "active_use",
        description = "选择一个玩家，你和该玩家平分你们的总资金。"
    },

    {
        id = 2012,
        name = "流放卡",
        level = 2,
        type = "banish",
        weight = 500,
        immune_to_angel = true,
        trigger_time = "active_use",
        description = "选择一个玩家，将其强制流放到深山中。"
    },

    -- 3级道具（高级卡）
    {
        id = 2013,
        name = "导弹卡",
        level = 3,
        type = "missile",
        weight = 250,
        immune_to_angel = false,
        trigger_time = "active_use",
        description = "向前后3格范围内释放导弹，摧毁所有建筑和座驾，玩家住进医院。"
    },

    {
        id = 2014,
        name = "查税卡",
        level = 3,
        type = "tax_check",
        weight = 250,
        immune_to_angel = true,
        trigger_time = "active_use",
        description = "选择一个玩家，该玩家立即支付50%资金的所得税。"
    },

    {
        id = 2015,
        name = "请神卡",
        level = 3,
        type = "invoke_god",
        weight = 250,
        immune_to_angel = false,
        trigger_time = "active_use",
        description = "选择其他玩家，将其身上的附身神请到自己身上。"
    },

    {
        id = 2016,
        name = "送神卡",
        level = 3,
        type = "send_god",
        weight = 250,
        immune_to_angel = false,
        trigger_time = "when_cursed",
        description = "被穷神附身时使用，选择一个玩家，将穷神送到他身上。"
    },

    -- 特殊神仙卡（权重为0，只能通过机会卡获得）
    {
        id = 2017,
        name = "财神卡",
        level = 3,
        type = "wealth_god",
        weight = 0,
        immune_to_angel = false,
        trigger_time = "active_use",
        description = "财神附身5回合，收到的租金和奖金翻倍。"
    },

    {
        id = 2018,
        name = "穷神卡",
        level = 3,
        type = "poor_god",
        weight = 0,
        immune_to_angel = false,
        trigger_time = "active_use",
        description = "选择一个玩家，令其穷神附身5回合，支付的租金和罚金翻倍。"
    },

    {
        id = 2019,
        name = "天使卡",
        level = 3,
        type = "angel",
        weight = 0,
        immune_to_angel = false,
        trigger_time = "active_use",
        description = "天使附身5回合，免受负面卡牌效果影响。"
    }
}

-- 黑市价格配置
config.black_market = {
    prices = {
        [2001] = { type = "ads", value = 1 },             -- 免费卡：1个广告
        [2002] = { type = "coins", value = 1000 },        -- 遥控骰子：1000金币
        [2003] = { type = "coins", value = 1000 },        -- 骰子加倍：1000金币
        [2004] = { type = "coins", value = 1000 },        -- 路障：1000金币
        [2005] = { type = "coins", value = 1000 },        -- 地雷：1000金币
        [2006] = { type = "coins", value = 1000 },        -- 清障：1000金币
        [2007] = { type = "paradise_coins", value = 10 }, -- 偷窃：10乐园币
        [2008] = { type = "paradise_coins", value = 10 }, -- 怪兽：10乐园币
        [2009] = { type = "paradise_coins", value = 10 }, -- 强征：10乐园币
        [2010] = { type = "paradise_coins", value = 10 }, -- 免税：10乐园币
        [2011] = { type = "paradise_coins", value = 10 }, -- 均富：10乐园币
        [2012] = { type = "paradise_coins", value = 10 }, -- 流放：10乐园币
        [2013] = { type = "gold_beans", value = 5 },      -- 导弹：5金豆
        [2014] = { type = "gold_beans", value = 5 },      -- 查税：5金豆
        [2015] = { type = "gold_beans", value = 5 },      -- 请神：5金豆
        [2016] = { type = "gold_beans", value = 5 },      -- 送神：5金豆
        [2017] = { type = "gold_beans", value = 5 },      -- 财神：5金豆
        [2018] = { type = "gold_beans", value = 5 },      -- 穷神：5金豆
        [2019] = { type = "gold_beans", value = 5 }       -- 天使：5金豆
    }
}

-- 建筑升级成本配置
config.building_costs = {
    -- 基于地块的房间类型：house, apartment, hotel, mansion
    -- 升级到这个等级的费用 = 地块价格 * 系数
    multipliers = { 1, 2, 4, 8 }
}

-- 常量表（位置按照上方 tiles 列表）
config.constants = {
    GRID_SIZE = 9,
    TILE_COUNT = 45,
    DICE_MIN = 1,
    DICE_MAX = 6,
    START_MONEY = 100000,
    PASS_START_BONUS = 2000,
    HOSPITAL_FEE = 1000,
    HOSPITAL_STAY = 2,
    HOSPITAL_POSITION = 9,
    MOUNTAIN_STAY = 2,
    MOUNTAIN_POSITION = 17,
    TAX_OFFICE_POSITION = 25,
    TAX_RATE = 0.5,
    BLACK_MARKET_POSITION = 36,
    JAIL_POSITION = nil,
    JAIL_STAY = 3,
    MAX_ITEM_SLOTS = 5,
    BUFF_DURATION = 5,
    WINDOW_WIDTH = 960,
    WINDOW_HEIGHT = 640
}

return config
