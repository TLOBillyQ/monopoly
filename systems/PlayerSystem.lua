-- 玩家系统 - Spoke框架实现
-- 管理玩家的反应式状态

local State = require("Spoke.State")
local Memo = require("Spoke.Memo")

local PlayerSystem = {}

-- 创建新玩家状态
function PlayerSystem.createPlayer(id, characterId, vehicleId, isAI)
    local playerState = {
        -- 基本信息
        id = State.Create(id),
        characterId = State.Create(characterId or 1001),
        vehicleId = State.Create(vehicleId or 4001),
        isAI = State.Create(isAI or false),
        
        -- 金融状态
        money = State.Create(100000),  -- 初始金币
        
        -- 位置和移动
        position = State.Create(1),  -- 地块位置（1-45）
        
        -- 资产
        properties = State.Create({}),  -- 拥有的地块
        items = State.Create({}),       -- 道具卡
        
        -- 状态
        state = State.Create("normal"),  -- normal, hospital, mountain, jail, bankrupt
        stayTurns = State.Create(0),     -- 停留回合数
        
        -- 附身
        buffs = State.Create({}),  -- 当前附身状态
        buffTurns = State.Create({}),  -- 附身剩余回合数
        
        -- 座驾
        vehicleDurability = State.Create(100),
    }
    
    -- 创建计算属性（Memo）
    playerState.totalAsset = Memo.new("TotalAsset_" .. id, function(s)
        local money = s:D(playerState.money)
        local properties = s:D(playerState.properties)
        local propertyValue = 0
        for _, propId in ipairs(properties) do
            propertyValue = propertyValue + (propId * 100)  -- 简化计算
        end
        return money + propertyValue
    end, {playerState.money, playerState.properties})
    
    playerState.isBankrupt = Memo.new("IsBankrupt_" .. id, function(s)
        local money = s:D(playerState.money)
        local state = s:D(playerState.state)
        return state == "bankrupt" or money < 0
    end, {playerState.money, playerState.state})
    
    return playerState
end

-- 添加金币
function PlayerSystem.addMoney(playerState, amount)
    local currentMoney = playerState.money:Get()
    playerState.money:Set(currentMoney + amount)
end

-- 减少金币
function PlayerSystem.subtractMoney(playerState, amount)
    local currentMoney = playerState.money:Get()
    local newAmount = math.max(0, currentMoney - amount)
    playerState.money:Set(newAmount)
end

-- 获得地块
function PlayerSystem.acquireProperty(playerState, propertyId)
    local properties = playerState.properties:Get()
    table.insert(properties, propertyId)
    playerState.properties:Set(properties)
end

-- 失去地块
function PlayerSystem.loseProperty(playerState, propertyId)
    local properties = playerState.properties:Get()
    for i, id in ipairs(properties) do
        if id == propertyId then
            table.remove(properties, i)
            break
        end
    end
    playerState.properties:Set(properties)
end

-- 添加道具
function PlayerSystem.addItem(playerState, itemId)
    local items = playerState.items:Get()
    if #items < 5 then  -- 最多5个道具
        table.insert(items, itemId)
        playerState.items:Set(items)
        return true
    end
    return false
end

-- 移除道具
function PlayerSystem.removeItem(playerState, itemId)
    local items = playerState.items:Get()
    for i, id in ipairs(items) do
        if id == itemId then
            table.remove(items, i)
            playerState.items:Set(items)
            return true
        end
    end
    return false
end

-- 移动玩家
function PlayerSystem.moveTo(playerState, position, maxPos)
    maxPos = maxPos or 45
    position = position % maxPos
    if position == 0 then position = maxPos end
    playerState.position:Set(position)
end

-- 进入医院
function PlayerSystem.enterHospital(playerState)
    playerState.state:Set("hospital")
    playerState.stayTurns:Set(2)
end

-- 进入深山
function PlayerSystem.enterMountain(playerState)
    playerState.state:Set("mountain")
    playerState.stayTurns:Set(2)
end

-- 应用附身
function PlayerSystem.applyBuff(playerState, buffType, duration)
    local buffs = playerState.buffs:Get()
    local buffTurns = playerState.buffTurns:Get()
    
    if not buffs[buffType] then
        buffs[buffType] = buffType
        buffTurns[buffType] = duration
        playerState.buffs:Set(buffs)
        playerState.buffTurns:Set(buffTurns)
    end
end

-- 移除附身
function PlayerSystem.removeBuff(playerState, buffType)
    local buffs = playerState.buffs:Get()
    local buffTurns = playerState.buffTurns:Get()
    
    buffs[buffType] = nil
    buffTurns[buffType] = nil
    playerState.buffs:Set(buffs)
    playerState.buffTurns:Set(buffTurns)
end

-- 减少附身时间
function PlayerSystem.reduceBuff(playerState)
    local buffTurns = playerState.buffTurns:Get()
    local buffs = playerState.buffs:Get()
    
    if not buffTurns or not buffs then
        return
    end
    
    for buffType, turns in pairs(buffTurns) do
        buffTurns[buffType] = turns - 1
        if buffTurns[buffType] <= 0 then
            buffs[buffType] = nil
            buffTurns[buffType] = nil
        end
    end
    
    playerState.buffs:Set(buffs)
    playerState.buffTurns:Set(buffTurns)
end

return PlayerSystem
