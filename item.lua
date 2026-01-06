-- 道具卡系统
-- Item Card System - 基于数据表设计（19个道具）

local Item = {}
local Player = require("player")

-- ==================== 道具类型 ====================
Item.Type = {
    -- 1级道具（基础卡）
    FREE_PASS = "free_pass",              -- 2001: 免费卡
    REMOTE_DICE = "remote_dice",          -- 2002: 遥控骰子卡
    DICE_DOUBLE = "dice_double",          -- 2003: 骰子加倍卡
    ROADBLOCK = "roadblock",              -- 2004: 路障卡
    LANDMINE = "landmine",                -- 2005: 地雷卡
    CLEAR_ROAD = "clear_road",            -- 2006: 清障卡
    
    -- 2级道具（中级卡）
    STEAL = "steal",                      -- 2007: 偷窃卡
    MONSTER = "monster",                  -- 2008: 怪兽卡
    FORCE_ACQUIRE = "force_acquire",      -- 2009: 强征卡
    TAX_FREE = "tax_free",                -- 2010: 免税卡
    EQUAL_WEALTH = "equal_wealth",        -- 2011: 均富卡
    BANISH = "banish",                    -- 2012: 流放卡
    
    -- 3级道具（高级卡）
    MISSILE = "missile",                  -- 2013: 导弹卡
    TAX_CHECK = "tax_check",              -- 2014: 查税卡
    INVOKE_GOD = "invoke_god",            -- 2015: 请神卡
    SEND_GOD = "send_god",                -- 2016: 送神卡
    
    -- 特殊神仙卡（只能通过机会卡获得）
    WEALTH_GOD = "wealth_god",            -- 2017: 财神卡
    POOR_GOD = "poor_god",                -- 2018: 穷神卡
    ANGEL = "angel"                       -- 2019: 天使卡
}

-- 道具ID映射到类型
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

-- 道具信息（从config中提取）
Item.Info = {
    [Item.Type.FREE_PASS] = {
        id = 2001, name = "免费卡", level = 1,
        description = "当你停留在其他玩家的地块上时，使用此卡可以免交本次租金。",
        triggerTime = "after_action"
    },
    [Item.Type.REMOTE_DICE] = {
        id = 2002, name = "遥控骰子卡", level = 1,
        description = "在你行动前可以使用，可以遥控骰子投出的点数。",
        triggerTime = "before_action"
    },
    [Item.Type.DICE_DOUBLE] = {
        id = 2003, name = "骰子加倍卡", level = 1,
        description = "投出骰子后可以使用，使当前投出的点数加倍。",
        triggerTime = "after_roll"
    },
    [Item.Type.ROADBLOCK] = {
        id = 2004, name = "路障卡", level = 1,
        description = "放置路障，任何玩家经过此地时强制停留1个回合。",
        triggerTime = "active_use"
    },
    [Item.Type.LANDMINE] = {
        id = 2005, name = "地雷卡", level = 1,
        description = "在脚下放置地雷，任何玩家经过此地时触发地雷，摧毁座驾并强制住院。",
        triggerTime = "active_use"
    },
    [Item.Type.CLEAR_ROAD] = {
        id = 2006, name = "清障卡", level = 1,
        description = "放出机器人清除前方12格以内的路障和地雷。",
        triggerTime = "before_action"
    },
    [Item.Type.STEAL] = {
        id = 2007, name = "偷窃卡", level = 2,
        description = "当你路过其他玩家时，可以选择使用此卡获得他的一个道具。",
        triggerTime = "pass_player"
    },
    [Item.Type.MONSTER] = {
        id = 2008, name = "怪兽卡", level = 2,
        description = "选择前后3格内其他玩家的建筑，释放怪兽拆除该建筑。",
        triggerTime = "active_use"
    },
    [Item.Type.FORCE_ACQUIRE] = {
        id = 2009, name = "强征卡", level = 2,
        description = "停留在其他玩家地块上时，支付费用后强制获得这块地块的所有权。",
        triggerTime = "after_action"
    },
    [Item.Type.TAX_FREE] = {
        id = 2010, name = "免税卡", level = 2,
        description = "在税务局征税时使用，可以抵扣本次税金。",
        triggerTime = "tax_time"
    },
    [Item.Type.EQUAL_WEALTH] = {
        id = 2011, name = "均富卡", level = 2,
        description = "选择一个玩家，你和该玩家平分你们的总资金。",
        triggerTime = "active_use"
    },
    [Item.Type.BANISH] = {
        id = 2012, name = "流放卡", level = 2,
        description = "选择一个玩家，将其强制流放到深山中。",
        triggerTime = "active_use"
    },
    [Item.Type.MISSILE] = {
        id = 2013, name = "导弹卡", level = 3,
        description = "向前后3格范围内释放导弹，摧毁所有建筑和座驾，玩家住进医院。",
        triggerTime = "active_use"
    },
    [Item.Type.TAX_CHECK] = {
        id = 2014, name = "查税卡", level = 3,
        description = "选择一个玩家，该玩家立即支付50%资金的所得税。",
        triggerTime = "active_use"
    },
    [Item.Type.INVOKE_GOD] = {
        id = 2015, name = "请神卡", level = 3,
        description = "选择其他玩家，将其身上的附身神请到自己身上。",
        triggerTime = "active_use"
    },
    [Item.Type.SEND_GOD] = {
        id = 2016, name = "送神卡", level = 3,
        description = "被穷神附身时使用，选择一个玩家，将穷神送到他身上。",
        triggerTime = "when_cursed"
    },
    [Item.Type.WEALTH_GOD] = {
        id = 2017, name = "财神卡", level = 3,
        description = "财神附身5回合，收到的租金和奖金翻倍。",
        triggerTime = "active_use"
    },
    [Item.Type.POOR_GOD] = {
        id = 2018, name = "穷神卡", level = 3,
        description = "选择一个玩家，令其穷神附身5回合，支付的租金和罚金翻倍。",
        triggerTime = "active_use"
    },
    [Item.Type.ANGEL] = {
        id = 2019, name = "天使卡", level = 3,
        description = "天使附身5回合，免受负面卡牌效果影响。",
        triggerTime = "active_use"
    }
}

-- ==================== 道具获取和管理 ====================

-- 获取道具信息
function Item.getInfo(itemId)
    local itemType = Item.IdToType[itemId]
    if itemType then
        return Item.Info[itemType]
    end
    return nil
end

-- 获取道具名称
function Item.getName(itemId)
    local info = Item.getInfo(itemId)
    return info and info.name or "未知道具"
end

-- 获取道具描述
function Item.getDescription(itemId)
    local info = Item.getInfo(itemId)
    return info and info.description or "无描述"
end

-- 根据权重随机抽取一个道具
function Item.drawRandom(config)
    local items = config.items
    local totalWeight = 0
    
    for _, item in ipairs(items) do
        if item.weight > 0 then
            totalWeight = totalWeight + item.weight
        end
    end
    
    if totalWeight <= 0 then
        return items[1].id
    end
    
    local rand = math.random() * totalWeight
    local currentWeight = 0
    
    for _, item in ipairs(items) do
        if item.weight > 0 then
            currentWeight = currentWeight + item.weight
            if rand <= currentWeight then
                return item.id
            end
        end
    end
    
    return items[1].id
end

-- ==================== 道具使用逻辑 ====================

-- 执行道具效果
-- itemId: 道具ID, user: 使用者, target: 目标玩家, gameState: 游戏状态
function Item.execute(itemId, user, target, gameState)
    local result = {success = false, message = ""}
    local itemType = Item.IdToType[itemId]
    
    if not itemType then
        result.message = "无效的道具"
        return result
    end
    
    -- 检查天使附身免疫
    if user.buffType == "angel" then
        -- 某些道具在天使保护下无法使用（如负面效果）
        -- 这里需要判断具体道具
    end
    
    -- 执行道具效果
    if itemType == Item.Type.FREE_PASS then
        -- 2001: 免费卡 - 免交本次租金（在支付环节处理）
        result.success = true
        result.message = "使用免费卡，本次租金豁免"
        result.effectType = "skip_rent"
        
    elseif itemType == Item.Type.REMOTE_DICE then
        -- 2002: 遥控骰子 - 可以控制骰子点数（UI处理）
        result.success = true
        result.message = "使用遥控骰子，可以选择投掷点数"
        result.effectType = "remote_dice"
        
    elseif itemType == Item.Type.DICE_DOUBLE then
        -- 2003: 骰子加倍 - 当前骰子点数加倍
        result.success = true
        result.message = "使用骰子加倍卡，本次点数翻倍"
        result.effectType = "dice_double"
        
    elseif itemType == Item.Type.ROADBLOCK then
        -- 2004: 路障卡 - 放置路障（需要玩家选择位置）
        result.success = true
        result.message = "使用路障卡，选择放置位置"
        result.effectType = "roadblock"
        result.requiresSelection = true
        
    elseif itemType == Item.Type.LANDMINE then
        -- 2005: 地雷卡 - 放置地雷（在当前位置）
        result.success = true
        result.message = "使用地雷卡，在脚下放置地雷"
        result.effectType = "landmine"
        
    elseif itemType == Item.Type.CLEAR_ROAD then
        -- 2006: 清障卡 - 清除前方障碍
        result.success = true
        result.message = "使用清障卡，清除前方障碍"
        result.effectType = "clear_road"
        
    elseif itemType == Item.Type.STEAL then
        -- 2007: 偷窃卡 - 偷取目标的一个道具
        if target and #target.items > 0 then
            local stolenId = target.items[math.random(1, #target.items)]
            Player.removeItem(target, 1)
            Player.addItem(user, stolenId)
            result.success = true
            result.message = "偷取了一个道具"
            result.effectType = "steal"
        else
            result.message = "目标没有道具"
        end
        
    elseif itemType == Item.Type.MONSTER then
        -- 2008: 怪兽卡 - 拆除附近建筑
        result.success = true
        result.message = "使用怪兽卡，选择要拆除的建筑"
        result.effectType = "monster"
        result.requiresSelection = true
        
    elseif itemType == Item.Type.FORCE_ACQUIRE then
        -- 2009: 强征卡 - 强制购买他人地块
        if target then
            result.success = true
            result.message = "使用强征卡，强制购买目标地块"
            result.effectType = "force_acquire"
            result.requiresTarget = true
        end
        
    elseif itemType == Item.Type.TAX_FREE then
        -- 2010: 免税卡 - 免除税金（在税务局处理）
        result.success = true
        result.message = "使用免税卡，本次税金豁免"
        result.effectType = "tax_free"
        
    elseif itemType == Item.Type.EQUAL_WEALTH then
        -- 2011: 均富卡 - 与目标平分金币
        if target then
            local totalMoney = user.money + target.money
            local half = math.floor(totalMoney / 2)
            Player.subtractMoney(user, user.money - half)
            Player.transfer(target, user, target.money - half)
            result.success = true
            result.message = "使用均富卡，与" .. target.name .. "平分金币"
            result.effectType = "equal_wealth"
        end
        
    elseif itemType == Item.Type.BANISH then
        -- 2012: 流放卡 - 强制流放到深山
        if target then
            Player.moveTo(target, 15)  -- 深山位置
            Player.enterMountain(target, gameState.config.rules.mountainStay)
            result.success = true
            result.message = "将" .. target.name .. "流放到深山"
            result.effectType = "banish"
        end
        
    elseif itemType == Item.Type.MISSILE then
        -- 2013: 导弹卡 - 摧毁范围内建筑和座驾
        result.success = true
        result.message = "使用导弹卡，选择攻击范围"
        result.effectType = "missile"
        result.requiresSelection = true
        
    elseif itemType == Item.Type.TAX_CHECK then
        -- 2014: 查税卡 - 让目标支付50%税金
        if target then
            local taxAmount = math.floor(target.money * gameState.config.rules.taxRate)
            Player.transfer(target, gameState, taxAmount)  -- 转给游戏状态（国库）
            result.success = true
            result.message = target.name .. "被查税，支付" .. taxAmount .. "金币"
            result.effectType = "tax_check"
        end
        
    elseif itemType == Item.Type.INVOKE_GOD then
        -- 2015: 请神卡 - 从目标获得附身神
        if target and target.buffType then
            user.buffType = target.buffType
            user.buffTurns = target.buffTurns
            target.buffType = nil
            target.buffTurns = 0
            result.success = true
            result.message = "请来了附身在" .. target.name .. "身上的神仙"
            result.effectType = "invoke_god"
        end
        
    elseif itemType == Item.Type.SEND_GOD then
        -- 2016: 送神卡 - 将穷神转移到目标
        if user.buffType == "poor" and target then
            target.buffType = "poor"
            target.buffTurns = user.buffTurns
            user.buffType = nil
            user.buffTurns = 0
            result.success = true
            result.message = "将穷神送给了" .. target.name
            result.effectType = "send_god"
        else
            result.message = "只能在被穷神附身时使用"
        end
        
    elseif itemType == Item.Type.WEALTH_GOD then
        -- 2017: 财神卡 - 财神附身5回合
        Player.applyBuff(user, "wealth", gameState.config.rules.wealthDuration)
        result.success = true
        result.message = "财神附身，收益翻倍"
        result.effectType = "wealth_god"
        
    elseif itemType == Item.Type.POOR_GOD then
        -- 2018: 穷神卡 - 穷神附身目标5回合
        if target then
            Player.applyBuff(target, "poor", gameState.config.rules.poorDuration)
            result.success = true
            result.message = target.name .. "被穷神附身"
            result.effectType = "poor_god"
        end
        
    elseif itemType == Item.Type.ANGEL then
        -- 2019: 天使卡 - 天使附身5回合
        Player.applyBuff(user, "angel", gameState.config.rules.angelDuration)
        result.success = true
        result.message = "天使附身，免受负面效果"
        result.effectType = "angel"
    end
    
    return result
end

return Item
