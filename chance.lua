-- 机会卡系统
-- Chance Card System

local Chance = {}

-- 事件类型
Chance.EventType = {
    GAIN_MONEY = "gain_money",  -- 获得金币
    LOSE_MONEY = "lose_money",  -- 扣除金币
    LOSE_MONEY_PERCENT = "lose_money_percent",  -- 按比例扣除金币
    COLLECT_MONEY = "collect_money",  -- 向其他玩家收取金币
    PAY_MONEY = "pay_money",  -- 向其他玩家支付金币
    CHANGE_VEHICLE = "change_vehicle",  -- 更换座驾
    DEMOLISH_BUILDING = "demolish_building",  -- 拆除建筑
    RESET_PROPERTY = "reset_property",  -- 重置地块
    FORCE_MOVE = "force_move",  -- 强制移动
    GAIN_ITEM = "gain_item",  -- 获得道具
    LOSE_ITEM = "lose_item",  -- 丢弃道具
    LOSE_PROPERTY = "lose_property"  -- 丢弃地块
}

-- 事件目标
Chance.TargetType = {
    SELF = "self",  -- 抽卡角色
    ALL = "all",  -- 全体角色
    OTHER = "other"  -- 其他角色
}

-- 创建机会卡
function Chance.new(id, name, eventType, targetType, value, description, isNegative, weight)
    local chance = {
        id = id,
        name = name,
        eventType = eventType,
        targetType = targetType,
        value = value,  -- 事件数值（金币、格数等）
        description = description,
        isNegative = isNegative,  -- 是否为负收益（天使可以免除）
        weight = weight or 1  -- 抽取权重
    }
    
    return chance
end

-- 预定义的机会卡列表
function Chance.createAllChances()
    local chances = {}
    
    -- 获得金币类
    table.insert(chances, Chance.new(1, "奖金", Chance.EventType.GAIN_MONEY, 
        Chance.TargetType.SELF, 2000, "恭喜你，获得2000金币", false, 5))
    
    table.insert(chances, Chance.new(2, "彩票中奖", Chance.EventType.GAIN_MONEY, 
        Chance.TargetType.SELF, 5000, "恭喜你中了彩票，获得5000金币", false, 3))
    
    table.insert(chances, Chance.new(3, "遗产继承", Chance.EventType.GAIN_MONEY, 
        Chance.TargetType.SELF, 10000, "你继承了一笔遗产，获得10000金币", false, 2))
    
    -- 扣除金币类
    table.insert(chances, Chance.new(4, "罚款", Chance.EventType.LOSE_MONEY, 
        Chance.TargetType.SELF, 1000, "你违规停车，被罚款1000金币", true, 5))
    
    table.insert(chances, Chance.new(5, "医疗费", Chance.EventType.LOSE_MONEY, 
        Chance.TargetType.SELF, 1500, "你感冒了，支付医疗费1500金币", true, 4))
    
    table.insert(chances, Chance.new(6, "慈善捐款", Chance.EventType.LOSE_MONEY, 
        Chance.TargetType.SELF, 2000, "你捐了2000金币做慈善", true, 3))
    
    -- 按比例扣除金币
    table.insert(chances, Chance.new(7, "投资失败", Chance.EventType.LOSE_MONEY_PERCENT, 
        Chance.TargetType.SELF, 0.2, "投资失败，损失20%现金", true, 3))
    
    table.insert(chances, Chance.new(8, "被骗", Chance.EventType.LOSE_MONEY_PERCENT, 
        Chance.TargetType.SELF, 0.3, "你被骗了，损失30%现金", true, 2))
    
    -- 向其他玩家收取金币
    table.insert(chances, Chance.new(9, "收保护费", Chance.EventType.COLLECT_MONEY, 
        Chance.TargetType.OTHER, 500, "向每个玩家收取500金币保护费", false, 4))
    
    table.insert(chances, Chance.new(10, "生日祝福", Chance.EventType.COLLECT_MONEY, 
        Chance.TargetType.OTHER, 1000, "今天是你的生日，每人送你1000金币", false, 3))
    
    -- 向其他玩家支付金币
    table.insert(chances, Chance.new(11, "请客吃饭", Chance.EventType.PAY_MONEY, 
        Chance.TargetType.OTHER, 500, "你请大家吃饭，支付每人500金币", true, 4))
    
    table.insert(chances, Chance.new(12, "赔偿", Chance.EventType.PAY_MONEY, 
        Chance.TargetType.OTHER, 800, "你损坏了别人的东西，赔偿每人800金币", true, 3))
    
    -- 更换座驾
    table.insert(chances, Chance.new(13, "汽车抽奖", Chance.EventType.CHANGE_VEHICLE, 
        Chance.TargetType.SELF, 1, "恭喜你获得一辆汽车（投掷2个骰子）", false, 3))
    
    table.insert(chances, Chance.new(14, "车祸", Chance.EventType.CHANGE_VEHICLE, 
        Chance.TargetType.SELF, 0, "你的车发生了事故，失去座驾", true, 3))
    
    -- 拆除建筑
    table.insert(chances, Chance.new(15, "地震", Chance.EventType.DEMOLISH_BUILDING, 
        Chance.TargetType.ALL, 1, "地震！所有玩家随机损失一栋建筑", true, 2))
    
    table.insert(chances, Chance.new(16, "火灾", Chance.EventType.DEMOLISH_BUILDING, 
        Chance.TargetType.SELF, 1, "你的一栋建筑发生火灾被拆除", true, 3))
    
    -- 强制移动
    table.insert(chances, Chance.new(17, "传送", Chance.EventType.FORCE_MOVE, 
        Chance.TargetType.SELF, 0, "你被传送到起点", false, 4))
    
    table.insert(chances, Chance.new(18, "后退", Chance.EventType.FORCE_MOVE, 
        Chance.TargetType.SELF, -5, "倒霉！后退5格", true, 3))
    
    table.insert(chances, Chance.new(19, "前进", Chance.EventType.FORCE_MOVE, 
        Chance.TargetType.SELF, 5, "幸运！前进5格", false, 3))
    
    -- 获得道具
    table.insert(chances, Chance.new(20, "道具礼包", Chance.EventType.GAIN_ITEM, 
        Chance.TargetType.SELF, 1, "获得一个随机道具", false, 5))
    
    table.insert(chances, Chance.new(21, "天使降临", Chance.EventType.GAIN_ITEM, 
        Chance.TargetType.SELF, "angel", "天使降临，获得天使卡", false, 2))
    
    -- 丢弃道具
    table.insert(chances, Chance.new(22, "遗失", Chance.EventType.LOSE_ITEM, 
        Chance.TargetType.SELF, 1, "你不小心丢失了一个道具", true, 3))
    
    -- 全体事件
    table.insert(chances, Chance.new(23, "全民狂欢", Chance.EventType.GAIN_MONEY, 
        Chance.TargetType.ALL, 3000, "全民狂欢！每人获得3000金币", false, 2))
    
    table.insert(chances, Chance.new(24, "经济危机", Chance.EventType.LOSE_MONEY_PERCENT, 
        Chance.TargetType.ALL, 0.15, "经济危机！所有人损失15%现金", true, 2))
    
    return chances
end

-- 根据权重随机抽取机会卡
function Chance.drawRandom(chanceList)
    local totalWeight = 0
    for _, chance in ipairs(chanceList) do
        totalWeight = totalWeight + chance.weight
    end
    
    local rand = math.random() * totalWeight
    local currentWeight = 0
    
    for _, chance in ipairs(chanceList) do
        currentWeight = currentWeight + chance.weight
        if rand <= currentWeight then
            return chance
        end
    end
    
    return chanceList[1]
end

-- 执行机会卡事件
function Chance.execute(chance, drawer, allPlayers, gameState)
    local result = {
        success = true,
        message = chance.description,
        effects = {}
    }
    
    -- 检查天使附身（负面事件无效）
    if chance.isNegative and drawer.angelTurns > 0 then
        result.message = "天使保护！" .. chance.description .. "（无效）"
        return result
    end
    
    -- 根据事件类型执行
    if chance.eventType == Chance.EventType.GAIN_MONEY then
        if chance.targetType == Chance.TargetType.SELF then
            drawer.money = drawer.money + chance.value
            table.insert(result.effects, {player = drawer, type = "money", value = chance.value})
        elseif chance.targetType == Chance.TargetType.ALL then
            for _, player in ipairs(allPlayers) do
                player.money = player.money + chance.value
                table.insert(result.effects, {player = player, type = "money", value = chance.value})
            end
        end
        
    elseif chance.eventType == Chance.EventType.LOSE_MONEY then
        if chance.targetType == Chance.TargetType.SELF then
            drawer.money = math.max(0, drawer.money - chance.value)
            table.insert(result.effects, {player = drawer, type = "money", value = -chance.value})
        end
        
    elseif chance.eventType == Chance.EventType.LOSE_MONEY_PERCENT then
        if chance.targetType == Chance.TargetType.SELF then
            local loseAmount = math.floor(drawer.money * chance.value)
            drawer.money = drawer.money - loseAmount
            table.insert(result.effects, {player = drawer, type = "money", value = -loseAmount})
        elseif chance.targetType == Chance.TargetType.ALL then
            for _, player in ipairs(allPlayers) do
                local loseAmount = math.floor(player.money * chance.value)
                player.money = player.money - loseAmount
                table.insert(result.effects, {player = player, type = "money", value = -loseAmount})
            end
        end
        
    elseif chance.eventType == Chance.EventType.COLLECT_MONEY then
        for _, player in ipairs(allPlayers) do
            if player ~= drawer then
                local amount = math.min(player.money, chance.value)
                player.money = player.money - amount
                drawer.money = drawer.money + amount
                table.insert(result.effects, {from = player, to = drawer, type = "transfer", value = amount})
            end
        end
        
    elseif chance.eventType == Chance.EventType.PAY_MONEY then
        for _, player in ipairs(allPlayers) do
            if player ~= drawer then
                local amount = math.min(drawer.money, chance.value)
                drawer.money = drawer.money - amount
                player.money = player.money + amount
                table.insert(result.effects, {from = drawer, to = player, type = "transfer", value = amount})
            end
        end
        
    elseif chance.eventType == Chance.EventType.CHANGE_VEHICLE then
        drawer.vehicle = chance.value > 0 and "car" or nil
        table.insert(result.effects, {player = drawer, type = "vehicle", value = drawer.vehicle})
        
    -- 其他事件类型的实现...
    end
    
    return result
end

return Chance
