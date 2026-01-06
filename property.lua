-- 地块系统 - 完全重构
-- Property/Board System - 基于16格地块设计

local Property = {}

-- ==================== 地块类型 ====================
Property.Type = {
    START = "start",                      -- 起点
    PROPERTY = "property",                -- 可购买地块（普通房地产）
    TAX_OFFICE = "tax_office",            -- 税务局
    HOSPITAL = "hospital",                -- 医院
    MOUNTAIN = "mountain",                -- 深山
    BLACK_MARKET = "black_market",        -- 黑市
    JAIL = "jail"                         -- 监狱
}

-- 建筑等级
Property.Building = {
    NONE = 0,           -- 无建筑
    HOUSE = 1,          -- 住宅
    APARTMENT = 2,      -- 公寓
    HOTEL = 3,          -- 酒店
    MANSION = 4         -- 豪宅
}

-- ==================== 地块创建 ====================

-- 根据config创建地块
function Property.createFromConfig(config)
    local tiles = {}
    
    for i, tileConfig in ipairs(config.tiles) do
        local tile = {
            id = tileConfig.id,
            name = tileConfig.name,
            type = tileConfig.type,
            price = tileConfig.price or 0,
            
            -- 所有权
            owner = nil,                   -- 拥有者ID
            
            -- 建筑
            building_level = 0,            -- 建筑等级（0-4）
            
            -- 特殊对象
            roadblock = false,             -- 是否有路障
            roadblock_owner = nil,         -- 路障放置者ID
            landmine = false,              -- 是否有地雷
            landmine_owner = nil,          -- 地雷放置者ID
            
            -- 位置信息
            position = i
        }
        
        tiles[i] = tile
    end
    
    return tiles
end

-- ==================== 租金计算 ====================

-- 计算地块基础租金
-- 租金 = 价格 * (0.5 + 0.5 * 建筑等级)
function Property.calculateRent(tile, withBuff)
    if tile.type ~= Property.Type.PROPERTY or not tile.owner then
        return 0
    end
    
    local rent = tile.price * (0.5 + 0.5 * tile.building_level)
    
    -- 申用财神附身加成（如果传入）
    if withBuff then
        rent = rent * 2
    end
    
    return rent
end

-- 计算地块升级费用
-- 升级费用 = 价格 * (2 ^ 下一级别)
function Property.calculateUpgradeCost(tile)
    if tile.type ~= Property.Type.PROPERTY or not tile.owner then
        return 0
    end
    
    if tile.building_level >= Property.Building.MANSION then
        return 0  -- 已是最高等级
    end
    
    local nextLevel = tile.building_level + 1
    return tile.price * (2 ^ nextLevel)
end

-- 获取建筑等级名称
function Property.getBuildingName(level)
    local names = {
        "空地",
        "住宅",
        "公寓",
        "酒店",
        "豪宅"
    }
    return names[level + 1] or "未知"
end

-- ==================== 地块操作 ====================

-- 购买地块
function Property.buy(tile, playerId, cost)
    if tile.type ~= Property.Type.PROPERTY then
        return false, "该地块无法购买"
    end
    
    if tile.owner then
        return false, "该地块已被购买"
    end
    
    tile.owner = playerId
    tile.building_level = Property.Building.NONE
    
    return true, cost or tile.price
end

-- 升级地块
function Property.upgrade(tile, playerId, cost)
    if tile.type ~= Property.Type.PROPERTY then
        return false, "该地块无法升级"
    end
    
    if tile.owner ~= playerId then
        return false, "这不是你的地块"
    end
    
    if tile.building_level >= Property.Building.MANSION then
        return false, "已是最高等级"
    end
    
    local newLevel = tile.building_level + 1
    tile.building_level = newLevel
    
    return true, Property.calculateUpgradeCost(tile)
end

-- 降级地块（拆除建筑）
function Property.downgrade(tile)
    if tile.building_level > Property.Building.NONE then
        tile.building_level = tile.building_level - 1
        return true
    end
    return false
end

-- 转移所有权
function Property.transfer(tile, fromPlayerId, toPlayerId)
    if tile.owner ~= fromPlayerId then
        return false, "无法转移不属于你的地块"
    end
    
    tile.owner = toPlayerId
    return true
end

-- 重置地块
function Property.reset(tile)
    tile.owner = nil
    tile.building_level = Property.Building.NONE
    tile.roadblock = false
    tile.roadblock_owner = nil
    tile.landmine = false
    tile.landmine_owner = nil
end

-- ==================== 障碍物管理 ====================

-- 放置路障
function Property.placeRoadblock(tile, playerId)
    if tile.roadblock then
        return false, "该地块已有路障"
    end
    
    tile.roadblock = true
    tile.roadblock_owner = playerId
    return true
end

-- 移除路障
function Property.removeRoadblock(tile)
    if not tile.roadblock then
        return false, "该地块没有路障"
    end
    
    tile.roadblock = false
    tile.roadblock_owner = nil
    return true
end

-- 放置地雷
function Property.placeLandmine(tile, playerId)
    if tile.landmine then
        return false, "该地块已有地雷"
    end
    
    tile.landmine = true
    tile.landmine_owner = playerId
    return true
end

-- 触发地雷（摧毁座驾并住院）
function Property.triggerLandmine(tile)
    local result = {
        triggered = tile.landmine,
        owner = tile.landmine_owner
    }
    
    -- 触发后地雷消失
    if tile.landmine then
        tile.landmine = false
        tile.landmine_owner = nil
    end
    
    return result
end

-- ==================== 信息查询 ====================

-- 获取地块总价值（地块价格 + 所有建筑价格）
function Property.getTotalValue(tile)
    if tile.type ~= Property.Type.PROPERTY or not tile.owner then
        return 0
    end
    
    local total = tile.price
    
    -- 加上所有已建筑的升级费用
    for level = 1, tile.building_level do
        total = total + (tile.price * (2 ^ level))
    end
    
    return total
end

-- 获取地块信息摘要
function Property.getSummary(tile)
    local summary = {
        id = tile.id,
        name = tile.name,
        type = tile.type,
        price = tile.price,
        owner = tile.owner,
        building_level = tile.building_level,
        building_name = Property.getBuildingName(tile.building_level),
        rent = tile.owner and Property.calculateRent(tile) or 0,
        roadblock = tile.roadblock,
        landmine = tile.landmine
    }
    
    return summary
end

-- 获取地块描述
function Property.getDescription(tile)
    local desc = tile.name .. "\n类型: " .. tile.type
    
    if tile.type == Property.Type.PROPERTY then
        desc = desc .. "\n价格: " .. tile.price .. " 金币"
        
        if tile.owner then
            desc = desc .. "\n拥有者: 玩家 " .. tile.owner
            desc = desc .. "\n建筑: " .. Property.getBuildingName(tile.building_level)
            desc = desc .. "\n租金: " .. math.floor(Property.calculateRent(tile)) .. " 金币"
            
            if tile.building_level < Property.Building.MANSION then
                desc = desc .. "\n升级费用: " .. Property.calculateUpgradeCost(tile) .. " 金币"
            end
        else
            desc = desc .. "\n状态: 可购买"
        end
    elseif tile.type == Property.Type.TAX_OFFICE then
        desc = desc .. "\n效果: 支付现金的50%作为税金"
    elseif tile.type == Property.Type.HOSPITAL then
        desc = desc .. "\n效果: 支付费用并停留数回合"
    elseif tile.type == Property.Type.MOUNTAIN then
        desc = desc .. "\n效果: 被困深山，停留数回合"
    elseif tile.type == Property.Type.BLACK_MARKET then
        desc = desc .. "\n效果: 使用特殊货币购买道具"
    end
    
    return desc
end

-- ==================== 高级功能 ====================

-- 强征地块（使用强征卡）
function Property.forceAcquire(tile, fromPlayerId, toPlayerId, cost)
    if tile.owner ~= fromPlayerId then
        return false, "目标地块不属于该玩家"
    end
    
    -- 转移所有权（包括建筑）
    tile.owner = toPlayerId
    
    return true, cost
end

-- 获取相邻地块
-- 假设16个地块排列成 4x4 的正方形
function Property.getAdjacentTiles(tileId, allTiles)
    local adjacent = {}
    local adjacentIds = {}
    
    -- 简化版：仅返回前一个和后一个地块
    if tileId > 1 then
        table.insert(adjacentIds, tileId - 1)
    else
        table.insert(adjacentIds, 16)
    end
    
    if tileId < 16 then
        table.insert(adjacentIds, tileId + 1)
    else
        table.insert(adjacentIds, 1)
    end
    
    for _, id in ipairs(adjacentIds) do
        if allTiles[id] then
            table.insert(adjacent, allTiles[id])
        end
    end
    
    return adjacent
end

-- 检查是否可以加盖（可选：检查相邻地块是否都被拥有）
function Property.canUpgrade(tile, allTiles)
    if tile.type ~= Property.Type.PROPERTY then
        return false, "只有房地产可以升级"
    end
    
    if not tile.owner then
        return false, "未拥有的地块无法升级"
    end
    
    if tile.building_level >= Property.Building.MANSION then
        return false, "已是最高等级"
    end
    
    return true
end

return Property
