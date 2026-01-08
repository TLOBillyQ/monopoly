local Config = require("config")
local Player = require("player")
local Property = require("property")
local Chance = require("chance")
local Item = require("item")
local Render = require("render")
local Input = require("input")

local game = {}

local phase = {
    ROLL = "ROLL",
    MOVE = "MOVE",
    RESOLVE = "RESOLVE",
    END_TURN = "END"
}

local function current_player(state)
    return state.players[state.current_player_index]
end

local function find_player_by_id(state, id)
    for _, p in ipairs(state.players) do
        if p.id == id then
            return p
        end
    end
end

local function log(state, message)
    state.last_log = message
    table.insert(state.logs, message)
    if #state.logs > 80 then
        table.remove(state.logs, 1)
    end
end

local function build_tile_index_by_type(tiles)
    local map = {}
    for _, tile in ipairs(tiles) do
        if tile.type and not map[tile.type] then
            map[tile.type] = tile.id
        end
    end
    return map
end

local function create_players(config, count, tile_count)
    local players = {}
    for i = 1, count do
        local character_id = (config.characters[i] and config.characters[i].id) or 1000 + i
        local vehicle_id = config.vehicles[1].id
        local is_ai = i > 1
        local player = Player.new(i, character_id, vehicle_id, is_ai, tile_count)
        player.money = config.rules.start_money
        player.total_assets = player.money
        table.insert(players, player)
    end
    return players
end

local function reset_prompts(state)
    state.waiting_action = nil
    state.ui = nil
    game.choose_yes = nil
    game.choose_no = nil
end

local function set_prompt(state, title, message, yes_fn, no_fn)
    state.waiting_action = { title = title }
    state.ui = {
        title = title,
        message = message,
        buttons = { "Y - 是", "N - 否" }
    }
    game.choose_yes = function()
        reset_prompts(state)
        yes_fn()
    end
    game.choose_no = function()
        reset_prompts(state)
        if no_fn then
            no_fn()
        end
    end
end

local function apply_bankruptcy_if_needed(state, player)
    if player.money <= 0 and not Player.is_bankrupt(player) then
        Player.bankrupt(player)
        for _, tile in ipairs(state.tiles) do
            if tile.owner == player.id then
                Property.reset(tile)
            end
        end
        log(state, string.format("玩家%d 破产，退出游戏", player.id))
    end
end

local function apply_item_gain(state, player, item_id)
    if not item_id then
        log(state, "未抽到任何道具")
        return
    end
    local added = Player.add_item(player, item_id)
    local name = Item.get_name(item_id)
    if not added then
        log(state, string.format("%s 道具栏已满", name))
        return
    end
    log(state, string.format("%s 获得道具：%s", player.name, name))

    -- 所有道具均为即时效果，获得后立刻生效
    local use_result = Item.use(item_id, player, state)
    if use_result and use_result.message then
        log(state, use_result.message)
    end
end

local function handle_rent(state, tenant, tile)
    local owner = find_player_by_id(state, tile.owner)
    if not owner then
        return
    end
    local rent = math.floor(Property.calculate_rent(tile, owner.buff_type == "wealth"))

    if tenant.free_pass then
        tenant.free_pass = false
        log(state, string.format("%s 使用免费卡，免租金", tenant.name))
        rent = 0
    elseif tenant.buff_type == "poor" and tenant.buff_turns > 0 then
        rent = rent * 2
    end

    if rent > 0 then
        Player.transfer(tenant, owner, rent)
        log(state, string.format("%s 向 %s 支付租金 %d", tenant.name, owner.name, rent))
        apply_bankruptcy_if_needed(state, tenant)
    else
        log(state, string.format("%s 本次无需支付租金", tenant.name))
    end
end

local function resolve_property(state, player, tile)
    if not tile.owner then
        if player.is_ai or state.auto_mode then
            if player.money >= tile.price then
                Property.buy(tile, player.id, tile.price)
                Player.subtract_money(player, tile.price)
                Player.acquire_property(player, tile.id)
                log(state, string.format("%s 自动购买了 %s", player.name, tile.name))
            else
                log(state, string.format("%s 资金不足，无法购买 %s", player.name, tile.name))
            end
            state.current_phase = phase.END_TURN
            return
        end

        set_prompt(
            state,
            "购买地块？",
            string.format("%s - 价格 %d", tile.name, tile.price),
            function() game.buy_property() end,
            function() game.skip_action() end
        )
        return
    end

    if tile.owner == player.id then
        if (player.is_ai or state.auto_mode) and tile.building_level < Property.buildings.mansion then
            local cost = Property.calculate_upgrade_cost(tile)
            if cost > 0 and player.money > cost + 300 then
                Property.upgrade(tile, player.id, cost)
                Player.subtract_money(player, cost)
                log(state, string.format("%s 自动升级了 %s", player.name, tile.name))
            end
        end
        state.current_phase = phase.END_TURN
        return
    end

    handle_rent(state, player, tile)
    state.current_phase = phase.END_TURN
end

local function resolve_special_tile(state, player, tile)
    local rules = state.config.rules
    if tile.type == "chance_card" then
        local event = Chance.draw_random(state.chance_deck)
        local res = Chance.execute(event, player, state.players, state)
        log(state, res.message)
        state.current_phase = phase.END_TURN
    elseif tile.type == "item_card" then
        local item_id = Item.draw_random(state.config)
        apply_item_gain(state, player, item_id)
        state.current_phase = phase.END_TURN
    elseif tile.type == "hospital" then
        Player.enter_hospital(player, rules.hospital_stay)
        Player.subtract_money(player, rules.hospital_fee)
        log(state, string.format("%s 住院，需要等待 %d 回合", player.name, rules.hospital_stay))
        apply_bankruptcy_if_needed(state, player)
        state.current_phase = phase.END_TURN
    elseif tile.type == "mountain" then
        Player.enter_mountain(player, rules.mountain_stay)
        log(state, string.format("%s 在深山停留 %d 回合", player.name, rules.mountain_stay))
        state.current_phase = phase.END_TURN
    elseif tile.type == "tax_office" then
        local tax = math.floor(player.money * rules.tax_rate)
        if player.free_pass then
            player.free_pass = false
            log(state, string.format("%s 使用免费卡，免税", player.name))
        else
            Player.subtract_money(player, tax)
            log(state, string.format("%s 支付税金 %d", player.name, tax))
            apply_bankruptcy_if_needed(state, player)
        end
        state.current_phase = phase.END_TURN
    elseif tile.type == "black_market" then
        local cost = 600
        if player.is_ai or state.auto_mode then
            if player.money >= cost then
                Player.subtract_money(player, cost)
                apply_item_gain(state, player, Item.draw_random(state.config))
            else
                log(state, string.format("%s 资金不足，无法在黑市购物", player.name))
            end
            state.current_phase = phase.END_TURN
        else
            set_prompt(
                state,
                "黑市购物？",
                string.format("花费 %d 获取随机道具", cost),
                function()
                    if player.money >= cost then
                        Player.subtract_money(player, cost)
                        apply_item_gain(state, player, Item.draw_random(state.config))
                    else
                        log(state, "金币不足，无法购物")
                    end
                    game.skip_action()
                end,
                function() game.skip_action() end
            )
        end
    elseif tile.type == "rest" then
        Player.add_money(player, 300)
        log(state, string.format("%s 休息并获得 300 金币", player.name))
        state.current_phase = phase.END_TURN
    elseif tile.type == "start" then
        Player.add_money(player, math.floor(rules.pass_start_bonus / 2))
        log(state, string.format("%s 停在起点，获得奖励", player.name))
        state.current_phase = phase.END_TURN
    else
        state.current_phase = phase.END_TURN
    end
end

local function move_player(state, player)
    local steps = state.pending_move or state.last_dice or 0
    local tile_count = state.tile_count
    local old_pos = player.position
    local new_pos = ((old_pos - 1 + steps) % tile_count) + 1
    if new_pos < old_pos then
        Player.add_money(player, state.config.rules.pass_start_bonus)
        log(state, string.format("%s 经过起点，获得 %d 金币", player.name, state.config.rules.pass_start_bonus))
    end
    player.position = new_pos
    log(state, string.format("%s 前进到格子 %d", player.name, new_pos))
end

local function prepare_turn(state, player)
    if Player.is_bankrupt(player) then
        return false
    end
    Player.start_turn(player)
    if player.state ~= Player.state.normal then
        log(state, string.format("%s 仍在等待，剩余 %d 回合", player.name, player.stay_turns))
        state.current_phase = phase.END_TURN
        return false
    end
    return true
end

local function advance_to_next_player(state)
    local alive = {}
    for _, p in ipairs(state.players) do
        if not Player.is_bankrupt(p) then
            table.insert(alive, p)
        end
    end
    if #alive <= 1 then
        state.winner = alive[1] and alive[1].id or nil
        if state.winner then
            state.ui = { title = "游戏结束", message = string.format("玩家%d 获胜！", state.winner) }
        end
        return
    end

    repeat
        state.current_player_index = state.current_player_index + 1
        if state.current_player_index > #state.players then
            state.current_player_index = 1
            state.current_turn = state.current_turn + 1
        end
    until not Player.is_bankrupt(state.players[state.current_player_index])

    state.current_phase = phase.ROLL
    state.pending_move = nil
end

function game.create_new_game(config, player_count)
    local cfg = config or Config
    local tiles = Property.create_from_config(cfg)
    local tile_count = #tiles
    local players = create_players(cfg, player_count or 4, tile_count)

    game.state = {
        config = cfg,
        cfg = cfg,
        tiles = tiles,
        tile_count = tile_count,
        tile_index_by_type = build_tile_index_by_type(tiles),
        chance_deck = Chance.create_from_config(cfg),
        players = players,
        current_player_index = 1,
        current_phase = phase.ROLL,
        current_turn = 1,
        last_dice = nil,
        pending_move = nil,
        last_log = "",
        logs = {},
        auto_mode = false,
        base_auto_interval = cfg.rules.auto_step_interval or 1.0,
        auto_interval = cfg.rules.auto_step_interval or 1.0,
        auto_timer = 0,
        waiting_action = nil,
        ui = nil,
        winner = nil
    }

    log(game.state, "新游戏开始，按空格投骰子")
    return game.state
end

function game.get_state()
    return game.state
end

function game.is_waiting_for_input()
    local state = game.state
    return state and state.waiting_action ~= nil
end

function game.is_auto_mode()
    local state = game.state
    return state and state.auto_mode
end

function game.toggle_auto_mode()
    local state = game.state
    if not state then
        return false
    end
    state.auto_mode = not state.auto_mode
    if state.auto_mode then
        reset_prompts(state)
    end
    return state.auto_mode
end

function game.set_auto_speed(multiplier)
    local state = game.state
    if not state then
        return
    end
    state.auto_interval = math.max(0.1, state.base_auto_interval * multiplier)
end

function game.buy_property()
    local state = game.state
    if not state then
        return
    end
    local player = current_player(state)
    local tile = state.tiles[player.position]
    if tile.type ~= "property" or tile.owner then
        log(state, "无法购买当前地块")
        state.current_phase = phase.END_TURN
        return
    end
    if player.money < tile.price then
        log(state, "金币不足，购买失败")
        state.current_phase = phase.END_TURN
        return
    end
    Property.buy(tile, player.id, tile.price)
    Player.subtract_money(player, tile.price)
    Player.acquire_property(player, tile.id)
    log(state, string.format("%s 购买了 %s", player.name, tile.name))
    state.current_phase = phase.END_TURN
end

function game.upgrade_property()
    local state = game.state
    if not state then
        return
    end
    local player = current_player(state)
    local tile = state.tiles[player.position]
    if tile.type ~= "property" or tile.owner ~= player.id then
        log(state, "当前地块无法升级")
        return
    end
    local cost = Property.calculate_upgrade_cost(tile)
    if cost <= 0 or player.money < cost then
        log(state, "资金不足或已达最高等级")
        return
    end
    Property.upgrade(tile, player.id, cost)
    Player.subtract_money(player, cost)
    log(state, string.format("%s 将 %s 升级到等级 %d", player.name, tile.name, tile.building_level))
end

function game.skip_action()
    local state = game.state
    if not state then
        return
    end
    reset_prompts(state)
    state.current_phase = phase.END_TURN
end

function game.next_step()
    local state = game.state
    if not state or state.winner then
        return
    end
    if state.waiting_action then
        return
    end

    local player = current_player(state)
    if not player then
        return
    end

    if Player.is_bankrupt(player) then
        advance_to_next_player(state)
        return
    end

    if state.current_phase == phase.ROLL then
        if not prepare_turn(state, player) then
            return
        end
        local dice = player.pending_dice_override or math.random(1, 6)
        player.pending_dice_override = nil
        if player.pending_dice_double then
            dice = dice * 2
            player.pending_dice_double = false
        end
        state.last_dice = dice
        state.pending_move = dice
        log(state, string.format("%s 投出 %d 点", player.name, dice))
        state.current_phase = phase.MOVE
    elseif state.current_phase == phase.MOVE then
        move_player(state, player)
        state.current_phase = phase.RESOLVE
    elseif state.current_phase == phase.RESOLVE then
        local tile = state.tiles[player.position]
        if tile.type == "property" then
            resolve_property(state, player, tile)
        else
            resolve_special_tile(state, player, tile)
        end
    elseif state.current_phase == phase.END_TURN then
        advance_to_next_player(state)
    end
end

function game.update(dt)
    local state = game.state
    if not state or state.winner then
        return
    end
    if state.auto_mode and not state.waiting_action then
        state.auto_timer = state.auto_timer + dt
        if state.auto_timer >= state.auto_interval then
            state.auto_timer = 0
            game.next_step()
        end
    end
end

function game.draw()
    if game.state then
        Render.draw(game.state)
    end
end

function game.handle_input(key)
    Input.handle_key(key, game)
end

return game
