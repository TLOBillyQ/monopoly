-- 玩家/角色系统
-- Player System

local Player = {}

-- 玩家状态
Player.State = {
    NORMAL = "normal",
    IN_HOSPITAL = "in_hospital",
    IN_MOUNTAIN = "in_mountain",
    IN_JAIL = "in_jail",
    BANKRUPT = "bankrupt"
}

-- 创建新玩家
function Player.new(id, characterId, vehicleId, isAI, tileCount)
    local player = {
        id = id,
        name = ("玩家" .. id),
        isAI = isAI or false,
        tileCount = tileCount or 16,
        
        -- 角色和座驾
        characterId = characterId or 1001,
        vehicleId = vehicleId or 4001,
        
        -- 财务
        money = 100000,  -- 初始金币
        properties = {},  -- 拥有的地块 ID 列表
        
        -- 位置和移动
        position = 1,  -- 当前位置（1-16）
        
        -- 状态管理
        state = Player.State.NORMAL,
        stayTurns = 0,  -- 停留回合数
        stayType = nil,  -- 停留类型
        
        -- 道具系统
        items = {},  -- 道具卡列表，最多5个
        itemCount = 0,  -- 当前道具数量
        
        -- 附身状态（互斥，最多一个）
        buffType = nil,  -- "angel", "wealth", "poor" 或 nil
        buffTurns = 0,  -- 附身剩余回合数
        
        -- 座驾管理
        hasVehicle = true,  -- 是否有座驾
        vehicleDestroyed = false,  -- 座驾是否被摧毁
        
        -- 其他状态
        freeJailCard = false,  -- 免费停留卡（在监狱中使用）
        
        -- 统计数据
        totalAssets = 100000,  -- 总资产
        turnsPlayed = 0,  -- 已进行回合数
        
        -- 调试信息
        lastAction = nil
    }
    
    return player
end

local function resolveTileCount(player, tileCount)
    if tileCount then
        return tileCount
    end
    if player and player.tileCount then
        return player.tileCount
    end
    return 16
end


-- ==================== 金币管理 ====================

-- 添加金币
function Player.addMoney(player, amount)
    player.money = player.money + amount
    if player.money < 0 then
        player.money = 0
    end
    Player.updateTotalAssets(player)
end

-- 减少金币
function Player.subtractMoney(player, amount)
    player.money = player.money - amount
    if player.money < 0 then
        player.money = 0
    end
    Player.updateTotalAssets(player)
end

-- 转账：从一个玩家转账给另一个玩家
function Player.transfer(payer, receiver, amount)
    local actualAmount = math.min(payer.money, amount)
    Player.subtractMoney(payer, actualAmount)
    Player.addMoney(receiver, actualAmount)
    return actualAmount
end

-- ==================== 地块管理 ====================

-- 添加地块所有权
function Player.acquireProperty(player, propertyId)
    for _, id in ipairs(player.properties) do
        if id == propertyId then
            return false  -- 已经拥有
        end
    end
    table.insert(player.properties, propertyId)
    Player.updateTotalAssets(player)
    return true
end

-- 失去地块所有权
function Player.loseProperty(player, propertyId)
    for i, id in ipairs(player.properties) do
        if id == propertyId then
            table.remove(player.properties, i)
            Player.updateTotalAssets(player)
            return true
        end
    end
    return false
end

-- 随机失去一块地块
function Player.loseRandomProperty(player)
    if #player.properties > 0 then
        local idx = math.random(1, #player.properties)
        local propertyId = player.properties[idx]
        table.remove(player.properties, idx)
        Player.updateTotalAssets(player)
        return propertyId
    end
    return nil
end

-- 失去所有地块
function Player.loseAllProperties(player)
    local count = #player.properties
    player.properties = {}
    Player.updateTotalAssets(player)
    return count
end

-- ==================== 道具管理 ====================

-- 添加道具
function Player.addItem(player, itemId)
    if player.itemCount >= 5 then
        return false, "道具卡已满"
    end
    
    table.insert(player.items, itemId)
    player.itemCount = player.itemCount + 1
    return true
end

-- 移除指定索引的道具
function Player.removeItem(player, index)
    if index > 0 and index <= player.itemCount then
        table.remove(player.items, index)
        player.itemCount = player.itemCount - 1
        return true
    end
    return false
end

-- 随机移除一个道具
function Player.removeRandomItem(player)
    if player.itemCount > 0 then
        local idx = math.random(1, player.itemCount)
        local itemId = player.items[idx]
        table.remove(player.items, idx)
        player.itemCount = player.itemCount - 1
        return itemId
    end
    return nil
end

-- 清空所有道具
function Player.clearAllItems(player)
    local count = #player.items
    player.items = {}
    player.itemCount = 0
    return count
end

-- 是否持有某个道具
function Player.hasItem(player, itemId)
    for i, id in ipairs(player.items) do
        if id == itemId then
            return true, i
        end
    end
    return false
end

-- ==================== 附身状态管理 ====================

-- 获得附身状态
function Player.applyBuff(player, buffType, duration)
    player.buffType = buffType
    player.buffTurns = duration
end

-- 移除附身状态
function Player.removeBuff(player)
    player.buffType = nil
    player.buffTurns = 0
end

-- 减少附身时间
function Player.reduceBuff(player)
    if player.buffTurns > 0 then
        player.buffTurns = player.buffTurns - 1
        if player.buffTurns == 0 then
            player.buffType = nil
        end
    end
end

-- 检查玩家是否受到天使保护
function Player.isProtectedByAngel(player)
    return player.buffType == "angel" and player.buffTurns > 0
end

-- 检查玩家是否被穷神附身
function Player.isCursedByPoor(player)
    return player.buffType == "poor" and player.buffTurns > 0
end

-- 检查玩家是否被财神附身
function Player.isBlessedByWealth(player)
    return player.buffType == "wealth" and player.buffTurns > 0
end

-- ==================== 座驾管理 ====================

-- 获得座驾
function Player.obtainVehicle(player, vehicleId)
    player.vehicleId = vehicleId
    player.hasVehicle = true
    player.vehicleDestroyed = false
end

-- 摧毁座驾
function Player.destroyVehicle(player)
    player.vehicleDestroyed = true
    player.hasVehicle = false
end

-- 修复座驾
function Player.repairVehicle(player)
    player.vehicleDestroyed = false
    player.hasVehicle = true
end

-- ==================== 状态管理 ====================

-- 进入医院
function Player.enterHospital(player, stayTurns)
    player.state = Player.State.IN_HOSPITAL
    player.stayTurns = stayTurns
    player.stayType = "hospital"
    player.vehicleDestroyed = true
end

-- 进入深山
function Player.enterMountain(player, stayTurns)
    player.state = Player.State.IN_MOUNTAIN
    player.stayTurns = stayTurns
    player.stayType = "mountain"
end

-- 进入监狱
function Player.enterJail(player, stayTurns)
    player.state = Player.State.IN_JAIL
    player.stayTurns = stayTurns
    player.stayType = "jail"
end

-- 减少停留时间
function Player.reduceStayTurns(player)
    if player.stayTurns > 0 then
        player.stayTurns = player.stayTurns - 1
        
        if player.stayTurns == 0 then
            player.state = Player.State.NORMAL
            player.stayType = nil
        end
        
        return true
    end
    return false
end

-- 立即离开当前位置
function Player.releaseFromStay(player)
    player.state = Player.State.NORMAL
    player.stayTurns = 0
    player.stayType = nil
end

-- 设置破产
function Player.bankrupt(player)
    player.state = Player.State.BANKRUPT
    player.money = 0
    player.properties = {}
    player.items = {}
    player.itemCount = 0
    Player.updateTotalAssets(player)
end

-- 检查是否破产
function Player.isBankrupt(player)
    return player.state == Player.State.BANKRUPT
end

-- ==================== 位置管理 ====================

-- 移动到指定位置
function Player.moveTo(player, position, tileCount)
    tileCount = resolveTileCount(player, tileCount)
    player.position = position % tileCount
    if player.position == 0 then
        player.position = tileCount
    end
end

-- 前进指定步数
function Player.moveForward(player, steps, tileCount)
    tileCount = resolveTileCount(player, tileCount)
    player.position = player.position + steps
    while player.position > tileCount do
        player.position = player.position - tileCount
    end
    return player.position
end

-- 后退指定步数
function Player.moveBackward(player, steps, tileCount)
    tileCount = resolveTileCount(player, tileCount)
    player.position = player.position - steps
    while player.position <= 0 do
        player.position = player.position + tileCount
    end
    return player.position
end

-- ==================== 其他方法 ====================

-- 更新总资产（用于破产判定和排名）
function Player.updateTotalAssets(player)
    local total = player.money
    -- 地块价值会在 game.lua 中单独计算
    player.totalAssets = total
end

-- 开始新一回合
function Player.startTurn(player)
    player.turnsPlayed = player.turnsPlayed + 1
    Player.reduceBuff(player)
    
    -- 如果在停留状态，减少停留时间
    if player.state == Player.State.IN_HOSPITAL or 
       player.state == Player.State.IN_MOUNTAIN or
       player.state == Player.State.IN_JAIL then
        Player.reduceStayTurns(player)
    end
end

-- 检查玩家是否可以行动
function Player.canAct(player)
    return player.state == Player.State.NORMAL and not Player.isBankrupt(player)
end

-- 返回玩家信息摘要（用于调试和UI）
function Player.getSummary(player)
    return {
        id = player.id,
        name = player.name,
        money = player.money,
        position = player.position,
        properties = #player.properties,
        items = player.itemCount,
        state = player.state,
        stayTurns = player.stayTurns,
        buffType = player.buffType,
        buffTurns = player.buffTurns,
        hasVehicle = player.hasVehicle,
        totalAssets = player.totalAssets
    }
end

return Player
