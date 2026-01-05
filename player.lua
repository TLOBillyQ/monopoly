-- 玩家/角色系统
-- Player System

local Player = {}
local Property = require("property")

-- 玩家状态
Player.State = {
    NORMAL = "normal",
    IN_HOSPITAL = "in_hospital",
    IN_MOUNTAIN = "in_mountain",
    BANKRUPT = "bankrupt"
}

-- 创建新玩家
function Player.new(id, name, isAI)
    local player = {
        id = id,
        name = name or ("玩家" .. id),
        isAI = isAI or false,
        
        -- 财务
        money = 100000,  -- 初始金币
        properties = {},  -- 拥有的地块列表
        
        -- 位置
        position = 0,  -- 当前位置
        
        -- 状态
        state = Player.State.NORMAL,
        stayTurns = 0,  -- 停留回合数
        
        -- 道具
        items = {},  -- 道具卡槽，最多5个
        
        -- 附身神
        angelTurns = 0,  -- 天使附身剩余回合
        wealthGodTurns = 0,  -- 财神附身剩余回合
        poorGodTurns = 0,  -- 穷神附身剩余回合
        
        -- 座驾
        vehicle = nil,  -- 座驾类型，nil为无座驾
        
        -- 统计
        totalAssets = 100000,  -- 总资产
        turnsPlayed = 0  -- 已进行回合数
    }
    
    return player
end

-- 添加金币
function Player.addMoney(player, amount)
    player.money = player.money + amount
    Player.updateTotalAssets(player)
end

-- 减少金币
function Player.reduceMoney(player, amount)
    player.money = player.money - amount
    if player.money < 0 then
        player.money = 0
    end
    Player.updateTotalAssets(player)
end

-- 支付金币给另一个玩家
function Player.payTo(payer, receiver, amount)
    -- 深山中的玩家无法收到金币
    if receiver.state == Player.State.IN_MOUNTAIN then
        amount = 0
    end
    
    local actualAmount = math.min(payer.money, amount)
    Player.reduceMoney(payer, actualAmount)
    Player.addMoney(receiver, actualAmount)
    
    return actualAmount
end

-- 添加道具
function Player.addItem(player, item)
    if #player.items >= 5 then
        return false, "道具卡已满，无法获得"
    end
    
    table.insert(player.items, item)
    return true
end

-- 移除道具
function Player.removeItem(player, itemIndex)
    if itemIndex > 0 and itemIndex <= #player.items then
        table.remove(player.items, itemIndex)
        return true
    end
    return false
end

-- 添加地块
function Player.addProperty(player, property)
    table.insert(player.properties, property)
    Player.updateTotalAssets(player)
end

-- 移除地块
function Player.removeProperty(player, property)
    for i, prop in ipairs(player.properties) do
        if prop.id == property.id then
            table.remove(player.properties, i)
            break
        end
    end
    Player.updateTotalAssets(player)
end

-- 更新总资产
function Player.updateTotalAssets(player)
    local total = player.money
    
    -- 计算所有地块价值
    for _, property in ipairs(player.properties) do
        -- 使用Property工具函数获取总价值，避免nil字段
        total = total + Property.getTotalValue(property)
    end
    
    player.totalAssets = total
end

-- 移动到指定位置
function Player.moveTo(player, position)
    player.position = position
end

-- 检查是否破产
function Player.isBankrupt(player)
    return player.state == Player.State.BANKRUPT or player.money <= 0
end

-- 设置破产
function Player.setBankrupt(player)
    player.state = Player.State.BANKRUPT
    player.money = 0
    
    -- 清空所有地块
    player.properties = {}
end

-- 开始停留（医院或深山）
function Player.startStay(player, turns, stayType)
    player.stayTurns = turns
    player.state = stayType
end

-- 减少停留回合
function Player.reduceStayTurns(player)
    if player.stayTurns > 0 then
        player.stayTurns = player.stayTurns - 1
        
        if player.stayTurns <= 0 then
            player.state = Player.State.NORMAL
        end
        
        return true
    end
    return false
end

-- 设置座驾
function Player.setVehicle(player, vehicleType)
    player.vehicle = vehicleType
end

-- 移除座驾
function Player.removeVehicle(player)
    player.vehicle = nil
end

-- 有座驾时投掷2个骰子
function Player.getDiceCount(player)
    return player.vehicle and 2 or 1
end

-- 减少附身神回合
function Player.reduceGodTurns(player)
    if player.angelTurns > 0 then
        player.angelTurns = player.angelTurns - 1
    end
    if player.wealthGodTurns > 0 then
        player.wealthGodTurns = player.wealthGodTurns - 1
    end
    if player.poorGodTurns > 0 then
        player.poorGodTurns = player.poorGodTurns - 1
    end
end

-- AI决策逻辑
function Player.makeAIDecision(player, gameState)
    -- AI总是确认，如果有道具就使用
    -- 简化的AI逻辑，实际实现需要更复杂的判断
    return {
        action = "confirm",
        useItem = #player.items > 0
    }
end

return Player
