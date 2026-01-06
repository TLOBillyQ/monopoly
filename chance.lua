-- 机会卡系统
-- Chance Card System - 基于数据表设计（34个事件）

local Chance = {}
local Player = require("player")

-- ==================== 事件类型 ====================
Chance.EventType = {
    -- 金币相关
    GAIN_MONEY = "gain_money",              -- 获得金币
    LOSE_MONEY = "lose_money",              -- 失去金币
    LOSE_PERCENT = "lose_percent",          -- 失去百分比金币
    COLLECT_FROM_ALL = "collect_from_all",  -- 向所有人收取
    PAY_TO_ALL = "pay_to_all",              -- 向所有人支付
    
    -- 移动相关
    MOVE_FORWARD = "move_forward",          -- 前进
    MOVE_BACKWARD = "move_backward",        -- 后退
    TELEPORT_TO_TAX = "teleport_to_tax",    -- 传送到税务局
    TELEPORT_TO_HOSPITAL = "teleport_to_hospital",  -- 传送到医院
    TELEPORT_TO_MARKET = "teleport_to_market",     -- 传送到黑市
    TELEPORT_TO_START = "teleport_to_start",       -- 传送到起点
    TELEPORT_SECRET = "teleport_secret",    -- 密道传送
    SKIP_JAIL = "skip_jail",                -- 免费停留卡
    
    -- 道具相关
    GAIN_ITEM = "gain_item",                -- 获得道具
    LOSE_RANDOM_ITEM = "lose_random_item",  -- 随机丢失道具
    LOSE_ALL_ITEMS = "lose_all_items",      -- 丢失所有道具
    
    -- 地块相关
    LOSE_PROPERTY = "lose_property",        -- 丢失地块
    
    -- 惩罚相关
    FORCE_HOSPITAL = "force_hospital",      -- 强制住院
    FORCE_MOUNTAIN = "force_mountain",      -- 强制进山
    
    -- 特殊
    LOSE_PERCENT_ALL = "lose_percent_all"   -- 全体失去百分比金币
}


-- ==================== 从配置创建机会卡 ====================

-- 从config.lua中的数据创建所有机会卡
function Chance.createFromConfig(config)
    local chances = {}
    
    -- 直接使用config中的chanceEvents
    for _, eventData in ipairs(config.chanceEvents) do
        local chance = {
            id = eventData.id,
            name = eventData.name,
            eventType = eventData.type,  -- 从数据表中的"type"字段
            value = eventData.value,
            weight = eventData.weight,
            negative = eventData.negative,  -- 是否负面事件
            description = eventData.description,
            target = eventData.target  -- 事件目标
        }
        table.insert(chances, chance)
    end
    
    return chances
end

-- ==================== 随机抽取 ====================

-- 根据权重随机抽取一个机会卡
function Chance.drawRandom(chanceList)
    if not chanceList or #chanceList == 0 then
        return nil
    end
    
    local totalWeight = 0
    for _, event in ipairs(chanceList) do
        totalWeight = totalWeight + (event.weight or 1)
    end
    
    if totalWeight <= 0 then
        return chanceList[1]
    end
    
    local rand = math.random() * totalWeight
    local currentWeight = 0
    
    for _, event in ipairs(chanceList) do
        currentWeight = currentWeight + (event.weight or 1)
        if rand <= currentWeight then
            return event
        end
    end
    
    return chanceList[#chanceList]
end

-- ==================== 事件执行 ====================

-- 执行机会卡事件
-- 返回 {success, message, effects}
function Chance.execute(event, drawer, allPlayers, gameState)
    local result = {
        success = true,
        message = event.description or event.name,
        effects = {}
    }
    
    -- 检查天使附身保护（负面事件无效）
    if event.negative and drawer.buffType == "angel" then
        result.message = "天使附身保护！" .. (event.description or event.name) .. "（无效）"
        return result
    end
    
    -- 按事件类型执行
    local eventType = event.eventType
    
    if eventType == Chance.EventType.GAIN_MONEY then
        -- 3001, 3002: 获得金币
        Player.addMoney(drawer, event.value)
        table.insert(result.effects, {type = "money", player = drawer, amount = event.value})
        
    elseif eventType == Chance.EventType.LOSE_MONEY then
        -- 3003, 3004, 3005: 失去金币
        Player.subtractMoney(drawer, event.value)
        table.insert(result.effects, {type = "money", player = drawer, amount = -event.value})
        
    elseif eventType == Chance.EventType.LOSE_PERCENT then
        -- 3007: 失去百分比金币
        local loseAmount = math.floor(drawer.money * event.value)
        Player.subtractMoney(drawer, loseAmount)
        table.insert(result.effects, {type = "money", player = drawer, amount = -loseAmount})
        
    elseif eventType == Chance.EventType.LOSE_PERCENT_ALL then
        -- 3008: 全体失去百分比金币
        for _, player in ipairs(allPlayers) do
            if player.id ~= drawer.id then
                local loseAmount = math.floor(player.money * event.value)
                Player.subtractMoney(player, loseAmount)
                table.insert(result.effects, {type = "money", player = player, amount = -loseAmount})
            end
        end
        
    elseif eventType == Chance.EventType.COLLECT_FROM_ALL then
        -- 3006: 生日祝福，向所有人收取
        for _, player in ipairs(allPlayers) do
            if player.id ~= drawer.id then
                local transferred = Player.transfer(player, drawer, event.value)
                table.insert(result.effects, {type = "transfer", from = player, to = drawer, amount = transferred})
            end
        end
        
    elseif eventType == Chance.EventType.PAY_TO_ALL then
        -- 3009: 请客吃饭，向所有人支付
        for _, player in ipairs(allPlayers) do
            if player.id ~= drawer.id then
                local transferred = Player.transfer(drawer, player, event.value)
                table.insert(result.effects, {type = "transfer", from = drawer, to = player, amount = transferred})
            end
        end
        
    elseif eventType == Chance.EventType.MOVE_FORWARD then
        -- 3010, 3011: 前进
        Player.moveForward(drawer, event.value)
        table.insert(result.effects, {type = "move", player = drawer, position = drawer.position})
        
    elseif eventType == Chance.EventType.MOVE_BACKWARD then
        -- 3012, 3013: 后退
        Player.moveBackward(drawer, event.value)
        table.insert(result.effects, {type = "move", player = drawer, position = drawer.position})
        
    elseif eventType == Chance.EventType.TELEPORT_TO_TAX then
        -- 3014: 传送到税务局（格子7）
        Player.moveTo(drawer, 7)
        table.insert(result.effects, {type = "teleport", player = drawer, position = 7})
        
    elseif eventType == Chance.EventType.TELEPORT_TO_HOSPITAL then
        -- 3015: 传送到医院（格子14）并住院
        Player.moveTo(drawer, 14)
        Player.enterHospital(drawer, gameState.config.rules.hospitalStay)
        table.insert(result.effects, {type = "hospital", player = drawer})
        
    elseif eventType == Chance.EventType.TELEPORT_TO_MARKET then
        -- 3016: 传送到黑市（格子13）
        Player.moveTo(drawer, 13)
        table.insert(result.effects, {type = "teleport", player = drawer, position = 13})
        
    elseif eventType == Chance.EventType.TELEPORT_TO_START then
        -- 3017: 传送到起点（格子1）
        Player.moveTo(drawer, 1)
        table.insert(result.effects, {type = "teleport", player = drawer, position = 1})
        
    elseif eventType == Chance.EventType.TELEPORT_SECRET then
        -- 3034: 密道传送到黑市（格子13）
        Player.moveTo(drawer, 13)
        table.insert(result.effects, {type = "teleport", player = drawer, position = 13})
        
    elseif eventType == Chance.EventType.SKIP_JAIL then
        -- 3018: 获得免费停留卡
        drawer.freeJailCard = true
        table.insert(result.effects, {type = "item", player = drawer, itemType = "jail_free"})
        
    elseif eventType == Chance.EventType.GAIN_ITEM then
        -- 3020-3027: 获得道具或神仙卡
        local itemId = event.value
        local success = Player.addItem(drawer, itemId)
        if success then
            table.insert(result.effects, {type = "item", player = drawer, itemId = itemId})
        else
            result.message = result.message .. "（但道具卡已满，无法获得）"
        end
        
    elseif eventType == Chance.EventType.LOSE_RANDOM_ITEM then
        -- 3028: 随机丢失一个道具
        local lostItem = Player.removeRandomItem(drawer)
        if lostItem then
            table.insert(result.effects, {type = "item_lost", player = drawer, itemId = lostItem})
        else
            result.message = result.message .. "（但没有道具可丢失）"
        end
        
    elseif eventType == Chance.EventType.LOSE_ALL_ITEMS then
        -- 3029: 丢失所有道具
        local count = Player.clearAllItems(drawer)
        table.insert(result.effects, {type = "items_lost", player = drawer, count = count})
        
    elseif eventType == Chance.EventType.LOSE_PROPERTY then
        -- 3030: 随机丢失一块地块
        if #drawer.properties > 0 then
            local lostProperty = Player.loseRandomProperty(drawer)
            table.insert(result.effects, {type = "property_lost", player = drawer, propertyId = lostProperty})
        else
            result.message = result.message .. "（但没有地块可丢失）"
        end
        
    elseif eventType == Chance.EventType.FORCE_HOSPITAL then
        -- 3031: 强制进入医院
        Player.moveTo(drawer, 14)  -- 医院位置
        Player.enterHospital(drawer, gameState.config.rules.hospitalStay)
        table.insert(result.effects, {type = "hospital", player = drawer})
        
    elseif eventType == Chance.EventType.FORCE_MOUNTAIN then
        -- 3032: 强制进入深山
        Player.moveTo(drawer, 15)  -- 深山位置
        Player.enterMountain(drawer, gameState.config.rules.mountainStay)
        table.insert(result.effects, {type = "mountain", player = drawer})
    end
    
    return result
end

-- ==================== 生成所有机会卡 ====================

-- 创建所有34个预定义的机会卡
function Chance.createAllEvents()
    local events = {
        -- 3001-3009: 金币相关
        {id = 3001, name = "奖金", type = Chance.EventType.GAIN_MONEY, value = 2000, weight = 300, negative = false, description = "你赢得了彩票，获得2000金币。"},
        {id = 3002, name = "双倍奖金", type = Chance.EventType.GAIN_MONEY, value = 5000, weight = 200, negative = false, description = "投资成功，获得5000金币。"},
        {id = 3003, name = "罚款", type = Chance.EventType.LOSE_MONEY, value = 1000, weight = 300, negative = true, description = "你被罚款1000金币。"},
        {id = 3004, name = "医疗费", type = Chance.EventType.LOSE_MONEY, value = 1500, weight = 250, negative = true, description = "支付医疗费1500金币。"},
        {id = 3005, name = "罚金翻倍", type = Chance.EventType.LOSE_MONEY, value = 2000, weight = 150, negative = true, description = "支付罚金2000金币。"},
        {id = 3006, name = "生日祝福", type = Chance.EventType.COLLECT_FROM_ALL, value = 1000, weight = 200, negative = false, description = "今天是你的生日！每个玩家都要祝贺你，各支付1000金币。"},
        {id = 3007, name = "投资失败", type = Chance.EventType.LOSE_PERCENT, value = 0.2, weight = 250, negative = true, description = "投资失败，失去资金的20%。"},
        {id = 3008, name = "经济危机", type = Chance.EventType.LOSE_PERCENT_ALL, value = 0.15, weight = 200, negative = true, description = "经济危机，所有玩家失去资金的15%。"},
        {id = 3009, name = "请客吃饭", type = Chance.EventType.PAY_TO_ALL, value = 500, weight = 200, negative = true, description = "今天请客吃饭，每个玩家各支付500金币。"},
        
        -- 3010-3019: 移动相关
        {id = 3010, name = "前进5格", type = Chance.EventType.MOVE_FORWARD, value = 5, weight = 200, negative = false, description = "前进5格。"},
        {id = 3011, name = "前进10格", type = Chance.EventType.MOVE_FORWARD, value = 10, weight = 150, negative = false, description = "前进10格。"},
        {id = 3012, name = "后退3格", type = Chance.EventType.MOVE_BACKWARD, value = 3, weight = 200, negative = true, description = "后退3格。"},
        {id = 3013, name = "后退5格", type = Chance.EventType.MOVE_BACKWARD, value = 5, weight = 150, negative = true, description = "后退5格。"},
        {id = 3014, name = "前往税务局", type = Chance.EventType.TELEPORT_TO_TAX, value = 0, weight = 150, negative = true, description = "前往税务局。"},
        {id = 3015, name = "前往医院", type = Chance.EventType.TELEPORT_TO_HOSPITAL, value = 0, weight = 150, negative = true, description = "前往医院。"},
        {id = 3016, name = "前往黑市", type = Chance.EventType.TELEPORT_TO_MARKET, value = 0, weight = 200, negative = false, description = "前往黑市。"},
        {id = 3017, name = "回到起点", type = Chance.EventType.TELEPORT_TO_START, value = 0, weight = 200, negative = false, description = "回到起点。"},
        {id = 3018, name = "免费停留", type = Chance.EventType.SKIP_JAIL, value = 0, weight = 100, negative = false, description = "获得一张免费停留卡。"},
        
        -- 3020-3027: 道具相关
        {id = 3020, name = "幸运道具", type = Chance.EventType.GAIN_ITEM, value = 2001, weight = 300, negative = false, description = "获得一张免费卡。"},
        {id = 3021, name = "遥控骰子", type = Chance.EventType.GAIN_ITEM, value = 2002, weight = 250, negative = false, description = "获得一张遥控骰子卡。"},
        {id = 3022, name = "清障卡", type = Chance.EventType.GAIN_ITEM, value = 2006, weight = 250, negative = false, description = "获得一张清障卡。"},
        {id = 3023, name = "财神降临", type = Chance.EventType.GAIN_ITEM, value = 2017, weight = 200, negative = false, description = "财神降临，获得财神卡。"},
        {id = 3024, name = "天使降临", type = Chance.EventType.GAIN_ITEM, value = 2019, weight = 200, negative = false, description = "天使降临，获得天使卡。"},
        {id = 3025, name = "幸运轮盘", type = Chance.EventType.GAIN_ITEM, value = 2003, weight = 200, negative = false, description = "获得一张骰子加倍卡。"},
        {id = 3026, name = "穷神附身", type = Chance.EventType.GAIN_ITEM, value = 2018, weight = 300, negative = false, description = "穷神附身，持续5回合，支付的租金和罚金翻倍。"},
        {id = 3027, name = "天使附身", type = Chance.EventType.GAIN_ITEM, value = 2019, weight = 300, negative = false, description = "天使附身，持续5回合，免受负面道具效果影响。"},
        
        -- 3028-3034: 道具丢失和移动惩罚
        {id = 3028, name = "小偷光临", type = Chance.EventType.LOSE_RANDOM_ITEM, value = 1, weight = 200, negative = true, description = "小偷光临，你随机丢失1张道具卡。"},
        {id = 3029, name = "强盗来袭", type = Chance.EventType.LOSE_ALL_ITEMS, value = 0, weight = 200, negative = true, description = "强盗来袭，你丢失所有道具卡。"},
        {id = 3030, name = "火灾", type = Chance.EventType.LOSE_PROPERTY, value = 1, weight = 200, negative = true, description = "你遭遇火灾，随机丢失1张地块持有证。"},
        {id = 3031, name = "住院", type = Chance.EventType.FORCE_HOSPITAL, value = 0, weight = 200, negative = true, description = "你突然晕倒了，被送入医院。"},
        {id = 3032, name = "迷路", type = Chance.EventType.FORCE_MOUNTAIN, value = 0, weight = 200, negative = true, description = "你迷路走进了深山。"},
        {id = 3033, name = "税务局", type = Chance.EventType.TELEPORT_TO_TAX, value = 0, weight = 200, negative = true, description = "你收到税务局通知，立刻赶往税务局交代问题。"},
        {id = 3034, name = "密道", type = Chance.EventType.TELEPORT_SECRET, value = 0, weight = 200, negative = false, description = "你发现密道，进入黑市。"}
    }
    
    return events
end

return Chance
