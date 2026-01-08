-- 道具系统（完整数据适配，无 Spoke 版）

local Item = {}
local Player = require("player")
local Property = require("property")

Item.Type = {
    FREE_PASS = "free_pass",
    REMOTE_DICE = "remote_dice",
    DICE_DOUBLE = "dice_double",
    ROADBLOCK = "roadblock",
    LANDMINE = "landmine",
    CLEAR_ROAD = "clear_road",
    STEAL = "steal",
    MONSTER = "monster",
    FORCE_ACQUIRE = "force_acquire",
    TAX_FREE = "tax_free",
    EQUAL_WEALTH = "equal_wealth",
    BANISH = "banish",
    MISSILE = "missile",
    TAX_CHECK = "tax_check",
    INVOKE_GOD = "invoke_god",
    SEND_GOD = "send_god",
    WEALTH_GOD = "wealth_god",
    POOR_GOD = "poor_god",
    ANGEL = "angel"
}

Item.IdToType = {
    [2001] = Item.Type.FREE_PASS,
    [2002] = Item.Type.REMOTE_DICE,
    [2003] = Item.Type.DICE_DOUBLE,
    [2004] = Item.Type.ROADBLOCK,
    [2005] = Item.Type.LANDMINE,
    [2006] = Item.Type.CLEAR_ROAD,
    [2007] = Item.Type.STEAL,
    [2008] = Item.Type.MONSTER,
    [2009] = Item.Type.FORCE_ACQUIRE,
    [2010] = Item.Type.TAX_FREE,
    [2011] = Item.Type.EQUAL_WEALTH,
    [2012] = Item.Type.BANISH,
    [2013] = Item.Type.MISSILE,
    [2014] = Item.Type.TAX_CHECK,
    [2015] = Item.Type.INVOKE_GOD,
    [2016] = Item.Type.SEND_GOD,
    [2017] = Item.Type.WEALTH_GOD,
    [2018] = Item.Type.POOR_GOD,
    [2019] = Item.Type.ANGEL
}

Item.Info = {
    [Item.Type.FREE_PASS] = { id = 2001, name = "免费卡", description = "免除下一次租金或税金。" },
    [Item.Type.REMOTE_DICE] = { id = 2002, name = "遥控骰子卡", description = "控制下一次掷骰点数。" },
    [Item.Type.DICE_DOUBLE] = { id = 2003, name = "骰子加倍卡", description = "本回合掷骰结果翻倍。" },
    [Item.Type.ROADBLOCK] = { id = 2004, name = "路障卡", description = "放置路障，阻挡其他玩家。" },
    [Item.Type.LANDMINE] = { id = 2005, name = "地雷卡", description = "在脚下放置地雷。" },
    [Item.Type.CLEAR_ROAD] = { id = 2006, name = "清障卡", description = "清除前方障碍。" },
    [Item.Type.STEAL] = { id = 2007, name = "偷窃卡", description = "偷取其他玩家的道具。" },
    [Item.Type.MONSTER] = { id = 2008, name = "怪兽卡", description = "释放怪兽拆除建筑。" },
    [Item.Type.FORCE_ACQUIRE] = { id = 2009, name = "强征卡", description = "强制获得当前地块。" },
    [Item.Type.TAX_FREE] = { id = 2010, name = "免税卡", description = "抵扣下一次税金。" },
    [Item.Type.EQUAL_WEALTH] = { id = 2011, name = "均富卡", description = "与目标平分金币。" },
    [Item.Type.BANISH] = { id = 2012, name = "流放卡", description = "将目标流放到深山。" },
    [Item.Type.MISSILE] = { id = 2013, name = "导弹卡", description = "攻击范围内的建筑。" },
    [Item.Type.TAX_CHECK] = { id = 2014, name = "查税卡", description = "让目标支付税金。" },
    [Item.Type.INVOKE_GOD] = { id = 2015, name = "请神卡", description = "夺取他人附身神。" },
    [Item.Type.SEND_GOD] = { id = 2016, name = "送神卡", description = "将穷神转移出去。" },
    [Item.Type.WEALTH_GOD] = { id = 2017, name = "财神卡", description = "财神附身，收益翻倍。" },
    [Item.Type.POOR_GOD] = { id = 2018, name = "穷神卡", description = "让目标穷神附身。" },
    [Item.Type.ANGEL] = { id = 2019, name = "天使卡", description = "天使附身，免疫负面效果。" }
}

local function resolveItemType(itemId)
    return Item.IdToType[itemId]
end

local function otherPlayers(player, gameState)
    local others = {}
    if gameState and gameState.players then
        for _, p in ipairs(gameState.players) do
            if p.id ~= player.id and not Player.isBankrupt(p) then
                table.insert(others, p)
            end
        end
    end
    return others
end

local function getTileIndexByType(gameState, tileType, defaultValue)
    if gameState and gameState.tileIndexByType and tileType then
        return gameState.tileIndexByType[tileType] or defaultValue
    end
    return defaultValue
end

function Item.getInfo(itemId)
    local t = resolveItemType(itemId)
    return t and Item.Info[t] or nil
end

function Item.getName(itemId)
    local info = Item.getInfo(itemId)
    return info and info.name or ("道具" .. tostring(itemId))
end

function Item.drawRandom(config)
    local items = (config and config.items) or {}
    local total = 0
    for _, entry in ipairs(items) do
        if (entry.weight or 0) > 0 then
            total = total + entry.weight
        end
    end
    if total <= 0 then
        return items[1] and items[1].id or nil
    end
    local rand = math.random() * total
    local current = 0
    for _, entry in ipairs(items) do
        if (entry.weight or 0) > 0 then
            current = current + entry.weight
            if rand <= current then
                return entry.id
            end
        end
    end
    return items[#items] and items[#items].id or nil
end

function Item.removeFromPlayer(player, itemId)
    if not player or not player.items then
        return false
    end
    for idx, id in ipairs(player.items) do
        if id == itemId then
            Player.removeItem(player, idx)
            return true
        end
    end
    return false
end

-- 立即使用并消耗道具
function Item.use(itemId, player, gameState)
    local itemType = resolveItemType(itemId)
    if not itemType then
        return { success = false, message = "未知道具" }
    end

    local rules = (gameState and gameState.config and gameState.config.rules) or {}
    local others = otherPlayers(player, gameState)
    local target = others[1]
    local result = { success = true, message = Item.getName(itemId) }

    if itemType == Item.Type.FREE_PASS then
        player.freePass = true
        result.message = "下次租金或税金豁免"
    elseif itemType == Item.Type.REMOTE_DICE then
        player.pendingDiceOverride = 6
        result.message = "遥控骰子：下一次掷骰固定为 6 点"
    elseif itemType == Item.Type.DICE_DOUBLE then
        player.pendingDiceDouble = true
        result.message = "本回合骰子结果加倍"
    elseif itemType == Item.Type.ROADBLOCK or itemType == Item.Type.LANDMINE or itemType == Item.Type.CLEAR_ROAD then
        result.message = Item.getName(itemId) .. " 功能未实现，已作废"
    elseif itemType == Item.Type.STEAL then
        if target and target.items and #target.items > 0 then
            local stolen = Player.removeRandomItem(target)
            Player.addItem(player, stolen)
            result.message = string.format("偷取 %s 的道具 %s", target.name, Item.getName(stolen))
        else
            result.message = "目标没有可偷的道具"
        end
    elseif itemType == Item.Type.MONSTER then
        result.message = "怪兽卡效果未实现，已作废"
    elseif itemType == Item.Type.FORCE_ACQUIRE then
        local tiles = gameState and gameState.tiles
        local tile = tiles and tiles[player.position]
        if tile and tile.type == "property" and tile.owner and tile.owner ~= player.id then
            local cost = math.floor((tile.price or 0) * 1.2)
            if player.money >= cost then
                Property.reset(tile)
                Property.buy(tile, player.id, tile.price)
                Player.subtractMoney(player, cost)
                Player.acquireProperty(player, tile.id)
                result.message = string.format("强征成功，花费 %d 获得 %s", cost, tile.name)
            else
                result.message = "资金不足，无法强征"
            end
        else
            result.message = "当前位置无法强征"
        end
    elseif itemType == Item.Type.TAX_FREE then
        player.freePass = true
        result.message = "免税卡已激活"
    elseif itemType == Item.Type.EQUAL_WEALTH then
        if target then
            local total = player.money + target.money
            local half = math.floor(total / 2)
            local function setFunds(p, desired)
                local diff = desired - p.money
                if diff >= 0 then
                    Player.addMoney(p, diff)
                else
                    Player.subtractMoney(p, -diff)
                end
            end
            setFunds(player, half)
            setFunds(target, total - half)
            result.message = string.format("与 %s 平分金币", target.name)
        else
            result.message = "没有可平分的目标"
        end
    elseif itemType == Item.Type.BANISH then
        if target then
            local dest = getTileIndexByType(gameState, "mountain", target.tileCount)
            if dest then
                Player.moveTo(target, dest, target.tileCount)
            end
            Player.enterMountain(target, rules.mountainStay or 1)
            result.message = string.format("将 %s 流放到深山", target.name)
        else
            result.message = "没有可流放的目标"
        end
    elseif itemType == Item.Type.MISSILE then
        result.message = "导弹卡效果未实现，已作废"
    elseif itemType == Item.Type.TAX_CHECK then
        if target then
            local tax = math.floor(target.money * (rules.taxRate or 0.5))
            Player.transfer(target, player, tax)
            result.message = string.format("%s 被查税，支付 %d", target.name, tax)
        else
            result.message = "没有可查税的目标"
        end
    elseif itemType == Item.Type.INVOKE_GOD then
        if target and target.buffType then
            player.buffType = target.buffType
            player.buffTurns = target.buffTurns
            target.buffType = nil
            target.buffTurns = 0
            result.message = string.format("夺取了 %s 的附身状态", target.name)
        else
            result.message = "目标没有附身状态"
        end
    elseif itemType == Item.Type.SEND_GOD then
        if player.buffType == "poor" and target then
            target.buffType = "poor"
            target.buffTurns = player.buffTurns
            player.buffType = nil
            player.buffTurns = 0
            result.message = string.format("将穷神送给 %s", target.name)
        else
            result.message = "只有被穷神附身时才能使用"
        end
    elseif itemType == Item.Type.WEALTH_GOD then
        Player.applyBuff(player, "wealth", rules.wealthDuration or 5)
        result.message = "财神附身，收益翻倍"
    elseif itemType == Item.Type.POOR_GOD then
        if target then
            Player.applyBuff(target, "poor", rules.poorDuration or 5)
            result.message = string.format("让 %s 被穷神附身", target.name)
        else
            result.message = "没有目标可施加穷神"
        end
    elseif itemType == Item.Type.ANGEL then
        Player.applyBuff(player, "angel", rules.angelDuration or 5)
        result.message = "天使附身，免疫负面效果"
    end

    Item.removeFromPlayer(player, itemId)
    return result
end

return Item
