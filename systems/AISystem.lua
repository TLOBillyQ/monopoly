-- AI决策系统 - Spoke框架实现
-- 提供AI玩家的决策逻辑

local State = require("Spoke.State")
local Memo = require("Spoke.Memo")

local AISystem = {}

-- AI难度级别
AISystem.Difficulty = {
    EASY = "easy",
    MEDIUM = "medium",
    HARD = "hard",
}

-- 创建AI玩家
function AISystem.createAIPlayer(id, difficulty, characterId, vehicleId)
    local aiPlayer = {
        id = State.Create(id),
        difficulty = State.Create(difficulty or AISystem.Difficulty.MEDIUM),
        characterId = State.Create(characterId),
        vehicleId = State.Create(vehicleId),
        isAI = State.Create(true),
        
        -- 财务状态
        money = State.Create(100000),
        
        -- 资产
        properties = State.Create({}),
        items = State.Create({}),
        
        -- 决策历史（用于学习）
        decisionHistory = State.Create({}),
        
        -- AI特定的状态
        aggressiveness = State.Create(0.5),  -- 激进度 (0-1)
        riskTolerance = State.Create(0.5),   -- 风险承受度 (0-1)
    }
    
    -- 创建AI评分函数
    aiPlayer.propertyValue = Memo.new("PropertyValue_" .. id, function(s)
        local properties = s:D(aiPlayer.properties)
        local value = 0
        for _, propId in ipairs(properties) do
            value = value + (propId * 50)
        end
        return value
    end, {aiPlayer.properties})
    
    return aiPlayer
end

-- 决定是否购买地块
function AISystem.decideToBuyProperty(aiPlayer, tilePrice, tileType, gameContext)
    local difficulty = aiPlayer.difficulty:Get()
    local money = aiPlayer.money:Get()
    local aggressiveness = aiPlayer.aggressiveness:Get()
    
    -- 简单计算是否应该购买
    local affordability = money / tilePrice
    
    if difficulty == AISystem.Difficulty.EASY then
        return affordability > 1.5  -- 容易难度：金币足够就买
        
    elseif difficulty == AISystem.Difficulty.MEDIUM then
        local shouldBuy = affordability > 1.2 and aggressiveness > 0.3
        return shouldBuy
        
    elseif difficulty == AISystem.Difficulty.HARD then
        local shouldBuy = affordability > 0.8 and aggressiveness > 0.6
        return shouldBuy
    end
    
    return false
end

-- 决定是否使用物品卡
function AISystem.decideToUseItem(aiPlayer, itemId, situation, gameContext)
    local difficulty = aiPlayer.difficulty:Get()
    local money = aiPlayer.money:Get()
    
    if difficulty == AISystem.Difficulty.EASY then
        return math.random() > 0.7  -- 容易难度：随机使用
        
    elseif difficulty == AISystem.Difficulty.MEDIUM then
        -- 中等难度：考虑当前局势
        return situation.needsHelp == true
        
    elseif difficulty == AISystem.Difficulty.HARD then
        -- 困难难度：策略性使用
        return situation.benefit > situation.cost
    end
    
    return false
end

-- 决定升级地块
function AISystem.decideToUpgrade(aiPlayer, propertyId, upgradeCost, gameContext)
    local difficulty = aiPlayer.difficulty:Get()
    local money = aiPlayer.money:Get()
    local riskTolerance = aiPlayer.riskTolerance:Get()
    
    local moneyAfterUpgrade = money - upgradeCost
    local minimumRequired = gameContext.config:Get().constants.START_MONEY * 0.2
    
    if difficulty == AISystem.Difficulty.EASY then
        return moneyAfterUpgrade > minimumRequired * 2
        
    elseif difficulty == AISystem.Difficulty.MEDIUM then
        return moneyAfterUpgrade > minimumRequired and riskTolerance > 0.4
        
    elseif difficulty == AISystem.Difficulty.HARD then
        return moneyAfterUpgrade > minimumRequired * 0.5 and riskTolerance > 0.6
    end
    
    return false
end

-- 选择目标（用于攻击性卡牌）
function AISystem.selectTarget(aiPlayer, availableTargets, gameContext)
    -- 选择财富最多的对手
    local targetWithMostWealth = nil
    local maxWealth = 0
    
    for _, target in ipairs(availableTargets) do
        local wealth = target.money:Get() + (#target.properties:Get() * 50)
        if wealth > maxWealth then
            maxWealth = wealth
            targetWithMostWealth = target
        end
    end
    
    return targetWithMostWealth
end

-- 评估游戏形势
function AISystem.evaluateGameSituation(aiPlayer, allPlayers, gameContext)
    local aiMoney = aiPlayer.money:Get()
    local aiProperties = #aiPlayer.properties:Get()
    
    local averageMoney = 0
    local averageProperties = 0
    
    for _, player in ipairs(allPlayers) do
        if player.id:Get() ~= aiPlayer.id:Get() then
            averageMoney = averageMoney + player.money:Get()
            averageProperties = averageProperties + #player.properties:Get()
        end
    end
    
    local playerCount = #allPlayers - 1
    averageMoney = averageMoney / playerCount
    averageProperties = averageProperties / playerCount
    
    return {
        isLeading = aiMoney > averageMoney and aiProperties > averageProperties,
        moneyAdvantage = aiMoney - averageMoney,
        propertyAdvantage = aiProperties - averageProperties,
        needsHelp = aiMoney < averageMoney * 0.5,
    }
end

return AISystem
