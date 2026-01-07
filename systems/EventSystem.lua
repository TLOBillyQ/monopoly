-- 事件系统 - Spoke框架实现
-- 处理着陆、购买、租金等事件

local State = require("spoke.state")
local Trigger = require("spoke.trigger")

local EventSystem = {}

-- 创建事件触发器
function EventSystem.createEventTriggers()
    return {
        onLand = Trigger.Create("onLand"),
        onBuyProperty = Trigger.Create("onBuyProperty"),
        onPayRent = Trigger.Create("onPayRent"),
        onChanceCard = Trigger.Create("onChanceCard"),
        onItemCard = Trigger.Create("onItemCard"),
        onPlayerBankrupt = Trigger.Create("onPlayerBankrupt"),
        onGameEnd = Trigger.Create("onGameEnd"),
    }
end

-- 处理着陆事件
function EventSystem.handleLandEvent(player, tile, gameContext)
    local tileType = tile.type:Now()
    
    if tileType == "start" then
        -- 经过起点获得奖金
        local reward = gameContext.config:Now().constants.PASS_START_BONUS
        return {event = "passStart", reward = reward}
        
    elseif tileType == "property" then
        local owner = tile.owner:Now()
        if not owner then
            -- 无主地块，可以购买
            return {event = "canBuyProperty", tileId = tile.id:Now()}
        elseif owner ~= player.id:Now() then
            -- 他人地块，支付租金
            local rent = EventSystem.calculateRent(tile)
            return {event = "payRent", amount = rent, owner = owner}
        end
        
    elseif tileType == "chance_card" then
        -- 抽取机会卡
        return {event = "drawChanceCard"}
        
    elseif tileType == "item_card" then
        -- 抽取物品卡
        return {event = "drawItemCard"}
        
    elseif tileType == "hospital" then
        -- 进入医院
        return {event = "enterHospital"}
        
    elseif tileType == "mountain" then
        -- 进入深山
        return {event = "enterMountain"}
        
    elseif tileType == "tax_office" then
        -- 税务局
        return {event = "taxOffice"}
        
    elseif tileType == "black_market" then
        -- 黑市
        return {event = "blackMarket"}
        
    end
    
    return {event = "none"}
end

-- 计算租金
function EventSystem.calculateRent(tile)
    local level = tile.level:Now()
    local basePrice = tile.basePrice:Now()
    
    if level == 0 then return 0 end
    
    -- 租金 = 上次升级费用 * 0.5
    local lastUpgradeCost = basePrice * (2 ^ (level - 1))
    return math.floor(lastUpgradeCost * 0.5)
end

-- 处理机会卡事件
function EventSystem.handleChanceCardEvent(card, player, gameContext)
    local cardType = card.type
    
    if cardType == "gain_money" then
        return {action = "addMoney", amount = card.value}
    elseif cardType == "lose_money" then
        return {action = "subtractMoney", amount = card.value}
    elseif cardType == "move_forward" then
        return {action = "moveForward", steps = card.value}
    elseif cardType == "move_backward" then
        return {action = "moveBackward", steps = card.value}
    elseif cardType == "gain_item" then
        return {action = "addItem", itemId = card.value}
    elseif cardType == "lose_item" then
        return {action = "removeItem", count = card.value}
    end
    
    return {action = "none"}
end

-- 处理购买地块
function EventSystem.handlePropertyPurchase(player, tile, gameContext, buyPrice)
    local playerMoney = player.money:Now()
    
    if playerMoney >= buyPrice then
        -- 可以购买
        player.money:Set(playerMoney - buyPrice)
        tile.owner:Set(player.id:Now())
        tile.level:Set(1)
        
        local properties = player.properties:Now()
        table.insert(properties, tile.id:Now())
        player.properties:Set(properties)
        
        return {success = true, message = "购买成功"}
    else
        return {success = false, message = "金币不足"}
    end
end

-- 破产检查
function EventSystem.checkBankruptcy(player)
    local money = player.money:Now()
    local state = player.state:Now()
    
    if money <= 0 and state ~= "bankrupt" then
        player.state:Set("bankrupt")
        return true
    end
    
    return false
end

return EventSystem
