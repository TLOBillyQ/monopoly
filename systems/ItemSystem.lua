-- 物品和机会卡系统 - Spoke框架实现

local State = require("Spoke.State")

local ItemSystem = {}

-- 创建物品数据库
function ItemSystem.createItemDatabase(itemConfigs)
    local db = {}
    for id, config in pairs(itemConfigs) do
        db[id] = {
            id = id,
            name = config.name,
            level = config.level,
            type = config.type,
            description = config.description,
            blackMarketCost = config.blackMarketCost,
        }
    end
    return State.Create(db)
end

-- 创建机会卡数据库
function ItemSystem.createChanceDatabase(chanceConfigs)
    local db = {}
    for id, config in pairs(chanceConfigs) do
        db[id] = {
            id = id,
            name = config.name,
            description = config.description,
            type = config.type,
            target = config.target,
            value = config.value,
        }
    end
    return State.Create(db)
end

-- 随机抽取物品（按权重）
function ItemSystem.drawRandomItem(itemDatabase)
    local db = itemDatabase:Get()
    local items = {}
    local weights = {}
    
    for id, config in pairs(db) do
        table.insert(items, id)
        -- 这里应该从配置中读取权重
        table.insert(weights, 100)
    end
    
    if #items == 0 then return nil end
    
    -- 简单随机选择
    return items[math.random(#items)]
end

-- 随机抽取机会卡
function ItemSystem.drawRandomChance(chanceDatabase)
    local db = chanceDatabase:Get()
    local chances = {}
    
    for id, config in pairs(db) do
        table.insert(chances, id)
    end
    
    if #chances == 0 then return nil end
    
    return chances[math.random(#chances)]
end

-- 应用物品效果
function ItemSystem.applyItemEffect(itemId, itemDatabase, targetPlayer, context)
    local db = itemDatabase:Get()
    local item = db[itemId]
    
    if not item then return false end
    
    -- 根据物品类型应用效果
    -- 这里是框架，具体效果由游戏逻辑处理
    return true
end

-- 应用机会卡效果
function ItemSystem.applyChanceEffect(chanceId, chanceDatabase, targetPlayer, context)
    local db = chanceDatabase:Get()
    local chance = db[chanceId]
    
    if not chance then return false end
    
    -- 根据机会卡类型应用效果
    -- 这里是框架，具体效果由游戏逻辑处理
    return true
end

return ItemSystem
