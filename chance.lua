-- 机会卡系统（完整数据版，同步 main 数据）

local chance = {}
local player = require("player")
local item = require("item")
local property = require("property")

-- 事件类型枚举
chance.event_types = {
    gain_money = "gain_money",
    lose_money = "lose_money",
    lose_percent = "lose_percent",
    lose_percent_all = "lose_percent_all",
    collect_from_all = "collect_from_all",
    pay_to_all = "pay_to_all",
    move_forward = "move_forward",
    move_backward = "move_backward",
    teleport_to_tax = "teleport_to_tax",
    teleport_to_hospital = "teleport_to_hospital",
    teleport_to_market = "teleport_to_market",
    teleport_to_start = "teleport_to_start",
    teleport_secret = "teleport_secret",
    skip_jail = "skip_jail",
    gain_item = "gain_item",
    lose_random_item = "lose_random_item",
    lose_all_items = "lose_all_items",
    lose_property = "lose_property",
    force_hospital = "force_hospital",
    force_mountain = "force_mountain"
}

local function get_tile_index_by_type(game_state, tile_type, default_value)
    if game_state and game_state.tile_index_by_type and tile_type then
        return game_state.tile_index_by_type[tile_type] or default_value
    end
    return default_value
end

local function get_tile_count(game_state)
    if game_state and game_state.tile_count then
        return game_state.tile_count
    end
    return 16
end

-- 从配置构建机会卡列表
function chance.create_from_config(config)
    local events = {}
    for _, entry in ipairs(config.chance_events or {}) do
        local evt = {}
        for k, v in pairs(entry) do
            evt[k] = v
        end
        evt.event_type = entry.type or entry.event_type
        table.insert(events, evt)
    end
    return events
end

-- 按权重随机抽取一张机会卡
function chance.draw_random(chance_list)
    if not chance_list or #chance_list == 0 then
        return nil
    end
    local total_weight = 0
    for _, event in ipairs(chance_list) do
        total_weight = total_weight + (event.weight or 1)
    end
    if total_weight <= 0 then
        return chance_list[1]
    end
    local rand = math.random() * total_weight
    local current = 0
    for _, event in ipairs(chance_list) do
        current = current + (event.weight or 1)
        if rand <= current then
            return event
        end
    end
    return chance_list[#chance_list]
end

local function teleport_to(drawer, tile_index, tile_count)
    if tile_index then
        player.move_to(drawer, tile_index, tile_count)
    end
end

local function apply_hospital(drawer, rules)
    player.enter_hospital(drawer, rules.hospital_stay or 1)
    if rules.hospital_fee then
        player.subtract_money(drawer, rules.hospital_fee)
    end
end

-- 执行机会卡
function chance.execute(event, drawer, all_players, game_state)
    if not event then
        return { message = "没有可用的机会卡", applied = false }
    end

    local rules = (game_state and game_state.config and game_state.config.rules) or {}
    local tile_count = get_tile_count(game_state)
    local event_type = event.event_type or event.type
    local angel_protected = event.negative and drawer.buff_type == "angel" and (drawer.buff_turns or 0) > 0

    if angel_protected then
        return { message = "天使护符生效，负面事件无效", applied = false }
    end

    local result = { message = event.description or event.name or "机会卡", applied = true }

    if event_type == chance.event_types.gain_money then
        player.add_money(drawer, event.value or 0)
        result.message = string.format("%s，获得 %d 金币", event.name or "奖金", event.value or 0)
    elseif event_type == chance.event_types.lose_money then
        player.subtract_money(drawer, event.value or 0)
        result.message = string.format("%s，失去 %d 金币", event.name or "罚款", event.value or 0)
    elseif event_type == chance.event_types.lose_percent then
        local amount = math.floor(drawer.money * (event.value or 0))
        player.subtract_money(drawer, amount)
        result.message = string.format("损失资金的 %d%%（%d 金币）", math.floor((event.value or 0) * 100), amount)
    elseif event_type == chance.event_types.lose_percent_all then
        for _, p in ipairs(all_players or {}) do
            if p.id ~= drawer.id then
                local amount = math.floor(p.money * (event.value or 0))
                player.subtract_money(p, amount)
            end
        end
        result.message = "所有其他玩家损失资金"
    elseif event_type == chance.event_types.collect_from_all then
        local total = 0
        for _, p in ipairs(all_players or {}) do
            if p.id ~= drawer.id then
                total = total + player.transfer(p, drawer, event.value or 0)
            end
        end
        result.message = string.format("每人支付 %d 金币，共收获 %d", event.value or 0, total)
    elseif event_type == chance.event_types.pay_to_all then
        for _, p in ipairs(all_players or {}) do
            if p.id ~= drawer.id then
                player.transfer(drawer, p, event.value or 0)
            end
        end
        result.message = string.format("请客，每人获得 %d 金币", event.value or 0)
    elseif event_type == chance.event_types.move_forward then
        player.move_forward(drawer, event.value or 0, tile_count)
        result.message = string.format("前进 %d 格", event.value or 0)
    elseif event_type == chance.event_types.move_backward then
        player.move_backward(drawer, event.value or 0, tile_count)
        result.message = string.format("后退 %d 格", event.value or 0)
    elseif event_type == chance.event_types.teleport_to_tax then
        local target = get_tile_index_by_type(game_state, "tax_office", 1)
        teleport_to(drawer, target, tile_count)
        result.message = "前往税务局"
    elseif event_type == chance.event_types.teleport_to_hospital then
        local target = get_tile_index_by_type(game_state, "hospital", 1)
        teleport_to(drawer, target, tile_count)
        apply_hospital(drawer, rules)
        result.message = "前往医院并住院"
    elseif event_type == chance.event_types.teleport_to_market then
        local target = get_tile_index_by_type(game_state, "black_market", 1)
        teleport_to(drawer, target, tile_count)
        result.message = "前往黑市"
    elseif event_type == chance.event_types.teleport_to_start then
        local target = get_tile_index_by_type(game_state, "start", 1)
        teleport_to(drawer, target, tile_count)
        result.message = "回到起点"
    elseif event_type == chance.event_types.teleport_secret then
        local target = get_tile_index_by_type(game_state, "black_market", 1)
        teleport_to(drawer, target, tile_count)
        result.message = "通过密道进入黑市"
    elseif event_type == chance.event_types.skip_jail then
        drawer.free_jail_card = true
        result.message = "获得免费停留卡"
    elseif event_type == chance.event_types.gain_item then
        local item_id = event.value
        local added = player.add_item(drawer, item_id)
        if not added then
            result.message = "道具栏已满，无法获得道具"
        else
            local name = item.get_name(item_id)
            result.message = string.format("获得道具：%s", name)
            local use_result = item.use and item.use(item_id, drawer, game_state)
            if use_result and use_result.message then
                result.message = use_result.message
            end
        end
    elseif event_type == chance.event_types.lose_random_item then
        local lost = player.remove_random_item(drawer)
        result.message = lost and string.format("丢失一张道具（ID %s）", tostring(lost)) or "没有道具可丢失"
    elseif event_type == chance.event_types.lose_all_items then
        local count = player.clear_all_items(drawer)
        result.message = string.format("丢失所有道具，共 %d 张", count)
    elseif event_type == chance.event_types.lose_property then
        if drawer.properties and #drawer.properties > 0 then
            local lost_property_id = player.lose_random_property(drawer)
            if lost_property_id and game_state and game_state.tiles then
                for _, t in ipairs(game_state.tiles) do
                    if t.id == lost_property_id then
                        property.reset(t)
                        break
                    end
                end
            end
            result.message = string.format("失去一块地块（ID %s）", tostring(lost_property_id))
        else
            result.message = "没有地块可失去"
        end
    elseif event_type == chance.event_types.force_hospital then
        local target = get_tile_index_by_type(game_state, "hospital", 1)
        teleport_to(drawer, target, tile_count)
        apply_hospital(drawer, rules)
        result.message = "强制住院"
    elseif event_type == chance.event_types.force_mountain then
        local target = get_tile_index_by_type(game_state, "mountain", 1)
        teleport_to(drawer, target, tile_count)
        player.enter_mountain(drawer, rules.mountain_stay or 1)
        result.message = "被迫进入深山"
    end

    return result
end

return chance
