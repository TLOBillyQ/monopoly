-- 道具系统（精简版）

local Item = {}
local Player = require("player")

Item.Type = {
    FREE_PASS = "free_pass",
    DICE_DOUBLE = "dice_double",
    ANGEL = "angel",
    HEAL = "heal"
}

Item.IdToType = {
    [2001] = Item.Type.FREE_PASS,
    [2002] = Item.Type.DICE_DOUBLE,
    [2003] = Item.Type.ANGEL,
    [2004] = Item.Type.HEAL
}

Item.Info = {
    [Item.Type.FREE_PASS] = {id = 2001, name = "免费卡", description = "免除下一次租金或税金。"},
    [Item.Type.DICE_DOUBLE] = {id = 2002, name = "加倍骰子", description = "本回合掷骰结果翻倍。"},
    [Item.Type.ANGEL] = {id = 2003, name = "幸运护符", description = "5 回合内免疫负面机会卡。"},
    [Item.Type.HEAL] = {id = 2004, name = "急救包", description = "立刻解除住院/深山等待。"}
}

local function resolveItemType(itemId)
    return Item.IdToType[itemId]
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
        total = total + (entry.weight or 1)
    end
    if total <= 0 then
        return items[1] and items[1].id or nil
    end
    
    local rand = math.random() * total
    local current = 0
    for _, entry in ipairs(items) do
        current = current + (entry.weight or 1)
        if rand <= current then
            return entry.id
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
        return {success = false, message = "未知道具"}
    end
    
    local rules = gameState and gameState.config and gameState.config.rules or {}
    local result = {success = true, message = Item.getName(itemId)}
    
    if itemType == Item.Type.FREE_PASS then
        player.freePass = true
        result.message = "下次租金或税金豁免"
        
    elseif itemType == Item.Type.DICE_DOUBLE then
        player.pendingDiceDouble = true
        result.message = "本回合骰子结果加倍"
        
    elseif itemType == Item.Type.ANGEL then
        Player.applyBuff(player, "angel", 5)
        result.message = "获得 5 回合的幸运护符"
        
    elseif itemType == Item.Type.HEAL then
        if player.state == Player.State.IN_HOSPITAL or player.state == Player.State.IN_MOUNTAIN then
            Player.releaseFromStay(player)
            result.message = "立即恢复，可以继续行动"
        else
            Player.addMoney(player, rules.hospitalFee or 0)
            result.message = "状态良好，转为获得一点补给"
        end
    end
    
    Item.removeFromPlayer(player, itemId)
    return result
end

return Item
