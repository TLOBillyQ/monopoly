-- 地块系统
-- Property/Board System

local Property = {}

-- 地块类型
Property.Type = {
    EMPTY = "empty",  -- 空地块
    START = "start",  -- 起点
    CHANCE = "chance",  -- 机会卡
    ITEM = "item",  -- 道具卡
    HOSPITAL = "hospital",  -- 医院
    MOUNTAIN = "mountain",  -- 深山
    TAX = "tax",  -- 税务局
    BLACK_MARKET = "black_market"  -- 黑市
}

-- 建筑等级
Property.BuildingLevel = {
    EMPTY_LAND = 0,  -- 空地
    HOUSE = 1,  -- 房屋
    VILLA = 2,  -- 别墅
    BUILDING = 3  -- 高楼
}

-- 创建新地块
function Property.new(id, name, type, basePrice)
    local property = {
        id = id,
        name = name,
        type = type,
        basePrice = basePrice or 0,
        
        -- 所有权
        owner = nil,
        
        -- 建筑等级
        buildingLevel = Property.BuildingLevel.EMPTY_LAND,
        
        -- 道具
        hasRoadblock = false,  -- 路障
        hasLandmine = false,  -- 地雷
        
        -- 坐标
        roadCoord = {x = 0, y = 0},  -- 道路坐标
        buildingCoord = {x = 0, y = 0}  -- 建筑坐标
    }
    
    return property
end

-- 计算当前加盖价格
function Property.getUpgradePrice(property)
    if property.type ~= Property.Type.EMPTY or not property.owner then
        return 0
    end
    
    if property.buildingLevel >= Property.BuildingLevel.BUILDING then
        return 0  -- 已经是高楼，无法再加盖
    end
    
    -- 加盖费用 = 地块价格 * (2 ^ 加盖次数)
    local upgradeTimes = property.buildingLevel + 1
    return property.basePrice * (2 ^ upgradeTimes)
end

-- 计算当前租金
function Property.getRent(property)
    if property.type ~= Property.Type.EMPTY or not property.owner then
        return 0
    end
    
    if property.buildingLevel == Property.BuildingLevel.EMPTY_LAND then
        return property.basePrice * 0.5
    end
    
    -- 租金 = 最后一次加盖费用 * 0.5
    local lastUpgradePrice = property.basePrice * (2 ^ property.buildingLevel)
    return lastUpgradePrice * 0.5
end

-- 计算总价值
function Property.getTotalValue(property)
    if property.type ~= Property.Type.EMPTY then
        return 0
    end
    
    local total = property.basePrice
    
    -- 加上所有加盖价格
    for i = 1, property.buildingLevel do
        total = total + (property.basePrice * (2 ^ i))
    end
    
    return total
end

-- 购买地块
function Property.buy(property, player)
    if property.owner or property.type ~= Property.Type.EMPTY then
        return false, "无法购买该地块"
    end
    
    if player.money < property.basePrice then
        return false, "金币不足"
    end
    
    property.owner = player
    property.buildingLevel = Property.BuildingLevel.EMPTY_LAND
    
    return true
end

-- 加盖建筑
function Property.upgrade(property, player)
    if property.owner ~= player then
        return false, "不是你的地块"
    end
    
    if property.buildingLevel >= Property.BuildingLevel.BUILDING then
        return false, "已经是高楼，无法再加盖"
    end
    
    local upgradePrice = Property.getUpgradePrice(property)
    if player.money < upgradePrice then
        return false, "金币不足"
    end
    
    property.buildingLevel = property.buildingLevel + 1
    return true, upgradePrice
end

-- 拆除建筑（降低一级）
function Property.downgrade(property)
    if property.buildingLevel > Property.BuildingLevel.EMPTY_LAND then
        property.buildingLevel = property.buildingLevel - 1
        return true
    end
    return false
end

-- 重置地块为空地
function Property.reset(property)
    property.owner = nil
    property.buildingLevel = Property.BuildingLevel.EMPTY_LAND
    property.hasRoadblock = false
    property.hasLandmine = false
end

-- 设置路障
function Property.setRoadblock(property, hasRoadblock)
    property.hasRoadblock = hasRoadblock
end

-- 设置地雷
function Property.setLandmine(property, hasLandmine)
    property.hasLandmine = hasLandmine
end

-- 计算相邻地块租金（如果相邻地块属于同一个玩家）
function Property.calculateTotalRent(property, adjacentProperties)
    local totalRent = Property.getRent(property)
    
    if not property.owner then
        return totalRent
    end
    
    -- 检查相邻地块
    for _, adjacent in ipairs(adjacentProperties) do
        if adjacent.owner == property.owner then
            totalRent = totalRent + Property.getRent(adjacent)
        end
    end
    
    return totalRent
end

-- 地块事件处理
function Property.onPlayerLand(property, player)
    local event = {
        type = property.type,
        property = property,
        player = player,
        actions = {}
    }
    
    if property.type == Property.Type.EMPTY then
        if not property.owner then
            -- 空地块，可以购买
            event.actions = {"buy", "pass"}
        elseif property.owner == player then
            -- 自己的地块，可以加盖
            if property.buildingLevel < Property.BuildingLevel.BUILDING then
                event.actions = {"upgrade", "pass"}
            end
        else
            -- 他人的地块，需要支付租金
            event.actions = {"pay_rent"}
        end
    elseif property.type == Property.Type.CHANCE then
        -- 机会卡
        event.actions = {"draw_chance"}
    elseif property.type == Property.Type.ITEM then
        -- 道具卡
        event.actions = {"draw_item"}
    elseif property.type == Property.Type.HOSPITAL then
        -- 医院
        event.actions = {"hospital"}
    elseif property.type == Property.Type.MOUNTAIN then
        -- 深山
        event.actions = {"mountain"}
    elseif property.type == Property.Type.TAX then
        -- 税务局
        event.actions = {"pay_tax"}
    elseif property.type == Property.Type.BLACK_MARKET then
        -- 黑市
        event.actions = {"open_black_market"}
    end
    
    return event
end

return Property
