-- 机会卡系统（精简版）

local Chance = {}
local Player = require("player")
local Item = require("item")

Chance.EventType = {
    GAIN_MONEY = "gain_money",
    LOSE_MONEY = "lose_money",
    MOVE_FORWARD = "move_forward",
    MOVE_BACKWARD = "move_backward",
    TELEPORT = "teleport",
    COLLECT_FROM_ALL = "collect_from_all",
    PAY_TO_ALL = "pay_to_all",
    DRAW_ITEM = "draw_item"
}

local function getTileIndexByType(gameState, tileType)
    if gameState and gameState.tileIndexByType and tileType then
        return gameState.tileIndexByType[tileType]
    end
    return nil
end

local function getTileCount(gameState)
    if gameState and gameState.tileCount then
        return gameState.tileCount
    end
    return 16
end

function Chance.createFromConfig(config)
    local events = {}
    for _, entry in ipairs(config.chanceEvents or {}) do
        table.insert(events, entry)
    end
    return events
end

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
    local current = 0
    for _, event in ipairs(chanceList) do
        current = current + (event.weight or 1)
        if rand <= current then
            return event
        end
    end
    
    return chanceList[#chanceList]
end

-- 执行机会卡
function Chance.execute(event, drawer, allPlayers, gameState)
    local result = {message = event.description or event.name or "机会卡", applied = true}
    if not event then
        return {message = "没有可用的机会卡", applied = false}
    end
    
    local tileCount = getTileCount(gameState)
    local rules = gameState and gameState.config and gameState.config.rules or {}
    local angelProtected = (drawer.buffType == "angel" and drawer.buffTurns and drawer.buffTurns > 0)
    
    if event.type == Chance.EventType.GAIN_MONEY then
        Player.addMoney(drawer, event.value or 0)
        result.message = string.format("%s，获得 %d 金币", event.name or "奖金", event.value or 0)
        
    elseif event.type == Chance.EventType.LOSE_MONEY then
        if angelProtected then
            result.message = "天使护符生效，免除罚款"
        else
            Player.subtractMoney(drawer, event.value or 0)
            result.message = string.format("%s，失去 %d 金币", event.name or "罚款", event.value or 0)
        end
        
    elseif event.type == Chance.EventType.MOVE_FORWARD then
        Player.moveForward(drawer, event.value or 0, tileCount)
        result.message = string.format("前进 %d 格", event.value or 0)
        
    elseif event.type == Chance.EventType.MOVE_BACKWARD then
        Player.moveBackward(drawer, event.value or 0, tileCount)
        result.message = string.format("后退 %d 格", event.value or 0)
        
    elseif event.type == Chance.EventType.TELEPORT then
        local target = getTileIndexByType(gameState, event.target) or 1
        Player.moveTo(drawer, target, tileCount)
        result.message = string.format("前往 %s", event.target or "指定地点")
        if event.target == "hospital" then
            Player.enterHospital(drawer, rules.hospitalStay or 1)
            if rules.hospitalFee then
                Player.subtractMoney(drawer, rules.hospitalFee)
            end
        elseif event.target == "mountain" then
            Player.enterMountain(drawer, rules.mountainStay or 1)
        end
        
    elseif event.type == Chance.EventType.COLLECT_FROM_ALL then
        local total = 0
        for _, p in ipairs(allPlayers or {}) do
            if p.id ~= drawer.id then
                total = total + Player.transfer(p, drawer, event.value or 0)
            end
        end
        result.message = string.format("每人支付 %d 金币，共收获 %d", event.value or 0, total)
        
    elseif event.type == Chance.EventType.PAY_TO_ALL then
        if angelProtected then
            result.message = "天使护符生效，免除请客"
        else
            for _, p in ipairs(allPlayers or {}) do
                if p.id ~= drawer.id then
                    Player.transfer(drawer, p, event.value or 0)
                end
            end
            result.message = string.format("每人获得你 %d 金币", event.value or 0)
        end
        
    elseif event.type == Chance.EventType.DRAW_ITEM then
        local itemId = Item.drawRandom(gameState.config)
        local added = Player.addItem(drawer, itemId)
        if added then
            result.message = string.format("获得道具：%s", Item.getName(itemId))
        else
            result.message = "道具栏已满，无法获得新道具"
        end
    end
    
    return result
end

return Chance
