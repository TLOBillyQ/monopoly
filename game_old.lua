-- New consolidated game state and logic

local Game = {}

local AUTO_SIM = true -- 自动模拟整局，无需按键或确认
local STEP_INTERVAL = 0.1 -- 自动推进的时间间隔（秒）

local Phase = {
    BEFORE = "before_action",
    ROLL = "roll",
    MOVE = "move",
    EVENT = "event",
    AFTER = "after_action"
}

local function shallowCopy(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local function weightedPick(list)
    local total = 0
    for _, item in ipairs(list) do total = total + (item.weight or 1) end
    local roll = math.random() * total
    local acc = 0
    for _, item in ipairs(list) do
        acc = acc + (item.weight or 1)
        if roll <= acc then return item end
    end
    return list[1]
end

local function buildTileState(configTiles)
    local tiles = {}
    for i, t in ipairs(configTiles) do
        tiles[i] = {
            id = i,
            name = t.name,
            type = t.type,
            price = t.price or 0,
            owner = nil,
            building = 0 -- 0~3
        }
    end
    return tiles
end

local function newPlayer(id, isAI, cfg)
    return {
        id = id,
        name = isAI and ("AI" .. id) or ("玩家" .. id),
        isAI = isAI,
        money = cfg.startMoney,
        position = 1,
        stay = 0,
        stayType = nil,
        items = {},
        angel = 0,
        poor = 0,
        wealth = 0,
        eliminated = false
    }
end

local function tileRent(tile)
    if tile.type ~= "empty" or not tile.owner then return 0 end
    local base = tile.price
    if tile.building == 0 then return base * 0.5 end
    local last = base * (2 ^ tile.building)
    return last * 0.5
end

local function tileUpgradePrice(tile)
    if tile.type ~= "empty" or not tile.owner then return 0 end
    if tile.building >= 3 then return 0 end
    local times = tile.building + 1
    return tile.price * (2 ^ times)
end

local function addMoney(p, amt)
    p.money = p.money + amt
    if p.money < 0 then p.money = 0 end
end

local function moveSteps(state, player, steps)
    local count = #state.tiles
    local start = player.position
    local raw = ((start - 1 + steps) % count) + 1
    if steps > 0 and (start + steps) > count then
        addMoney(player, state.cfg.passStartBonus)
        state.lastLog = player.name .. "经过起点 +" .. state.cfg.passStartBonus
    end
    player.position = raw
    return raw
end

local function nextActiveIndex(state, idx)
    local total = #state.players
    local i = idx
    repeat
        i = i + 1
        if i > total then i = 1 end
        local p = state.players[i]
        if not p.eliminated then return i end
    until false
end

local checkVictory -- forward declaration

local function eliminate(state, player)
    player.eliminated = true
    for _, tile in ipairs(state.tiles) do
        if tile.owner == player.id then
            tile.owner = nil
            tile.building = 0
        end
    end
    state.lastLog = player.name .. " 破产出局"
    checkVictory(state)
end

function checkVictory(state)
    local alive = {}
    for _, p in ipairs(state.players) do
        if not p.eliminated then table.insert(alive, p) end
    end
    if #alive <= 1 then
        state.finished = true
        state.winner = alive[1]
        if #alive == 1 then
            state.lastLog = alive[1].name .. " 获胜！"
        else
            state.lastLog = "所有玩家出局，平局"
        end
        return true
    end
    return false
end

local function applyChance(state, player)
    local card = weightedPick(state.cfg.chanceCards)
    local log = card.name
    if card.kind == "gain_money" then
        addMoney(player, card.value)
        log = log .. " +" .. card.value
    elseif card.kind == "lose_money" then
        addMoney(player, -card.value)
        if player.money == 0 then eliminate(state, player) end
        log = log .. " -" .. card.value
    elseif card.kind == "lose_percent" then
        local loss = math.floor(player.money * card.value)
        addMoney(player, -loss)
        if player.money == 0 then eliminate(state, player) end
        log = log .. " -" .. loss
    elseif card.kind == "collect" then
        for _, other in ipairs(state.players) do
            if other ~= player and not other.eliminated then
                local pay = math.min(other.money, card.value)
                addMoney(other, -pay)
                addMoney(player, pay)
            end
        end
        log = log .. " 向他人收取" .. card.value
    elseif card.kind == "pay_others" then
        for _, other in ipairs(state.players) do
            if other ~= player and not other.eliminated then
                local pay = math.min(player.money, card.value)
                addMoney(player, -pay)
                addMoney(other, pay)
            end
        end
        if player.money == 0 then eliminate(state, player) end
        log = log .. " 支付每人" .. card.value
    elseif card.kind == "move" then
        moveSteps(state, player, card.value)
        log = log .. " 移动" .. card.value .. "格"
    elseif card.kind == "gain_item" then
        if #player.items < state.cfg.maxItemSlots then
            table.insert(player.items, card.value)
            log = log .. " 获得道具" .. card.value
        else
            log = log .. " 道具栏已满"
        end
    elseif card.kind == "lose_item" then
        if #player.items > 0 then
            table.remove(player.items)
            log = log .. " 丢弃一个道具"
        else
            log = log .. " 无道具可丢弃"
        end
    end
    state.lastLog = log
end

local function drawItem(state, player)
    if #player.items >= state.cfg.maxItemSlots then
        state.lastLog = player.name .. " 道具栏已满"
        return
    end
    local card = weightedPick(state.cfg.itemCards)
    table.insert(player.items, card.type)
    state.lastLog = player.name .. " 获得道具 " .. card.name
end

local function buyFromBlackMarket(state, player)
    if #player.items >= state.cfg.maxItemSlots then
        state.lastLog = player.name .. " 黑市购物失败：卡槽已满"
        return
    end
    local price = state.cfg.blackMarketPrice or 0
    if player.money < price then
        state.lastLog = player.name .. " 黑市购物失败：资金不足"
        return
    end
    addMoney(player, -price)
    local card = weightedPick(state.cfg.itemCards)
    table.insert(player.items, card.type)
    state.lastLog = player.name .. " 在黑市购买了道具 " .. card.name .. " 花费" .. price
end

local function chargeRent(state, player, tile)
    local rent = tileRent(tile)
    local owner = state.players[tile.owner]
    if owner.eliminated then return end
    if owner.stayType == "mountain" and owner.stay > 0 then
        state.lastLog = owner.name .. " 在深山，免收租金"
        return
    end
    if player.money >= rent then
        addMoney(player, -rent)
        addMoney(owner, rent)
        state.lastLog = player.name .. " 支付租金 " .. rent
    else
        addMoney(owner, player.money)
        addMoney(player, -player.money)
        eliminate(state, player)
    end
end

local function promptDecision(state, opts)
    state.waiting = opts
    state.timer = 0
end

local GameState = {
    cfg = nil,
    tiles = {},
    players = {},
    current = 1,
    phase = Phase.BEFORE,
    turn = 1,
    timer = 0,
    waiting = nil,
    ui = nil,
    lastLog = "",
    finished = false,
    winner = nil,
    autoTimer = 0
}

function Game.init(cfg)
    GameState.cfg = {
        maxPlayers = cfg.rules.maxPlayers,
        minPlayers = cfg.rules.minPlayers,
        startMoney = cfg.rules.startMoney,
        passStartBonus = cfg.rules.passStartBonus,
        hospitalFee = cfg.rules.hospitalFee,
        hospitalStay = cfg.rules.hospitalStay,
        mountainStay = cfg.rules.mountainStay,
        turnTimeout = cfg.rules.turnTimeout,
        maxItemSlots = cfg.rules.maxItemSlots,
        blackMarketPrice = cfg.rules.blackMarketPrice,
        chanceCards = cfg.chanceCards,
        itemCards = cfg.itemCards,
        tiles = cfg.tiles,
        colors = cfg.colors
    }
    GameState.tiles = buildTileState(cfg.tiles)
    GameState.players = {}
    GameState.current = 1
    GameState.phase = Phase.BEFORE
    GameState.turn = 1
    GameState.waiting = nil
    GameState.ui = nil
    GameState.lastLog = "自动模拟中"
    GameState.finished = false
    GameState.winner = nil
    GameState.autoTimer = 0
end

function Game.startNewGame(humans)
    humans = math.max(1, math.min(GameState.cfg.maxPlayers, humans or 1))
    GameState.players = {}
    for i = 1, humans do
        table.insert(GameState.players, newPlayer(i, false, GameState.cfg))
    end
    for i = humans + 1, GameState.cfg.maxPlayers do
        table.insert(GameState.players, newPlayer(i, true, GameState.cfg))
    end
    GameState.current = 1
    GameState.phase = Phase.BEFORE
    GameState.turn = 1
    GameState.tiles = buildTileState(GameState.cfg.tiles)
    GameState.waiting = nil
    GameState.lastLog = "新游戏开始"
    GameState.finished = false
    GameState.winner = nil
    GameState.autoTimer = 0
end

function Game.getState()
    return GameState
end

local function beginDecision(state, title, msg, yesFn, noFn)
    state.ui = {
        title = title,
        message = msg,
        buttons = {"Y 确认", "N 放弃"}
    }
    promptDecision(state, {accept = yesFn, reject = noFn})
end

function Game.update(dt)
    GameState.timer = GameState.timer + dt
    if GameState.finished then return end

    if GameState.waiting and GameState.timer >= GameState.cfg.turnTimeout then
        if GameState.waiting.reject then GameState.waiting.reject() end
        GameState.waiting = nil
        GameState.ui = nil
        GameState.phase = Phase.AFTER
        GameState.timer = 0
        Game.advance()
    end

    if AUTO_SIM then
        GameState.autoTimer = GameState.autoTimer + dt
        while GameState.autoTimer >= STEP_INTERVAL and not GameState.finished and not GameState.waiting do
            Game.advance()
            GameState.autoTimer = GameState.autoTimer - STEP_INTERVAL
        end
    end
end

function Game.advance()
    if GameState.finished then return end
    if GameState.waiting then return end

    local p = GameState.players[GameState.current]
    if p.eliminated then
        GameState.current = nextActiveIndex(GameState, GameState.current)
        return
    end

    if GameState.phase == Phase.BEFORE then
        GameState.phase = Phase.ROLL
        GameState.timer = 0
        local dice = math.random(1, 6)
        GameState.lastRoll = dice
        local pos = moveSteps(GameState, p, dice)
        GameState.phase = Phase.EVENT
        local tile = GameState.tiles[pos]

        -- handle tile event
        if tile.type == "start" then
            GameState.lastLog = p.name .. " 停留在起点"
        elseif tile.type == "empty" then
            if not tile.owner then
                local price = tile.price
                if p.money >= price then
                    addMoney(p, -price)
                    tile.owner = p.id
                    GameState.lastLog = p.name .. " 购入 " .. tile.name
                else
                    GameState.lastLog = p.name .. " 资金不足，放弃购买"
                end
            elseif tile.owner == p.id then
                local up = tileUpgradePrice(tile)
                if up > 0 then
                    if p.money >= up then
                        addMoney(p, -up)
                        tile.building = tile.building + 1
                        GameState.lastLog = p.name .. " 加盖 " .. tile.name
                    else
                        GameState.lastLog = p.name .. " 资金不足，放弃加盖"
                    end
                else
                    GameState.lastLog = tile.name .. " 已是高楼"
                end
            else
                chargeRent(GameState, p, tile)
            end
        elseif tile.type == "chance" then
            applyChance(GameState, p)
        elseif tile.type == "item" then
            drawItem(GameState, p)
        elseif tile.type == "hospital" then
            local fee = GameState.cfg.hospitalFee
            if p.money >= fee then
                addMoney(p, -fee)
                p.stay = GameState.cfg.hospitalStay
                p.stayType = "hospital"
                GameState.lastLog = p.name .. " 入院 停留" .. p.stay .. "回合"
            else
                eliminate(GameState, p)
            end
        elseif tile.type == "mountain" then
            p.stay = GameState.cfg.mountainStay
            p.stayType = "mountain"
            GameState.lastLog = p.name .. " 被困深山 " .. p.stay .. "回合"
        elseif tile.type == "tax" then
            local tax = math.floor(p.money * 0.5)
            addMoney(p, -tax)
            GameState.lastLog = p.name .. " 缴税 " .. tax
            if p.money == 0 then eliminate(GameState, p) end
        elseif tile.type == "black_market" then
            buyFromBlackMarket(GameState, p)
        end

        if not GameState.waiting then
            GameState.phase = Phase.AFTER
            Game.advance() -- immediately go after_action
        end

    elseif GameState.phase == Phase.AFTER then
        -- tick stay counters
        if p.stay and p.stay > 0 then
            p.stay = p.stay - 1
            if p.stay <= 0 then p.stayType = nil end
        end

        if checkVictory(GameState) then return end

        -- next player
        GameState.current = nextActiveIndex(GameState, GameState.current)
        GameState.phase = Phase.BEFORE
        GameState.turn = GameState.turn + 1
        GameState.timer = 0
    end
end

function Game.chooseYes()
    if GameState.waiting then
        if GameState.waiting.accept then GameState.waiting.accept() end
        GameState.waiting = nil
        GameState.ui = nil
        GameState.phase = Phase.AFTER
        GameState.timer = 0
        Game.advance()
    end
end

function Game.chooseNo()
    if GameState.waiting then
        if GameState.waiting.reject then GameState.waiting.reject() end
        GameState.waiting = nil
        GameState.ui = nil
        GameState.phase = Phase.AFTER
        GameState.timer = 0
        Game.advance()
    end
end

return Game
