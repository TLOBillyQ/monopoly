local class = require("Utils.ClassUtils").class

---@class Player
---@field new fun(id: integer, character_id: integer, vehicle_id: integer, is_ai: boolean, tile_count: integer): Player
local Player = class("Player")

Player.states = {
    normal = "normal",
    in_hospital = "in_hospital",
    in_mountain = "in_mountain",
    in_jail = "in_jail",
    bankrupt = "bankrupt"
}

-- 创建新玩家
function Player:ctor(id, character_id, vehicle_id, is_ai, tile_count)
    self.id = id
    self.name = ("玩家" .. id)
    self.is_ai = is_ai or false
    self.tile_count = tile_count or 16

    -- 角色和座驾
    self.character_id = character_id or 1001
    self.vehicle_id = vehicle_id or 4001

    -- 财务
    self.money = 100000
    self.properties = {}

    -- 位置和移动
    self.position = 1

    -- 状态管理
    self.state = Player.states.normal
    self.stay_turns = 0
    self.stay_type = nil

    -- 道具系统
    self.items = {}
    self.item_count = 0

    -- 附身状态
    self.buff_type = nil
    self.buff_turns = 0

    -- 座驾管理
    self.has_vehicle = true
    self.vehicle_destroyed = false

    -- 其他状态
    self.free_jail_card = false

    -- 统计数据
    self.total_assets = 100000
    self.turns_played = 0

    -- 调试信息
    self.last_action = nil
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
function Player:add_money(amount)
    self.money = self.money + amount
    if self.money < 0 then
        self.money = 0
    end
    self:update_total_assets()
end

-- 减少金币
function Player:subtract_money(amount)
    self.money = self.money - amount
    if self.money < 0 then
        self.money = 0
    end
    self:update_total_assets()
end

-- 转账：从一个玩家转账给另一个玩家
function Player.transfer(payer, receiver, amount)
    local actual_amount = math.min(payer.money, amount)
    payer:subtract_money(actual_amount)
    receiver:add_money(actual_amount)
    return actual_amount
end

-- ==================== 地块管理 ====================

-- 添加地块所有权
function Player:acquire_property(property_id)
    for _, id in ipairs(self.properties) do
        if id == property_id then
            return false -- 已经拥有
        end
    end
    table.insert(self.properties, property_id)
    self:update_total_assets()
    return true
end

-- 失去地块所有权
function Player:lose_property(property_id)
    for i, id in ipairs(self.properties) do
        if id == property_id then
            table.remove(self.properties, i)
            self:update_total_assets()
            return true
        end
    end
    return false
end

-- 随机失去一块地块
function Player:lose_random_property()
    if #self.properties > 0 then
        local idx = math.random(1, #self.properties)
        local property_id = self.properties[idx]
        table.remove(self.properties, idx)
        self:update_total_assets()
        return property_id
    end
    return nil
end

-- 失去所有地块
function Player:lose_all_properties()
    local count = #self.properties
    self.properties = {}
    self:update_total_assets()
    return count
end

-- ==================== 道具管理 ====================

-- 添加道具
function Player:add_item(item_id)
    if self.item_count >= 5 then
        return false, "道具卡已满"
    end

    table.insert(self.items, item_id)
    self.item_count = self.item_count + 1
    return true
end

-- 移除指定索引的道具
function Player:remove_item(index)
    if index > 0 and index <= self.item_count then
        table.remove(self.items, index)
        self.item_count = self.item_count - 1
        return true
    end
    return false
end

-- 随机移除一个道具
function Player:remove_random_item()
    if self.item_count > 0 then
        local idx = math.random(1, self.item_count)
        local item_id = self.items[idx]
        table.remove(self.items, idx)
        self.item_count = self.item_count - 1
        return item_id
    end
    return nil
end

-- 清空所有道具
function Player:clear_all_items()
    local count = #self.items
    self.items = {}
    self.item_count = 0
    return count
end

-- 是否持有某个道具
function Player:has_item(item_id)
    for i, id in ipairs(self.items) do
        if id == item_id then
            return true, i
        end
    end
    return false
end

-- ==================== 附身状态管理 ====================

-- 获得附身状态
function Player:apply_buff(buff_type, duration)
    self.buff_type = buff_type
    self.buff_turns = duration
end

-- 移除附身状态
function Player:remove_buff()
    self.buff_type = nil
    self.buff_turns = 0
end

-- 减少附身时间
function Player:reduce_buff()
    if self.buff_turns > 0 then
        self.buff_turns = self.buff_turns - 1
        if self.buff_turns == 0 then
            self.buff_type = nil
        end
    end
end

-- 检查玩家是否受到天使保护
function Player:is_protected_by_angel()
    return self.buff_type == "angel" and self.buff_turns > 0
end

-- 检查玩家是否被穷神附身
function Player:is_cursed_by_poor()
    return self.buff_type == "poor" and self.buff_turns > 0
end

-- 检查玩家是否被财神附身
function Player:is_blessed_by_wealth()
    return self.buff_type == "wealth" and self.buff_turns > 0
end

-- ==================== 座驾管理 ====================

-- 获得座驾
function Player:obtain_vehicle(vehicle_id)
    self.vehicle_id = vehicle_id
    self.has_vehicle = true
    self.vehicle_destroyed = false
end

-- 摧毁座驾
function Player:destroy_vehicle()
    self.vehicle_destroyed = true
    self.has_vehicle = false
end

-- 修复座驾
function Player:repair_vehicle()
    self.vehicle_destroyed = false
    self.has_vehicle = true
end

-- ==================== 状态管理 ====================

-- 进入医院
function Player:enter_hospital(stay_turns)
    self.state = Player.states.in_hospital
    self.stay_turns = stay_turns
    self.stay_type = "hospital"
    self.vehicle_destroyed = true
end

-- 进入深山
function Player:enter_mountain(stay_turns)
    self.state = Player.states.in_mountain
    self.stay_turns = stay_turns
    self.stay_type = "mountain"
end

-- 进入监狱
function Player:enter_jail(stay_turns)
    self.state = Player.states.in_jail
    self.stay_turns = stay_turns
    self.stay_type = "jail"
end

-- 减少停留时间
function Player:reduce_stay_turns()
    if self.stay_turns > 0 then
        self.stay_turns = self.stay_turns - 1

        if self.stay_turns == 0 then
            self.state = Player.states.normal
            self.stay_type = nil
        end

        return true
    end
    return false
end

-- 立即离开当前位置
function Player:release_from_stay()
    self.state = Player.states.normal
    self.stay_turns = 0
    self.stay_type = nil
end

-- 设置破产
function Player:bankrupt()
    self.state = Player.states.bankrupt
    self.money = 0
    self.properties = {}
    self.items = {}
    self.item_count = 0
    self:update_total_assets()
end

-- 检查是否破产
function Player:is_bankrupt()
    return self.state == Player.states.bankrupt
end

-- ==================== 位置管理 ====================

-- 移动到指定位置
function Player:move_to(position, tile_count)
    tile_count = resolve_tile_count(self, tile_count)
    self.position = position % tile_count
    if self.position == 0 then
        self.position = tile_count
    end
end

-- 前进指定步数
function Player:move_forward(steps, tile_count)
    tile_count = resolve_tile_count(self, tile_count)
    self.position = self.position + steps
    while self.position > tile_count do
        self.position = self.position - tile_count
    end
    return self.position
end

-- 后退指定步数
function Player:move_backward(steps, tile_count)
    tile_count = resolve_tile_count(self, tile_count)
    self.position = self.position - steps
    while self.position <= 0 do
        self.position = self.position + tile_count
    end
    return self.position
end

-- ==================== 其他方法 ====================

-- 更新总资产（用于破产判定和排名）
function Player:update_total_assets()
    local total = self.money
    -- 地块价值会在 game.lua 中单独计算
    self.total_assets = total
end

-- 开始新一回合
function Player:start_turn()
    self.turns_played = self.turns_played + 1
    self:reduce_buff()

    -- 如果在停留状态，减少停留时间
    if self.state == Player.states.in_hospital or
        self.state == Player.states.in_mountain or
        self.state == Player.states.in_jail then
        self:reduce_stay_turns()
    end
end

-- 检查玩家是否可以行动
function Player:can_act()
    return self.state == Player.states.normal and not self:is_bankrupt()
end

-- 返回玩家信息摘要（用于调试和UI）
function Player:get_summary()
    return {
        id = self.id,
        name = self.name,
        money = self.money,
        position = self.position,
        properties = #self.properties,
        items = self.item_count,
        state = self.state,
        stay_turns = self.stay_turns,
        buff_type = self.buff_type,
        buff_turns = self.buff_turns,
        has_vehicle = self.has_vehicle,
        total_assets = self.total_assets
    }
end

return Player
