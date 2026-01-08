local Config = require("config")
local Player = require("player")
local Property = require("property")
local Chance = require("chance")
local Item = require("item")
local Render = require("render")
local Input = require("input")

local GameManager = {}

local Phase = {
    ROLL = "ROLL",
    MOVE = "MOVE",
    RESOLVE = "RESOLVE",
    END_TURN = "END"
}

local function currentPlayer(state)
    return state.players[state.currentPlayerIndex]
end

local function findPlayerById(state, id)
    for _, p in ipairs(state.players) do
        if p.id == id then
            return p
        end
    end
end

local function log(state, message)
    state.lastLog = message
    table.insert(state.logs, message)
    if #state.logs > 80 then
        table.remove(state.logs, 1)
    end
end

local function buildTileIndexByType(tiles)
    local map = {}
    for _, tile in ipairs(tiles) do
        if tile.type and not map[tile.type] then
            map[tile.type] = tile.id
        end
    end
    return map
end

local function createPlayers(config, count, tileCount)
    local players = {}
    for i = 1, count do
        local characterId = (config.characters[i] and config.characters[i].id) or 1000 + i
        local vehicleId = config.vehicles[1].id
        local isAI = i > 1
        local player = Player.new(i, characterId, vehicleId, isAI, tileCount)
        player.money = config.rules.startMoney
        player.totalAssets = player.money
        table.insert(players, player)
    end
    return players
end

local function resetPrompts(state)
    state.waitingAction = nil
    state.ui = nil
    GameManager.chooseYes = nil
    GameManager.chooseNo = nil
end

local function setPrompt(state, title, message, yesFn, noFn)
    state.waitingAction = {title = title}
    state.ui = {
        title = title,
        message = message,
        buttons = {"Y - 是", "N - 否"}
    }
    GameManager.chooseYes = function()
        resetPrompts(state)
        yesFn()
    end
    GameManager.chooseNo = function()
        resetPrompts(state)
        if noFn then
            noFn()
        end
    end
end

local function applyBankruptcyIfNeeded(state, player)
    if player.money <= 0 and not Player.isBankrupt(player) then
        Player.bankrupt(player)
        for _, tile in ipairs(state.tiles) do
            if tile.owner == player.id then
                Property.reset(tile)
            end
        end
        log(state, string.format("玩家%d 破产，退出游戏", player.id))
    end
end

local function applyItemGain(state, player, itemId)
    if not itemId then
        log(state, "未抽到任何道具")
        return
    end
    local added = Player.addItem(player, itemId)
    local name = Item.getName(itemId)
    if not added then
        log(state, string.format("%s 道具栏已满", name))
        return
    end
    log(state, string.format("%s 获得道具：%s", player.name, name))
    
    -- 所有道具均为即时效果，获得后立刻生效
    local useResult = Item.use(itemId, player, state)
    if useResult and useResult.message then
        log(state, useResult.message)
    end
end

local function handleRent(state, tenant, tile)
    local owner = findPlayerById(state, tile.owner)
    if not owner then
        return
    end
    local rent = math.floor(Property.calculateRent(tile, owner.buffType == "wealth"))
    
    if tenant.freePass then
        tenant.freePass = false
        log(state, string.format("%s 使用免费卡，免租金", tenant.name))
        rent = 0
    elseif tenant.buffType == "poor" and tenant.buffTurns > 0 then
        rent = rent * 2
    end
    
    if rent > 0 then
        Player.transfer(tenant, owner, rent)
        log(state, string.format("%s 向 %s 支付租金 %d", tenant.name, owner.name, rent))
        applyBankruptcyIfNeeded(state, tenant)
    else
        log(state, string.format("%s 本次无需支付租金", tenant.name))
    end
end

local function resolveProperty(state, player, tile)
    if not tile.owner then
        if player.isAI or state.autoMode then
            if player.money >= tile.price then
                Property.buy(tile, player.id, tile.price)
                Player.subtractMoney(player, tile.price)
                Player.acquireProperty(player, tile.id)
                log(state, string.format("%s 自动购买了 %s", player.name, tile.name))
            else
                log(state, string.format("%s 资金不足，无法购买 %s", player.name, tile.name))
            end
            state.currentPhase = Phase.END_TURN
            return
        end
        
        setPrompt(
            state,
            "购买地块？",
            string.format("%s - 价格 %d", tile.name, tile.price),
            function() GameManager.buyProperty() end,
            function() GameManager.skipAction() end
        )
        return
    end
    
    if tile.owner == player.id then
        if (player.isAI or state.autoMode) and tile.building_level < Property.Building.MANSION then
            local cost = Property.calculateUpgradeCost(tile)
            if cost > 0 and player.money > cost + 300 then
                Property.upgrade(tile, player.id, cost)
                Player.subtractMoney(player, cost)
                log(state, string.format("%s 自动升级了 %s", player.name, tile.name))
            end
        end
        state.currentPhase = Phase.END_TURN
        return
    end
    
    handleRent(state, player, tile)
    state.currentPhase = Phase.END_TURN
end

local function resolveSpecialTile(state, player, tile)
    local rules = state.config.rules
    if tile.type == "chance_card" then
        local event = Chance.drawRandom(state.chanceDeck)
        local res = Chance.execute(event, player, state.players, state)
        log(state, res.message)
        state.currentPhase = Phase.END_TURN
    elseif tile.type == "item_card" then
        local itemId = Item.drawRandom(state.config)
        applyItemGain(state, player, itemId)
        state.currentPhase = Phase.END_TURN
    elseif tile.type == "hospital" then
        Player.enterHospital(player, rules.hospitalStay)
        Player.subtractMoney(player, rules.hospitalFee)
        log(state, string.format("%s 住院，需要等待 %d 回合", player.name, rules.hospitalStay))
        applyBankruptcyIfNeeded(state, player)
        state.currentPhase = Phase.END_TURN
    elseif tile.type == "mountain" then
        Player.enterMountain(player, rules.mountainStay)
        log(state, string.format("%s 在深山停留 %d 回合", player.name, rules.mountainStay))
        state.currentPhase = Phase.END_TURN
    elseif tile.type == "tax_office" then
        local tax = math.floor(player.money * rules.taxRate)
        if player.freePass then
            player.freePass = false
            log(state, string.format("%s 使用免费卡，免税", player.name))
        else
            Player.subtractMoney(player, tax)
            log(state, string.format("%s 支付税金 %d", player.name, tax))
            applyBankruptcyIfNeeded(state, player)
        end
        state.currentPhase = Phase.END_TURN
    elseif tile.type == "black_market" then
        local cost = 600
        if player.isAI or state.autoMode then
            if player.money >= cost then
                Player.subtractMoney(player, cost)
                applyItemGain(state, player, Item.drawRandom(state.config))
            else
                log(state, string.format("%s 资金不足，无法在黑市购物", player.name))
            end
            state.currentPhase = Phase.END_TURN
        else
            setPrompt(
                state,
                "黑市购物？",
                string.format("花费 %d 获取随机道具", cost),
                function()
                    if player.money >= cost then
                        Player.subtractMoney(player, cost)
                        applyItemGain(state, player, Item.drawRandom(state.config))
                    else
                        log(state, "金币不足，无法购物")
                    end
                    GameManager.skipAction()
                end,
                function() GameManager.skipAction() end
            )
        end
    elseif tile.type == "rest" then
        Player.addMoney(player, 300)
        log(state, string.format("%s 休息并获得 300 金币", player.name))
        state.currentPhase = Phase.END_TURN
    elseif tile.type == "start" then
        Player.addMoney(player, math.floor(rules.passStartBonus / 2))
        log(state, string.format("%s 停在起点，获得奖励", player.name))
        state.currentPhase = Phase.END_TURN
    else
        state.currentPhase = Phase.END_TURN
    end
end

local function movePlayer(state, player)
    local steps = state.pendingMove or state.lastDice or 0
    local tileCount = state.tileCount
    local oldPos = player.position
    local newPos = ((oldPos - 1 + steps) % tileCount) + 1
    if newPos < oldPos then
        Player.addMoney(player, state.config.rules.passStartBonus)
        log(state, string.format("%s 经过起点，获得 %d 金币", player.name, state.config.rules.passStartBonus))
    end
    player.position = newPos
    log(state, string.format("%s 前进到格子 %d", player.name, newPos))
end

local function prepareTurn(state, player)
    if Player.isBankrupt(player) then
        return false
    end
    Player.startTurn(player)
    if player.state ~= Player.State.NORMAL then
        log(state, string.format("%s 仍在等待，剩余 %d 回合", player.name, player.stayTurns))
        state.currentPhase = Phase.END_TURN
        return false
    end
    return true
end

local function advanceToNextPlayer(state)
    local alive = {}
    for _, p in ipairs(state.players) do
        if not Player.isBankrupt(p) then
            table.insert(alive, p)
        end
    end
    if #alive <= 1 then
        state.winner = alive[1] and alive[1].id or nil
        if state.winner then
            state.ui = {title = "游戏结束", message = string.format("玩家%d 获胜！", state.winner)}
        end
        return
    end
    
    repeat
        state.currentPlayerIndex = state.currentPlayerIndex + 1
        if state.currentPlayerIndex > #state.players then
            state.currentPlayerIndex = 1
            state.currentTurn = state.currentTurn + 1
        end
    until not Player.isBankrupt(state.players[state.currentPlayerIndex])
    
    state.currentPhase = Phase.ROLL
    state.pendingMove = nil
end

function GameManager.createNewGame(config, playerCount)
    local cfg = config or Config
    local tiles = Property.createFromConfig(cfg)
    local tileCount = #tiles
    local players = createPlayers(cfg, playerCount or 4, tileCount)
    
    GameManager.state = {
        config = cfg,
        cfg = cfg,
        tiles = tiles,
        tileCount = tileCount,
        tileIndexByType = buildTileIndexByType(tiles),
        chanceDeck = Chance.createFromConfig(cfg),
        players = players,
        currentPlayerIndex = 1,
        currentPhase = Phase.ROLL,
        currentTurn = 1,
        lastDice = nil,
        pendingMove = nil,
        lastLog = "",
        logs = {},
        autoMode = false,
        baseAutoInterval = cfg.rules.autoStepInterval or 1.0,
        autoInterval = cfg.rules.autoStepInterval or 1.0,
        autoTimer = 0,
        waitingAction = nil,
        ui = nil,
        winner = nil
    }
    
    log(GameManager.state, "新游戏开始，按空格投骰子")
    return GameManager.state
end

function GameManager.getState()
    return GameManager.state
end

function GameManager.isWaitingForInput()
    local state = GameManager.state
    return state and state.waitingAction ~= nil
end

function GameManager.isAutoMode()
    local state = GameManager.state
    return state and state.autoMode
end

function GameManager.toggleAutoMode()
    local state = GameManager.state
    if not state then
        return false
    end
    state.autoMode = not state.autoMode
    if state.autoMode then
        resetPrompts(state)
    end
    return state.autoMode
end

function GameManager.setAutoSpeed(multiplier)
    local state = GameManager.state
    if not state then
        return
    end
    state.autoInterval = math.max(0.1, state.baseAutoInterval * multiplier)
end

function GameManager.buyProperty()
    local state = GameManager.state
    if not state then
        return
    end
    local player = currentPlayer(state)
    local tile = state.tiles[player.position]
    if tile.type ~= "property" or tile.owner then
        log(state, "无法购买当前地块")
        state.currentPhase = Phase.END_TURN
        return
    end
    if player.money < tile.price then
        log(state, "金币不足，购买失败")
        state.currentPhase = Phase.END_TURN
        return
    end
    Property.buy(tile, player.id, tile.price)
    Player.subtractMoney(player, tile.price)
    Player.acquireProperty(player, tile.id)
    log(state, string.format("%s 购买了 %s", player.name, tile.name))
    state.currentPhase = Phase.END_TURN
end

function GameManager.upgradeProperty()
    local state = GameManager.state
    if not state then
        return
    end
    local player = currentPlayer(state)
    local tile = state.tiles[player.position]
    if tile.type ~= "property" or tile.owner ~= player.id then
        log(state, "当前地块无法升级")
        return
    end
    local cost = Property.calculateUpgradeCost(tile)
    if cost <= 0 or player.money < cost then
        log(state, "资金不足或已达最高等级")
        return
    end
    Property.upgrade(tile, player.id, cost)
    Player.subtractMoney(player, cost)
    log(state, string.format("%s 将 %s 升级到等级 %d", player.name, tile.name, tile.building_level))
end

function GameManager.skipAction()
    local state = GameManager.state
    if not state then
        return
    end
    resetPrompts(state)
    state.currentPhase = Phase.END_TURN
end

function GameManager.nextStep()
    local state = GameManager.state
    if not state or state.winner then
        return
    end
    if state.waitingAction then
        return
    end
    
    local player = currentPlayer(state)
    if not player then
        return
    end
    
    if Player.isBankrupt(player) then
        advanceToNextPlayer(state)
        return
    end
    
    if state.currentPhase == Phase.ROLL then
        if not prepareTurn(state, player) then
            return
        end
        local dice = player.pendingDiceOverride or math.random(1, 6)
        player.pendingDiceOverride = nil
        if player.pendingDiceDouble then
            dice = dice * 2
            player.pendingDiceDouble = false
        end
        state.lastDice = dice
        state.pendingMove = dice
        log(state, string.format("%s 投出 %d 点", player.name, dice))
        state.currentPhase = Phase.MOVE
        
    elseif state.currentPhase == Phase.MOVE then
        movePlayer(state, player)
        state.currentPhase = Phase.RESOLVE
        
    elseif state.currentPhase == Phase.RESOLVE then
        local tile = state.tiles[player.position]
        if tile.type == "property" then
            resolveProperty(state, player, tile)
        else
            resolveSpecialTile(state, player, tile)
        end
        
    elseif state.currentPhase == Phase.END_TURN then
        advanceToNextPlayer(state)
    end
end

function GameManager.update(dt)
    local state = GameManager.state
    if not state or state.winner then
        return
    end
    if state.autoMode and not state.waitingAction then
        state.autoTimer = state.autoTimer + dt
        if state.autoTimer >= state.autoInterval then
            state.autoTimer = 0
            GameManager.nextStep()
        end
    end
end

function GameManager.draw()
    if GameManager.state then
        Render.draw(GameManager.state)
    end
end

function GameManager.handleInput(key)
    Input.handleKey(key, GameManager)
end

return GameManager
