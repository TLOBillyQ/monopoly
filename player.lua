-- 玩家/角色系统
-- Player System

local player = {}

-- 玩家状态
player.state = {
    normal = "normal",
    in_hospital = "in_hospital",
    in_mountain = "in_mountain",
    in_jail = "in_jail",
    bankrupt = "bankrupt"
}

player.__index = player

local states = player.state

-- 创建新玩家
function player.new(id, character_id, vehicle_id, is_ai, tile_count)
    local p = {
        id = id,
        name = ("玩家" .. id),
        is_ai = is_ai or false,
        tile_count = tile_count or 16,

        -- 角色和座驾
        character_id = character_id or 1001,
        vehicle_id = vehicle_id or 4001,

        -- 财务
        money = 100000,  -- 初始金币
        properties = {}, -- 拥有的地块 ID 列表

        -- 位置和移动
        position = 1, -- 当前位置（1-16）

        -- 状态管理
        state = states.normal,
        stay_turns = 0,  -- 停留回合数
        stay_type = nil, -- 停留类型

        -- 道具系统
        items = {},    -- 道具卡列表，最多5个
        item_count = 0, -- 当前道具数量

        -- 附身状态（互斥，最多一个）
        buff_type = nil, -- "angel", "wealth", "poor" 或 nil
        buff_turns = 0,  -- 附身剩余回合数

        -- 座驾管理
        has_vehicle = true,        -- 是否有座驾
        vehicle_destroyed = false, -- 座驾是否被摧毁

        -- 其他状态
        free_jail_card = false, -- 免费停留卡（在监狱中使用）

        -- 统计数据
        total_assets = 100000, -- 总资产
        turns_played = 0,      -- 已进行回合数

        -- 调试信息
        last_action = nil
    }

    setmetatable(p, player)

    return p
end

local function resolve_tile_count(player, tile_count)
    if tile_count then
        return tile_count
    end
    if player and player.tile_count then
        return player.tile_count
    end
    return 16
end


-- ==================== 金币管理 ====================

-- 添加金币
function player.add_money(player, amount)
    player.money = player.money + amount
    if player.money < 0 then
        player.money = 0
    end
    player.update_total_assets(player)
end

-- 减少金币
function player.subtract_money(player, amount)
    player.money = player.money - amount
    if player.money < 0 then
        player.money = 0
    end
    player.update_total_assets(player)
end

-- 转账：从一个玩家转账给另一个玩家
function player.transfer(payer, receiver, amount)
    local actual_amount = math.min(payer.money, amount)
    player.subtract_money(payer, actual_amount)
    player.add_money(receiver, actual_amount)
    return actual_amount
end

-- ==================== 地块管理 ====================

-- 添加地块所有权
function player.acquire_property(player, property_id)
    for _, id in ipairs(player.properties) do
        if id == property_id then
            return false -- 已经拥有
        end
    end
    table.insert(player.properties, property_id)
    player.update_total_assets(player)
    return true
end

-- 失去地块所有权
function player.lose_property(player, property_id)
    for i, id in ipairs(player.properties) do
        if id == property_id then
            table.remove(player.properties, i)
            player.update_total_assets(player)
            return true
        end
    end
    return false
end

-- 随机失去一块地块
function player.lose_random_property(player)
    if #player.properties > 0 then
        local idx = math.random(1, #player.properties)
        local property_id = player.properties[idx]
        table.remove(player.properties, idx)
        player.update_total_assets(player)
        return property_id
    end
    return nil
end

-- 失去所有地块
function player.lose_all_properties(player)
    local count = #player.properties
    player.properties = {}
    player.update_total_assets(player)
    return count
end

-- ==================== 道具管理 ====================

-- 添加道具
function player.add_item(player, item_id)
    if player.item_count >= 5 then
        return false, "道具卡已满"
    end

    table.insert(player.items, item_id)
    player.item_count = player.item_count + 1
    return true
end

-- 移除指定索引的道具
function player.remove_item(player, index)
    if index > 0 and index <= player.item_count then
        table.remove(player.items, index)
        player.item_count = player.item_count - 1
        return true
    end
    return false
end

-- 随机移除一个道具
function player.remove_random_item(player)
    if player.item_count > 0 then
        local idx = math.random(1, player.item_count)
        local item_id = player.items[idx]
        table.remove(player.items, idx)
        player.item_count = player.item_count - 1
        return item_id
    end
    return nil
end

-- 清空所有道具
function player.clear_all_items(player)
    local count = #player.items
    player.items = {}
    player.item_count = 0
    return count
end

-- 是否持有某个道具
function player.has_item(player, item_id)
    for i, id in ipairs(player.items) do
        if id == item_id then
            return true, i
        end
    end
    return false
end

-- ==================== 附身状态管理 ====================

-- 获得附身状态
function player.apply_buff(player, buff_type, duration)
    player.buff_type = buff_type
    player.buff_turns = duration
end

-- 移除附身状态
function player.remove_buff(player)
    player.buff_type = nil
    player.buff_turns = 0
end

-- 减少附身时间
function player.reduce_buff(player)
    if player.buff_turns > 0 then
        player.buff_turns = player.buff_turns - 1
        if player.buff_turns == 0 then
            player.buff_type = nil
        end
    end
end

-- 检查玩家是否受到天使保护
function player.is_protected_by_angel(player)
    return player.buff_type == "angel" and player.buff_turns > 0
end

-- 检查玩家是否被穷神附身
function player.is_cursed_by_poor(player)
    return player.buff_type == "poor" and player.buff_turns > 0
end

-- 检查玩家是否被财神附身
function player.is_blessed_by_wealth(player)
    return player.buff_type == "wealth" and player.buff_turns > 0
end

-- ==================== 座驾管理 ====================

-- 获得座驾
function player.obtain_vehicle(player, vehicle_id)
    player.vehicle_id = vehicle_id
    player.has_vehicle = true
    player.vehicle_destroyed = false
end

-- 摧毁座驾
function player.destroy_vehicle(player)
    player.vehicle_destroyed = true
    player.has_vehicle = false
end

-- 修复座驾
function player.repair_vehicle(player)
    player.vehicle_destroyed = false
    player.has_vehicle = true
end

-- ==================== 状态管理 ====================

-- 进入医院
function player.enter_hospital(player, stay_turns)
    player.state = states.in_hospital
    player.stay_turns = stay_turns
    player.stay_type = "hospital"
    player.vehicle_destroyed = true
end

-- 进入深山
function player.enter_mountain(player, stay_turns)
    player.state = states.in_mountain
    player.stay_turns = stay_turns
    player.stay_type = "mountain"
end

-- 进入监狱
function player.enter_jail(player, stay_turns)
    player.state = states.in_jail
    player.stay_turns = stay_turns
    player.stay_type = "jail"
end

-- 减少停留时间
function player.reduce_stay_turns(player)
    if player.stay_turns > 0 then
        player.stay_turns = player.stay_turns - 1

        if player.stay_turns == 0 then
            player.state = states.normal
            player.stay_type = nil
        end

        return true
    end
    return false
end

-- 立即离开当前位置
function player.release_from_stay(player)
    player.state = states.normal
    player.stay_turns = 0
    player.stay_type = nil
end

-- 设置破产
function player.bankrupt(player)
    player.state = states.bankrupt
    player.money = 0
    player.properties = {}
    player.items = {}
    player.item_count = 0
    player.update_total_assets(player)
end

-- 检查是否破产
function player.is_bankrupt(player)
    return player.state == states.bankrupt
end

-- ==================== 位置管理 ====================

-- 移动到指定位置
function player.move_to(player, position, tile_count)
    tile_count = resolve_tile_count(player, tile_count)
    player.position = position % tile_count
    if player.position == 0 then
        player.position = tile_count
    end
end

-- 前进指定步数
function player.move_forward(player, steps, tile_count)
    tile_count = resolve_tile_count(player, tile_count)
    player.position = player.position + steps
    while player.position > tile_count do
        player.position = player.position - tile_count
    end
    return player.position
end

-- 后退指定步数
function player.move_backward(player, steps, tile_count)
    tile_count = resolve_tile_count(player, tile_count)
    player.position = player.position - steps
    while player.position <= 0 do
        player.position = player.position + tile_count
    end
    return player.position
end

-- ==================== 其他方法 ====================

-- 更新总资产（用于破产判定和排名）
function player.update_total_assets(player)
    local total = player.money
    -- 地块价值会在 game.lua 中单独计算
    player.total_assets = total
end

-- 开始新一回合
function player.start_turn(player)
    player.turns_played = player.turns_played + 1
    player.reduce_buff(player)

    -- 如果在停留状态，减少停留时间
    if player.state == states.in_hospital or
        player.state == states.in_mountain or
        player.state == states.in_jail then
        player.reduce_stay_turns(player)
    end
end

-- 检查玩家是否可以行动
function player.can_act(player)
    return player.state == states.normal and not player.is_bankrupt(player)
end

-- 返回玩家信息摘要（用于调试和UI）
function player.get_summary(player)
    return {
        id = player.id,
        name = player.name,
        money = player.money,
        position = player.position,
        properties = #player.properties,
        items = player.item_count,
        state = player.state,
        stay_turns = player.stay_turns,
        buff_type = player.buff_type,
        buff_turns = player.buff_turns,
        has_vehicle = player.has_vehicle,
        total_assets = player.total_assets
    }
end

return player
