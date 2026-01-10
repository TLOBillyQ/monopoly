local class = require("Utils.ClassUtils").class
local config = require("config")
local Player = require("Player")
local Tile = require("Tile")

---@class ItemSystem
---@field new fun(): ItemSystem
local ItemSystem = class("ItemSystem")

ItemSystem.types = {
    free_pass = "free_pass",
    remote_dice = "remote_dice",
    dice_double = "dice_double",
    roadblock = "roadblock",
    landmine = "landmine",
    clear_road = "clear_road",
    steal = "steal",
    monster = "monster",
    force_acquire = "force_acquire",
    tax_free = "tax_free",
    equal_wealth = "equal_wealth",
    banish = "banish",
    missile = "missile",
    tax_check = "tax_check",
    invoke_god = "invoke_god",
    send_god = "send_god",
    wealth_god = "wealth_god",
    poor_god = "poor_god",
    angel = "angel"
}

ItemSystem.id_to_type = {
    [2001] = ItemSystem.types.free_pass,
    [2002] = ItemSystem.types.remote_dice,
    [2003] = ItemSystem.types.dice_double,
    [2004] = ItemSystem.types.roadblock,
    [2005] = ItemSystem.types.landmine,
    [2006] = ItemSystem.types.clear_road,
    [2007] = ItemSystem.types.steal,
    [2008] = ItemSystem.types.monster,
    [2009] = ItemSystem.types.force_acquire,
    [2010] = ItemSystem.types.tax_free,
    [2011] = ItemSystem.types.equal_wealth,
    [2012] = ItemSystem.types.banish,
    [2013] = ItemSystem.types.missile,
    [2014] = ItemSystem.types.tax_check,
    [2015] = ItemSystem.types.invoke_god,
    [2016] = ItemSystem.types.send_god,
    [2017] = ItemSystem.types.wealth_god,
    [2018] = ItemSystem.types.poor_god,
    [2019] = ItemSystem.types.angel
}

ItemSystem.info = {
    [ItemSystem.types.free_pass] = { id = 2001, name = "免费卡", description = "免除下一次租金或税金。" },
    [ItemSystem.types.remote_dice] = { id = 2002, name = "遥控骰子卡", description = "控制下一次掷骰点数。" },
    [ItemSystem.types.dice_double] = { id = 2003, name = "骰子加倍卡", description = "本回合掷骰结果翻倍。" },
    [ItemSystem.types.roadblock] = { id = 2004, name = "路障卡", description = "放置路障，阻挡其他玩家。" },
    [ItemSystem.types.landmine] = { id = 2005, name = "地雷卡", description = "在脚下放置地雷。" },
    [ItemSystem.types.clear_road] = { id = 2006, name = "清障卡", description = "清除前方障碍。" },
    [ItemSystem.types.steal] = { id = 2007, name = "偷窃卡", description = "偷取其他玩家的道具。" },
    [ItemSystem.types.monster] = { id = 2008, name = "怪兽卡", description = "释放怪兽拆除建筑。" },
    [ItemSystem.types.force_acquire] = { id = 2009, name = "强征卡", description = "强制获得当前地块。" },
    [ItemSystem.types.tax_free] = { id = 2010, name = "免税卡", description = "抵扣下一次税金。" },
    [ItemSystem.types.equal_wealth] = { id = 2011, name = "均富卡", description = "与目标平分金币。" },
    [ItemSystem.types.banish] = { id = 2012, name = "流放卡", description = "将目标流放到深山。" },
    [ItemSystem.types.missile] = { id = 2013, name = "导弹卡", description = "攻击范围内的建筑。" },
    [ItemSystem.types.tax_check] = { id = 2014, name = "查税卡", description = "让目标支付税金。" },
    [ItemSystem.types.invoke_god] = { id = 2015, name = "请神卡", description = "夺取他人附身神。" },
    [ItemSystem.types.send_god] = { id = 2016, name = "送神卡", description = "将穷神转移出去。" },
    [ItemSystem.types.wealth_god] = { id = 2017, name = "财神卡", description = "财神附身，收益翻倍。" },
    [ItemSystem.types.poor_god] = { id = 2018, name = "穷神卡", description = "让目标穷神附身。" },
    [ItemSystem.types.angel] = { id = 2019, name = "天使卡", description = "天使附身，免疫负面效果。" }
}

local function resolve_item_type(item_id)
    return ItemSystem.id_to_type[item_id]
end

local function other_players(player, game_state)
    local others = {}
    if game_state and game_state.players then
        for _, p in ipairs(game_state.players) do
            if p.id ~= player.id and not p:is_bankrupt() then
                table.insert(others, p)
            end
        end
    end
    return others
end

local function get_tile_index_by_type(game_state, tile_type, default_value)
    if game_state and game_state.tile_index_by_type and tile_type then
        return game_state.tile_index_by_type[tile_type] or default_value
    end
    return default_value
end

function ItemSystem:ctor()
    -- 留作未来扩展：注入配置或依赖
end

function ItemSystem:get_info(item_id)
    local t = resolve_item_type(item_id)
    return t and ItemSystem.info[t] or nil
end

function ItemSystem:get_name(item_id)
    local info = self:get_info(item_id)
    return info and info.name or ("道具" .. tostring(item_id))
end

function ItemSystem:draw_random()
    local items = (config and config.items) or {}
    local total = 0
    for _, entry in ipairs(items) do
        if (entry.weight or 0) > 0 then
            total = total + entry.weight
        end
    end
    if total <= 0 then
        return items[1] and items[1].id or nil
    end
    local rand = math.random() * total
    local current = 0
    for _, entry in ipairs(items) do
        if (entry.weight or 0) > 0 then
            current = current + entry.weight
            if rand <= current then
                return entry.id
            end
        end
    end
    return items[#items] and items[#items].id or nil
end

function ItemSystem:remove_from_player(player, item_id)
    if not player or not player.items then
        return false
    end
    for idx, id in ipairs(player.items) do
        if id == item_id then
            player:remove_item(idx)
            return true
        end
    end
    return false
end

-- 立即使用并消耗道具
function ItemSystem:use(item_id, player, game_state)
    local item_type = resolve_item_type(item_id)
    if not item_type then
        return { success = false, message = "未知道具" }
    end

    local rules = (game_state and game_state.config and game_state.config.rules) or {}
    local others = other_players(player, game_state)
    local target = others[1]
    local result = { success = true, message = self:get_name(item_id) }

    if item_type == ItemSystem.types.free_pass then
        player.free_pass = true
        result.message = "下次租金或税金豁免"
    elseif item_type == ItemSystem.types.remote_dice then
        player.pending_dice_override = 6
        result.message = "遥控骰子：下一次掷骰固定为 6 点"
    elseif item_type == ItemSystem.types.dice_double then
        player.pending_dice_double = true
        result.message = "本回合骰子结果加倍"
    elseif item_type == ItemSystem.types.roadblock or item_type == ItemSystem.types.landmine or item_type == ItemSystem.types.clear_road then
        result.message = self:get_name(item_id) .. " 功能未实现，已作废"
    elseif item_type == ItemSystem.types.steal then
        if target and target.items and #target.items > 0 then
            local stolen = target:remove_random_item()
            player:add_item(stolen)
            result.message = string.format("偷取 %s 的道具 %s", target.name, self:get_name(stolen))
        else
            result.message = "目标没有可偷的道具"
        end
    elseif item_type == ItemSystem.types.monster then
        result.message = "怪兽卡效果未实现，已作废"
    elseif item_type == ItemSystem.types.force_acquire then
        local tiles = game_state and game_state.tiles
        local tile = tiles and tiles[player.position]
        if tile and tile.type == Tile.types.property and tile.owner and tile.owner ~= player.id then
            local cost = math.floor((tile.price or 0) * 1.2)
            if player.money >= cost then
                tile:reset()
                tile:buy(player.id, tile.price)
                player:subtract_money(cost)
                player:acquire_property(tile.id)
                result.message = string.format("强征成功，花费 %d 获得 %s", cost, tile.name)
            else
                result.message = "资金不足，无法强征"
            end
        else
            result.message = "当前位置无法强征"
        end
    elseif item_type == ItemSystem.types.tax_free then
        player.free_pass = true
        result.message = "免税卡已激活"
    elseif item_type == ItemSystem.types.equal_wealth then
        if target then
            local total = player.money + target.money
            local half = math.floor(total / 2)
            local function set_funds(p, desired)
                local diff = desired - p.money
                if diff >= 0 then
                    p:add_money(diff)
                else
                    p:subtract_money(-diff)
                end
            end
            set_funds(player, half)
            set_funds(target, total - half)
            result.message = string.format("与 %s 平分金币", target.name)
        else
            result.message = "没有可平分的目标"
        end
    elseif item_type == ItemSystem.types.banish then
        if target then
            local dest = get_tile_index_by_type(game_state, Tile.types.mountain, target.tile_count)
            if dest then
                target:move_to(dest, target.tile_count)
            end
            target:enter_mountain(rules.mountain_stay or 1)
            result.message = string.format("将 %s 流放到深山", target.name)
        else
            result.message = "没有可流放的目标"
        end
    elseif item_type == ItemSystem.types.missile then
        result.message = "导弹卡效果未实现，已作废"
    elseif item_type == ItemSystem.types.tax_check then
        if target then
            local tax = math.floor(target.money * (rules.tax_rate or 0.5))
            Player.transfer(target, player, tax)
            result.message = string.format("%s 被查税，支付 %d", target.name, tax)
        else
            result.message = "没有可查税的目标"
        end
    elseif item_type == ItemSystem.types.invoke_god then
        if target and target.buff_type then
            player.buff_type = target.buff_type
            player.buff_turns = target.buff_turns
            target.buff_type = nil
            target.buff_turns = 0
            result.message = string.format("夺取了 %s 的附身状态", target.name)
        else
            result.message = "目标没有附身状态"
        end
    elseif item_type == ItemSystem.types.send_god then
        if player.buff_type == "poor" and target then
            target.buff_type = "poor"
            target.buff_turns = player.buff_turns
            player.buff_type = nil
            player.buff_turns = 0
            result.message = string.format("将穷神送给 %s", target.name)
        else
            result.message = "只有被穷神附身时才能使用"
        end
    elseif item_type == ItemSystem.types.wealth_god then
        player:apply_buff("wealth", rules.wealth_duration or 5)
        result.message = "财神附身，收益翻倍"
    elseif item_type == ItemSystem.types.poor_god then
        if target then
            target:apply_buff("poor", rules.poor_duration or 5)
            result.message = string.format("让 %s 被穷神附身", target.name)
        else
            result.message = "没有目标可施加穷神"
        end
    elseif item_type == ItemSystem.types.angel then
        player:apply_buff("angel", rules.angel_duration or 5)
        result.message = "天使附身，免疫负面效果"
    end

    self:remove_from_player(player, item_id)
    return result
end

local instance = ItemSystem.new()
return instance
