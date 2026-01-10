local config = require "config"

local property = {}

-- ==================== 地块类型 ====================
property.types = {
    start = "start",               -- 起点
    property = "property",         -- 可购买地块（普通房地产）
    tax_office = "tax_office",     -- 税务局
    hospital = "hospital",         -- 医院
    mountain = "mountain",         -- 深山
    black_market = "black_market", -- 黑市
    jail = "jail"                  -- 监狱
}

-- 建筑等级
property.buildings = {
    none = 0,      -- 无建筑
    house = 1,     -- 住宅
    apartment = 2, -- 公寓
    hotel = 3,     -- 酒店
    mansion = 4    -- 豪宅
}

-- ==================== 地块创建 ====================

-- 根据config创建地块
function property.create_from_config()
    local tiles = {}

    for i, tile_config in ipairs(config.tiles) do
        local tile = {
            id = tile_config.id,
            name = tile_config.name,
            type = tile_config.type,
            price = tile_config.price or 0,
            grid_pos = tile_config.grid_pos,

            -- 所有权
            owner = nil, -- 拥有者ID

            -- 建筑
            building_level = 0, -- 建筑等级（0-4）

            -- 特殊对象
            roadblock = false,     -- 是否有路障
            roadblock_owner = nil, -- 路障放置者ID
            landmine = false,      -- 是否有地雷
            landmine_owner = nil,  -- 地雷放置者ID

            -- 位置信息
            position = i
        }

        tiles[i] = tile
    end

    return tiles
end

-- ==================== 租金计算 ====================

-- 计算地块基础租金
-- 租金 = 价格 * (0.4 + 0.3 * 建筑等级)
function property.calculate_rent(tile, with_buff)
    if tile.type ~= property.types.property or not tile.owner then
        return 0
    end

    local rent = tile.price * (0.4 + 0.3 * tile.building_level)

    -- 申用财神附身加成（如果传入）
    if with_buff then
        rent = rent * 2
    end

    return rent
end

-- 计算地块升级费用
-- 升级费用随等级线性提升
function property.calculate_upgrade_cost(tile)
    if tile.type ~= property.types.property or not tile.owner then
        return 0
    end

    if tile.building_level >= property.buildings.mansion then
        return 0 -- 已是最高等级
    end

    local next_level = tile.building_level + 1
    return math.floor(tile.price * (1 + 0.5 * next_level))
end

-- 获取建筑等级名称
function property.get_building_name(level)
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
function property.buy(tile, player_id, cost)
    if tile.type ~= property.types.property then
        return false, "该地块无法购买"
    end

    if tile.owner then
        return false, "该地块已被购买"
    end

    tile.owner = player_id
    tile.building_level = property.buildings.none

    return true, cost or tile.price
end

-- 升级地块
function property.upgrade(tile, player_id, cost)
    if tile.type ~= property.types.property then
        return false, "该地块无法升级"
    end

    if tile.owner ~= player_id then
        return false, "这不是你的地块"
    end

    if tile.building_level >= property.buildings.mansion then
        return false, "已是最高等级"
    end

    local new_level = tile.building_level + 1
    tile.building_level = new_level

    return true, property.calculate_upgrade_cost(tile)
end

-- 降级地块（拆除建筑）
function property.downgrade(tile)
    if tile.building_level > property.buildings.none then
        tile.building_level = tile.building_level - 1
        return true
    end
    return false
end

-- 转移所有权
function property.transfer(tile, from_player_id, to_player_id)
    if tile.owner ~= from_player_id then
        return false, "无法转移不属于你的地块"
    end

    tile.owner = to_player_id
    return true
end

-- 重置地块
function property.reset(tile)
    tile.owner = nil
    tile.building_level = property.buildings.none
    tile.roadblock = false
    tile.roadblock_owner = nil
    tile.landmine = false
    tile.landmine_owner = nil
end

-- ==================== 障碍物管理 ====================

-- 放置路障
function property.place_roadblock(tile, player_id)
    if tile.roadblock then
        return false, "该地块已有路障"
    end

    tile.roadblock = true
    tile.roadblock_owner = player_id
    return true
end

-- 移除路障
function property.remove_roadblock(tile)
    if not tile.roadblock then
        return false, "该地块没有路障"
    end

    tile.roadblock = false
    tile.roadblock_owner = nil
    return true
end

-- 放置地雷
function property.place_landmine(tile, player_id)
    if tile.landmine then
        return false, "该地块已有地雷"
    end

    tile.landmine = true
    tile.landmine_owner = player_id
    return true
end

-- 触发地雷（摧毁座驾并住院）
function property.trigger_landmine(tile)
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
function property.get_total_value(tile)
    if tile.type ~= property.types.property or not tile.owner then
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
function property.get_summary(tile)
    local summary = {
        id = tile.id,
        name = tile.name,
        type = tile.type,
        price = tile.price,
        owner = tile.owner,
        building_level = tile.building_level,
        building_name = property.get_building_name(tile.building_level),
        rent = tile.owner and property.calculate_rent(tile) or 0,
        roadblock = tile.roadblock,
        landmine = tile.landmine
    }

    return summary
end

-- 获取地块描述
function property.get_description(tile)
    local desc = tile.name .. "\n类型: " .. tile.type

    if tile.type == property.types.property then
        desc = desc .. "\n价格: " .. tile.price .. " 金币"

        if tile.owner then
            desc = desc .. "\n拥有者: 玩家 " .. tile.owner
            desc = desc .. "\n建筑: " .. property.get_building_name(tile.building_level)
            desc = desc .. "\n租金: " .. math.floor(property.calculate_rent(tile)) .. " 金币"

            if tile.building_level < property.buildings.mansion then
                desc = desc .. "\n升级费用: " .. property.calculate_upgrade_cost(tile) .. " 金币"
            end
        else
            desc = desc .. "\n状态: 可购买"
        end
    elseif tile.type == property.types.tax_office then
        desc = desc .. "\n效果: 支付现金的50%作为税金"
    elseif tile.type == property.types.hospital then
        desc = desc .. "\n效果: 支付费用并停留数回合"
    elseif tile.type == property.types.mountain then
        desc = desc .. "\n效果: 被困深山，停留数回合"
    elseif tile.type == property.types.black_market then
        desc = desc .. "\n效果: 使用特殊货币购买道具"
    end

    return desc
end

-- ==================== 高级功能 ====================

-- 强征地块（使用强征卡）
function property.force_acquire(tile, from_player_id, to_player_id, cost)
    if tile.owner ~= from_player_id then
        return false, "目标地块不属于该玩家"
    end

    -- 转移所有权（包括建筑）
    tile.owner = to_player_id

    return true, cost
end

-- 获取相邻地块
-- 假设16个地块排列成 4x4 的正方形
function property.get_adjacent_tiles(tile_id, all_tiles)
    local adjacent = {}
    local adjacent_ids = {}

    -- 简化版：仅返回前一个和后一个地块
    if tile_id > 1 then
        table.insert(adjacent_ids, tile_id - 1)
    else
        table.insert(adjacent_ids, 16)
    end

    if tile_id < 16 then
        table.insert(adjacent_ids, tile_id + 1)
    else
        table.insert(adjacent_ids, 1)
    end

    for _, id in ipairs(adjacent_ids) do
        if all_tiles[id] then
            table.insert(adjacent, all_tiles[id])
        end
    end

    return adjacent
end

-- 检查是否可以加盖（可选：检查相邻地块是否都被拥有）
function property.can_upgrade(tile, all_tiles)
    if tile.type ~= property.types.property then
        return false, "只有房地产可以升级"
    end

    if not tile.owner then
        return false, "未拥有的地块无法升级"
    end

    if tile.building_level >= property.buildings.mansion then
        return false, "已是最高等级"
    end

    return true
end

return property
