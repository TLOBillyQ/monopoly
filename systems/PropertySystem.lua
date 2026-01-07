-- 地块系统 - Spoke框架实现
-- 管理游戏地图和地块状态
local State = require("spoke.state")
local Memo = require("spoke.memo")

local PropertySystem = {}

-- 创建地块
function PropertySystem.createTile(id, config)
    return {
        id = State.Create(id),
        name = State.Create(config.name),
        type = State.Create(config.type),
        basePrice = State.Create(config.basePrice or 0),
        owner = State.Create(nil),  -- 拥有者ID
        level = State.Create(0),    -- 建筑等级 (0=空地, 1=房屋, 2=别墅, 3=高楼)
        roadblocks = State.Create({}),  -- 路障列表
        landmines = State.Create({}),   -- 地雷列表
    }
end

-- 创建地图
function PropertySystem.createMap(tileConfigs)
    local tiles = {}
    for i, config in ipairs(tileConfigs) do
        tiles[i] = PropertySystem.createTile(i, config)
    end
    return State.Create(tiles)
end

-- 购买地块
function PropertySystem.buyProperty(tile, playerId, price)
    tile.owner:Set(playerId)
    tile.level:Set(1)  -- 基础等级
    return price
end

-- 升级地块
function PropertySystem.upgradeProperty(tile, price)
    local currentLevel = tile.level:Now()
    if currentLevel < 3 then
        tile.level:Set(currentLevel + 1)
        return price * (2 ^ currentLevel)
    end
    return 0
end

-- 计算租金
function PropertySystem.calculateRent(tile, boardSize)
    local tileType = tile.type:Now()
    local level = tile.level:Now()
    local basePrice = tile.basePrice:Now()
    
    if tileType ~= "property" then
        return 0
    end
    
    if level == 0 then
        return 0  -- 无主地块不收租
    end
    
    -- 租金 = 上次升级费用 * 0.5
    local lastUpgradeCost = basePrice * (2 ^ (level - 1))
    return lastUpgradeCost * 0.5
end

-- 放置路障
function PropertySystem.placeRoadblock(tile, playerId)
    local roadblocks = tile.roadblocks:Now()
    table.insert(roadblocks, {playerId = playerId, turnsLeft = 1})
    tile.roadblocks:Set(roadblocks)
end

-- 放置地雷
function PropertySystem.placeLandmine(tile, playerId)
    local landmines = tile.landmines:Now()
    table.insert(landmines, {playerId = playerId, turnsLeft = 1})
    tile.landmines:Set(landmines)
end

-- 清除路障和地雷
function PropertySystem.clearObstacles(tile)
    tile.roadblocks:Set({})
    tile.landmines:Set({})
end

return PropertySystem
