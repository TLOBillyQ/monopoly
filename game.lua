local class = require("Utils.ClassUtils").class
local config = require("config")
local Player = require("Player")
local Tile = require("Tile")
local ChanceDeck = require("chance")
local ItemSystem = require("ItemSystem")
local render = require("render")
local input = require("input")

local phase = {
    ROLL = "ROLL",
    MOVE = "MOVE",
    RESOLVE = "RESOLVE",
    END_TURN = "END"
}

---@class Game
---@field new fun(): Game
local Game = class("Game")

function Game:ctor()
    self.state = nil
    self.choose_yes = nil
    self.choose_no = nil
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

function Game:current_player()
    return self.state.players[self.state.current_player_index]
end

function Game:find_player_by_id(id)
    for _, p in ipairs(self.state.players) do
        if p.id == id then
            return p
        end
    end
end

function Game:log(message)
    local state = self.state
    state.last_log = message
    table.insert(state.logs, message)
    if #state.logs > 80 then
        table.remove(state.logs, 1)
    end
end

local function create_players(count, tile_count)
    local players = {}
    for i = 1, count do
        local character_id = (config.characters[i] and config.characters[i].id) or 1000 + i
        local vehicle_id = config.vehicles[1].id
        local is_ai = i > 1
        local p = Player.new(i, character_id, vehicle_id, is_ai, tile_count)
        p.money = config.rules.start_money
        p.total_assets = p.money
        table.insert(players, p)
    end
    return players
end

function Game:reset_prompts()
    self.state.waiting_action = nil
    self.state.ui = nil
    self.choose_yes = nil
    self.choose_no = nil
end

function Game:set_prompt(title, message, yes_fn, no_fn)
    local state = self.state
    state.waiting_action = { title = title }
    state.ui = {
        title = title,
        message = message,
        buttons = { "Y - 是", "N - 否" }
    }
    self.choose_yes = function()
        self:reset_prompts()
        yes_fn()
    end
    self.choose_no = function()
        self:reset_prompts()
        if no_fn then
            no_fn()
        end
    end
end

function Game:apply_bankruptcy_if_needed(player)
    if player.money <= 0 and not player:is_bankrupt() then
        player:bankrupt()
        for _, tile in ipairs(self.state.tiles) do
            if tile.owner == player.id then
                tile:reset()
            end
        end
        self:log(string.format("玩家%d 破产，退出游戏", player.id))
    end
end

function Game:apply_item_gain(player, item_id)
    if not item_id then
        self:log("未抽到任何道具")
        return
    end
    local added = player:add_item(item_id)
    local name = ItemSystem:get_name(item_id)
    if not added then
        self:log(string.format("%s 道具栏已满", name))
        return
    end
    self:log(string.format("%s 获得道具：%s", player.name, name))

    local use_result = ItemSystem:use(item_id, player, self.state)
    if use_result and use_result.message then
        self:log(use_result.message)
    end
end

function Game:handle_rent(tenant, tile)
    local owner = self:find_player_by_id(tile.owner)
    if not owner then
        return
    end
    local rent = math.floor(tile:calculate_rent(owner.buff_type == "wealth"))

    if tenant.free_pass then
        tenant.free_pass = false
        self:log(string.format("%s 使用免费卡，免租金", tenant.name))
        rent = 0
    elseif tenant.buff_type == "poor" and tenant.buff_turns > 0 then
        rent = rent * 2
    end

    if rent > 0 then
        Player.transfer(tenant, owner, rent)
        self:log(string.format("%s 向 %s 支付租金 %d", tenant.name, owner.name, rent))
        self:apply_bankruptcy_if_needed(tenant)
    else
        self:log(string.format("%s 本次无需支付租金", tenant.name))
    end
end

function Game:resolve_property(player, tile)
    if not tile.owner then
        if player.is_ai or self.state.auto_mode then
            if player.money >= tile.price then
                tile:buy(player.id, tile.price)
                player:subtract_money(tile.price)
                player:acquire_property(tile.id)
                self:log(string.format("%s 自动购买了 %s", player.name, tile.name))
            else
                self:log(string.format("%s 资金不足，无法购买 %s", player.name, tile.name))
            end
            self.state.current_phase = phase.END_TURN
            return
        end

        self:set_prompt(
            "购买地块？",
            string.format("%s - 价格 %d", tile.name, tile.price),
            function() self:buy_property() end,
            function() self:skip_action() end
        )
        return
    end

    if tile.owner == player.id then
        if (player.is_ai or self.state.auto_mode) and tile.building_level < Tile.buildings.mansion then
            local cost = tile:calculate_upgrade_cost()
            if cost > 0 and player.money > cost + 300 then
                tile:upgrade(player.id, cost)
                player:subtract_money(cost)
                self:log(string.format("%s 自动升级了 %s", player.name, tile.name))
            end
        end
        self.state.current_phase = phase.END_TURN
        return
    end

    self:handle_rent(player, tile)
    self.state.current_phase = phase.END_TURN
end

function Game:resolve_special_tile(player, tile)
    local rules = self.state.config.rules
    if tile.type == "chance_card" then
        local event = self.state.chance_deck:draw_random()
        local res = self.state.chance_deck:execute(event, player, self.state.players, self.state)
        self:log(res.message)
        self.state.current_phase = phase.END_TURN
    elseif tile.type == "item_card" then
        local item_id = ItemSystem:draw_random(self.state.config)
        self:apply_item_gain(player, item_id)
        self.state.current_phase = phase.END_TURN
    elseif tile.type == "hospital" then
        player:enter_hospital(rules.hospital_stay)
        player:subtract_money(rules.hospital_fee)
        self:log(string.format("%s 住院，需要等待 %d 回合", player.name, rules.hospital_stay))
        self:apply_bankruptcy_if_needed(player)
        self.state.current_phase = phase.END_TURN
    elseif tile.type == "mountain" then
        player:enter_mountain(rules.mountain_stay)
        self:log(string.format("%s 在深山停留 %d 回合", player.name, rules.mountain_stay))
        self.state.current_phase = phase.END_TURN
    elseif tile.type == "tax_office" then
        local tax = math.floor(player.money * rules.tax_rate)
        if player.free_pass then
            player.free_pass = false
            self:log(string.format("%s 使用免费卡，免税", player.name))
        else
            player:subtract_money(tax)
            self:log(string.format("%s 支付税金 %d", player.name, tax))
            self:apply_bankruptcy_if_needed(player)
        end
        self.state.current_phase = phase.END_TURN
    elseif tile.type == "black_market" then
        local cost = 600
        if player.is_ai or self.state.auto_mode then
            if player.money >= cost then
                player:subtract_money(cost)
                self:apply_item_gain(player, ItemSystem:draw_random(self.state.config))
            else
                self:log(string.format("%s 资金不足，无法在黑市购物", player.name))
            end
            self.state.current_phase = phase.END_TURN
        else
            self:set_prompt(
                "黑市购物？",
                string.format("花费 %d 获取随机道具", cost),
                function()
                    if player.money >= cost then
                        player:subtract_money(cost)
                        self:apply_item_gain(player, ItemSystem:draw_random(self.state.config))
                    else
                        self:log("金币不足，无法购物")
                    end
                    self:skip_action()
                end,
                function() self:skip_action() end
            )
        end
    elseif tile.type == "rest" then
        player:add_money(300)
        self:log(string.format("%s 休息并获得 300 金币", player.name))
        self.state.current_phase = phase.END_TURN
    elseif tile.type == "start" then
        player:add_money(math.floor(rules.pass_start_bonus / 2))
        self:log(string.format("%s 停在起点，获得奖励", player.name))
        self.state.current_phase = phase.END_TURN
    else
        self.state.current_phase = phase.END_TURN
    end
end

local function move_player(state, player)
    local steps = state.pending_move or state.last_dice or 0
    local tile_count = state.tile_count
    local old_pos = player.position
    local new_pos = ((old_pos - 1 + steps) % tile_count) + 1
    if new_pos < old_pos then
        player:add_money(state.config.rules.pass_start_bonus)
        state.game:log(string.format("%s 经过起点，获得 %d 金币", player.name, state.config.rules.pass_start_bonus))
    end
    player.position = new_pos
    state.game:log(string.format("%s 前进到格子 %d", player.name, new_pos))
end

local function prepare_turn(state, player)
    if player:is_bankrupt() then
        return false
    end
    player:start_turn()
    if player.state ~= Player.states.normal then
        state.game:log(string.format("%s 仍在等待，剩余 %d 回合", player.name, player.stay_turns))
        state.current_phase = phase.END_TURN
        return false
    end
    return true
end

function Game:advance_to_next_player()
    local state = self.state
    local alive = {}
    for _, p in ipairs(state.players) do
        if not p:is_bankrupt() then
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
    until not state.players[state.current_player_index]:is_bankrupt()

    state.current_phase = phase.ROLL
    state.pending_move = nil
end

function Game:create_new_game(player_count)
    local tiles = Tile.create_from_config()
    local tile_count = #tiles
    local players = create_players(player_count, tile_count)

    self.state = {
        tiles = tiles,
        tile_count = tile_count,
        tile_index_by_type = build_tile_index_by_type(tiles),
        chance_deck = ChanceDeck.from_config(),
        players = players,
        current_player_index = 1,
        current_phase = phase.ROLL,
        current_turn = 1,
        last_dice = nil,
        pending_move = nil,
        last_log = "",
        logs = {},
        auto_mode = false,
        base_auto_interval = config.rules.auto_step_interval,
        auto_interval = config.rules.auto_step_interval,
        auto_timer = 0,
        waiting_action = nil,
        ui = nil,
        winner = nil,
        config = config,
        game = self
    }

    self:log("新游戏开始，按空格投骰子")
    return self.state
end

function Game:get_state()
    return self.state
end

function Game:is_waiting_for_input()
    local state = self.state
    return state and state.waiting_action ~= nil
end

function Game:is_auto_mode()
    local state = self.state
    return state and state.auto_mode
end

function Game:toggle_auto_mode()
    local state = self.state
    if not state then
        return false
    end
    state.auto_mode = not state.auto_mode
    if state.auto_mode then
        self:reset_prompts()
    end
    return state.auto_mode
end

function Game:set_auto_speed(multiplier)
    local state = self.state
    if not state then
        return
    end
    state.auto_interval = math.max(0.1, state.base_auto_interval * multiplier)
end

function Game:buy_property()
    local state = self.state
    if not state then
        return
    end
    local player = self:current_player()
    local tile = state.tiles[player.position]
    if tile.type ~= "property" or tile.owner then
        self:log("无法购买当前地块")
        state.current_phase = phase.END_TURN
        return
    end
    if player.money < tile.price then
        self:log("金币不足，购买失败")
        state.current_phase = phase.END_TURN
        return
    end
    tile:buy(player.id, tile.price)
    player:subtract_money(tile.price)
    player:acquire_property(tile.id)
    self:log(string.format("%s 购买了 %s", player.name, tile.name))
    state.current_phase = phase.END_TURN
end

function Game:upgrade_property()
    local state = self.state
    if not state then
        return
    end
    local player = self:current_player()
    local tile = state.tiles[player.position]
    if tile.type ~= "property" or tile.owner ~= player.id then
        self:log("当前地块无法升级")
        return
    end
    local cost = tile:calculate_upgrade_cost()
    if cost <= 0 or player.money < cost then
        self:log("资金不足或已达最高等级")
        return
    end
    tile:upgrade(player.id, cost)
    player:subtract_money(cost)
    self:log(string.format("%s 将 %s 升级到等级 %d", player.name, tile.name, tile.building_level))
end

function Game:skip_action()
    if not self.state then
        return
    end
    self:reset_prompts()
    self.state.current_phase = phase.END_TURN
end

function Game:next_step()
    local state = self.state
    if not state or state.winner then
        return
    end
    if state.waiting_action then
        return
    end

    local player = self:current_player()
    if not player then
        return
    end

    if player:is_bankrupt() then
        self:advance_to_next_player()
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
        self:log(string.format("%s 投出 %d 点", player.name, dice))
        state.current_phase = phase.MOVE
    elseif state.current_phase == phase.MOVE then
        move_player(state, player)
        state.current_phase = phase.RESOLVE
    elseif state.current_phase == phase.RESOLVE then
        local tile = state.tiles[player.position]
        if tile.type == "property" then
            self:resolve_property(player, tile)
        else
            self:resolve_special_tile(player, tile)
        end
    elseif state.current_phase == phase.END_TURN then
        self:advance_to_next_player()
    end
end

function Game:update(dt)
    local state = self.state
    if not state or state.winner then
        return
    end
    if state.auto_mode and not state.waiting_action then
        state.auto_timer = state.auto_timer + dt
        if state.auto_timer >= state.auto_interval then
            state.auto_timer = 0
            self:next_step()
        end
    end
end

function Game:draw()
    if self.state then
        render.draw(self.state)
    end
end

function Game:handle_input(key)
    input.handle_key(key, self)
end

local game = Game.new()
return game
