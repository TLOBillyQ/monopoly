-- 机会卡系统（完整数据版，同步 main 数据）

local Chance = {}
local Player = require("player")
local Item = require("item")
local Property = require("property")

-- 事件类型枚举
Chance.EventType = {
    GAIN_MONEY = "gain_money",
    LOSE_MONEY = "lose_money",
    LOSE_PERCENT = "lose_percent",
    LOSE_PERCENT_ALL = "lose_percent_all",
    COLLECT_FROM_ALL = "collect_from_all",
    PAY_TO_ALL = "pay_to_all",
    MOVE_FORWARD = "move_forward",
    MOVE_BACKWARD = "move_backward",
    TELEPORT_TO_TAX = "teleport_to_tax",
    TELEPORT_TO_HOSPITAL = "teleport_to_hospital",
    TELEPORT_TO_MARKET = "teleport_to_market",
    TELEPORT_TO_START = "teleport_to_start",
    TELEPORT_SECRET = "teleport_secret",
    SKIP_JAIL = "skip_jail",
    GAIN_ITEM = "gain_item",
    LOSE_RANDOM_ITEM = "lose_random_item",
    LOSE_ALL_ITEMS = "lose_all_items",
    LOSE_PROPERTY = "lose_property",
    FORCE_HOSPITAL = "force_hospital",
    FORCE_MOUNTAIN = "force_mountain"
}

local function getTileIndexByType(gameState, tileType, defaultValue)
    if gameState and gameState.tileIndexByType and tileType then
        return gameState.tileIndexByType[tileType] or defaultValue
    end
    return defaultValue
end

local function getTileCount(gameState)
    if gameState and gameState.tileCount then
        return gameState.tileCount
    end
    return 16
end

-- 从配置构建机会卡列表
function Chance.createFromConfig(config)
    local events = {}
    for _, entry in ipairs(config.chanceEvents or {}) do
        local evt = {}
        for k, v in pairs(entry) do
            evt[k] = v
        end
        evt.eventType = entry.type or entry.eventType
        table.insert(events, evt)
    end
    return events
end

-- 按权重随机抽取一张机会卡
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

local function teleportTo(drawer, tileIndex, tileCount)
    if tileIndex then
        Player.moveTo(drawer, tileIndex, tileCount)
    end
end

local function applyHospital(drawer, rules)
    Player.enterHospital(drawer, rules.hospitalStay or 1)
    if rules.hospitalFee then
        Player.subtractMoney(drawer, rules.hospitalFee)
    end
end

-- 执行机会卡
function Chance.execute(event, drawer, allPlayers, gameState)
    if not event then
        return {message = "没有可用的机会卡", applied = false}
    end

    local rules = (gameState and gameState.config and gameState.config.rules) or {}
    local tileCount = getTileCount(gameState)
    local eventType = event.eventType or event.type
    local angelProtected = event.negative and drawer.buffType == "angel" and (drawer.buffTurns or 0) > 0

    if angelProtected then
        return {message = "天使护符生效，负面事件无效", applied = false}
    end

    local result = {message = event.description or event.name or "机会卡", applied = true}

    if eventType == Chance.EventType.GAIN_MONEY then
        Player.addMoney(drawer, event.value or 0)
        result.message = string.format("%s，获得 %d 金币", event.name or "奖金", event.value or 0)

    elseif eventType == Chance.EventType.LOSE_MONEY then
        Player.subtractMoney(drawer, event.value or 0)
        result.message = string.format("%s，失去 %d 金币", event.name or "罚款", event.value or 0)

    elseif eventType == Chance.EventType.LOSE_PERCENT then
        local amount = math.floor(drawer.money * (event.value or 0))
        Player.subtractMoney(drawer, amount)
        result.message = string.format("损失资金的 %d%%（%d 金币）", math.floor((event.value or 0) * 100), amount)

    elseif eventType == Chance.EventType.LOSE_PERCENT_ALL then
        for _, p in ipairs(allPlayers or {}) do
            if p.id ~= drawer.id then
                local amount = math.floor(p.money * (event.value or 0))
                Player.subtractMoney(p, amount)
            end
        end
        result.message = "所有其他玩家损失资金"

    elseif eventType == Chance.EventType.COLLECT_FROM_ALL then
        local total = 0
        for _, p in ipairs(allPlayers or {}) do
            if p.id ~= drawer.id then
                total = total + Player.transfer(p, drawer, event.value or 0)
            end
        end
        result.message = string.format("每人支付 %d 金币，共收获 %d", event.value or 0, total)

    elseif eventType == Chance.EventType.PAY_TO_ALL then
        for _, p in ipairs(allPlayers or {}) do
            if p.id ~= drawer.id then
                Player.transfer(drawer, p, event.value or 0)
            end
        end
        result.message = string.format("请客，每人获得 %d 金币", event.value or 0)

    elseif eventType == Chance.EventType.MOVE_FORWARD then
        Player.moveForward(drawer, event.value or 0, tileCount)
        result.message = string.format("前进 %d 格", event.value or 0)

    elseif eventType == Chance.EventType.MOVE_BACKWARD then
        Player.moveBackward(drawer, event.value or 0, tileCount)
        result.message = string.format("后退 %d 格", event.value or 0)

    elseif eventType == Chance.EventType.TELEPORT_TO_TAX then
        local target = getTileIndexByType(gameState, "tax_office", 1)
        teleportTo(drawer, target, tileCount)
        result.message = "前往税务局"

    elseif eventType == Chance.EventType.TELEPORT_TO_HOSPITAL then
        local target = getTileIndexByType(gameState, "hospital", 1)
        teleportTo(drawer, target, tileCount)
        applyHospital(drawer, rules)
        result.message = "前往医院并住院"

    elseif eventType == Chance.EventType.TELEPORT_TO_MARKET then
        local target = getTileIndexByType(gameState, "black_market", 1)
        teleportTo(drawer, target, tileCount)
        result.message = "前往黑市"

    elseif eventType == Chance.EventType.TELEPORT_TO_START then
        local target = getTileIndexByType(gameState, "start", 1)
        teleportTo(drawer, target, tileCount)
        result.message = "回到起点"

    elseif eventType == Chance.EventType.TELEPORT_SECRET then
        local target = getTileIndexByType(gameState, "black_market", 1)
        teleportTo(drawer, target, tileCount)
        result.message = "通过密道进入黑市"

    elseif eventType == Chance.EventType.SKIP_JAIL then
        drawer.freeJailCard = true
        result.message = "获得免费停留卡"

    elseif eventType == Chance.EventType.GAIN_ITEM then
        local itemId = event.value
        local added = Player.addItem(drawer, itemId)
        if not added then
            result.message = "道具栏已满，无法获得道具"
        else
            local name = Item.getName(itemId)
            result.message = string.format("获得道具：%s", name)
            local useResult = Item.use and Item.use(itemId, drawer, gameState)
            if useResult and useResult.message then
                result.message = useResult.message
            end
        end

    elseif eventType == Chance.EventType.LOSE_RANDOM_ITEM then
        local lost = Player.removeRandomItem(drawer)
        result.message = lost and string.format("丢失一张道具（ID %s）", tostring(lost)) or "没有道具可丢失"

    elseif eventType == Chance.EventType.LOSE_ALL_ITEMS then
        local count = Player.clearAllItems(drawer)
        result.message = string.format("丢失所有道具，共 %d 张", count)

    elseif eventType == Chance.EventType.LOSE_PROPERTY then
        if drawer.properties and #drawer.properties > 0 then
            local lostPropertyId = Player.loseRandomProperty(drawer)
            if lostPropertyId and gameState and gameState.tiles then
                for _, t in ipairs(gameState.tiles) do
                    if t.id == lostPropertyId then
                        Property.reset(t)
                        break
                    end
                end
            end
            result.message = string.format("失去一块地块（ID %s）", tostring(lostPropertyId))
        else
            result.message = "没有地块可失去"
        end

    elseif eventType == Chance.EventType.FORCE_HOSPITAL then
        local target = getTileIndexByType(gameState, "hospital", 1)
        teleportTo(drawer, target, tileCount)
        applyHospital(drawer, rules)
        result.message = "强制住院"

    elseif eventType == Chance.EventType.FORCE_MOUNTAIN then
        local target = getTileIndexByType(gameState, "mountain", 1)
        teleportTo(drawer, target, tileCount)
        Player.enterMountain(drawer, rules.mountainStay or 1)
        result.message = "被迫进入深山"
    end

    return result
end

return Chance
