local class = require("Utils.ClassUtils").class
local config = require("config")

---@class Tile
---@field new fun(tile_config: table, index: integer): Tile
local Tile = class("Tile")

Tile.types = {
    start = "start",
    property = "property",
    tax_office = "tax_office",
    hospital = "hospital",
    mountain = "mountain",
    black_market = "black_market",
    jail = "jail"
}

Tile.buildings = {
    none = 0,
    house = 1,
    apartment = 2,
    hotel = 3,
    mansion = 4
}

function Tile:ctor(tile_config, index)
    self.id = tile_config.id
    self.name = tile_config.name
    self.type = tile_config.type
    self.price = tile_config.price or 0
    self.grid_pos = tile_config.grid_pos
    self.position = index or tile_config.id

    -- 所有权
    self.owner = nil

    -- 建筑
    self.building_level = Tile.buildings.none

    -- 特殊对象
    self.roadblock = false
    self.roadblock_owner = nil
    self.landmine = false
    self.landmine_owner = nil
end

function Tile.create_from_config()
    local tiles = {}
    for i, tile_config in ipairs(config.tiles) do
        tiles[i] = Tile.new(tile_config, i)
    end
    return tiles
end

-- ==================== 计算相关 ====================

-- 计算地块基础租金: 价格 * (0.4 + 0.3 * 建筑等级)
function Tile:calculate_rent(with_buff)
    if self.type ~= Tile.types.property or not self.owner then
        return 0
    end

    local rent = self.price * (0.4 + 0.3 * self.building_level)
    if with_buff then
        rent = rent * 2
    end
    return rent
end

-- 升级费用随等级线性提升
function Tile:calculate_upgrade_cost()
    if self.type ~= Tile.types.property or not self.owner then
        return 0
    end

    if self.building_level >= Tile.buildings.mansion then
        return 0
    end

    local next_level = self.building_level + 1
    return math.floor(self.price * (1 + 0.5 * next_level))
end

function Tile.get_building_name(level)
    local names = { "空地", "住宅", "公寓", "酒店", "豪宅" }
    return names[level + 1] or "未知"
end

-- ==================== 地块操作 ====================

function Tile:buy(player_id, cost)
    if self.type ~= Tile.types.property then
        return false, "该地块无法购买"
    end

    if self.owner then
        return false, "该地块已被购买"
    end

    self.owner = player_id
    self.building_level = Tile.buildings.none
    return true, cost or self.price
end

function Tile:upgrade(player_id, cost)
    if self.type ~= Tile.types.property then
        return false, "该地块无法升级"
    end

    if self.owner ~= player_id then
        return false, "这不是你的地块"
    end

    if self.building_level >= Tile.buildings.mansion then
        return false, "已是最高等级"
    end

    self.building_level = self.building_level + 1
    return true, self:calculate_upgrade_cost(cost)
end

function Tile:downgrade()
    if self.building_level > Tile.buildings.none then
        self.building_level = self.building_level - 1
        return true
    end
    return false
end

function Tile:transfer(from_player_id, to_player_id)
    if self.owner ~= from_player_id then
        return false, "无法转移不属于你的地块"
    end
    self.owner = to_player_id
    return true
end

function Tile:reset()
    self.owner = nil
    self.building_level = Tile.buildings.none
    self.roadblock = false
    self.roadblock_owner = nil
    self.landmine = false
    self.landmine_owner = nil
end

-- ==================== 障碍物管理 ====================

function Tile:place_roadblock(player_id)
    if self.roadblock then
        return false, "该地块已有路障"
    end
    self.roadblock = true
    self.roadblock_owner = player_id
    return true
end

function Tile:remove_roadblock()
    if not self.roadblock then
        return false, "该地块没有路障"
    end
    self.roadblock = false
    self.roadblock_owner = nil
    return true
end

function Tile:place_landmine(player_id)
    if self.landmine then
        return false, "该地块已有地雷"
    end
    self.landmine = true
    self.landmine_owner = player_id
    return true
end

function Tile:trigger_landmine()
    local result = {
        triggered = self.landmine,
        owner = self.landmine_owner
    }
    if self.landmine then
        self.landmine = false
        self.landmine_owner = nil
    end
    return result
end

-- ==================== 信息查询 ====================

function Tile:get_total_value()
    if self.type ~= Tile.types.property or not self.owner then
        return 0
    end

    local total = self.price
    for level = 1, self.building_level do
        total = total + (self.price * (2 ^ level))
    end
    return total
end

function Tile:get_summary()
    return {
        id = self.id,
        name = self.name,
        type = self.type,
        price = self.price,
        owner = self.owner,
        building_level = self.building_level,
        building_name = Tile.get_building_name(self.building_level),
        rent = self.owner and self:calculate_rent() or 0,
        roadblock = self.roadblock,
        landmine = self.landmine
    }
end

function Tile:get_description()
    local desc = self.name .. "\n类型: " .. self.type
    if self.type == Tile.types.property then
        desc = desc .. "\n价格: " .. self.price .. " 金币"
        if self.owner then
            desc = desc .. "\n拥有者: 玩家 " .. self.owner
            desc = desc .. "\n建筑: " .. Tile.get_building_name(self.building_level)
            desc = desc .. "\n租金: " .. math.floor(self:calculate_rent()) .. " 金币"
            if self.building_level < Tile.buildings.mansion then
                desc = desc .. "\n升级费用: " .. self:calculate_upgrade_cost() .. " 金币"
            end
        else
            desc = desc .. "\n状态: 可购买"
        end
    elseif self.type == Tile.types.tax_office then
        desc = desc .. "\n效果: 支付现金的50%作为税金"
    elseif self.type == Tile.types.hospital then
        desc = desc .. "\n效果: 支付费用并停留数回合"
    elseif self.type == Tile.types.mountain then
        desc = desc .. "\n效果: 被困深山，停留数回合"
    elseif self.type == Tile.types.black_market then
        desc = desc .. "\n效果: 使用特殊货币购买道具"
    end
    return desc
end

-- ==================== 高级功能 ====================

function Tile:force_acquire(from_player_id, to_player_id, cost)
    if self.owner ~= from_player_id then
        return false, "目标地块不属于该玩家"
    end
    self.owner = to_player_id
    return true, cost
end

function Tile.get_adjacent_tiles(tile_id, all_tiles)
    local adjacent = {}
    local adjacent_ids = {}

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

function Tile:can_upgrade(all_tiles)
    if self.type ~= Tile.types.property then
        return false, "只有房地产可以升级"
    end

    if not self.owner then
        return false, "未拥有的地块无法升级"
    end

    if self.building_level >= Tile.buildings.mansion then
        return false, "已是最高等级"
    end

    return true
end

return Tile
