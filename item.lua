-- 道具卡系统
-- Item Card System

local Item = {}

-- 道具类型
Item.Type = {
    -- 行动前使用
    REMOTE_DICE = "remote_dice",  -- 遥控骰子
    CLEAR_ROAD = "clear_road",  -- 清障卡
    ROADBLOCK = "roadblock",  -- 路障卡
    LANDMINE = "landmine",  -- 地雷卡
    
    -- 主动使用（行动前后）
    MONSTER = "monster",  -- 怪兽卡
    MISSILE = "missile",  -- 导弹卡
    BALANCED_WEALTH = "balanced_wealth",  -- 均富卡
    EXILE = "exile",  -- 流放卡
    TAX_CHECK = "tax_check",  -- 查税卡
    FORCED_PURCHASE = "forced_purchase",  -- 强征卡
    REQUEST_GOD = "request_god",  -- 请神卡
    SEND_GOD = "send_god",  -- 送神卡
    POOR_GOD = "poor_god",  -- 穷神卡
    WEALTH_GOD = "wealth_god",  -- 财神卡
    TRANSFER = "transfer",  -- 转让卡
    
    -- 被动触发
    STEAL = "steal",  -- 偷窃卡
    FREE_PASS = "free_pass",  -- 免费卡
    TAX_FREE = "tax_free",  -- 免税卡
    DICE_DOUBLE = "dice_double",  -- 骰子加倍卡
    ANGEL = "angel"  -- 天使卡
}

-- 使用时机
Item.UseTime = {
    BEFORE_ACTION = "before_action",  -- 行动前
    ACTIVE = "active",  -- 主动（行动前或后）
    TRIGGER = "trigger"  -- 被动触发
}

-- 创建道具
function Item.new(itemType)
    local item = {
        type = itemType,
        name = Item.getName(itemType),
        description = Item.getDescription(itemType),
        useTime = Item.getUseTime(itemType),
        weight = Item.getWeight(itemType)  -- 抽取权重
    }
    
    return item
end

-- 获取道具名称
function Item.getName(itemType)
    local names = {
        [Item.Type.REMOTE_DICE] = "遥控骰子",
        [Item.Type.CLEAR_ROAD] = "清障卡",
        [Item.Type.ROADBLOCK] = "路障卡",
        [Item.Type.LANDMINE] = "地雷卡",
        [Item.Type.MONSTER] = "怪兽卡",
        [Item.Type.MISSILE] = "导弹卡",
        [Item.Type.BALANCED_WEALTH] = "均富卡",
        [Item.Type.EXILE] = "流放卡",
        [Item.Type.TAX_CHECK] = "查税卡",
        [Item.Type.FORCED_PURCHASE] = "强征卡",
        [Item.Type.REQUEST_GOD] = "请神卡",
        [Item.Type.SEND_GOD] = "送神卡",
        [Item.Type.POOR_GOD] = "穷神卡",
        [Item.Type.WEALTH_GOD] = "财神卡",
        [Item.Type.TRANSFER] = "转让卡",
        [Item.Type.STEAL] = "偷窃卡",
        [Item.Type.FREE_PASS] = "免费卡",
        [Item.Type.TAX_FREE] = "免税卡",
        [Item.Type.DICE_DOUBLE] = "骰子加倍卡",
        [Item.Type.ANGEL] = "天使卡"
    }
    return names[itemType] or "未知道具"
end

-- 获取道具描述
function Item.getDescription(itemType)
    local descriptions = {
        [Item.Type.REMOTE_DICE] = "可以控制骰子点数",
        [Item.Type.CLEAR_ROAD] = "清除前方12格内的路障和地雷",
        [Item.Type.ROADBLOCK] = "在指定位置放置路障",
        [Item.Type.LANDMINE] = "在指定位置放置地雷",
        [Item.Type.MONSTER] = "拆除附近3格内的一个建筑",
        [Item.Type.MISSILE] = "拆除附近3格内的一个建筑",
        [Item.Type.BALANCED_WEALTH] = "平分所有玩家的现金",
        [Item.Type.EXILE] = "将指定玩家流放到深山",
        [Item.Type.TAX_CHECK] = "让指定玩家交税",
        [Item.Type.FORCED_PURCHASE] = "强制购买他人的地块",
        [Item.Type.REQUEST_GOD] = "从其他玩家处获得附身神",
        [Item.Type.SEND_GOD] = "将穷神转移给其他玩家",
        [Item.Type.POOR_GOD] = "让指定玩家被穷神附身",
        [Item.Type.WEALTH_GOD] = "让自己被财神附身",
        [Item.Type.TRANSFER] = "转让一块地给其他玩家",
        [Item.Type.STEAL] = "经过其他玩家时偷取道具",
        [Item.Type.FREE_PASS] = "免费通过他人地块",
        [Item.Type.TAX_FREE] = "免除一次交税",
        [Item.Type.DICE_DOUBLE] = "本次骰子点数加倍",
        [Item.Type.ANGEL] = "免除一次负面事件"
    }
    return descriptions[itemType] or "未知效果"
end

-- 获取使用时机
function Item.getUseTime(itemType)
    local beforeAction = {
        Item.Type.REMOTE_DICE,
        Item.Type.CLEAR_ROAD,
        Item.Type.ROADBLOCK,
        Item.Type.LANDMINE
    }
    
    local trigger = {
        Item.Type.STEAL,
        Item.Type.FREE_PASS,
        Item.Type.TAX_FREE,
        Item.Type.DICE_DOUBLE,
        Item.Type.ANGEL
    }
    
    for _, t in ipairs(beforeAction) do
        if t == itemType then
            return Item.UseTime.BEFORE_ACTION
        end
    end
    
    for _, t in ipairs(trigger) do
        if t == itemType then
            return Item.UseTime.TRIGGER
        end
    end
    
    return Item.UseTime.ACTIVE
end

-- 获取道具权重（用于随机抽取）
function Item.getWeight(itemType)
    -- 这里可以根据策划需求调整各道具的出现概率
    local weights = {
        [Item.Type.REMOTE_DICE] = 5,
        [Item.Type.CLEAR_ROAD] = 5,
        [Item.Type.ROADBLOCK] = 8,
        [Item.Type.LANDMINE] = 8,
        [Item.Type.MONSTER] = 6,
        [Item.Type.MISSILE] = 6,
        [Item.Type.BALANCED_WEALTH] = 4,
        [Item.Type.EXILE] = 5,
        [Item.Type.TAX_CHECK] = 5,
        [Item.Type.FORCED_PURCHASE] = 3,
        [Item.Type.REQUEST_GOD] = 4,
        [Item.Type.SEND_GOD] = 4,
        [Item.Type.POOR_GOD] = 5,
        [Item.Type.WEALTH_GOD] = 5,
        [Item.Type.TRANSFER] = 6,
        [Item.Type.STEAL] = 7,
        [Item.Type.FREE_PASS] = 8,
        [Item.Type.TAX_FREE] = 7,
        [Item.Type.DICE_DOUBLE] = 6,
        [Item.Type.ANGEL] = 3
    }
    return weights[itemType] or 5
end

-- 随机抽取道具
function Item.drawRandom()
    local allTypes = {}
    local totalWeight = 0
    
    -- 收集所有道具类型及权重
    for _, itemType in pairs(Item.Type) do
        local weight = Item.getWeight(itemType)
        table.insert(allTypes, {type = itemType, weight = weight})
        totalWeight = totalWeight + weight
    end
    
    -- 加权随机选择
    local rand = math.random() * totalWeight
    local currentWeight = 0
    
    for _, data in ipairs(allTypes) do
        currentWeight = currentWeight + data.weight
        if rand <= currentWeight then
            return Item.new(data.type)
        end
    end
    
    -- 默认返回第一个
    return Item.new(allTypes[1].type)
end

-- 使用道具
function Item.use(item, player, target, gameState)
    local success = false
    local message = ""
    
    -- 根据道具类型执行对应逻辑
    if item.type == Item.Type.REMOTE_DICE then
        -- 遥控骰子逻辑
        success = true
        message = "使用遥控骰子，可以选择骰子点数"
        
    elseif item.type == Item.Type.CLEAR_ROAD then
        -- 清障卡逻辑
        success = true
        message = "清除前方道路障碍"
        
    elseif item.type == Item.Type.ANGEL then
        -- 天使卡逻辑
        player.angelTurns = 5
        success = true
        message = "天使附身5回合"
        
    elseif item.type == Item.Type.WEALTH_GOD then
        -- 财神卡逻辑
        player.wealthGodTurns = 5
        success = true
        message = "财神附身5回合"
        
    -- 其他道具逻辑...
    else
        message = "道具效果待实现"
    end
    
    return success, message
end

-- 检查道具是否可以使用
function Item.canUse(item, player, currentPhase)
    if item.useTime == Item.UseTime.BEFORE_ACTION then
        return currentPhase == "before_action", "该卡只能在行动前使用"
    elseif item.useTime == Item.UseTime.ACTIVE then
        return currentPhase == "before_action" or currentPhase == "after_action",
               "该卡需在你的回合使用"
    elseif item.useTime == Item.UseTime.TRIGGER then
        return false, "该卡未到使用时机"
    end
    
    return false, "无法使用"
end

return Item
